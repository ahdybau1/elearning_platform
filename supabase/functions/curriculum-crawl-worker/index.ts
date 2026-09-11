// Agent de scraping curriculum — CRAWLER RÉCURSIF (BFS) piloté par la file curriculum_crawl_pages.
// Respecte robots.txt, budget profondeur/pages, filtre par pertinence, reprenable et annulable.
// Appelé par pg_cron (avec cron_secret) et/ou depuis l'admin (JWT). Chaque invocation traite un
// lot puis rend la main : « background » réel, sans blocage d'interface.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";
import { extractText, getDocumentProxy } from "npm:unpdf@0.12.1";

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

const KW = [
  "programme", "curriculum", "referentiel", "syllabus", "classe", "matiere", "discipline",
  "chapitre", "theme", "lecon", "college", "lycee", "secondaire", "seconde", "premiere",
  "terminale", "troisieme", "quatrieme", "cinquieme", "sixieme", "serie", "bac", "baccalaureat",
  "probatoire", "bepc", "enseignement", "pedagogie", "inspection", "officiel", "coefficient",
  "horaire", "instructions",
];
const strip = (s: string) => s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
function relevance(text: string): number {
  const t = strip(text);
  let hits = 0;
  for (const k of KW) if (t.includes(k)) hits++;
  return Math.min(1, hits / 8);
}
function urlKey(u: string): string {
  try {
    const x = new URL(u);
    return (x.hostname + x.pathname).replace(/\/+$/, "").toLowerCase();
  } catch {
    return u.toLowerCase();
  }
}
function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<nav[\s\S]*?<\/nav>/gi, " ")
    .replace(/<footer[\s\S]*?<\/footer>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&#\d+;/g, " ")
    .replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim();
}

