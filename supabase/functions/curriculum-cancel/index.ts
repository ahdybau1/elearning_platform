// Annule un import de curriculum : retire de l'arbre les entités créées par cet import
// QUI N'ONT PAS été éditées manuellement ET qui n'ont pas de contenu dépendant (leçons,
// sous-nœuds, autres liens). Réversibilité exigée par la demande #2, sans jamais toucher au
// travail manuel de l'admin.
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { data: u } = await admin.auth.getUser(jwt);
    const { data: adminRow } = u?.user?.id
      ? await admin.from("admin_users").select("id").eq("auth_user_id", u.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const { import_id } = await req.json().catch(() => ({}));
    if (!import_id) return json({ error: "Paramètre 'import_id' manquant." }, 400);

    const removed = { chapters: 0, subjects: 0, subjectLinks: 0, series: 0, classes: 0 };
    const kept: string[] = [];

    // 1. Chapitres de l'import, non édités, sans leçon.
    const { data: chs } = await admin.from("chapters")
      .select("id, title, manually_edited").eq("curriculum_import_id", import_id);
    for (const c of ((chs ?? []) as { id: string; title: string; manually_edited: boolean }[])) {
      if (c.manually_edited) { kept.push(`Chapitre « ${c.title} » (édité manuellement)`); continue; }
      const { count } = await admin.from("lessons").select("id", { count: "exact", head: true }).eq("chapter_id", c.id);
      if ((count ?? 0) > 0) { kept.push(`Chapitre « ${c.title} » (${count} leçon(s))`); continue; }
      await admin.from("chapters").delete().eq("id", c.id);
      removed.chapters++;
    }

    // 2. Matières de l'import, non éditées, sans chapitre restant.
    const { data: subs } = await admin.from("subjects")
      .select("id, name, manually_edited").eq("curriculum_import_id", import_id);
    for (const s of ((subs ?? []) as { id: string; name: string; manually_edited: boolean }[])) {
      if (s.manually_edited) { kept.push(`Matière « ${s.name} » (éditée manuellement)`); continue; }
      const { count: chCount } = await admin.from("chapters").select("id", { count: "exact", head: true }).eq("subject_id", s.id);
      if ((chCount ?? 0) > 0) { kept.push(`Matière « ${s.name} » (${chCount} chapitre(s) restant(s))`); continue; }
      const { data: links } = await admin.from("subject_class_links").select("subject_id").eq("subject_id", s.id);
      const linkCount = (links ?? []).length;
      await admin.from("subject_class_links").delete().eq("subject_id", s.id);
      removed.subjectLinks += linkCount;
      await admin.from("subjects").delete().eq("id", s.id);
      removed.subjects++;
    }

    // 3. Nœuds série puis classe de l'import, non édités, sans enfant ni contenu.
    const { data: nodes } = await admin.from("academic_nodes")
      .select("id, name, node_type, manually_edited").eq("curriculum_import_id", import_id);
    const byKind = (k: string) => ((nodes ?? []) as { id: string; name: string; node_type: string; manually_edited: boolean }[]).filter((n) => n.node_type === k);
    for (const kind of ["series", "class"]) {
      for (const n of byKind(kind)) {
        if (n.manually_edited) { kept.push(`${kind === "series" ? "Série" : "Classe"} « ${n.name} » (éditée)`); continue; }
        // Le nœud vient de cet import et n'a pas été édité → ses liens matière↔classe ont été posés
        // par l'import : on les retire (les matières elles-mêmes sont traitées à l'étape 2).
        const { data: nodeLinks } = await admin.from("subject_class_links").select("subject_id").eq("class_node_id", n.id);
        if ((nodeLinks ?? []).length) {
          await admin.from("subject_class_links").delete().eq("class_node_id", n.id);
          removed.subjectLinks += (nodeLinks ?? []).length;
        }
        const { count: childCount } = await admin.from("academic_nodes").select("id", { count: "exact", head: true }).eq("parent_id", n.id);
        const { count: chapCount } = await admin.from("chapters").select("id", { count: "exact", head: true }).eq("class_node_id", n.id);
        if ((childCount ?? 0) > 0 || (chapCount ?? 0) > 0) {
          kept.push(`${kind === "series" ? "Série" : "Classe"} « ${n.name} » (contenu rattaché)`);
          continue;
        }
        await admin.from("academic_nodes").delete().eq("id", n.id);
        if (kind === "series") removed.series++; else removed.classes++;
      }
    }

    await admin.from("curriculum_import_items").update({ status: "rejected" }).eq("import_id", import_id).in("status", ["proposed", "verified", "applied"]);
    await admin.from("curriculum_imports").update({ status: "cancelled" }).eq("id", import_id);

    return json({ import_id, removed, kept });
  } catch (err) {
    return json({ error: (err as Error).message ?? "Erreur interne de l'annulation." }, 500);
  }
});
