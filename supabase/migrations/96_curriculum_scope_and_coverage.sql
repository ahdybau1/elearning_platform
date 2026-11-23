-- 96 — Programmes : contenu commun de classe visible des séries, couverture et anomalies
--
-- Constat en production (23/11/2026) :
--   * Le profil d'un élève de second cycle pointe sur sa SÉRIE (« Terminale D »), mais 265 chapitres
--     ont été importés au niveau de la CLASSE (« Terminale », « Première », « Seconde ») : Philosophie,
--     Physique, Chimie, SVTEEHB, Histoire, Géographie, Anglais… L'app ne lisait que les chapitres de
--     la série : un élève de Terminale D ne voyait que les Mathématiques (15 chapitres sur ~120).
--   * Rien ne permettait de voir, dans l'admin, ce qui manque par classe et par matière.
--
-- Règle posée ici (tronc commun) : un élève voit
--   1. les chapitres rattachés à SA classe/série/spécialité ;
--   2. les chapitres rattachés à une classe ou famille PARENTE, uniquement pour les matières liées à
--      sa série (subject_class_links) ET si ce rattachement accepte le contenu commun
--      (`inherit_class_content`, vrai par défaut, décochable dans l'admin quand le programme de la
--      série diffère de celui posé au niveau de la classe).
-- Aucun chapitre n'est déplacé ni dupliqué.

-- ── 1. Option par rattachement matière-série ───────────────────────────────────────────────────
alter table subject_class_links
    add column if not exists inherit_class_content boolean not null default true;
comment on column subject_class_links.inherit_class_content is
    'Vrai : la série reprend aussi les chapitres de cette matière posés au niveau de la classe parente (tronc commun). Faux : seuls ses propres chapitres (programme spécifique).';

-- ── 2. Portée d'un nœud : lui-même puis ses parents jusqu'à la classe incluse ──────────────────
-- Ex. « Terminale F4BA » → [Terminale F4BA, famille IND, Terminale]. Une classe seule → [classe].
create or replace function content_scope_nodes(p_node uuid)
returns uuid[] as $$
    with recursive up as (
        select id, parent_id, node_type, 0 as depth from academic_nodes where id = p_node
        union all
        select a.id, a.parent_id, a.node_type, up.depth + 1
          from academic_nodes a join up on a.id = up.parent_id
         where up.node_type <> 'class' and up.depth < 6
    )
    select coalesce(array_agg(id order by depth), '{}'::uuid[]) from up;
$$ language sql stable security definer set search_path = public;

comment on function content_scope_nodes(uuid) is
    'Nœud puis parents jusqu''à la classe incluse (migration 96) : portée du contenu commun.';

-- ── 3. Chapitres visibles pour un nœud (les règles RLS de chapters restent appliquées) ─────────
create or replace function chapters_for_node(p_node uuid, p_subject uuid default null)
returns setof chapters as $$
    select c.*
      from chapters c
     where c.is_active
       and (p_subject is null or c.subject_id = p_subject)
       and (
            c.class_node_id = p_node
            or (
                c.class_node_id = any ((content_scope_nodes(p_node))[2:])
                and exists (
                    select 1 from subject_class_links l
                     where l.class_node_id = p_node
                       and l.subject_id = c.subject_id
                       and l.inherit_class_content
                )
            )
       );
$$ language sql stable security invoker set search_path = public;

comment on function chapters_for_node(uuid, uuid) is
    'Chapitres actifs visibles d''une classe/série : les siens + ceux de la classe parente pour ses matières en tronc commun (migration 96).';

grant execute on function content_scope_nodes(uuid) to authenticated, anon;
grant execute on function chapters_for_node(uuid, uuid) to authenticated, anon;

-- ── 4. Couverture des programmes (admin) ────────────────────────────────────────────────────────
create or replace view curriculum_coverage with (security_invoker = true) as
select l.id as link_id,
       l.class_node_id,
       l.subject_id,
       s.name as subject_name,
       l.is_mandatory,
       l.inherit_class_content,
       l.verification_status,
       (select count(*) from chapters c
         where c.is_active and c.subject_id = l.subject_id and c.class_node_id = l.class_node_id) as own_chapters,
       (select count(*) from chapters c
         where c.is_active and c.subject_id = l.subject_id
           and c.class_node_id = any ((content_scope_nodes(l.class_node_id))[2:])) as class_chapters,
       (select count(*) from lessons le join chapters c on c.id = le.chapter_id
         where le.is_active and c.is_active and c.subject_id = l.subject_id
           and (c.class_node_id = l.class_node_id
                or (l.inherit_class_content
                    and c.class_node_id = any ((content_scope_nodes(l.class_node_id))[2:])))) as visible_lessons,
       (select count(*) from exercises e join chapters c on c.id = e.chapter_id
         where e.is_active and c.is_active and c.subject_id = l.subject_id
           and (c.class_node_id = l.class_node_id
                or (l.inherit_class_content
                    and c.class_node_id = any ((content_scope_nodes(l.class_node_id))[2:])))) as visible_exercises
  from subject_class_links l
  join subjects s on s.id = l.subject_id;

