// Agent de scraping curriculum — EXTRACTION + AGRÉGATION.
// Passe le Model Router (multi-fournisseurs) sur les pages crawlées, extrait STRICTEMENT ce qui est
// présent (jamais d'invention), puis agrège en curriculum_import_items (dédup + statut « À vérifier »)
// et crée/actualise la ligne curriculum_imports (réutilise curriculum-apply / curriculum-cancel).
// Traité par lots ; reprenable.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const norm = (s: string) =>
  (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/^(classe de |serie |série )/i, "").replace(/[^a-z0-9]+/g, " ").trim();

async function routerJson(system: string, user: string): Promise<{ obj: Record<string, unknown> | null; provider: string; error?: string }> {
  try {
    const r = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-text`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SERVICE_ROLE}` },
      body: JSON.stringify({ capability: "structuring_json", json: true, max_tokens: 8192, temperature: 0.1, system_prompt: system, user_prompt: user }),
    });
    const d = await r.json();
    if (!r.ok) return { obj: null, provider: "none", error: d.error ?? `HTTP ${r.status}` };
    const t = (d.text as string).replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
    return { obj: JSON.parse(t), provider: d._provider ?? "?" };
  } catch (e) {
    return { obj: null, provider: "none", error: (e as Error).message };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    let adminId: string | null = null;
    let authed = body.cron_secret && CRON_SECRET && body.cron_secret === CRON_SECRET;
    if (!authed) {
      const { data: u } = await admin.auth.getUser(jwt);
      const { data: adminRow } = u?.user?.id
        ? await admin.from("admin_users").select("id").eq("auth_user_id", u.user.id).eq("is_active", true).maybeSingle()
        : { data: null };
      authed = !!adminRow;
      adminId = adminRow?.id ?? null;
    }
    if (!authed) return json({ error: "Non autorisé." }, 403);

    const runId: string | null = body.run_id ?? null;
    const pagesPerCall = Math.min(Math.max(Number(body.pages) || 4, 1), 8);

    let q = admin.from("curriculum_scrape_runs").select("*").eq("status", "extracting");
    if (runId) q = admin.from("curriculum_scrape_runs").select("*").eq("id", runId);
    const { data: runs } = await q.limit(2);
    if (!runs || runs.length === 0) return json({ processed: 0, has_more: false, message: "Aucun run à extraire." });

    let processed = 0;
    let anyMore = false;

    for (const run of runs as Record<string, unknown>[]) {
      // 1. S'assurer d'une ligne curriculum_imports.
      let importId = run.import_id as string | null;
      if (!importId) {
        const { data: imp } = await admin.from("curriculum_imports").insert({
          scope_country_id: run.scope_country_id, scope_node_id: run.scope_node_id,
          scope_label: run.scope_label, seed_urls: [], status: "collecting",
          created_by: adminId ?? run.created_by,
        }).select("id").single();
        importId = imp!.id;
        await admin.from("curriculum_scrape_runs").update({ import_id: importId }).eq("id", run.id);
      }

      // 2. Extraire un lot de pages fetched non encore extraites.
      const { data: pages } = await admin.from("curriculum_crawl_pages")
        .select("id, url, title, raw_text, relevance")
        .eq("run_id", run.id).eq("status", "fetched").eq("extracted", false)
        .order("relevance", { ascending: false }).limit(pagesPerCall);

      for (const p of (pages ?? []) as Record<string, unknown>[]) {
        processed++;
        const txt = (p.raw_text as string ?? "").slice(0, 14000);
        if (txt.length < 200) { await admin.from("curriculum_crawl_pages").update({ extracted: true }).eq("id", p.id); continue; }
        const { obj, provider, error } = await routerJson(
          "Tu extrais des données curriculaires UNIQUEMENT si elles sont EXPLICITEMENT présentes dans le texte. " +
          "N'invente RIEN, ne complète aucune liste. Si rien de curriculaire, renvoie des tableaux vides. JSON strict.",
          `Périmètre : ${run.scope_label}.\nPage : ${p.url}\nTITRE : ${p.title}\n\nTEXTE :\n"""${txt}"""\n\n` +
          `Renvoie ce JSON :\n{"education_types":["ex: Enseignement Général"],` +
          `"classes":[{"name":"ex: Classe de 1ère","series":["ex: Série C"]}],` +
          `"programs":[{"class_name":"","series_name":"ou null","subject_name":"","year":"ou null",` +
          `"completeness":"ok|incomplete|ambiguous",` +
          `"chapters":[{"title":"intitulé exact","order":1,"excerpt":"phrase littérale du texte"}]}],` +
          `"gaps":["mention explicite de ce qui manque/est partiel/ambigu"]}`,
        );
        await admin.from("curriculum_crawl_findings").insert({
          run_id: run.id, page_id: p.id, provider, payload: obj ?? { error },
        });
        await admin.from("curriculum_crawl_pages").update({ extracted: true }).eq("id", p.id);
      }

      // 3. Agrégation : reconstruit curriculum_import_items depuis TOUTES les findings du run.
      const { data: findings } = await admin.from("curriculum_crawl_findings")
        .select("payload, page_id").eq("run_id", run.id);
      const { data: pageMap } = await admin.from("curriculum_crawl_pages")
        .select("id, url, title").eq("run_id", run.id);
      const pById = new Map((pageMap ?? []).map((x: { id: string; url: string; title: string }) => [x.id, x]));

      type Agg = { kind: string; name: string; parentPath: string; parentRef: Record<string, string | null>; vs: string; conf: number; excerpt: string; url: string; title: string; year: string | null; order: number };
      const aggMap = new Map<string, Agg>();
      const gaps = new Set<string>();
      const put = (a: Agg) => {
        const key = `${a.kind}|${norm(a.name)}|${norm(a.parentPath)}`;
        const cur = aggMap.get(key);
        if (!cur || a.conf > cur.conf) aggMap.set(key, cur ? { ...a, conf: Math.max(a.conf, cur.conf) } : a);
      };
      const base = run.scope_label as string;

      for (const f of (findings ?? []) as { payload: Record<string, unknown>; page_id: string }[]) {
        const pl = f.payload ?? {};
        const pg = pById.get(f.page_id) as { url: string; title: string } | undefined;
        const src = { url: pg?.url ?? "", title: pg?.title ?? "" };
        for (const g of (pl.gaps as string[] | undefined) ?? []) gaps.add(`${src.url} : ${g}`);

        for (const cl of (pl.classes as Record<string, unknown>[] | undefined) ?? []) {
          const cn = String(cl.name ?? "").trim();
          if (!cn) continue;
          put({ kind: "class", name: cn, parentPath: base, parentRef: {}, vs: "ambiguous", conf: 0.5, excerpt: `Classe mentionnée sur ${src.url}`, url: src.url, title: src.title, year: null, order: 0 });
          for (const se of (cl.series as string[] | undefined) ?? []) {
            const sn = String(se).trim();
            if (!sn) continue;
            put({ kind: "series", name: sn.match(/^s[ée]rie/i) ? sn : `Série ${sn}`, parentPath: `${base} › ${cn}`, parentRef: { class_name: cn }, vs: "ambiguous", conf: 0.5, excerpt: `Série mentionnée sur ${src.url}`, url: src.url, title: src.title, year: null, order: 0 });
          }
        }
        for (const pr of (pl.programs as Record<string, unknown>[] | undefined) ?? []) {
          const cn = String(pr.class_name ?? "").trim();
          const sn = pr.series_name ? String(pr.series_name).trim() : null;
          const sub = String(pr.subject_name ?? "").trim();
          if (!cn || !sub) continue;
          const comp = String(pr.completeness ?? "ambiguous");
          const vs = comp === "ok" ? "ok" : (comp === "incomplete" ? "incomplete" : "ambiguous");
          const subPath = `${base} › ${cn}${sn ? " › " + sn : ""}`;
          if (cn) put({ kind: "class", name: cn, parentPath: base, parentRef: {}, vs: "ambiguous", conf: 0.55, excerpt: `Programme trouvé sur ${src.url}`, url: src.url, title: src.title, year: null, order: 0 });
          if (sn) put({ kind: "series", name: sn.match(/^s[ée]rie/i) ? sn : `Série ${sn}`, parentPath: `${base} › ${cn}`, parentRef: { class_name: cn }, vs: "ambiguous", conf: 0.55, excerpt: `Série du programme sur ${src.url}`, url: src.url, title: src.title, year: null, order: 0 });
          put({ kind: "subject", name: sub, parentPath: subPath, parentRef: { class_name: cn, series_name: sn }, vs: "ok", conf: 0.7, excerpt: `Matière du programme officiel sur ${src.url}`, url: src.url, title: src.title, year: pr.year ? String(pr.year) : null, order: 0 });
          const chs = (pr.chapters as Record<string, unknown>[] | undefined) ?? [];
          chs.forEach((ch, i) => {
            const ct = String(ch.title ?? "").trim();
            if (!ct) return;
            put({ kind: "chapter", name: ct, parentPath: `${subPath} › ${sub}`, parentRef: { class_name: cn, series_name: sn, subject_name: sub }, vs, conf: 0.75, excerpt: String(ch.excerpt ?? "").slice(0, 500), url: src.url, title: src.title, year: pr.year ? String(pr.year) : null, order: Number(ch.order ?? i + 1) });
          });
        }
      }

      // Dédup contre l'arbre existant → matched_*
      const { data: exN } = await admin.from("academic_nodes").select("id, name, node_type");
      const { data: exS } = await admin.from("subjects").select("id, name");
      const { data: exC } = await admin.from("chapters").select("title");
      const nodeK = new Map((exN ?? []).map((n: { id: string; name: string; node_type: string }) => [`${n.node_type}|${norm(n.name)}`, n.id]));
      const subjK = new Map((exS ?? []).map((s: { id: string; name: string }) => [norm(s.name), s.id]));
      const chapK = new Set((exC ?? []).map((c: { title: string }) => norm(c.title)));

      const COLS = ["import_id", "item_kind", "proposed_name", "proposed_code", "display_order", "parent_path", "parent_ref", "matched_node_id", "matched_subject_id", "matched_chapter_id", "match_confidence", "verification_status", "source_id", "source_title", "source_url", "source_year", "source_excerpt", "notes"];
      const rows = [...aggMap.values()].map((a) => {
        const r: Record<string, unknown> = {};
        for (const c of COLS) r[c] = null;
        r.import_id = importId; r.item_kind = a.kind; r.proposed_name = a.name;
        r.display_order = a.order; r.parent_path = a.parentPath; r.parent_ref = a.parentRef;
        r.match_confidence = 0; r.verification_status = a.vs;
        r.source_title = a.title || null; r.source_url = a.url || null;
        r.source_year = a.year; r.source_excerpt = a.excerpt || null;
        if (a.kind === "class" || a.kind === "series") { const m = nodeK.get(`${a.kind}|${norm(a.name)}`); if (m) { r.matched_node_id = m; r.match_confidence = 0.95; } }
        else if (a.kind === "subject") { const m = subjK.get(norm(a.name)); if (m) { r.matched_subject_id = m; r.match_confidence = 0.9; } }
        else if (a.kind === "chapter") { if (chapK.has(norm(a.name))) r.match_confidence = 0.8; }
        return r;
      });

      // Ne pas écraser une revue humaine déjà commencée : on ne reconstruit que si rien n'est
      // encore vérifié/appliqué manuellement.
      const { count: touched } = await admin.from("curriculum_import_items")
        .select("id", { count: "exact", head: true }).eq("import_id", importId).in("status", ["verified", "applied", "rejected"]);
      if ((touched ?? 0) === 0) {
        await admin.from("curriculum_import_items").delete().eq("import_id", importId);
        for (let i = 0; i < rows.length; i += 200) await admin.from("curriculum_import_items").insert(rows.slice(i, i + 200));
      }

      // 4. Fin d'extraction ?
      const { count: remaining } = await admin.from("curriculum_crawl_pages")
        .select("id", { count: "exact", head: true }).eq("run_id", run.id).eq("status", "fetched").eq("extracted", false);
      const summary = {
        proposed: rows.length,
        classes: rows.filter((r) => r.item_kind === "class").length,
        series: rows.filter((r) => r.item_kind === "series").length,
        subjects: rows.filter((r) => r.item_kind === "subject").length,
        chapters: rows.filter((r) => r.item_kind === "chapter").length,
        matched: rows.filter((r) => r.matched_node_id || r.matched_subject_id).length,
        ambiguous: rows.filter((r) => r.verification_status !== "ok").length,
      };
      const { data: pgAll } = await admin.from("curriculum_crawl_pages")
        .select("url, http_status, status, title, relevance").eq("run_id", run.id).order("relevance", { ascending: false }).limit(60);
      const sourcesConsulted = (pgAll ?? []).map((x: Record<string, unknown>) => ({
        url: x.url, http_status: x.http_status, status: x.status, title: x.title, ok: x.status === "fetched",
      }));

      await admin.from("curriculum_imports").update({
        status: "proposed", summary, gaps: [...gaps].slice(0, 60), sources_consulted: sourcesConsulted,
      }).eq("id", importId);

      if ((remaining ?? 0) === 0) {
        await admin.from("curriculum_scrape_runs").update({
          status: "proposed",
          stats: { ...(run.stats as Record<string, unknown> ?? {}), findings: (findings ?? []).length, items: rows.length },
        }).eq("id", run.id);
      } else {
        anyMore = true;
      }
    }

    return json({ processed, has_more: anyMore });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne de l'extraction." }, 500);
  }
});
