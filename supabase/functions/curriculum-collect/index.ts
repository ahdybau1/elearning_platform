// CurriculumCollectAgent — recherche + collecte + extraction + structuration des STRUCTURES
// scolaires et PROGRAMMES, en vue d'une intégration réelle dans l'arbre académique (demande #1/#2).
//
// Deux couches, jamais confondues :
//  A) STRUCTURE de référence (classes, séries applicables, matières socle) — connaissance publique
//     documentée de l'architecture du système. Marquée verification_status='ok' pour les
//     classes/séries, 'ambiguous' pour les listes de matières spécifiques à une série.
//  B) PROGRAMMES ANNUELS (chapitres par matière/classe) — proviennent UNIQUEMENT des documents
//     réellement collectés sur les sources fournies, avec extrait littéral (source_excerpt).
//     Rien n'est inventé : un programme absent/incomplet/ambigu est signalé dans `gaps`.
//
// Le résultat est écrit dans curriculum_import_items (statut 'proposed'), PAS renvoyé pour recopie.
// L'admin relit puis applique via curriculum-apply (dédup + statut « À vérifier »).
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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
    .replace(/^(classe de |serie |serie |série )/i, "")
    .replace(/[^a-z0-9]+/g, " ").trim();

// ── COUCHE A : architecture du secondaire général francophone (Cameroun) ──
// Connaissance publique documentée (MINESEC) — structure, PAS de programme de chapitres ici.
const CMR_GENERAL = {
  classes: [
    { name: "Classe de 3ème", order: 30, series: [] as string[], vs: "ok" },
    { name: "Classe de 2nde", order: 20, series: ["A", "C"], vs: "ok" },
    { name: "Classe de 1ère", order: 10, series: ["A", "C", "D"], vs: "ok" },
    { name: "Classe de Terminale", order: 0, series: ["A", "C", "D"], vs: "ok" },
  ],
  // Matières socle communes (verification_status='ok').
  commonSubjects: [
    "Français", "Anglais", "Mathématiques", "Histoire", "Géographie",
    "Éducation à la Citoyenneté et à la Morale", "Éducation Physique et Sportive", "Informatique",
  ],
  // Matières par série (verification_status='ambiguous' — la pondération/liste exacte varie).
  seriesSubjects: {
    "A": ["Philosophie", "Littérature", "Langue vivante 2 (Espagnol/Allemand)"],
    "C": ["Physique", "Chimie", "Sciences de la Vie et de la Terre", "Philosophie"],
    "D": ["Physique", "Chimie", "Sciences de la Vie et de la Terre", "Philosophie"],
  } as Record<string, string[]>,
  // Sans série : 3ème et 2nde ont un bloc sciences.
  noSeriesSciences: ["Sciences de la Vie et de la Terre", "Physique - Chimie - Technologie"],
};

type TreeNode = { id: string; parent_id: string | null; node_type: string; name: string };

