-- Plan académique global du Cameroun (demande porteur, 2026-09-18). Phase strictement limitée à
-- l'arbre Pays → Sous-système → Type d'enseignement → Cycle → Classe/Niveau → Famille → Spécialité.
-- AUCUNE matière, AUCUN chapitre, AUCUNE leçon, AUCUN contenu IA ici — seulement la structure.
--
-- État constaté avant cette migration (audité en direct) : Cameroun / Section Francophone /
-- Enseignement Général existaient déjà avec 4 classes (2nde/1ère/Tle/3ème) et leurs séries A/C/D,
-- MAIS directement enfants de l'Enseignement Général (aucun regroupement Premier/Second Cycle) ;
-- Enseignement Technique et Section Anglophone existaient mais étaient VIDES. Cette migration :
-- (1) ajoute les node_type manquants (cycle/family/specialty — le schéma n'en connaissait que 5) ;
-- (2) réattache les classes déjà existantes sous de vrais nœuds Cycle (aucune perte : les chapitres
--     déjà rattachés à ces classes le restent, ils référencent class_node_id directement) ;
-- (3) complète tout ce qui manquait. Idempotent (rejouable sans dupliquer) via une fonction utilitaire.

-- 1) Nœuds admis : ajout de 'cycle', 'family', 'specialty' (Country/Subsystem/EducationType déjà
-- couverts par country/section/education_type ; Level = 'class', Track = 'series' pour la filière
-- académique du Général, réservé à ce sens précis).
ALTER TABLE academic_nodes DROP CONSTRAINT IF EXISTS academic_nodes_node_type_check;
ALTER TABLE academic_nodes ADD CONSTRAINT academic_nodes_node_type_check
    CHECK (node_type = ANY (ARRAY['country','section','education_type','cycle','class','family','specialty','series']));

