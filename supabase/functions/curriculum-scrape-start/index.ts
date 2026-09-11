// Agent de scraping curriculum — DÉCOUVERTE de sources (recherche web réelle, coût zéro) +
// amorçage de la frontière de crawl. Multi-pays.
//
// Moyens de découverte combinés :
//  1. Index CommonCrawl  — énumère les URL réellement indexées sous un motif de domaine officiel
//  2. google_search (Gemini) — recherche ciblée quand le quota le permet
//  3. API Wikipédia      — aperçu structuré du système éducatif du pays
//  4. Registre curaté    — domaines/seed officiels connus (migration 84)
//
// N'invente rien : ne fait qu'inscrire des URL à visiter dans curriculum_crawl_pages.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI = Deno.env.get("GEMINI_API_KEY") ?? "";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const KW = [
  "programme", "curriculum", "referentiel", "referentiels", "syllabus", "classe", "classes",
  "matiere", "matieres", "discipline", "chapitre", "chapitres", "theme", "lecon", "lecons",
  "college", "lycee", "secondaire", "seconde", "premiere", "terminale", "troisieme", "quatrieme",
  "cinquieme", "sixieme", "serie", "series", "bac", "baccalaureat", "probatoire", "bepc",
  "enseignement", "pedagogie", "pedagogique", "inspection", "officiel", "officiels", "minesec",
  "coefficient", "horaire", "instructions",
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

async function fromCommonCrawl(pattern: string, limit = 120): Promise<{ url: string; score: number }[]> {
  // Deux collections récentes pour couvrir un peu plus large.
  const indexes = ["CC-MAIN-2025-05-index", "CC-MAIN-2024-51-index"];
  const out = new Map<string, number>();
  for (const idx of indexes) {
    try {
      const r = await fetch(
        `https://index.commoncrawl.org/${idx}?url=${encodeURIComponent(pattern)}&output=json&limit=${limit}`,
        { headers: { "User-Agent": "pq-learn-curriculum-bot/1.0" }, signal: AbortSignal.timeout(25000) },
      );
      if (!r.ok) continue;
      const body = await r.text();
      for (const line of body.split("\n")) {
        if (!line.trim()) continue;
        try {
          const rec = JSON.parse(line);
          if (!/html/i.test(rec["mime-detected"] ?? rec.mime ?? "")) continue;
          if (rec.status && rec.status !== "200") continue;
          const u = (rec.url as string).replace(/^http:/, "https:");
          const sc = relevance(u);
          out.set(u, Math.max(out.get(u) ?? 0, sc + 0.15)); // léger bonus : présent dans l'index officiel
        } catch { /* ligne non JSON */ }
      }
    } catch { /* index indisponible */ }
  }
  return [...out.entries()].map(([url, score]) => ({ url, score })).sort((a, b) => b.score - a.score);
}

async function fromGrounding(scopeLabel: string, country: string): Promise<string[]> {
  if (!GEMINI) return [];
  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${GEMINI}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            role: "user",
            parts: [{
              text:
                `Recherche les pages officielles décrivant l'organisation et les PROGRAMMES de ` +
                `l'enseignement secondaire (${scopeLabel}) en ${country} : classes, séries, matières, ` +
                `chapitres par matière et par classe. Donne les URL les plus utiles (ministère, ` +
                `inspections de pédagogie, dépôts officiels).`,
            }],
          }],
          tools: [{ google_search: {} }],
        }),
        signal: AbortSignal.timeout(40000),
      },
    );
    if (!r.ok) return [];
    const d = await r.json();
    const c = (d.candidates ?? [{}])[0];
    const chunks = c.groundingMetadata?.groundingChunks ?? [];
    return chunks.map((g: { web?: { uri?: string } }) => g.web?.uri).filter(Boolean) as string[];
  } catch {
    return [];
  }
}

