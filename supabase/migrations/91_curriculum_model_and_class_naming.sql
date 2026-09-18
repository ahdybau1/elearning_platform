-- Référentiel national des matières (§1, §41-42 du cahier "PQ LEARN — RÉFÉRENTIEL NATIONAL DES
-- MATIÈRES DU CAMEROUN") : ce document remplace les instructions précédentes sur les matières.
-- Cette migration pose le MODÈLE (curricula, sources, mapping enrichi) et corrige les noms de
-- classe affichés (§1). Migration 92 reconstruit les rattachements matière-classe eux-mêmes.
-- Ne crée ni chapitre, ni leçon, ni exercice, ni contenu IA (portée explicitement exclue).

-- ── 1. CURRICULA : une matière (SUBJECT) peut avoir plusieurs programmes (§2, §39) ────────────
-- Une seule ligne "Mathématiques", plusieurs curricula ("Mathématiques — Sixième",
-- "Mathématiques — Première C"...). Deux rattachements ne partagent le MÊME curriculum_id que
-- lorsque le programme est réellement confirmé identique (§19-20) — jamais par défaut simplement
-- parce que le nom de la matière est identique.
CREATE TABLE IF NOT EXISTS curricula (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  country_id UUID REFERENCES academic_nodes(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_curricula_subject ON curricula(subject_id);

-- ── 2. SOURCES (§42) ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS curriculum_sources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_url TEXT,
  title TEXT NOT NULL,
  issuing_authority TEXT,
  publication_date DATE,
  school_year TEXT,
  source_type TEXT,
  retrieved_at TIMESTAMPTZ,
  document_hash TEXT,
  verification_status TEXT NOT NULL DEFAULT 'TO_VERIFY'
    CHECK (verification_status IN ('OFFICIAL_VERIFIED', 'OFFICIAL_DERIVED', 'SECONDARY_CONFIRMED', 'TO_VERIFY')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── 3. Rattachement matière-classe enrichi (§41) ───────────────────────────────────────────────
-- verification_status/official_reference/notes/coefficient/weekly_hours existent déjà (migration
-- 90) sous un vocabulaire proche ; on y ajoute le lien vers le modèle curriculum/source et les
-- indicateurs obligatoire/optionnel/groupe de choix (ex: langues vivantes au choix).
ALTER TABLE subject_class_links
  ADD COLUMN IF NOT EXISTS curriculum_id UUID REFERENCES curricula(id),
  ADD COLUMN IF NOT EXISTS is_mandatory BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_optional BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS choice_group TEXT,
  ADD COLUMN IF NOT EXISTS source_id UUID REFERENCES curriculum_sources(id);

-- ── 4. Fonctions idempotentes ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_or_create_curriculum(
  p_subject_id UUID, p_country_id UUID, p_name TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM curricula WHERE subject_id = p_subject_id AND name = p_name;
  IF v_id IS NULL THEN
    INSERT INTO curricula (subject_id, country_id, name) VALUES (p_subject_id, p_country_id, p_name)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_or_create_curriculum_source(
  p_title TEXT, p_issuing_authority TEXT, p_verification_status TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM curriculum_sources WHERE title = p_title;
  IF v_id IS NULL THEN
    INSERT INTO curriculum_sources (title, issuing_authority, verification_status)
    VALUES (p_title, p_issuing_authority, p_verification_status)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Remplace la fonction de migration 90 : rattache désormais aussi un curriculum et les indicateurs
-- obligatoire/optionnel/groupe de choix/source, en conservant le comportement idempotent existant.
CREATE OR REPLACE FUNCTION upsert_subject_class_link(
  p_subject_id UUID,
  p_class_node_id UUID,
  p_verification_status TEXT,
  p_official_reference TEXT,
  p_notes TEXT,
  p_curriculum_id UUID DEFAULT NULL,
  p_is_mandatory BOOLEAN DEFAULT true,
  p_is_optional BOOLEAN DEFAULT false,
  p_choice_group TEXT DEFAULT NULL,
  p_source_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM subject_class_links
    WHERE subject_id = p_subject_id AND class_node_id = p_class_node_id;
  IF v_id IS NULL THEN
    INSERT INTO subject_class_links (
      subject_id, class_node_id, verification_status, official_reference, notes,
      curriculum_id, is_mandatory, is_optional, choice_group, source_id
    )
    VALUES (
      p_subject_id, p_class_node_id, p_verification_status, p_official_reference, p_notes,
      p_curriculum_id, p_is_mandatory, p_is_optional, p_choice_group, p_source_id
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE subject_class_links
      SET verification_status = p_verification_status,
          official_reference = p_official_reference,
          notes = p_notes,
          curriculum_id = COALESCE(p_curriculum_id, subject_class_links.curriculum_id),
          is_mandatory = p_is_mandatory,
          is_optional = p_is_optional,
          choice_group = p_choice_group,
          source_id = COALESCE(p_source_id, subject_class_links.source_id)
      WHERE id = v_id;
  END IF;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ── 5. Noms de classe corrects "dans toute l'interface" (§1) ───────────────────────────────────
-- Les anciennes formes abrégées (6e, 1ère, Tle...) restent disponibles via `code` comme alias de
-- recherche/interne — jamais comme libellé principal affiché. Aucun de ces nœuds n'est
-- manually_edited (vérifié avant migration).
UPDATE academic_nodes SET name = 'Sixième'   WHERE id = '92509ff6-ef27-476b-8fee-66f37a9091d1' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Cinquième' WHERE id = '9d920a0d-18b9-4411-97e0-02ddb812eff9' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Quatrième' WHERE id = '39ebcba0-565c-4bbc-88f4-d5d39a1cb753' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Troisième' WHERE id = '6d2bcc3e-98db-4d9f-ae99-7be0a17726dc' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Seconde'   WHERE id = '6b306f19-56b9-4747-9c60-2854ea8e77e5' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Première'  WHERE id = 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Terminale', code = 'TLE' WHERE id = '35b450cf-6fd7-49e5-985c-93cb816cfb8d' AND manually_edited = false;

-- Enseignement Technique et Professionnel — premier cycle (§1 : "Première année"... pas "1re année").
UPDATE academic_nodes SET name = 'Première année'  WHERE id = '67d549a8-9397-428f-952d-25f7593bf2c8' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Deuxième année'  WHERE id = 'fc5d5426-29f2-43a4-9cfe-428614dfbc6e' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Troisième année' WHERE id = '907a4c22-61d8-4cdc-aa1d-25adb5c8d112' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Quatrième année' WHERE id = 'd9fd7699-b344-49f4-bcf8-f9efd08f350d' AND manually_edited = false;

-- Enseignement Technique — second cycle (§1 : "Seconde / Première / Terminale", spécialité ajoutée
-- séparément par le nœud family/specialty, jamais fusionnée dans le nom de la classe elle-même).
UPDATE academic_nodes SET name = 'Seconde'   WHERE id = '6a77efea-2015-4e73-8def-542c2f401cbb' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Première'  WHERE id = 'b64cf3e2-889c-4ee6-89fd-00ab642f571f' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Terminale' WHERE id = 'b9fd3c1b-c6d6-4745-a886-0df11ae18380' AND manually_edited = false;
