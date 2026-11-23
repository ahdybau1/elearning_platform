-- ============================================================================
-- 95 — Familles de séries (scientifique / littéraire / artistique), libellé officiel, sexe
-- ============================================================================
-- Demande du porteur (22/11) : à l'inscription, après « Terminale », l'élève doit d'abord dire s'il
-- est en série scientifique ou littéraire, puis voir « Terminale C », « Terminale D »… et non une
-- liste plate « Série A, Série A1, …, Série TI ». Ajout du sexe de l'élève à l'inscription.
--
-- Nomenclature MINESEC (sous-système francophone, enseignement secondaire général), vérifiée le
-- 22/11/2026 :
--   • séries scientifiques et technologiques : C, D, TI, et E « Mathématiques et techniques »
--     (arrêté du 17 mars 2022) ;
--   • séries littéraires : A1 (lettres, latin et grec), A2 (lettres, latin et langue vivante 2),
--     A3 (lettres, latin), A4 (lettres, langue vivante 2 et philosophie), A5 (lettres, langues
--     vivantes 2 et 3), ABI (A4 bilingue) ;
--   • SH « Sciences humaines » et AC « Arts cinématographiques » : séries ouvertes en 2019 (pilote)
--     puis officiellement à la rentrée 2024-2025.
-- Sous-système anglophone (GCE A Level) : séries Science S1–S4, séries Arts A1–A8.
--
-- Non destructif : deux colonnes nullables sur academic_nodes, une sur accounts ; le remplissage
-- ne touche que les nœuds `series` dont la famille est encore vide (les choix faits dans l'admin
-- sont respectés). Les libellés de C, D et TI sont les intitulés usuels (à confirmer par l'admin).
-- ============================================================================

alter table academic_nodes
    add column if not exists series_family text
        check (series_family in ('scientifique', 'litteraire', 'artistique')),
    add column if not exists description text;

comment on column academic_nodes.series_family is
    'Famille d''une série (scientifique / littéraire / artistique) : l''inscription élève regroupe les séries par famille.';
comment on column academic_nodes.description is
    'Libellé officiel affiché sous le nom (ex. « Mathématiques et techniques » pour la série E).';

-- Sous-système francophone : « Série X »
update academic_nodes set series_family = 'scientifique'
 where node_type = 'series' and series_family is null and name ~ '^Série (C|D|E|TI)$';
update academic_nodes set series_family = 'litteraire'
 where node_type = 'series' and series_family is null and name ~ '^Série (A|A[1-5]|ABI|SH)$';
update academic_nodes set series_family = 'artistique'
 where node_type = 'series' and series_family is null and name = 'Série AC';

-- Sous-système anglophone : « S1 », « A1 »…
update academic_nodes set series_family = 'scientifique'
 where node_type = 'series' and series_family is null and name ~ '^S[0-9]+$';
update academic_nodes set series_family = 'litteraire'
 where node_type = 'series' and series_family is null and name ~ '^A[0-9]+$';

-- Libellés officiels (francophone)
update academic_nodes n set description = v.label
  from (values
        ('Série C',   'Mathématiques et sciences physiques'),
        ('Série D',   'Mathématiques et sciences de la vie et de la Terre'),
        ('Série E',   'Mathématiques et techniques'),
        ('Série TI',  'Technologies de l''information'),
        ('Série A',   'Lettres'),
        ('Série A1',  'Lettres, latin et grec'),
        ('Série A2',  'Lettres, latin et langue vivante 2'),
        ('Série A3',  'Lettres et latin'),
        ('Série A4',  'Lettres, langue vivante 2 et philosophie'),
        ('Série A5',  'Lettres, langues vivantes 2 et 3'),
        ('Série ABI', 'Lettres bilingues (A4 bilingue)'),
        ('Série SH',  'Sciences humaines'),
        ('Série AC',  'Arts cinématographiques')
       ) as v(name, label)
 where n.node_type = 'series' and n.name = v.name and n.description is null;

-- Libellés officiels (anglophone, combinaisons GCE A Level les plus courantes)
update academic_nodes n set description = v.label
  from (values
        ('S1', 'Chemistry, Physics, Pure Mathematics'),
        ('S2', 'Chemistry, Physics, Biology'),
        ('S3', 'Biology, Chemistry, Mathematics'),
        ('S4', 'Biology, Chemistry, Geology'),
        ('A1', 'Literature, History, French'),
        ('A2', 'History, Geography, Economics'),
        ('A3', 'Literature, Economics, History'),
        ('A4', 'Economics, Geography, Mathematics'),
        ('A5', 'Literature, Philosophy, Mathematics'),
        ('A6', 'Literature, French, one foreign language'),
        ('A7', 'Literature, Cinematography, Computer Science')
       ) as v(name, label)
 where n.node_type = 'series' and n.name = v.name and n.description is null;

-- ── Enseignement technique : intitulés officiels des filières et spécialités ──
-- Source : tables « Diversité de l'offre de formation » du MINESEC (sous-systèmes francophone et
-- anglophone), relevées le 23/11/2026. Les sigles dont l'intitulé n'apparaît pas dans ces tables
-- (BCA, BP CF, CMA-MVPL, CMBA, COOM, COUF, F7, IH, MAEL, MAIN, MAV, MENA, MIND, SES, SH en STT)
-- restent sans libellé : à compléter dans l'admin plutôt que d'inventer.
update academic_nodes n set description = v.label
  from (values
        ('IND', 'Sciences et techniques industrielles'),
        ('STT', 'Sciences et technologies du tertiaire'),
        ('Industrial', 'Industrial Sciences and Technology'),
        ('Commercial', 'Tertiary Sciences and Technology')
       ) as v(name, label)
 where n.node_type = 'family' and n.name = v.name and n.description is null;