comment on view curriculum_coverage is
    'Par rattachement matière-classe : chapitres propres, chapitres communs de la classe, leçons et exercices réellement visibles (migration 96).';

-- ── 5. Anomalies de programme (admin) ──────────────────────────────────────────────────────────
create or replace view curriculum_anomalies with (security_invoker = true) as
-- a) Chapitre de test laissé dans le programme
select 'CHAPITRE_TEMPORAIRE'::text as kind, c.class_node_id as node_id, c.subject_id, c.id as chapter_id,
       'Chapitre de test : « ' || c.title || ' »' as detail
  from chapters c
 where c.is_active and (c.title ilike '%temporaire%' or c.title ilike 'vérification studio%')
union all
-- b) Chapitres posés sur une classe pour une matière qu'aucune de ses séries n'étudie : invisibles
select 'CHAPITRES_INVISIBLES', c.class_node_id, c.subject_id, null,
       count(*) || ' chapitre(s) rattaché(s) à la classe pour une matière qu''aucune série/spécialité n''étudie'
  from chapters c
 where c.is_active
   and not exists (
        select 1 from subject_class_links l
         where l.subject_id = c.subject_id
           and (l.class_node_id = c.class_node_id
                or c.class_node_id = any ((content_scope_nodes(l.class_node_id))[2:])))
 group by c.class_node_id, c.subject_id
union all
-- c) Même numéro de chapitre en double dans un même trimestre (deux programmes mélangés)
select 'NUMEROTATION_EN_DOUBLE', d.class_node_id, d.subject_id, null,
       d.n || ' chapitres commencent par « ' || d.num || ' » dans le même trimestre : deux programmes semblent mélangés'
  from (select c.class_node_id, c.subject_id, c.term_id,
               substring(c.title from '^\s*(?:Chapitre\s+)?([IVXLC]+|[0-9]+)\s*[.:)\-]') as num,
               count(*) as n
          from chapters c
         where c.is_active
         group by 1, 2, 3, 4) d
 where d.num is not null and d.n > 1
union all
-- d) Matière liée à une classe/série sans aucun chapitre visible
select 'MATIERE_SANS_CHAPITRE', cc.class_node_id, cc.subject_id, null,
       'Aucun chapitre visible pour « ' || cc.subject_name || ' »'
  from curriculum_coverage cc
 where cc.own_chapters = 0 and (not cc.inherit_class_content or cc.class_chapters = 0)
union all
-- e) Classe/série/spécialité terminale de l'arbre sans aucune matière
select 'NIVEAU_SANS_MATIERE', n.id, null, null, 'Aucune matière rattachée'
  from academic_nodes n
 where n.is_active and n.node_type in ('class', 'series', 'specialty')
   and not exists (select 1 from academic_nodes ch where ch.parent_id = n.id and ch.is_active)
   and not exists (select 1 from subject_class_links l where l.class_node_id = n.id);

comment on view curriculum_anomalies is
    'Problèmes de programme à corriger dans l''admin : chapitres de test, invisibles, doublons, matières vides, niveaux sans matière (migration 96).';

revoke all on curriculum_coverage, curriculum_anomalies from anon;
grant select on curriculum_coverage, curriculum_anomalies to authenticated;

-- ── 6. Corrections de données sûres et réversibles ─────────────────────────────────────────────
-- a) Le chapitre de test « Vérification Studio — Suites (temporaire) » est posé sur « Terminale » :
--    avec la règle de tronc commun, il deviendrait visible des Terminale C/D. Désactivé (pas supprimé).
update chapters set is_active = false
 where is_active and title ilike 'vérification studio%temporaire%';

-- b) Les 9 chapitres « Informatique » posés sur « Terminale » sont le programme de la série TI
--    (MERISE, SQL, langage C, réseaux) : les autres séries de Terminale ne les reprennent pas.
update subject_class_links l set inherit_class_content = false
  from subjects s, academic_nodes n, academic_nodes p
 where s.id = l.subject_id and s.name = 'Informatique'
   and n.id = l.class_node_id and n.node_type = 'series' and n.name <> 'Série TI'
   and p.id = n.parent_id and p.node_type = 'class' and p.name = 'Terminale'
   and exists (select 1 from chapters c
                where c.class_node_id = p.id and c.subject_id = s.id and c.is_active
                  and c.title ilike '%MERISE%');

notify pgrst, 'reload schema';
