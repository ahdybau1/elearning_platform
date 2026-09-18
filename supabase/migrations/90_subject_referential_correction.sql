-- Correction du référentiel des matières (Premier Cycle Général Francophone 6e/5e/4e/3e +
-- disciplines spécialisées Première TI), sur instruction explicite et détaillée de l'utilisateur
-- ("CORRECTION OBLIGATOIRE DU RÉFÉRENTIEL DES MATIÈRES PQ LEARN"). Avant cette migration : 6e/5e/4e
-- et Première/Terminale TI n'avaient AUCUNE matière rattachée ; 3e avait des matières incomplètes
-- et deux rattachements incorrects ("Français & Littérature" en doublon de "Français", et "SVT"
-- générique au lieu de la discipline "SVTEEHB" propre au premier cycle). Ne crée ni chapitre ni
-- leçon (portée explicitement exclue par l'utilisateur pour cette phase).
--
-- Portée volontairement limitée à ce que l'utilisateur a formulé comme instruction ferme ("Créer :")
-- et non comme hypothèse conditionnelle ("lorsque confirmés", "lorsque applicable" — section E du
-- message, matières générales de Première TI, non créées ici, à confirmer explicitement plus tard).
-- Terminale TI n'est délibérément pas touchée (le cahier ne cite que Première TI) — confirmé avec
-- l'utilisateur avant d'exécuter cette migration.

-- ── 1. Provenance/vérification par rattachement matière-classe (section H du cahier) ──────────
-- Vocabulaire distinct de subjects.verification_status (échelle 'ok'/'ambiguous'/'incomplete' déjà
-- utilisée ailleurs) : ce nouveau jeu de colonnes documente la SOURCE de chaque rattachement, pas
-- l'état de relecture de la matière elle-même.
ALTER TABLE subject_class_links
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'TO_VERIFY',
  ADD COLUMN IF NOT EXISTS official_source_url TEXT,
  ADD COLUMN IF NOT EXISTS official_document_title TEXT,
  ADD COLUMN IF NOT EXISTS official_document_date DATE,
  ADD COLUMN IF NOT EXISTS official_reference TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS coefficient NUMERIC,
  ADD COLUMN IF NOT EXISTS weekly_hours NUMERIC;

ALTER TABLE subject_class_links
  DROP CONSTRAINT IF EXISTS subject_class_links_verification_status_check;
ALTER TABLE subject_class_links
  ADD CONSTRAINT subject_class_links_verification_status_check
  CHECK (verification_status IN ('OFFICIAL_VERIFIED', 'SECONDARY_SOURCE_CONFIRMED', 'TO_VERIFY'));

-- Empêche la création de doublons de matière par code (aucun doublon existant à ce jour — vérifié
-- avant d'ajouter la contrainte) et permet un upsert idempotent dans le bloc ci-dessous.
ALTER TABLE subjects
  DROP CONSTRAINT IF EXISTS subjects_country_code_unique;
ALTER TABLE subjects
  ADD CONSTRAINT subjects_country_code_unique UNIQUE (country_id, code);

-- ── 2. Fonctions idempotentes ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_or_create_subject(
  p_country_id UUID, p_code TEXT, p_name TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM subjects WHERE country_id = p_country_id AND code = p_code;
  IF v_id IS NULL THEN
    INSERT INTO subjects (name, code, country_id, is_active, verification_status, manually_edited)
    VALUES (p_name, p_code, p_country_id, true, 'ok', false)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upsert_subject_class_link(
  p_subject_id UUID,
  p_class_node_id UUID,
  p_verification_status TEXT,
  p_official_reference TEXT,
  p_notes TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM subject_class_links
    WHERE subject_id = p_subject_id AND class_node_id = p_class_node_id;
  IF v_id IS NULL THEN
    INSERT INTO subject_class_links (
      subject_id, class_node_id, verification_status, official_reference, notes
    )
    VALUES (p_subject_id, p_class_node_id, p_verification_status, p_official_reference, p_notes)
    RETURNING id INTO v_id;
  ELSE
    UPDATE subject_class_links
      SET verification_status = p_verification_status,
          official_reference = p_official_reference,
          notes = p_notes
      WHERE id = v_id;
  END IF;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ── 3. Alignement du code d'une matière déjà existante sur le référentiel (section F) ──────────
-- "Physique - Chimie - Technologie" existait déjà (code interne différent) ; aligné sur "PCT" tel
-- que listé dans le référentiel donné par l'utilisateur. Aucune donnée liée ne référence ce code en
-- dur (vérifié dans le code Flutter/Edge Functions avant modification) — seul l'id est une clé
-- étrangère réelle, inchangé.
UPDATE subjects SET code = 'PCT' WHERE code = 'PHYSIQ_CHIMIE_TECHNO' AND manually_edited = false;

-- ── 4. Rattachements ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_country UUID := 'e3f8f8d5-827b-446b-8550-f4bcc7e0672a'; -- Cameroun
  v_6e UUID := '92509ff6-ef27-476b-8fee-66f37a9091d1';
  v_5e UUID := '9d920a0d-18b9-4411-97e0-02ddb812eff9';
  v_4e UUID := '39ebcba0-565c-4bbc-88f4-d5d39a1cb753';
  v_3e UUID := '6d2bcc3e-98db-4d9f-ae99-7be0a17726dc';
  v_premiere_ti UUID := 'cb5bd07c-62d9-43c6-b316-0f59e620e4be';

  -- Matières déjà existantes, réutilisées telles quelles (aucun nouveau doublon créé).
  v_francais UUID := '1f4dd126-4976-423a-be01-e20f6ec2d33e';
  v_francais_litterature UUID := 'f8b24f5a-ae20-40cb-a548-11bbfb90c134'; -- à délier de 3e (doublon)
  v_anglais UUID := 'dc57d4e4-0688-4eb5-a79a-5efc5ab48360';
  v_histoire UUID := '7ff93baf-a007-498c-9fe3-ed70e319104d';
  v_geographie UUID := '11d31c87-e891-49c5-8886-033c68386329';
  v_ecm UUID := '516edec5-3510-427b-96a9-ffb39afa60c8';
  v_maths UUID := 'd744dc5f-b428-4546-b970-e8ff3dbe3a68';
  v_eps UUID := '98c876f1-02a5-4f99-ae03-2627443b0eca';
  v_informatique UUID := 'ba7fdba9-482b-46f9-82db-d69d39cace2d';
  v_lv2 UUID := '3722abbd-25ae-4172-a4a6-125c971e4f36'; -- "Langue Vivante II" du cahier
  v_pct UUID := 'a391c87a-2c2e-4116-84cc-d546091fdafc';
  v_svt UUID := '9f5d6151-08f1-4a27-ba2b-1eb3d46837e2'; -- à délier de 3e (remplacée par SVTEEHB)

  -- Nouvelles matières (section F du cahier).
  v_sciences UUID;
  v_lettres_classiques UUID;
  v_edu_artistique UUID;
  v_cultures_nat UUID;
  v_langues_nat UUID;
  v_travail_manuel UUID;
  v_svteehb UUID;
  v_algo UUID;
  v_sysinfo UUID;
  v_maintenance UUID;
  v_reseaux UUID;

  v_ref_arrete TEXT := 'Arrêté n°239/23 du 14 juin 2023 (grille nationale du premier cycle général francophone)';
  v_note_ti TEXT := 'Disciplines spécialisées de la filière Technologies de l''Information listées explicitement par l''administrateur (liste minimale) — référence légale à confirmer.';

  v_class UUID;
  v_subject UUID;
  v_6e_5e_subjects UUID[];
  v_4e_3e_subjects UUID[];
  v_ti_subjects UUID[];
BEGIN
  v_sciences := get_or_create_subject(v_country, 'SCIENCES', 'Sciences');
  v_lettres_classiques := get_or_create_subject(v_country, 'LETTRES_CLASSIQUES', 'Lettres classiques (Latin/Grec)');
  v_edu_artistique := get_or_create_subject(v_country, 'EDUCATION_ARTISTIQUE_CULTURELLE', 'Éducation artistique et culturelle');
  v_cultures_nat := get_or_create_subject(v_country, 'CULTURES_NATIONALES', 'Cultures nationales');
  v_langues_nat := get_or_create_subject(v_country, 'LANGUES_NATIONALES', 'Langues nationales');
  v_travail_manuel := get_or_create_subject(v_country, 'TRAVAIL_MANUEL', 'Travail Manuel');
  v_svteehb := get_or_create_subject(
    v_country, 'SVTEEHB',
    'Sciences de la Vie et de la Terre, Éducation Environnementale, Hygiène et Bonnes mœurs (SVTEEHB)'
  );
  v_algo := get_or_create_subject(v_country, 'ALGORITHMIQUE_PROGRAMMATION', 'Algorithmique et Programmation');
  v_sysinfo := get_or_create_subject(v_country, 'SYSTEME_INFORMATION', 'Système d''information');
  v_maintenance := get_or_create_subject(v_country, 'MAINTENANCE_MULTIMEDIA', 'Maintenance et Multimédia');
  v_reseaux := get_or_create_subject(v_country, 'RESEAUX_INTERNET_SECURITE', 'Réseaux / Internet / Sécurité informatique');

  -- 6e et 5e : mêmes 14 disciplines, "Sciences" intégrée (pas de Physique/Chimie/Technologie/SVTEEHB
  -- séparées à ce niveau — règle explicite du cahier).
  v_6e_5e_subjects := ARRAY[
    v_francais, v_anglais, v_lettres_classiques, v_histoire, v_geographie, v_ecm,
    v_maths, v_informatique, v_sciences, v_edu_artistique, v_cultures_nat,
    v_langues_nat, v_eps, v_travail_manuel
  ];
  FOREACH v_class IN ARRAY ARRAY[v_6e, v_5e]
  LOOP
    FOREACH v_subject IN ARRAY v_6e_5e_subjects
    LOOP
      PERFORM upsert_subject_class_link(v_subject, v_class, 'OFFICIAL_VERIFIED', v_ref_arrete, NULL);
    END LOOP;
  END LOOP;

  -- 4e et 3e : Sciences éclate en Physique-Chimie-Technologie (PCT) + SVTEEHB, ajout de Langue
  -- Vivante II (absente en 6e/5e).
  v_4e_3e_subjects := ARRAY[
    v_francais, v_anglais, v_lv2, v_lettres_classiques, v_histoire, v_geographie, v_ecm,
    v_maths, v_informatique, v_pct, v_svteehb, v_edu_artistique, v_cultures_nat,
    v_langues_nat, v_eps, v_travail_manuel
  ];
  FOREACH v_class IN ARRAY ARRAY[v_4e, v_3e]
  LOOP
    FOREACH v_subject IN ARRAY v_4e_3e_subjects
    LOOP
      PERFORM upsert_subject_class_link(v_subject, v_class, 'OFFICIAL_VERIFIED', v_ref_arrete, NULL);
    END LOOP;
  END LOOP;

  -- Corrections en 3e : retire le doublon "Français & Littérature" (Français suffit) et le
  -- rattachement générique "SVT" désormais remplacé par la discipline SVTEEHB du premier cycle.
  -- Suppression du seul rattachement (subject_class_links), jamais de la matière elle-même —
  -- "Français & Littérature" reste utilisée ailleurs (contenu pédagogique déjà publié dessus).
  DELETE FROM subject_class_links WHERE subject_id = v_francais_litterature AND class_node_id = v_3e;
  DELETE FROM subject_class_links WHERE subject_id = v_svt AND class_node_id = v_3e;

  -- Première TI : disciplines spécialisées distinctes (jamais un "Informatique" générique).
  -- Statut SECONDARY_SOURCE_CONFIRMED : liste ferme de l'administrateur, sans numéro de texte
  -- officiel cité (contrairement à la grille 6e-3e ci-dessus) — à faire évoluer vers
  -- OFFICIAL_VERIFIED si une référence officielle est fournie plus tard.
  v_ti_subjects := ARRAY[v_algo, v_sysinfo, v_maintenance, v_reseaux];
  FOREACH v_subject IN ARRAY v_ti_subjects
  LOOP
    PERFORM upsert_subject_class_link(v_subject, v_premiere_ti, 'SECONDARY_SOURCE_CONFIRMED', NULL, v_note_ti);
  END LOOP;

  -- Défensif : confirme qu'"Informatique" générique n'est pas (et ne reste pas) rattaché à
  -- Première TI — vérifié absent avant migration, cette suppression est un no-op idempotent.
  DELETE FROM subject_class_links WHERE subject_id = v_informatique AND class_node_id = v_premiere_ti;
END $$;