async function fromWikipedia(country: string): Promise<string[]> {
  const titles = [`Système éducatif au ${country}`, `Système éducatif en ${country}`, `Éducation au ${country}`, `Éducation en ${country}`];
  const urls: string[] = [];
  for (const t of titles) {
    try {
      const r = await fetch(
        `https://fr.wikipedia.org/w/api.php?action=query&format=json&prop=info&inprop=url&titles=${encodeURIComponent(t)}`,
        { signal: AbortSignal.timeout(12000) },
      );
      const d = await r.json();
      const pages = d.query?.pages ?? {};
      for (const k of Object.keys(pages)) {
        if (k !== "-1" && pages[k].fullurl) urls.push(pages[k].fullurl);
      }
    } catch { /* ignore */ }
  }
  return [...new Set(urls)];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { data: u } = await admin.auth.getUser(jwt);
    const { data: adminRow } = u?.user?.id
      ? await admin.from("admin_users").select("id").eq("auth_user_id", u.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const body = await req.json().catch(() => ({}));
    const countryCode: string = (body.country_code ?? "cm").toLowerCase();
    const systemHint: string | null = body.system_hint ?? null;
    const maxDepth = Math.min(Math.max(Number(body.max_depth) || 2, 1), 3);
    const maxPages = Math.min(Math.max(Number(body.max_pages) || 120, 20), 400);

    // Résolution du nœud pays dans l'arbre (par nom, pour rattacher l'import plus tard).
    const { data: countries } = await admin.from("academic_nodes")
      .select("id, name").eq("node_type", "country").eq("is_active", true);
    const { data: reg } = await admin.from("curriculum_source_registry")
      .select("*").eq("country_code", countryCode).eq("active", true).order("priority");
    const countryName = ((reg ?? [])[0]?.country_name as string) ?? countryCode.toUpperCase();
    const scopeCountry = ((countries ?? []) as { id: string; name: string }[])
      .find((c) => strip(c.name).includes(strip(countryName)) || strip(countryName).includes(strip(c.name)));
    const scopeLabel = `${countryName}${systemHint ? " · " + systemHint : " · enseignement secondaire"}`;

    const { data: run } = await admin.from("curriculum_scrape_runs").insert({
      scope_country_id: scopeCountry?.id ?? null,
      scope_node_id: body.scope_node_id ?? null,
      country_code: countryCode, scope_label: scopeLabel,
      max_depth: maxDepth, max_pages: maxPages,
      status: "discovering", created_by: adminRow.id,
    }).select("id").single();
    const runId = run!.id;

    // ── DÉCOUVERTE ──
    const discovery: Record<string, unknown> = {};
    const seeds: { url: string; via: string; score: number }[] = [];

    // Registre : seed_url directs + motifs → CommonCrawl
    for (const s of (reg ?? []) as { seed_url: string | null; domain_pattern: string; kind: string }[]) {
      if (s.seed_url) seeds.push({ url: s.seed_url, via: "registry", score: 0.6 });
    }
    const ccPerPattern: Record<string, number> = {};
    for (const s of (reg ?? []) as { domain_pattern: string }[]) {
      const found = await fromCommonCrawl(s.domain_pattern, 120);
      ccPerPattern[s.domain_pattern] = found.length;
      for (const f of found.slice(0, 45)) seeds.push({ url: f.url, via: "commoncrawl", score: f.score });
    }
    discovery.commoncrawl = ccPerPattern;

    const grounded = await fromGrounding(scopeLabel, countryName);
    discovery.grounding = grounded;
    for (const g of grounded) seeds.push({ url: g, via: "grounding", score: 0.7 });

    const wiki = await fromWikipedia(countryName);
    discovery.wikipedia = wiki;
    for (const w of wiki) seeds.push({ url: w, via: "wikipedia", score: 0.5 });

    // Dédup + insertion de la frontière (depth 0), plafonnée par max_pages.
    const seen = new Set<string>();
    const rows: Record<string, unknown>[] = [];
    for (const s of seeds.sort((a, b) => b.score - a.score)) {
      if (!/^https?:\/\//.test(s.url)) continue;
      const key = urlKey(s.url);
      if (seen.has(key)) continue;
      seen.add(key);
      let domain = "";
      try { domain = new URL(s.url).hostname; } catch { continue; }
      rows.push({
        run_id: runId, url: s.url, url_key: key, domain, depth: 0,
        discovered_via: s.via, relevance: Math.min(0.999, s.score), status: "queued",
      });
      if (rows.length >= Math.min(maxPages, 90)) break;
    }
    if (rows.length) await admin.from("curriculum_crawl_pages").insert(rows);

    const domains = new Set(rows.map((r) => r.domain));
    await admin.from("curriculum_scrape_runs").update({
      status: rows.length ? "crawling" : "failed",
      discovery,
      stats: { domains: domains.size, pages_queued: rows.length, pages_fetched: 0, pages_failed: 0, findings: 0, items: 0 },
      error_message: rows.length ? null : "Aucune source découverte (registre vide pour ce pays, CommonCrawl et grounding sans résultat).",
    }).eq("id", runId);

    return json({
      run_id: runId, scope_label: scopeLabel,
      discovered: {
        total_queued: rows.length, domains: domains.size,
        by_source: {
          registry: seeds.filter((s) => s.via === "registry").length,
          commoncrawl: seeds.filter((s) => s.via === "commoncrawl").length,
          grounding: grounded.length,
          wikipedia: wiki.length,
        },
      },
    });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne du démarrage de scraping." }, 500);
  }
});