async function loadTree(countryId: string) {
  const { data } = await admin.from("academic_nodes")
    .select("id, parent_id, node_type, name").eq("is_active", true);
  const nodes = (data ?? []) as TreeNode[];
  const byId = new Map<string, TreeNode>(nodes.map((n) => [n.id, n]));
  const childrenOf = (pid: string | null) => nodes.filter((n) => n.parent_id === pid);
  return { nodes, byId, childrenOf, countryId };
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
    let scopeNodeId: string | null = body.scope_node_id ?? null;
    const seedUrls: string[] = Array.isArray(body.seed_urls) ? body.seed_urls.filter((s: string) => /^https?:\/\//.test(s)) : [];

    // ── Résolution du périmètre : par défaut Cameroun → Francophone → Enseignement Général ──
    const { data: countries } = await admin.from("academic_nodes")
      .select("id, name").eq("node_type", "country").eq("is_active", true);
    const cmr = ((countries ?? []) as { id: string; name: string }[])
      .find((c) => norm(c.name).includes("cameroun") || norm(c.name).includes("cameroon"));
    if (!cmr) return json({ error: "Aucun nœud pays « Cameroun » actif dans l'arbre." }, 400);

    const tree = await loadTree(cmr.id);
    let scopeNode: TreeNode | undefined = scopeNodeId ? tree.byId.get(scopeNodeId) : undefined;
    if (!scopeNode) {
      // francophone → général
      const sections = tree.childrenOf(cmr.id);
      const franco = sections.find((s: TreeNode) => norm(s.name).includes("francophone")) ?? sections[0];
      const eduTypes = franco ? tree.childrenOf(franco.id) : [];
      scopeNode = eduTypes.find((e: TreeNode) => norm(e.name).includes("general")) ?? eduTypes[0] ?? franco ?? undefined;
      scopeNodeId = scopeNode?.id ?? null;
    }
    if (!scopeNode) return json({ error: "Impossible de résoudre le périmètre (section/enseignement) sous le Cameroun." }, 400);

    // Chemin lisible du périmètre
    const pathParts: string[] = [];
    let cur: TreeNode | undefined = scopeNode;
    while (cur) { pathParts.unshift(cur.name); cur = cur.parent_id ? tree.byId.get(cur.parent_id) : undefined; }
    const scopeLabel = pathParts.join(" › ");

    // ── Création du run d'import ──
    const { data: imp } = await admin.from("curriculum_imports").insert({
      scope_country_id: cmr.id, scope_node_id: scopeNodeId, scope_label: scopeLabel,
      seed_urls: seedUrls, status: "collecting", created_by: adminRow.id,
    }).select("id").single();
    const importId = imp!.id;

    const items: Record<string, unknown>[] = [];
    const sourcesConsulted: Record<string, unknown>[] = [];
    const gaps: string[] = [];

    // ── COUCHE A : structure de référence (uniquement si le périmètre est « général » francophone) ──
    const isCmrGeneral = norm(scopeLabel).includes("general") || norm(scopeNode.name).includes("general");
    if (isCmrGeneral) {
      for (const cl of CMR_GENERAL.classes) {
        items.push({
          import_id: importId, item_kind: "class", proposed_name: cl.name, display_order: cl.order,
          parent_path: scopeLabel, parent_ref: {}, verification_status: cl.vs,
          source_title: "Architecture officielle du secondaire général francophone (Cameroun)",
          source_excerpt: "Structure documentée : 3ème (tronc commun, BEPC), 2nde (A, C), 1ère et Terminale (A, C, D).",
        });
        for (const se of cl.series) {
          items.push({
            import_id: importId, item_kind: "series", proposed_name: `Série ${se}`, proposed_code: se, display_order: 0,
            parent_path: `${scopeLabel} › ${cl.name}`, parent_ref: { class_name: cl.name },
            verification_status: "ok",
            source_title: "Architecture officielle du secondaire général francophone (Cameroun)",
            source_excerpt: `Série ${se} applicable à la ${cl.name}.`,
          });
        }
        // Matières socle → rattachées à la classe (sans série) ou à chaque série.
        const targets = cl.series.length ? cl.series.map((s) => ({ series: `Série ${s}` })) : [{ series: null }];
        for (const t of targets) {
          for (const sub of CMR_GENERAL.commonSubjects) {
            items.push({
              import_id: importId, item_kind: "subject", proposed_name: sub, display_order: 0,
              parent_path: `${scopeLabel} › ${cl.name}${t.series ? " › " + t.series : ""}`,
              parent_ref: { class_name: cl.name, series_name: t.series },
              verification_status: "ok",
              source_title: "Architecture officielle du secondaire général francophone (Cameroun)",
              source_excerpt: "Matière socle commune du secondaire général.",
            });
          }
          if (!t.series) {
            for (const sub of CMR_GENERAL.noSeriesSciences) {
              items.push({
                import_id: importId, item_kind: "subject", proposed_name: sub, display_order: 0,
                parent_path: `${scopeLabel} › ${cl.name}`, parent_ref: { class_name: cl.name, series_name: null },
                verification_status: "ambiguous",
                source_title: "Architecture officielle du secondaire général francophone (Cameroun)",
                source_excerpt: "Bloc sciences des classes sans série (à confirmer selon l'établissement).",
              });
            }
          }
        }
        for (const [se, subs] of Object.entries(CMR_GENERAL.seriesSubjects)) {
          if (!cl.series.includes(se)) continue;
          for (const sub of subs) {
            items.push({
              import_id: importId, item_kind: "subject", proposed_name: sub, display_order: 0,
              parent_path: `${scopeLabel} › ${cl.name} › Série ${se}`,
              parent_ref: { class_name: cl.name, series_name: `Série ${se}` },
              verification_status: "ambiguous",
              source_title: "Architecture officielle du secondaire général francophone (Cameroun)",
              source_excerpt: `Matière de la Série ${se} (liste et coefficients à confirmer avec le programme officiel).`,
            });
          }
        }
      }
      gaps.push("Programmes annuels (chapitres) : non fournis par la couche « structure » — dépendent des documents collectés ci-dessous.");
    } else {
      gaps.push(`Périmètre « ${scopeLabel} » : la structure de référence intégrée ne couvre que l'enseignement général francophone du Cameroun. Fournissez des sources pour ce périmètre.`);
    }

    // ── COUCHE B : collecte web réelle + structuration des PROGRAMMES ──
    for (const url of seedUrls.slice(0, 6)) {
      const consulted: Record<string, unknown> = { url, ok: false };
      try {
        const { data: src } = await admin.from("ai_rag_sources").insert({
          title: `Programme collecté — ${new URL(url).hostname}`,
          source_type: "url", source_url: url, access_terms_ack: true, status: "active",
          provenance: `Collecte curriculum (import ${importId})`, created_by: adminRow.id,
        }).select("id").single();
        const { data: job } = await admin.from("ai_ingestion_jobs").insert({
          source_id: src!.id, job_type: "crawl", created_by: adminRow.id,
        }).select("id").single();

        const wr = await fetch(`${SUPABASE_URL}/functions/v1/ingestion-worker`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${jwt}` },
          body: JSON.stringify({ job_id: job!.id }),
        });
        const wrData = await wr.json();
        consulted.worker = wrData?.results?.[0]?.note ?? wrData?.message ?? "?";

        const { data: doc } = await admin.from("ai_extracted_documents")
          .select("id, title, extracted_text, metadata")
          .eq("source_id", src!.id).order("created_at", { ascending: false }).limit(1).maybeSingle();

        consulted.title = doc?.title ?? null;
        consulted.http_status = (doc?.metadata as Record<string, unknown> | undefined)?.http_status ?? null;

        if (!doc || (doc.extracted_text ?? "").length < 200) {
          gaps.push(`Source ${url} : contenu insuffisant ou inaccessible (aucun programme exploitable extrait).`);
          sourcesConsulted.push(consulted);
          continue;
        }
        consulted.ok = true;

        // Structuration via Model Router — extraction STRICTE, sans complétion.
        const rr = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-text`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SERVICE_ROLE}` },
          body: JSON.stringify({
            capability: "structuring_json",
            json: true,
            max_tokens: 8192,
            temperature: 0.1,
            system_prompt:
              "Tu extrais des données curriculaires UNIQUEMENT si elles sont EXPLICITEMENT présentes dans le texte fourni. " +
              "N'invente RIEN. Ne complète aucune liste manquante. Si le texte ne contient pas de programme, renvoie des tableaux vides. " +
              "Réponds en JSON strict.",
            user_prompt:
              `Périmètre attendu : ${scopeLabel} (Cameroun, secondaire général francophone, 3ème → Terminale, séries A/C/D).\n\n` +
              `TEXTE SOURCE (${url}) :\n"""${(doc.extracted_text as string).slice(0, 14000)}"""\n\n` +
              `Renvoie STRICTEMENT ce JSON :\n` +
              `{"year":"année/version du programme si mentionnée, sinon null",` +
              `"programs":[{"class_name":"ex: Classe de 1ère","series_name":"ex: Série C ou null","subject_name":"ex: Mathématiques",` +
              `"chapters":[{"title":"intitulé exact du chapitre/thème","order":1,"excerpt":"phrase littérale du texte qui le mentionne"}],` +
              `"completeness":"ok|incomplete|ambiguous"}],` +
              `"gaps":["ce qui est mentionné comme manquant/partiel/ambigu"]}`,
          }),
        });
        const rrData = await rr.json();
        if (!rr.ok) {
          gaps.push(`Source ${url} : structuration IA indisponible (${rrData.error ?? rr.status}).`);
          sourcesConsulted.push(consulted);
          continue;
        }
        let parsed: Record<string, unknown>;
        try {
          parsed = JSON.parse((rrData.text as string).replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim());
        } catch {
          gaps.push(`Source ${url} : réponse de structuration illisible.`);
          sourcesConsulted.push(consulted);
          continue;
        }
        consulted.year = parsed.year ?? null;
        consulted.provider = rrData._provider;
        for (const g of (parsed.gaps as string[] | undefined) ?? []) gaps.push(`Source ${url} : ${g}`);

        for (const prog of (parsed.programs as Record<string, unknown>[] | undefined) ?? []) {
          const chapters = (prog.chapters as Record<string, unknown>[] | undefined) ?? [];
          const completeness = (prog.completeness as string) ?? "ambiguous";
          chapters.forEach((ch, i) => {
            const title = String(ch.title ?? "").trim();
            if (!title) return;
            items.push({
              import_id: importId, item_kind: "chapter", proposed_name: title,
              display_order: Number(ch.order ?? i + 1),
              parent_path: `${scopeLabel} › ${prog.class_name}${prog.series_name ? " › " + prog.series_name : ""} › ${prog.subject_name}`,
              parent_ref: { class_name: prog.class_name, series_name: prog.series_name ?? null, subject_name: prog.subject_name },
              verification_status: completeness === "ok" ? "ok" : (completeness === "incomplete" ? "incomplete" : "ambiguous"),
              source_id: src!.id, source_title: doc.title, source_url: url,
              source_year: parsed.year ? String(parsed.year) : null,
              source_excerpt: String(ch.excerpt ?? "").slice(0, 500),
            });
          });
          // Matière explicitement nommée par la source mais absente de la couche A → proposée aussi.
          if (prog.subject_name) {
            items.push({
              import_id: importId, item_kind: "subject", proposed_name: String(prog.subject_name),
              display_order: 0,
              parent_path: `${scopeLabel} › ${prog.class_name}${prog.series_name ? " › " + prog.series_name : ""}`,
              parent_ref: { class_name: prog.class_name, series_name: prog.series_name ?? null },
              verification_status: "ok",
              source_id: src!.id, source_title: doc.title, source_url: url,
              source_excerpt: `Matière nommée dans le programme officiel collecté.`,
            });
          }
        }
      } catch (e) {
        gaps.push(`Source ${url} : erreur de collecte (${(e as Error).message}).`);
      }
      sourcesConsulted.push(consulted);
    }
    if (seedUrls.length === 0) {
      gaps.push("Aucune source web fournie : seule la structure de référence est proposée. Ajoutez des URL de programmes officiels (MINESEC, inspections de pédagogie, dépôts d'établissements) pour collecter les chapitres.");
    }

    // ── Dédup contre l'arbre existant + entre items ──
    const { data: existNodesRaw } = await admin.from("academic_nodes").select("id, name, node_type, parent_id");
    const { data: existSubjectsRaw } = await admin.from("subjects").select("id, name");
    const { data: existChaptersRaw } = await admin.from("chapters").select("id, title, subject_id, class_node_id");
    const existNodes = (existNodesRaw ?? []) as { id: string; name: string; node_type: string; parent_id: string | null }[];
    const existSubjects = (existSubjectsRaw ?? []) as { id: string; name: string }[];
    const existChapters = (existChaptersRaw ?? []) as { id: string; title: string }[];
    const nodeByKey = new Map<string, { id: string }>(existNodes.map((n) => [`${n.node_type}|${norm(n.name)}`, { id: n.id }]));
    const subjByName = new Map<string, { id: string }>(existSubjects.map((s) => [norm(s.name), { id: s.id }]));
    const chapKeys = new Set<string>(existChapters.map((c) => norm(c.title)));

    const seen = new Set<string>();
    const toInsert: Record<string, unknown>[] = [];
    let matched = 0, ambiguous = 0;
    for (const it of items) {
      const dedupKey = `${it.item_kind}|${norm(String(it.proposed_name))}|${norm(String(it.parent_path))}`;
      if (seen.has(dedupKey)) continue;
      seen.add(dedupKey);

      if (it.verification_status === "ambiguous" || it.verification_status === "incomplete") ambiguous++;

      if (it.item_kind === "class" || it.item_kind === "series") {
        const m = nodeByKey.get(`${it.item_kind}|${norm(String(it.proposed_name))}`);
        if (m) { it.matched_node_id = m.id; it.match_confidence = 0.95; matched++; }
      } else if (it.item_kind === "subject") {
        const m = subjByName.get(norm(String(it.proposed_name)));
        if (m) { it.matched_subject_id = m.id; it.match_confidence = 0.9; matched++; }
      } else if (it.item_kind === "chapter") {
        if (chapKeys.has(norm(String(it.proposed_name)))) { it.match_confidence = 0.8; matched++; }
      }
      toInsert.push(it);
    }

    // Normalise chaque ligne au MÊME jeu de colonnes (PostgREST refuse un insert en lot hétérogène).
    const COLS = [
      "import_id", "item_kind", "proposed_name", "proposed_code", "display_order",
      "parent_path", "parent_ref", "matched_node_id", "matched_subject_id", "matched_chapter_id",
      "match_confidence", "verification_status", "source_id", "source_title", "source_url",
      "source_year", "source_excerpt", "notes",
    ];
    const rows = toInsert.map((it) => {
      const r: Record<string, unknown> = {};
      for (const c of COLS) r[c] = it[c] ?? (c === "match_confidence" || c === "display_order" ? 0 : null);
      r.parent_ref = it.parent_ref ?? {};
      return r;
    });
    let insertError: string | null = null;
    for (let i = 0; i < rows.length; i += 200) {
      const { error } = await admin.from("curriculum_import_items").insert(rows.slice(i, i + 200));
      if (error) { insertError = error.message; break; }
    }
    if (insertError) {
      await admin.from("curriculum_imports").update({ status: "failed", error_message: `Insertion des éléments : ${insertError}` }).eq("id", importId);
      return json({ error: `Échec d'enregistrement des éléments proposés : ${insertError}`, import_id: importId }, 500);
    }

    const summary = {
      proposed: toInsert.length,
      classes: toInsert.filter((i) => i.item_kind === "class").length,
      series: toInsert.filter((i) => i.item_kind === "series").length,
      subjects: toInsert.filter((i) => i.item_kind === "subject").length,
      chapters: toInsert.filter((i) => i.item_kind === "chapter").length,
      matched, ambiguous,
    };
    await admin.from("curriculum_imports").update({
      status: "proposed", summary, sources_consulted: sourcesConsulted, gaps,
    }).eq("id", importId);

    return json({ import_id: importId, scope_label: scopeLabel, summary, sources_consulted: sourcesConsulted, gaps });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne de la collecte curriculum." }, 500);
  }
});
