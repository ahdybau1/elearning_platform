-- ============================================================================
-- 95 — Groupes de séries (scientifique / littéraire), sexe et pays du téléphone
-- ============================================================================
-- Demande du porteur (22/11/2026) : à l'inscription, un élève du second cycle doit d'abord
-- choisir s'il est en série scientifique ou littéraire, puis sa série (« Terminale D », jamais
-- « Série D » seul) ; le formulaire doit demander le sexe et le pays du numéro de téléphone.
--
-- Structure officielle (MINESEC, sous-système francophone, enseignement général, second cycle) :
--   - séries scientifiques et technologiques : C, D, E (arrêté du 17 mars 2022), TI ;
--   - séries littéraires : A1, A2, A3, A4, A5, ABI (A4 bilingue) ;
--   - séries innovantes rattachées aux humanités : SH (Sciences humaines), AC (Arts cinématographiques).
-- Sous-système anglophone (Lower/Upper Sixth) : combinaisons « A… » (Arts) et « S… » (Science).
--
-- Choix technique : on N'AJOUTE PAS de niveau dans l'arbre (ce qui changerait le parent de chaque
-- série et toutes les requêtes qui remontent l'arbre). On marque chaque série avec `track`, et
-- l'app élève propose le choix scientifique / littéraire comme une étape d'affichage. Les
-- profils, chapitres et exercices restent rattachés aux mêmes nœuds : rien n'est déplacé.
-- Non destructif.
-- ============================================================================

alter table academic_nodes add column if not exists track text;
alter table academic_nodes drop constraint if exists academic_nodes_track_check;
alter table academic_nodes add constraint academic_nodes_track_check
    check (track is null or track in ('scientifique', 'litteraire'));

comment on column academic_nodes.track is
    'Groupe de série affiché à l''élève avant la série elle-même : scientifique (C, D, E, TI, S…) ou litteraire (A, A1-A5, ABI, SH, AC, A…). NULL hors séries.';

-- Remplissage initial des séries existantes (seulement là où rien n'a été choisi).
-- Code de série = dernier mot du nom, sans parenthèse : « Série D » → D, « S2 » → S2,
-- « Terminale C (Scientifique Math/Physique) » → C.
with s as (
    select id, upper((regexp_match(regexp_replace(trim(name), '\s*\(.*$', ''), '(\S+)$'))[1]) as short_name
    from academic_nodes
    where node_type = 'series' and track is null
)
update academic_nodes n
set track = case
        when s.short_name ~ '^(C|D|E|TI|S[0-9]+)$' then 'scientifique'
        when s.short_name ~ '^(A[0-9]*|ABI|SH|AC)$' then 'litteraire'
    end
from s
where n.id = s.id
  and (s.short_name ~ '^(C|D|E|TI|S[0-9]+)$' or s.short_name ~ '^(A[0-9]*|ABI|SH|AC)$');

-- Comptes élèves : sexe et pays de l'indicatif téléphonique (le numéro complet reste dans
-- `phone`, au format international +237…).
alter table accounts add column if not exists gender text;
alter table accounts drop constraint if exists accounts_gender_check;
alter table accounts add constraint accounts_gender_check
    check (gender is null or gender in ('masculin', 'feminin'));

alter table accounts add column if not exists phone_country_code text;
alter table accounts drop constraint if exists accounts_phone_country_code_check;
alter table accounts add constraint accounts_phone_country_code_check
    check (phone_country_code is null or phone_country_code ~ '^[A-Z]{2}$');

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Nom d'affichage d'une classe : « Terminale D », « Première TI », « Upper Sixth S1 »…
-- Une série ou spécialité seule (« Série D », « F4BA ») n'a pas de sens hors de sa classe.
-- Champ calculé PostgREST : `select('academic_nodes(name, display_name)')`.
-- ---------------------------------------------------------------------------
create or replace function academic_node_short_name(p_name text)
returns text as $$
    select trim(regexp_replace(regexp_replace(coalesce(p_name, ''), '^Classe de\s+', '', 'i'), '^S[ée]rie\s+', '', 'i'));
$$ language sql immutable;

create or replace function display_name(n academic_nodes)
returns text as $$
    with recursive up as (
        select p.id, p.parent_id, p.node_type, p.name, 1 as depth
        from academic_nodes p where p.id = n.parent_id
        union all
        select p.id, p.parent_id, p.node_type, p.name, up.depth + 1
        from academic_nodes p join up on p.id = up.parent_id
        where up.node_type <> 'class' and up.depth < 10
    )
    , cls as (
        select academic_node_short_name(up.name) as short_class
        from up where up.node_type = 'class' order by up.depth limit 1
    )
    select case
        when n.node_type in ('series', 'specialty') and exists (select 1 from cls) then (
            select case
                -- Le nom contient déjà la classe (« Terminale C (…) ») : on le garde tel quel.
                when lower(academic_node_short_name(n.name)) like lower(cls.short_class) || ' %'
                    then academic_node_short_name(n.name)
                else cls.short_class || ' ' || academic_node_short_name(n.name)
            end
            from cls)
        else n.name
    end;
$$ language sql stable set search_path = public;

grant execute on function display_name(academic_nodes) to anon, authenticated;
grant execute on function academic_node_short_name(text) to anon, authenticated;
