// Applique les éléments d'un import de curriculum dans l'arbre académique (demande #2).
// Rattachement aux bons parents · correspondance avec l'existant · prévention des doublons ·
// mise à jour SANS écraser les modifications manuelles · conservation des sources · statut
// « À vérifier » pour les éléments ambigus/incomplets · suivi et réversibilité.
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
    .replace(/^(classe de |serie |série )/i, "").replace(/[^a-z0-9]+/g, " ").trim();

type Item = {
  id: string; item_kind: string; proposed_name: string; proposed_code: string | null;
  display_order: number; parent_ref: Record<string, string | null>;
  matched_node_id: string | null; matched_subject_id: string | null; matched_chapter_id: string | null;
  verification_status: string; source_id: string | null; source_year: string | null;
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { data: u } = await admin.auth.getUser(jwt);
    const { data: adminRow } = u?.user?.id
      ? await admin.from("admin_users").select("id, role").eq("auth_user_id", u.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const { import_id, item_ids, mode } = await req.json().catch(() => ({}));
    if (!import_id) return json({ error: "Paramètre 'import_id' manquant." }, 400);

    const { data: imp } = await admin.from("curriculum_imports")
      .select("id, scope_node_id, scope_country_id, status").eq("id", import_id).maybeSingle();
    if (!imp) return json({ error: "Import introuvable." }, 404);
    if (!imp.scope_node_id) return json({ error: "Import sans périmètre résolu." }, 400);

    let q = admin.from("curriculum_import_items").select("*").eq("import_id", import_id)
      .in("status", mode === "reapply" ? ["proposed", "verified", "applied"] : ["proposed", "verified"]);
    if (Array.isArray(item_ids) && item_ids.length) q = q.in("id", item_ids);
    const { data: itemsRaw } = await q;
    const all = (itemsRaw ?? []) as Item[];
    // mode 'verified_only' : ne garder que les éléments non ambigus/incomplets.
    const items = mode === "verified_only" ? all.filter((i) => i.verification_status === "ok") : all;

    // Ordre de traitement : parents d'abord.
    const order = { class: 0, series: 1, subject: 2, chapter: 3 } as Record<string, number>;
    items.sort((a, b) => (order[a.item_kind] ?? 9) - (order[b.item_kind] ?? 9));

    // Caches résolus au fil de l'eau (nom normalisé → id).
    const classNodeByName = new Map<string, string>();
    const seriesNodeByKey = new Map<string, string>(); // `${classNorm}|${seriesNorm}` → id
    const subjectByName = new Map<string, string>();

    // Pré-charger l'existant.
    const { data: nAll } = await admin.from("academic_nodes").select("id, name, node_type, parent_id");
    const nodes = (nAll ?? []) as { id: string; name: string; node_type: string; parent_id: string | null }[];
    for (const n of nodes) {
      if (n.node_type === "class") classNodeByName.set(norm(n.name), n.id);
    }
    const { data: sAll } = await admin.from("subjects").select("id, name, code");
    const usedCodes = new Set<string>();
    for (const s of (sAll ?? []) as { id: string; name: string; code: string | null }[]) {
      subjectByName.set(norm(s.name), s.id);
      if (s.code) usedCodes.add(s.code);
    }
    // subjects.code est NOT NULL sans défaut → on génère un code court unique.
    const makeCode = (name: string): string => {
      const base = norm(name).split(" ").filter((w) => w.length > 2).slice(0, 3)
        .map((w) => w.slice(0, 6)).join("_").toUpperCase().slice(0, 20) || "MAT";
      let code = base, i = 2;
      while (usedCodes.has(code)) code = `${base}_${i++}`.slice(0, 24);
      usedCodes.add(code);
      return code;
    };
    // séries : `${classNorm}|${seriesNorm}`
    for (const n of nodes.filter((x) => x.node_type === "series")) {
      const parent = nodes.find((p) => p.id === n.parent_id);
      if (parent) seriesNodeByKey.set(`${norm(parent.name)}|${norm(n.name)}`, n.id);
    }

    const result = { classes: 0, series: 0, subjects: 0, links: 0, chapters: 0, skipped: 0, updated: 0, errors: [] as string[] };

    const resolveClassId = (className: string): string | null =>
      classNodeByName.get(norm(className)) ?? null;
    const resolveClassNodeId = (pref: Record<string, string | null>): string | null => {
      // renvoie l'id du nœud classe OU série selon parent_ref
      const cId = pref.class_name ? resolveClassId(pref.class_name) : null;
      if (!cId) return null;
      if (pref.series_name) {
        const k = `${norm(pref.class_name!)}|${norm(pref.series_name)}`;
        return seriesNodeByKey.get(k) ?? cId; // repli sur la classe si la série n'existe pas encore
      }
      return cId;
    };

    for (const it of items) {
      try {
        if (it.item_kind === "class") {
          let id = it.matched_node_id ?? classNodeByName.get(norm(it.proposed_name)) ?? null;
          if (!id) {
            const { data: created, error: e } = await admin.from("academic_nodes").insert({
              parent_id: imp.scope_node_id, node_type: "class", name: it.proposed_name,
              country_id: imp.scope_country_id, verification_status: it.verification_status,
              curriculum_import_id: import_id, is_active: true,
            }).select("id").single();
            if (e || !created) { result.errors.push(`Classe « ${it.proposed_name} » : ${e?.message ?? "insertion refusée"}`); continue; }
            id = created.id; result.classes++;
          }
          classNodeByName.set(norm(it.proposed_name), id!);
          await admin.from("curriculum_import_items").update({ status: "applied", applied_entity_id: id }).eq("id", it.id);
        } else if (it.item_kind === "series") {
          const classId = it.parent_ref.class_name ? resolveClassId(it.parent_ref.class_name) : null;
          if (!classId) { result.errors.push(`Série « ${it.proposed_name} » : classe parente introuvable.`); continue; }
          const key = `${norm(it.parent_ref.class_name!)}|${norm(it.proposed_name)}`;
          let id = it.matched_node_id ?? seriesNodeByKey.get(key) ?? null;
          if (!id) {
            const { data: created, error: e } = await admin.from("academic_nodes").insert({
              parent_id: classId, node_type: "series", name: it.proposed_name, code: it.proposed_code,
              country_id: imp.scope_country_id, verification_status: it.verification_status,
              curriculum_import_id: import_id, is_active: true,
            }).select("id").single();
            if (e || !created) { result.errors.push(`Série « ${it.proposed_name} » : ${e?.message ?? "insertion refusée"}`); continue; }
            id = created.id; result.series++;
          }
          seriesNodeByKey.set(key, id!);
          await admin.from("curriculum_import_items").update({ status: "applied", applied_entity_id: id }).eq("id", it.id);
        } else if (it.item_kind === "subject") {
          let sid = it.matched_subject_id ?? subjectByName.get(norm(it.proposed_name)) ?? null;
          if (!sid) {
            const { data: created, error: subErr } = await admin.from("subjects").insert({
              name: it.proposed_name, code: makeCode(it.proposed_name),
              country_id: imp.scope_country_id, is_active: true,
              verification_status: it.verification_status, curriculum_import_id: import_id,
            }).select("id").single();
            if (subErr || !created) {
              result.errors.push(`Matière « ${it.proposed_name} » : ${subErr?.message ?? "insertion refusée"}`);
              continue;
            }
            sid = created.id; result.subjects++;
          }
          subjectByName.set(norm(it.proposed_name), sid!);
          const classNodeId = resolveClassNodeId(it.parent_ref);
          if (classNodeId) {
            const { data: existLink } = await admin.from("subject_class_links")
              .select("subject_id").eq("subject_id", sid).eq("class_node_id", classNodeId).maybeSingle();
            if (!existLink) {
              await admin.from("subject_class_links").insert({ subject_id: sid, class_node_id: classNodeId });
              result.links++;
            }
          }
          await admin.from("curriculum_import_items").update({ status: "applied", applied_entity_id: sid }).eq("id", it.id);
        } else if (it.item_kind === "chapter") {
          const sid = it.parent_ref.subject_name ? subjectByName.get(norm(it.parent_ref.subject_name)) : null;
          const classNodeId = resolveClassNodeId(it.parent_ref);
          if (!sid || !classNodeId) {
            result.errors.push(`Chapitre « ${it.proposed_name} » : matière ou classe parente non résolue.`);
            continue;
          }
          // Dédup : chapitre existant de même titre (insensible casse/accents) pour (matière, classe).
          const { data: existRows } = await admin.from("chapters")
            .select("id, title, manually_edited")
            .eq("subject_id", sid).eq("class_node_id", classNodeId);
          const target = ((existRows ?? []) as { id: string; title: string; manually_edited: boolean }[])
            .find((c) => norm(c.title) === norm(it.proposed_name)) ?? null;
          if (target) {
            if (target.manually_edited) { result.skipped++; }
            else {
              await admin.from("chapters").update({
                display_order: it.display_order, verification_status: it.verification_status,
                source_id: it.source_id, source_year: it.source_year, curriculum_import_id: import_id,
              }).eq("id", target.id);
              result.updated++;
            }
            await admin.from("curriculum_import_items").update({ status: "applied", applied_entity_id: target.id }).eq("id", it.id);
          } else {
            const { data: created, error: e } = await admin.from("chapters").insert({
              subject_id: sid, class_node_id: classNodeId, title: it.proposed_name,
              display_order: it.display_order, is_active: true,
              verification_status: it.verification_status, curriculum_import_id: import_id,
              source_id: it.source_id, source_year: it.source_year,
            }).select("id").single();
            if (e || !created) { result.errors.push(`Chapitre « ${it.proposed_name} » : ${e?.message ?? "insertion refusée"}`); continue; }
            result.chapters++;
            await admin.from("curriculum_import_items").update({ status: "applied", applied_entity_id: created.id }).eq("id", it.id);
          }
        }
      } catch (e) {
        result.errors.push(`${it.item_kind} « ${it.proposed_name} » : ${(e as Error).message}`);
      }
    }

    // Statut de l'import
    const { count: remaining } = await admin.from("curriculum_import_items")
      .select("id", { count: "exact", head: true }).eq("import_id", import_id).in("status", ["proposed", "verified"]);
    const newStatus = (remaining ?? 0) > 0 ? "partially_applied" : "applied";
    await admin.from("curriculum_imports").update({ status: newStatus, applied_at: new Date().toISOString() }).eq("id", import_id);

    return json({ import_id, status: newStatus, applied: result });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne de l'application curriculum." }, 500);
  }
});