update academic_nodes n set description = v.label
  from (values
        -- Sciences et technologies du tertiaire (STT)
        ('AAT', 'Accueil et animation touristique'), ('ACA', 'Action et communication administrative'),
        ('ACC', 'Action et communication commerciale'), ('AV', 'Agence de voyage'),
        ('BPA', 'Boulangerie pâtisserie'), ('CG', 'Comptabilité de gestion'), ('CU', 'Cuisine'),
        ('ESCOM', 'Employé des services comptables'), ('ESF', 'Économie sociale et familiale'),
        ('ESFI', 'Employé des services financiers'), ('FIG', 'Fiscalité et informatique de gestion'),
        ('HE', 'Hébergement'), ('HO', 'Hôtellerie'), ('RE', 'Restauration'),
        ('SEBU', 'Secrétariat et bureautique'), ('SEME', 'Secrétariat médical'),
        ('TO', 'Tourisme'), ('VENTE', 'Vendeur'),
        -- Génie mécanique
        ('BIJO', 'Bijouterie'), ('CAPA', 'Carrosserie peinture automobile'), ('CM', 'Construction mécanique'),
        ('CMA-MVT', 'Construction et maintenance automobile, option véhicules de tourisme'),
        ('E', 'Technique et mathématiques'), ('F1', 'Fabrication mécanique'), ('MA', 'Mécanique automobile'),
        ('MARE', 'Mécanique automobile, réparation'), ('MEFA', 'Mécanique de fabrication'),
        ('MEFE', 'Métaux en feuilles'), ('MEM', 'Maintenance électromécanique'),
        ('MF/CM', 'Métaux en feuilles et construction métallique'),
        -- Génie électrique, chimie industrielle, sciences biomédicales
        ('AICB', 'Aide chimiste biologiste'), ('AICI', 'Aide chimiste industriel'), ('CI', 'Chimie industrielle'),
        ('ELEQ', 'Électricité d''équipement'), ('ELME', 'Électromécanique'), ('ELNI', 'Électronique'),
        ('F2', 'Électronique'), ('F3', 'Électrotechnique'), ('F5', 'Froid et climatisation'),
        ('F6-BIPE', 'Génie chimique, option bioprocédés'), ('F6-COPH', 'Génie chimique, option cosmétique et pharmacie'),
        ('F6-MIPE', 'Génie chimique, option mines et pétroles'), ('F8', 'Sciences et technologies médico-sociales'),
        ('FRCL', 'Froid et climatisation'), ('MEHB', 'Maintenance des équipements hospitaliers et biomédicaux'),
        ('MISE', 'Maintenance et installation des systèmes électroniques'),
        -- Génie civil, génie du bois, techniques agricoles
        ('CARR', 'Carrelage'), ('DEBA', 'Dessin en bâtiment'), ('F4BA', 'Génie civil, bâtiment'),
        ('F4BE', 'Génie civil, bureau d''études'), ('F4TP', 'Génie civil, travaux publics'),
        ('GTTO', 'Géomètre topographe'), ('IB', 'Industrie du bois'), ('INSA', 'Installation sanitaire'),
        ('IS', 'Installation sanitaire'), ('MACO', 'Maçonnerie'), ('MEB', 'Menuiserie ébénisterie'),
        ('MENU', 'Menuiserie'), ('PA', 'Production animale'), ('PV', 'Production végétale'),
        ('TGF', 'Techniques et gestion forestières'),
        -- Arts et modes
        ('COME', 'Couture sur mesure'), ('DECOR', 'Décoration'), ('ESCO', 'Esthétique et coiffure'),
        ('PEINT', 'Peinture'), ('SCULP', 'Sculpture')
       ) as v(name, label)
 where n.node_type = 'specialty' and n.name = v.name and n.description is null;