-- 2) Utilitaire de dédoublonnage (get-or-create), pour que toute la suite du script — et une
-- future ré-exécution accidentelle — ne crée jamais de doublon. `country_id` hérité du parent
-- (le nœud pays porte lui-même son propre id dans `country_id`, déjà le cas pour Cameroun).
CREATE OR REPLACE FUNCTION get_or_create_academic_node(
    p_parent_id UUID,
    p_node_type TEXT,
    p_name TEXT,
    p_code TEXT DEFAULT NULL,
    p_display_order INT DEFAULT 0
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_country_id UUID;
BEGIN
    SELECT id INTO v_id FROM academic_nodes
    WHERE node_type = p_node_type AND name = p_name
      AND parent_id IS NOT DISTINCT FROM p_parent_id;
    IF v_id IS NOT NULL THEN
        RETURN v_id;
    END IF;

    SELECT country_id INTO v_country_id FROM academic_nodes WHERE id = p_parent_id;

    INSERT INTO academic_nodes (parent_id, node_type, name, code, country_id, display_order)
    VALUES (p_parent_id, p_node_type, p_name, p_code, v_country_id, p_display_order)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- 3) Renommage de cohérence (nœuds existants, jamais modifiés manuellement — vérifié
-- `manually_edited = false` avant d'y toucher).
UPDATE academic_nodes SET name = 'Section Anglophone'
    WHERE id = '0c00c1d1-04c6-4a6e-956b-3977c989a692' AND manually_edited = false;
UPDATE academic_nodes SET name = 'Enseignement Technique et Professionnel'
    WHERE id = '22eb8ffa-c314-4af2-b224-2402ae25c8c3' AND manually_edited = false;

DO $$
DECLARE
    v_cameroun_id UUID;
    v_fr_id UUID;
    v_en_id UUID;
    v_fr_gen_id UUID;
    v_fr_tech_id UUID;

    v_premier_cycle_id UUID;
    v_second_cycle_id UUID;
    v_c6e_id UUID;
    v_c5e_id UUID;
    v_c4e_id UUID;
    v_c3e_id UUID;
    v_2nde_id UUID;
    v_1ere_id UUID;
    v_tle_id UUID;

    v_tech_premier_cycle_id UUID;
    v_tech_second_cycle_id UUID;
    v_year_id UUID;
    v_stt_id UUID;
    v_ind_id UUID;
    v_genie_meca_id UUID;
    v_genie_elec_id UUID;
    v_genie_civil_id UUID;
    v_genie_arts_id UUID;
    v_seconde_tech_id UUID;
    v_premiere_tech_id UUID;
    v_terminale_tech_id UUID;

    v_en_gen_id UUID;
    v_en_first_cycle_id UUID;
    v_en_second_cycle_id UUID;
    v_lower_sixth_id UUID;
    v_upper_sixth_id UUID;
    v_en_tech_id UUID;
    v_commercial_id UUID;
    v_industrial_id UUID;
    v_ind_first_cycle_id UUID;
    v_ind_second_cycle_id UUID;

    v_stt_specialties_premier TEXT[] := ARRAY['ESCOM','ESF','ESFI','RE','SEBU','SEME','SH','VENTE'];
    v_ind_specialties_premier TEXT[] := ARRAY['CAPA','COOM','MAEL','MAIN','MARE','MEFA','MEFE','AICB','AICI','ELEQ','ELME','ELNI','FRCL','CARR','DEBA','MACO','MENU','COME','DECOR','ESCO'];
    v_stt_specialties_second TEXT[] := ARRAY['AAT','ACA','ACC','AV','BPA','CG','CU','ESF','FIG','HE','HO','SES','TO'];
    v_meca_specialties TEXT[] := ARRAY['BIJO','CM','CMA-MVPL','CMA-MVT','E','F1','MA','MEM','MF/CM'];
    v_elec_specialties TEXT[] := ARRAY['CI','F2','F3','F5','F6-BIPE','F6-COPH','F6-MIPE','F7','F8','MAV','MEHB','MISE'];
    v_civil_specialties TEXT[] := ARRAY['F4BA','F4BE','F4TP','GTTO','IB','IS','MEB','PA','PV','TGF'];
    v_arts_specialties TEXT[] := ARRAY['BP CF','IH','PEINT','SCULP'];

    v_year_names TEXT[] := ARRAY['1re année','2e année','3e année','4e année'];
    v_year_codes TEXT[] := ARRAY['1AN_T','2AN_T','3AN_T','4AN_T'];

    v_code TEXT;
    i INT;
BEGIN
    SELECT id INTO v_cameroun_id FROM academic_nodes WHERE node_type='country' AND code='CM';
    SELECT id INTO v_fr_id FROM academic_nodes WHERE id='731a2ebb-b24b-4860-a997-ec557f1e039b';
    SELECT id INTO v_en_id FROM academic_nodes WHERE id='0c00c1d1-04c6-4a6e-956b-3977c989a692';
    SELECT id INTO v_fr_gen_id FROM academic_nodes WHERE id='f1e20d8e-3f45-4c9b-bd37-a630079382c1';
    SELECT id INTO v_fr_tech_id FROM academic_nodes WHERE id='22eb8ffa-c314-4af2-b224-2402ae25c8c3';

    -- ===================== §3-4 FRANCOPHONE / GÉNÉRAL =====================
    v_premier_cycle_id := get_or_create_academic_node(v_fr_gen_id, 'cycle', 'Premier Cycle', 'PC_GEN_FR', 1);
    v_second_cycle_id := get_or_create_academic_node(v_fr_gen_id, 'cycle', 'Second Cycle', 'SC_GEN_FR', 2);

    v_c6e_id := get_or_create_academic_node(v_premier_cycle_id, 'class', '6e', '6E', 1);
    v_c5e_id := get_or_create_academic_node(v_premier_cycle_id, 'class', '5e', '5E', 2);
    v_c4e_id := get_or_create_academic_node(v_premier_cycle_id, 'class', '4e', '4E', 3);

    -- Réattache les classes déjà existantes (2nde/1ère/Tle/3e) sous leur vrai Cycle — jamais
    -- recréées, seul leur parent_id change ; aucun contenu (chapitres/matières) déjà rattaché
    -- n'est affecté (référence class_node_id directement, pas la chaîne de parents).
    UPDATE academic_nodes SET parent_id = v_premier_cycle_id, display_order = 4
        WHERE id = '6d2bcc3e-98db-4d9f-ae99-7be0a17726dc'; -- Classe de 3ème
    UPDATE academic_nodes SET parent_id = v_second_cycle_id, display_order = 1
        WHERE id = '6b306f19-56b9-4747-9c60-2854ea8e77e5'; -- Classe de 2nde
    UPDATE academic_nodes SET parent_id = v_second_cycle_id, display_order = 2
        WHERE id = 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d'; -- Classe de 1ère
    UPDATE academic_nodes SET parent_id = v_second_cycle_id, display_order = 3
        WHERE id = '35b450cf-6fd7-49e5-985c-93cb816cfb8d'; -- Classe de Terminale

    v_2nde_id := '6b306f19-56b9-4747-9c60-2854ea8e77e5';
    v_1ere_id := 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d';
    v_tle_id := '35b450cf-6fd7-49e5-985c-93cb816cfb8d';

    -- Série TI manquante en Première/Terminale (jamais en Seconde — conforme au périmètre demandé).
    PERFORM get_or_create_academic_node(v_1ere_id, 'series', 'Série TI', 'TI', 4);
    PERFORM get_or_create_academic_node(v_tle_id, 'series', 'Série TI', 'TI', 4);

    -- ============ §5-9 FRANCOPHONE / TECHNIQUE — PREMIER CYCLE (4 ans) ============
    v_tech_premier_cycle_id := get_or_create_academic_node(v_fr_tech_id, 'cycle', 'Premier Cycle', 'PC_TECH_FR', 1);

    FOR i IN 1..4 LOOP
        v_year_id := get_or_create_academic_node(v_tech_premier_cycle_id, 'class', v_year_names[i], v_year_codes[i], i);

        v_stt_id := get_or_create_academic_node(v_year_id, 'family', 'STT', 'STT', 1);
        FOREACH v_code IN ARRAY v_stt_specialties_premier LOOP
            PERFORM get_or_create_academic_node(v_stt_id, 'specialty', v_code, v_code);
        END LOOP;

        v_ind_id := get_or_create_academic_node(v_year_id, 'family', 'IND', 'IND', 2);
        FOREACH v_code IN ARRAY v_ind_specialties_premier LOOP
            PERFORM get_or_create_academic_node(v_ind_id, 'specialty', v_code, v_code);
        END LOOP;
    END LOOP;

    -- ============ §10-12 FRANCOPHONE / TECHNIQUE — SECOND CYCLE (3 ans) ============
    v_tech_second_cycle_id := get_or_create_academic_node(v_fr_tech_id, 'cycle', 'Second Cycle', 'SC_TECH_FR', 2);

    -- Seconde technique : mutualisée, pas encore de spécialité (§11 : "Créer principalement :
    -- Seconde STT" ; §12 : "la Seconde industrielle peut être commune... avant spécialisation").
    v_seconde_tech_id := get_or_create_academic_node(v_tech_second_cycle_id, 'class', 'Seconde technique', '2NDE_T', 1);
    PERFORM get_or_create_academic_node(v_seconde_tech_id, 'family', 'STT', 'STT', 1);
    v_ind_id := get_or_create_academic_node(v_seconde_tech_id, 'family', 'IND', 'IND', 2);
    v_genie_meca_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie mécanique', 'GMECA', 1);
    v_genie_elec_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie électrique / chimie industrielle / biomédical', 'GELEC', 2);
    v_genie_civil_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie civil / bois / techniques agricoles', 'GCIVIL', 3);
    v_genie_arts_id := get_or_create_academic_node(v_ind_id, 'family', 'Arts et modes', 'GARTS', 4);

    -- Première technique et Terminale technique : structure identique, spécialités réelles à
    -- chaque niveau (§12 : "Première spécialité → Terminale spécialité").
    v_premiere_tech_id := get_or_create_academic_node(v_tech_second_cycle_id, 'class', 'Première technique', '1ERE_T', 2);
    v_terminale_tech_id := get_or_create_academic_node(v_tech_second_cycle_id, 'class', 'Terminale technique', 'TLE_T', 3);

    FOREACH v_year_id IN ARRAY ARRAY[v_premiere_tech_id, v_terminale_tech_id] LOOP
        v_stt_id := get_or_create_academic_node(v_year_id, 'family', 'STT', 'STT', 1);
        FOREACH v_code IN ARRAY v_stt_specialties_second LOOP
            PERFORM get_or_create_academic_node(v_stt_id, 'specialty', v_code, v_code);
        END LOOP;

        v_ind_id := get_or_create_academic_node(v_year_id, 'family', 'IND', 'IND', 2);

        v_genie_meca_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie mécanique', 'GMECA', 1);
        FOREACH v_code IN ARRAY v_meca_specialties LOOP
            PERFORM get_or_create_academic_node(v_genie_meca_id, 'specialty', v_code, v_code);
        END LOOP;

        v_genie_elec_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie électrique / chimie industrielle / biomédical', 'GELEC', 2);
        FOREACH v_code IN ARRAY v_elec_specialties LOOP
            PERFORM get_or_create_academic_node(v_genie_elec_id, 'specialty', v_code, v_code);
        END LOOP;

        v_genie_civil_id := get_or_create_academic_node(v_ind_id, 'family', 'Génie civil / bois / techniques agricoles', 'GCIVIL', 3);
        FOREACH v_code IN ARRAY v_civil_specialties LOOP
            PERFORM get_or_create_academic_node(v_genie_civil_id, 'specialty', v_code, v_code);
        END LOOP;

        v_genie_arts_id := get_or_create_academic_node(v_ind_id, 'family', 'Arts et modes', 'GARTS', 4);
        FOREACH v_code IN ARRAY v_arts_specialties LOOP
            PERFORM get_or_create_academic_node(v_genie_arts_id, 'specialty', v_code, v_code);
        END LOOP;
    END LOOP;

    -- ===================== §14-15 ANGLOPHONE / GENERAL EDUCATION =====================
    v_en_gen_id := get_or_create_academic_node(v_en_id, 'education_type', 'General Education', 'GEN_EN', 1);

    v_en_first_cycle_id := get_or_create_academic_node(v_en_gen_id, 'cycle', 'First Cycle', 'FC_GEN_EN', 1);
    PERFORM get_or_create_academic_node(v_en_first_cycle_id, 'class', 'Form 1', 'F1', 1);
    PERFORM get_or_create_academic_node(v_en_first_cycle_id, 'class', 'Form 2', 'F2', 2);
    PERFORM get_or_create_academic_node(v_en_first_cycle_id, 'class', 'Form 3', 'F3', 3);
    PERFORM get_or_create_academic_node(v_en_first_cycle_id, 'class', 'Form 4', 'F4', 4);
    PERFORM get_or_create_academic_node(v_en_first_cycle_id, 'class', 'Form 5', 'F5', 5);

    -- Lower/Upper Sixth : même motif Classe→Série qu'en Francophone (2nde→A/C) pour rester
    -- cohérent avec le modèle déjà existant — l'affichage "Lower Sixth Arts" en un seul intitulé
    -- (§15/§20) est un résultat de navigation (niveaux inutiles sautés automatiquement), pas une
    -- contrainte sur la forme des données.
    v_en_second_cycle_id := get_or_create_academic_node(v_en_gen_id, 'cycle', 'Second Cycle', 'SC_GEN_EN', 2);
    v_lower_sixth_id := get_or_create_academic_node(v_en_second_cycle_id, 'class', 'Lower Sixth', 'L6', 1);
    PERFORM get_or_create_academic_node(v_lower_sixth_id, 'series', 'Arts', 'ARTS', 1);
    PERFORM get_or_create_academic_node(v_lower_sixth_id, 'series', 'Sciences', 'SCI', 2);
    v_upper_sixth_id := get_or_create_academic_node(v_en_second_cycle_id, 'class', 'Upper Sixth', 'U6', 2);
    PERFORM get_or_create_academic_node(v_upper_sixth_id, 'series', 'Arts', 'ARTS', 1);
    PERFORM get_or_create_academic_node(v_upper_sixth_id, 'series', 'Sciences', 'SCI', 2);

    -- ============ §16 ANGLOPHONE / TECHNICAL AND PROFESSIONAL EDUCATION ============
    v_en_tech_id := get_or_create_academic_node(v_en_id, 'education_type', 'Technical and Professional Education', 'TECH_EN', 2);

    -- Commercial : demandé explicitement (§16 "Créer deux grandes familles") mais aucun détail de
    -- cycle/année fourni pour cette branche (contrairement à Industrial) — créé seul, sans enfant
    -- inventé, conformément à la règle "ne rien inventer" (§21).
    v_commercial_id := get_or_create_academic_node(v_en_tech_id, 'family', 'Commercial', 'COM', 1);

    v_industrial_id := get_or_create_academic_node(v_en_tech_id, 'family', 'Industrial', 'INDUS', 2);
    v_ind_first_cycle_id := get_or_create_academic_node(v_industrial_id, 'cycle', 'First Cycle', 'FC_IND_EN', 1);
    PERFORM get_or_create_academic_node(v_ind_first_cycle_id, 'class', 'Year I', 'Y1', 1);
    PERFORM get_or_create_academic_node(v_ind_first_cycle_id, 'class', 'Year II', 'Y2', 2);
    PERFORM get_or_create_academic_node(v_ind_first_cycle_id, 'class', 'Year III', 'Y3', 3);
    PERFORM get_or_create_academic_node(v_ind_first_cycle_id, 'class', 'Year IV', 'Y4', 4);

    v_ind_second_cycle_id := get_or_create_academic_node(v_industrial_id, 'cycle', 'Second Cycle', 'SC_IND_EN', 2);
    PERFORM get_or_create_academic_node(v_ind_second_cycle_id, 'class', 'Year V', 'Y5', 1);
    PERFORM get_or_create_academic_node(v_ind_second_cycle_id, 'class', 'Year VI', 'Y6', 2);
    PERFORM get_or_create_academic_node(v_ind_second_cycle_id, 'class', 'Year VII', 'Y7', 3);
END $$;

NOTIFY pgrst, 'reload schema';