const robotsCache = new Map<string, string[]>();
async function robotsDisallows(origin: string): Promise<string[]> {
  if (robotsCache.has(origin)) return robotsCache.get(origin)!;
  let dis: string[] = [];
  try {
    const r = await fetch(`${origin}/robots.txt`, { signal: AbortSignal.timeout(8000) });
    if (r.ok) {
      const lines = (await r.text()).split("\n").map((l) => l.trim());
      let all = false;
      for (const l of lines) {
        const low = l.toLowerCase();
        if (low.startsWith("user-agent:")) all = l.split(":")[1].trim() === "*";
        else if (all && low.startsWith("disallow:")) {
          const p = l.split(":").slice(1).join(":").trim();
          if (p) dis.push(p);
        }
      }
    }
  } catch { dis = []; }
  robotsCache.set(origin, dis);
  return dis;
}
function robotsBlocks(u: URL, dis: string[]): boolean {
  return dis.some((d) => d === "/" || u.pathname.startsWith(d));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    let authed = body.cron_secret && CRON_SECRET && body.cron_secret === CRON_SECRET;
    if (!authed) {
      const { data: u } = await admin.auth.getUser(jwt);
      const { data: adminRow } = u?.user?.id
        ? await admin.from("admin_users").select("id").eq("auth_user_id", u.user.id).eq("is_active", true).maybeSingle()
        : { data: null };
      authed = !!adminRow;
    }
    if (!authed) return json({ error: "Non autorisé." }, 403);

    const runId: string | null = body.run_id ?? null;
    const batch = Math.min(Math.max(Number(body.batch) || 12, 1), 20);

    let runsQ = admin.from("curriculum_scrape_runs").select("*")
      .eq("status", "crawling").eq("cancel_requested", false);
    if (runId) runsQ = admin.from("curriculum_scrape_runs").select("*").eq("id", runId);
    const { data: runs } = await runsQ.limit(3);
    if (!runs || runs.length === 0) return json({ processed: 0, has_more: false, message: "Aucun run à crawler." });

    let totalProcessed = 0;
    let anyMore = false;

    for (const run of runs as Record<string, unknown>[]) {
      if (run.cancel_requested) {
        await admin.from("curriculum_scrape_runs").update({ status: "cancelled" }).eq("id", run.id);
        continue;
      }
      const stats = (run.stats ?? {}) as Record<string, number>;
      const maxPages = (run.max_pages as number) ?? 120;
      const maxDepth = (run.max_depth as number) ?? 2;

      const { data: pages } = await admin.from("curriculum_crawl_pages")
        .select("id, url, url_key, domain, depth")
        .eq("run_id", run.id).eq("status", "queued")
        .order("relevance", { ascending: false }).order("depth", { ascending: true })
        .limit(batch);

      if (!pages || pages.length === 0) {
        // Fin du crawl pour ce run.
        const { count: fetched } = await admin.from("curriculum_crawl_pages")
          .select("id", { count: "exact", head: true }).eq("run_id", run.id).eq("status", "fetched");
        await admin.from("curriculum_scrape_runs").update({
          status: (fetched ?? 0) >= 2 ? "extracting" : "failed",
          error_message: (fetched ?? 0) >= 2 ? null : "Crawl terminé sans page exploitable.",
        }).eq("id", run.id);
        continue;
      }

      // Motifs de domaine autorisés (registre du pays) + domaines déjà présents.
      const { data: reg } = await admin.from("curriculum_source_registry")
        .select("domain_pattern").eq("country_code", run.country_code).eq("active", true);
      const allowedHostSuffixes = new Set<string>();
      for (const r of (reg ?? []) as { domain_pattern: string }[]) {
        allowedHostSuffixes.add(r.domain_pattern.replace(/^\*\./, ""));
      }
      allowedHostSuffixes.add("wikipedia.org");

      const { count: totalPagesNow } = await admin.from("curriculum_crawl_pages")
        .select("id", { count: "exact", head: true }).eq("run_id", run.id);
      let budget = Math.max(0, maxPages - (totalPagesNow ?? 0));

      for (const p of pages) {
        await admin.from("curriculum_crawl_pages").update({ status: "fetching" }).eq("id", p.id);
        totalProcessed++;
        let ok = false;
        try {
          const u = new URL(p.url);
          const dis = await robotsDisallows(u.origin);
          if (robotsBlocks(u, dis)) {
            await admin.from("curriculum_crawl_pages").update({ status: "skipped_robots" }).eq("id", p.id);
            continue;
          }
          const resp = await fetch(p.url, {
            headers: { "User-Agent": "pq-learn-curriculum-bot/1.0 (+admin)" },
            signal: AbortSignal.timeout(25000),
            redirect: "follow",
          });
          const ct = resp.headers.get("content-type") ?? "";
          const isPdf = /pdf/i.test(ct) || /\.pdf($|\?)/i.test(p.url as string);
          let html = "";
          let text = "";
          let title = u.hostname;

          if (/(image|zip|octet-stream)/i.test(ct) && !isPdf) {
            await admin.from("curriculum_crawl_pages").update({
              status: "skipped_type", http_status: resp.status,
              error_message: `Type ${ct} non extractible.`,
            }).eq("id", p.id);
            continue;
          }

          if (isPdf) {
            // Extraction texte des PDF (programmes officiels souvent en PDF) via unpdf.
            try {
              const bytes = new Uint8Array(await resp.arrayBuffer());
              const doc = await getDocumentProxy(bytes);
              const r = await extractText(doc, { mergePages: true });
              text = (Array.isArray(r.text) ? r.text.join("\n") : r.text).replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim().slice(0, 80000);
              title = decodeURIComponent((p.url as string).split("/").pop() ?? u.hostname).slice(0, 200);
            } catch (pdfErr) {
              await admin.from("curriculum_crawl_pages").update({
                status: "failed", http_status: resp.status,
                error_message: `PDF illisible : ${(pdfErr as Error).message}`.slice(0, 200),
              }).eq("id", p.id);
              continue;
            }
          } else {
            html = await resp.text();
            const titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
            title = titleM ? htmlToText(titleM[1]).slice(0, 200) : u.hostname;
            text = htmlToText(html).slice(0, 60000);
          }
          const rel = Math.max(relevance(title + " " + text.slice(0, 4000)), Number(p.depth) === 0 ? 0.3 : 0);

          if (Number(p.depth) > 0 && rel < 0.12) {
            await admin.from("curriculum_crawl_pages").update({
              status: "skipped_offtopic", http_status: resp.status, title, relevance: rel,
            }).eq("id", p.id);
            continue;
          }

          const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
          const hash = [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

          await admin.from("curriculum_crawl_pages").update({
            status: "fetched", http_status: resp.status, title, relevance: rel,
            content_hash: hash, text_len: text.length, raw_text: text, fetched_at: new Date().toISOString(),
          }).eq("id", p.id);
          ok = true;

          // Extraction des liens → nouvelle frontière (depth+1).
          if (Number(p.depth) < maxDepth && budget > 0 && rel >= 0.15) {
            const hrefs = [...html.matchAll(/<a[^>]+href=["']([^"'#]+)["']/gi)].map((m) => m[1]);
            const cand = new Map<string, number>();
            for (const h of hrefs) {
              let abs: URL;
              try { abs = new URL(h, p.url); } catch { continue; }
              if (!/^https?:$/.test(abs.protocol)) continue;
              const host = abs.hostname;
              const sameOrAllowed = host === u.hostname ||
                [...allowedHostSuffixes].some((suf) => host === suf || host.endsWith("." + suf));
              if (!sameOrAllowed) continue;
              const sc = relevance(abs.pathname + " " + h);
              if (sc < 0.12) continue;
              cand.set(abs.toString(), Math.max(cand.get(abs.toString()) ?? 0, sc));
            }
            const top = [...cand.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12);
            const newRows: Record<string, unknown>[] = [];
            for (const [cu, sc] of top) {
              if (budget <= 0) break;
              const k = urlKey(cu);
              const { data: exists } = await admin.from("curriculum_crawl_pages")
                .select("id").eq("run_id", run.id).eq("url_key", k).maybeSingle();
              if (exists) continue;
              newRows.push({
                run_id: run.id, url: cu, url_key: k, domain: (() => { try { return new URL(cu).hostname; } catch { return host_fallback(cu); } })(),
                depth: Number(p.depth) + 1, discovered_via: "link", relevance: Math.min(0.999, sc), status: "queued",
              });
              budget--;
            }
            if (newRows.length) await admin.from("curriculum_crawl_pages").insert(newRows);
          }
        } catch (e) {
          await admin.from("curriculum_crawl_pages").update({
            status: "failed", error_message: (e as Error).message.slice(0, 200),
          }).eq("id", p.id);
        }
        stats.pages_fetched = (stats.pages_fetched ?? 0) + (ok ? 1 : 0);
        stats.pages_failed = (stats.pages_failed ?? 0) + (ok ? 0 : 1);
      }

      const { count: stillQueued } = await admin.from("curriculum_crawl_pages")
        .select("id", { count: "exact", head: true }).eq("run_id", run.id).eq("status", "queued");
      const { count: domainCount } = await admin.from("curriculum_crawl_pages")
        .select("domain", { count: "exact", head: true }).eq("run_id", run.id);
      stats.pages_queued = stillQueued ?? 0;
      stats.domains = domainCount ?? stats.domains ?? 0;
      anyMore = anyMore || (stillQueued ?? 0) > 0;

      const done = (stillQueued ?? 0) === 0;
      await admin.from("curriculum_scrape_runs").update({
        stats, status: done ? "extracting" : "crawling",
      }).eq("id", run.id);
    }

    return json({ processed: totalProcessed, has_more: anyMore });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne du crawler." }, 500);
  }
});

function host_fallback(u: string): string {
  const m = u.match(/^https?:\/\/([^/]+)/i);
  return m ? m[1] : "";
}