-- ── Ordre officiel des classes et des séries (auparavant alphabétique : « Cinquième » avant
-- « Sixième ») ──
update academic_nodes n set display_order = v.ord
  from (values
        ('Sixième', 1), ('Cinquième', 2), ('Quatrième', 3), ('Troisième', 4),
        ('Seconde', 1), ('Première', 2), ('Terminale', 3),
        ('Première année', 1), ('Deuxième année', 2), ('Troisième année', 3), ('Quatrième année', 4),
        ('Form 1', 1), ('Form 2', 2), ('Form 3', 3), ('Form 4', 4), ('Form 5', 5),
        ('Lower Sixth', 1), ('Upper Sixth', 2),
        ('Year I', 1), ('Year II', 2), ('Year III', 3), ('Year IV', 4),
        ('Year V', 1), ('Year VI', 2), ('Year VII', 3)
       ) as v(name, ord)
 where n.node_type = 'class' and n.name = v.name;

update academic_nodes n set display_order = v.ord
  from (values
        ('Série C', 1), ('Série D', 2), ('Série E', 3), ('Série TI', 4),
        ('Série A', 10), ('Série A1', 11), ('Série A2', 12), ('Série A3', 13), ('Série A4', 14),
        ('Série A5', 15), ('Série ABI', 16), ('Série SH', 17), ('Série AC', 18)
       ) as v(name, ord)
 where n.node_type = 'series' and n.name = v.name;

-- ── Libellé complet d'une classe : « Terminale D », « Première F4BA », « Lower Sixth S1 » ──
-- Colonne calculée PostgREST : `select('name, display_label')`. Pour une série ou une spécialité,
-- on préfixe par la classe la plus proche dans l'arbre (une spécialité technique peut être séparée
-- de sa classe par une ou deux familles).
create or replace function display_label(n academic_nodes)
returns text as $$
    with recursive up as (
        select a.id, a.parent_id, a.node_type, a.name, 1 as depth
          from academic_nodes a where a.id = n.parent_id
        union all
        select a.id, a.parent_id, a.node_type, a.name, up.depth + 1
          from academic_nodes a join up on a.id = up.parent_id
         where up.depth < 8
    )
    , cls as (
        select regexp_replace(up.name, '^Classe de\s+', '', 'i') as short_class
          from up where up.node_type = 'class' order by up.depth limit 1
    )
    , me as (select trim(regexp_replace(n.name, '^S[ée]rie\s+', '', 'i')) as short_name)
    select case
        when n.node_type not in ('series', 'specialty') then n.name
        when not exists (select 1 from cls) then (select short_name from me)
        -- Le nom contient déjà la classe (« Terminale C (…) ») : on ne la répète pas.
        when (select lower(short_name) from me) like (select lower(short_class) from cls) || ' %'
            then (select short_name from me)
        else (select short_class from cls) || ' ' || (select short_name from me)
    end;
$$ language sql stable set search_path = public;

comment on function display_label(academic_nodes) is
    'Libellé complet affiché à l''élève : « Terminale D » plutôt que « Série D » (migration 95).';

-- Sexe de l'élève (facultatif : null = non renseigné)
alter table accounts
    add column if not exists gender text check (gender in ('masculin', 'feminin'));
comment on column accounts.gender is 'Sexe déclaré à l''inscription : masculin / feminin (facultatif).';

notify pgrst, 'reload schema';
