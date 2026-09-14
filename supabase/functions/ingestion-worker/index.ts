// WP3 — Worker d'ingestion (consigne #6). Traite la file `ai_ingestion_jobs` : collecte URL
// (robots.txt respecté), extraction texte + métadonnées, déduplication, classement pédagogique
// (via ai-curriculum-mapping), et indexation RAG (via ai-embeddings-generate) UNIQUEMENT après
// validation humaine de l'extrait.
//
// Non bloquant : déclenché depuis l'admin, écrit la progression sur la ligne de job, reprend là où
// il s'était arrêté. Respecte `cancel_requested`. Le texte collecté est traité comme **non fiable** :
// il n'est jamais injecté dans les instructions d'un agent (seul ai-curriculum-mapping le lit, et
// il ne fait que du rapprochement lexical déterministe, sans prompt LLM).
//
// Limites honnêtes : profondeur de collecte 0 (page unique) dans cette itération ; OCR d'images /
// PDF scannés non disponible (aucun moteur vision auto-hébergé à coût zéro).
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&#\d+;/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

async function md5Hex(s: string): Promise<string> {
  // md5 non dispo dans Web Crypto ; on utilise SHA-256 tronqué comme empreinte de dédup.
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** robots.txt : refus si une règle `Disallow` pour `User-agent: *` couvre le chemin. */
async function robotsAllows(url: URL): Promise<{ allowed: boolean; reason: string }> {
  try {
    const r = await fetch(`${url.origin}/robots.txt`, { signal: AbortSignal.timeout(8000) });
    if (!r.ok) return { allowed: true, reason: "robots.txt absent — collecte autorisée par défaut." };
    const body = await r.text();
    const lines = body.split("\n").map((l) => l.trim());
    let appliesToAll = false;
    const disallows: string[] = [];
    for (const line of lines) {
      const low = line.toLowerCase();
      if (low.startsWith("user-agent:")) {
        appliesToAll = line.split(":")[1].trim() === "*";
      } else if (appliesToAll && low.startsWith("disallow:")) {
        const p = line.split(":").slice(1).join(":").trim();
        if (p) disallows.push(p);
      }
    }
    for (const d of disallows) {
      if (d === "/" || url.pathname.startsWith(d)) {
        return { allowed: false, reason: `Interdit par robots.txt (Disallow: ${d}).` };
      }
    }
    return { allowed: true, reason: "Autorisé par robots.txt." };
  } catch (_e) {
    return { allowed: true, reason: "robots.txt injoignable — collecte autorisée par défaut." };
  }
}

async function pushError(jobId: string, msg: string) {
  const { data } = await admin.from("ai_ingestion_jobs").select("error_history, attempts").eq("id", jobId).maybeSingle();
  const hist = Array.isArray(data?.error_history) ? data!.error_history : [];
  hist.push({ at: new Date().toISOString(), message: msg });
  const attempts = (data?.attempts ?? 0);
  await admin.from("ai_ingestion_jobs").update({
    status: "failed", error_history: hist, updated_at: new Date().toISOString(),
    next_retry_at: new Date(Date.now() + 5 * 60_000).toISOString(),
    finished_at: new Date().toISOString(),
    progress_pct: 0,
  }).eq("id", jobId);
  void attempts;
}

async function processJob(job: any, jwt: string): Promise<{ ok: boolean; note: string }> {
  const jobId = job.id;
  const { data: fresh } = await admin.from("ai_ingestion_jobs").select("cancel_requested").eq("id", jobId).maybeSingle();
  if (fresh?.cancel_requested) {
    await admin.from("ai_ingestion_jobs").update({ status: "cancelled", finished_at: new Date().toISOString() }).eq("id", jobId);
    return { ok: false, note: "annulé" };
  }

  await admin.from("ai_ingestion_jobs").update({
    status: "running", started_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    attempts: (job.attempts ?? 0) + 1, progress_pct: 5,
  }).eq("id", jobId);

  const { data: src } = await admin.from("ai_rag_sources").select("*").eq("id", job.source_id).maybeSingle();
  if (!src) { await pushError(jobId, "Source introuvable."); return { ok: false, note: "source introuvable" }; }

  try {
    // ---------- CRAWL / EXTRACT (URL) ----------
    if (job.job_type === "crawl" || (job.job_type === "extract" && src.source_type === "url")) {
      if (!src.access_terms_ack) {
        await pushError(jobId, "Conditions d'accès non attestées (access_terms_ack = false).");
        return { ok: false, note: "CGU non attestées" };
      }
      const url = new URL(src.source_url);
      const robots = await robotsAllows(url);
      if (!robots.allowed) { await pushError(jobId, robots.reason); return { ok: false, note: robots.reason }; }

      await admin.from("ai_ingestion_jobs").update({ progress_pct: 30 }).eq("id", jobId);
      const resp = await fetch(url.toString(), {
        headers: { "User-Agent": "pq-learn-ingestion/1.0 (+admin)" },
        signal: AbortSignal.timeout(20000),
      });
      const httpStatus = resp.status;
      const ct = resp.headers.get("content-type") ?? "";
      if (!resp.ok) { await pushError(jobId, `HTTP ${httpStatus} en récupérant ${url}`); return { ok: false, note: `HTTP ${httpStatus}` }; }
      if (/(image|pdf)/i.test(ct)) {
        await pushError(jobId, `Type ${ct} : OCR indisponible (aucun moteur vision auto-hébergé). Collez le texte manuellement.`);
        return { ok: false, note: "OCR indisponible" };
      }

      const raw = await resp.text();
      const text = /html/i.test(ct) ? htmlToText(raw) : raw.replace(/[ \t]+/g, " ").trim();
      const hash = await md5Hex(text);
      const { data: dup } = await admin.from("ai_extracted_documents")
        .select("id").eq("content_hash", hash).neq("source_id", src.id).limit(1).maybeSingle();

      await admin.from("ai_ingestion_jobs").update({ progress_pct: 70 }).eq("id", jobId);
      const titleMatch = raw.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
      await admin.from("ai_extracted_documents").insert({
        source_id: src.id, job_id: jobId,
        title: titleMatch ? htmlToText(titleMatch[1]).slice(0, 200) : url.hostname,
        extracted_text: text.slice(0, 200_000),
        metadata: {
          url: url.toString(), http_status: httpStatus, content_type: ct,
          fetched_at: new Date().toISOString(), robots: robots.reason,
          word_count: text.split(/\s+/).length, depth: 0,
        },
        content_hash: hash, is_duplicate: !!dup, duplicate_of: dup?.id ?? null,
      });
      await admin.from("ai_rag_sources").update({ collected_at: new Date().toISOString() }).eq("id", src.id);
      await admin.from("ai_ingestion_jobs").update({
        status: "done", progress_pct: 100, finished_at: new Date().toISOString(),
        result: { extracted: 1, duplicate: !!dup, bytes: text.length },
      }).eq("id", jobId);
      return { ok: true, note: dup ? "extrait (doublon détecté)" : "extrait" };
    }

    // ---------- CLASSIFY ----------
    if (job.job_type === "classify") {
      const { data: doc } = await admin.from("ai_extracted_documents")
        .select("*").eq("source_id", src.id).order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (!doc) { await pushError(jobId, "Aucun extrait à classer pour cette source."); return { ok: false, note: "aucun extrait" }; }

      await admin.from("ai_ingestion_jobs").update({ progress_pct: 40 }).eq("id", jobId);
      const resp = await fetch(`${SUPABASE_URL}/functions/v1/ai-curriculum-mapping`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${jwt}`, "apikey": ANON_KEY },
        body: JSON.stringify({ text: doc.extracted_text.slice(0, 8000) }),
      });
      const mapping = await resp.json();
      const topChapter = (mapping.chapter_candidates ?? [])[0];
      await admin.from("ai_extracted_documents").update({
        classification: mapping,
        proposed_chapter_id: topChapter?.chapter_id ?? null,
        proposed_subject_id: topChapter?.subject_id ?? null,
        proposed_class_node_id: topChapter?.class_node_id ?? null,
      }).eq("id", doc.id);
      await admin.from("ai_ingestion_jobs").update({
        status: "done", progress_pct: 100, finished_at: new Date().toISOString(),
        result: { chapter_candidates: (mapping.chapter_candidates ?? []).length, needs_human_review: mapping.needs_human_review },
      }).eq("id", jobId);
      return { ok: true, note: `classé (${(mapping.chapter_candidates ?? []).length} chapitre(s) candidat(s))` };
    }

    // ---------- EMBED (après validation humaine uniquement) ----------
    if (job.job_type === "embed") {
      const { data: doc } = await admin.from("ai_extracted_documents")
        .select("*").eq("source_id", src.id).eq("review_status", "validated")
        .order("reviewed_at", { ascending: false }).limit(1).maybeSingle();
      if (!doc) { await pushError(jobId, "Aucun extrait VALIDÉ à indexer (la validation humaine est requise avant indexation)."); return { ok: false, note: "non validé" }; }

      const { data: ing } = await admin.from("ai_rag_ingestions").insert({
        source_id: src.id, status: "processing", embedding_provider: "gemini-embedding-001",
      }).select("id").single();
      const ingestionId = ing!.id;

      // Segmentation simple par paragraphes, fenêtres ~1200 caractères.
      const paras = doc.extracted_text.split(/\n{2,}/).map((p: string) => p.trim()).filter(Boolean);
      const chunks: string[] = [];
      let cur = "";
      for (const p of paras) {
        if ((cur + "\n\n" + p).length > 1200 && cur) { chunks.push(cur); cur = p; }
        else { cur = cur ? cur + "\n\n" + p : p; }
      }
      if (cur) chunks.push(cur);
      const capped = chunks.slice(0, 80);

      await admin.from("ai_ingestion_jobs").update({ progress_pct: 40 }).eq("id", jobId);
      const embResp = await fetch(`${SUPABASE_URL}/functions/v1/ai-embeddings-generate`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${jwt}`, "apikey": ANON_KEY },
        body: JSON.stringify({ texts: capped }),
      });
      const emb = await embResp.json();
      if (!embResp.ok || !Array.isArray(emb.embeddings)) {
        await admin.from("ai_rag_ingestions").update({ status: "failed", error_message: emb.error ?? `HTTP ${embResp.status}`, completed_at: new Date().toISOString() }).eq("id", ingestionId);
        await pushError(jobId, `Embeddings : ${emb.error ?? embResp.status}`);
        return { ok: false, note: "embeddings échoués" };
      }

      const rows = capped.map((content, i) => ({
        ingestion_id: ingestionId, source_id: src.id, chunk_index: i, content,
        embedding: emb.embeddings[i],
        class_node_id: doc.proposed_class_node_id ?? src.class_node_id ?? null,
        subject_id: doc.proposed_subject_id ?? src.subject_id ?? null,
      }));
      await admin.from("ai_rag_chunks").insert(rows);
      await admin.from("ai_rag_ingestions").update({ status: "completed", chunk_count: rows.length, completed_at: new Date().toISOString() }).eq("id", ingestionId);
      await admin.from("ai_rag_sources").update({ validated: true, validated_at: new Date().toISOString() }).eq("id", src.id);
      await admin.from("ai_ingestion_jobs").update({
        status: "done", progress_pct: 100, finished_at: new Date().toISOString(),
        result: { chunks: rows.length, ingestion_id: ingestionId },
      }).eq("id", jobId);
      return { ok: true, note: `${rows.length} chunk(s) indexé(s)` };
    }

    await pushError(jobId, `Type de job non géré : ${job.job_type}`);
    return { ok: false, note: "type inconnu" };
  } catch (e: any) {
    await pushError(jobId, e?.message ?? String(e));
    return { ok: false, note: e?.message ?? "erreur" };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { data: userData } = await admin.auth.getUser(jwt);
    const { data: adminRow } = userData?.user?.id
      ? await admin.from("admin_users").select("id").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const body = await req.json().catch(() => ({}));
    let jobs: any[] = [];
    if (body.job_id) {
      const { data } = await admin.from("ai_ingestion_jobs").select("*").eq("id", body.job_id).maybeSingle();
      if (data) jobs = [data];
    } else {
      const { data } = await admin.from("ai_ingestion_jobs").select("*")
        .in("status", ["queued", "failed"]).eq("cancel_requested", false)
        .lt("attempts", 3).order("created_at").limit(10);
      jobs = data ?? [];
    }
    if (jobs.length === 0) return json({ processed: 0, message: "Aucun job à traiter." });

    const results: any[] = [];
    for (const job of jobs) {
      const r = await processJob(job, jwt);
      results.push({ job_id: job.id, job_type: job.job_type, ...r });
    }
    return json({ processed: results.length, results });
  } catch (err: any) {
    return json({ error: err?.message ?? "Erreur interne du worker d'ingestion." }, 500);
  }
});
