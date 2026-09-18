-- Reprend le seed des matières du Général Francophone (Seconde→Terminale, tous les séries) et
-- corrige intégralement Première TI / Terminale TI, sur la base du "RÉFÉRENTIEL NATIONAL DES
-- MATIÈRES DU CAMEROUN" qui remplace toutes les instructions précédentes sur les matières. 6e/5e/4e/
-- 3e (déjà justes en contenu depuis la migration 90) sont seulement reliés au nouveau modèle
-- curriculum ; leur liste de matières ne change pas, sauf le remplacement de la "Langue vivante 2"
-- générique par les langues concrètes (§7).
--
-- Portée : uniquement Enseignement Général Francophone + Première/Terminale TI, tel qu'explicité en
-- détail dans le cahier. Le Technique STT/IND (au-delà de la structure déjà en place), l'Anglophone
-- et l'Enseignement Normal (ENIEG/ENIET) ne sont PAS peuplés ici — le cahier ne donne pas de liste
-- ferme et répète "ne pas inventer" pour leurs matières professionnelles ; laissés explicitement en
-- attente (voir rapport). Aucun chapitre/leçon/exercice créé.

CREATE OR REPLACE FUNCTION get_or_create_curriculum_for_class(
  p_subject_id UUID, p_class_node_id UUID, p_country_id UUID
) RETURNS UUID AS $$
DECLARE
  v_class_name TEXT;
  v_subject_name TEXT;
BEGIN
  SELECT name INTO v_class_name FROM academic_nodes WHERE id = p_class_node_id;
  SELECT name INTO v_subject_name FROM subjects WHERE id = p_subject_id;
  RETURN get_or_create_curriculum(p_subject_id, p_country_id, v_subject_name || ' — ' || v_class_name);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION link_mandatory_subject(
  p_subject_id UUID, p_class_node_id UUID, p_country_id UUID,
  p_verification_status TEXT, p_source_id UUID
) RETURNS VOID AS $$
DECLARE v_curr UUID;
BEGIN
  v_curr := get_or_create_curriculum_for_class(p_subject_id, p_class_node_id, p_country_id);
  PERFORM upsert_subject_class_link(
    p_subject_id, p_class_node_id, p_verification_status, NULL, NULL, v_curr, true, false, NULL, p_source_id
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION link_optional_subject(
  p_subject_id UUID, p_class_node_id UUID, p_country_id UUID,
  p_verification_status TEXT, p_source_id UUID, p_choice_group TEXT
) RETURNS VOID AS $$
DECLARE v_curr UUID;
BEGIN
  v_curr := get_or_create_curriculum_for_class(p_subject_id, p_class_node_id, p_country_id);
  PERFORM upsert_subject_class_link(
    p_subject_id, p_class_node_id, p_verification_status, NULL, NULL, v_curr, false, true, p_choice_group, p_source_id
  );
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  v_country UUID := 'e3f8f8d5-827b-446b-8550-f4bcc7e0672a';

  -- Classes.
  v_6e UUID := '92509ff6-ef27-476b-8fee-66f37a9091d1';
  v_5e UUID := '9d920a0d-18b9-4411-97e0-02ddb812eff9';
  v_4e UUID := '39ebcba0-565c-4bbc-88f4-d5d39a1cb753';
  v_3e UUID := '6d2bcc3e-98db-4d9f-ae99-7be0a17726dc';
  v_2ndeA UUID := '53c73c4e-371f-4178-9227-f73e62587485';
  v_2ndeC UUID := '951e2ca3-1214-462c-a021-2cdb888f3909';
  v_1ereA UUID := '247129a4-4490-41c2-9047-fa22d822d704';
  v_1ereC UUID := '56684178-6bd2-4e02-b2fb-5f9c0376a8eb';
  v_1ereD UUID := 'e19ac911-28dd-40d6-a1af-f4223601e83c';
  v_1ereTI UUID := 'cb5bd07c-62d9-43c6-b316-0f59e620e4be';
  v_TleA UUID := 'afce42f3-7d21-44cc-bac6-c3b6fe12f88b';
  v_TleC UUID := '174da8b4-dee0-4aef-a522-460a072283b1';
  v_TleD UUID := '60e32d50-1739-4f5c-a828-4625f859a3a0';
  v_TleTI UUID := '85350cdd-b23e-4986-93a3-62ebbb0141a5';

  -- Matières déjà existantes réutilisées.
  v_francais UUID := '1f4dd126-4976-423a-be01-e20f6ec2d33e';
  v_anglais UUID := 'dc57d4e4-0688-4eb5-a79a-5efc5ab48360';
  v_histoire UUID := '7ff93baf-a007-498c-9fe3-ed70e319104d';
  v_geographie UUID := '11d31c87-e891-49c5-8886-033c68386329';
  v_ecm UUID := '516edec5-3510-427b-96a9-ffb39afa60c8';
  v_maths UUID := 'd744dc5f-b428-4546-b970-e8ff3dbe3a68';
  v_eps UUID := '98c876f1-02a5-4f99-ae03-2627443b0eca';
  v_informatique UUID := 'ba7fdba9-482b-46f9-82db-d69d39cace2d';
  v_pct UUID := 'a391c87a-2c2e-4116-84cc-d546091fdafc';
  v_svt_generic UUID := '9f5d6151-08f1-4a27-ba2b-1eb3d46837e2'; -- ancien lien générique à retirer
  v_svteehb UUID := 'a5e64b4b-c084-4413-98d6-8920a4a66926';
  v_edu_artistique UUID := (SELECT id FROM subjects WHERE code = 'EDUCATION_ARTISTIQUE_CULTURELLE');
  v_cultures_nat UUID := (SELECT id FROM subjects WHERE code = 'CULTURES_NATIONALES');
  v_langues_nat UUID := (SELECT id FROM subjects WHERE code = 'LANGUES_NATIONALES');
  v_travail_manuel UUID := (SELECT id FROM subjects WHERE code = 'TRAVAIL_MANUEL');
  v_lettres_classiques UUID := 'dc86691c-66bc-4003-9708-9f7062272b08';
  v_sciences UUID := '281559fd-c022-4547-b3e9-a438c0ed783e';
  v_litterature UUID := '42dd6651-083d-4f33-abe7-29d297dfed71';
  v_philosophie UUID := '08ab04d9-3140-4735-a75b-b7dda757ad23';
  v_physique UUID := '360c3696-da8a-4d06-9ea8-58b75a3b1b36';
  v_chimie UUID := '8e627a40-8ff5-4c2a-b9af-7e91672c18c7';
  v_lv2_generic UUID := '3722abbd-25ae-4172-a4a6-125c971e4f36'; -- ancien lien générique à retirer
  v_algo UUID := 'd6d8b95e-d037-4d6a-b941-0b984f8eaa4b';
  v_sysinfo_premiere UUID := 'c2c88b36-8705-4ef0-a4de-4e449bada19f'; -- "Système d'information" (Première TI)
  v_maintenance UUID := '3f48e0c9-039f-4500-af33-89b6c73ad687'; -- renommée ci-dessous
  v_reseaux UUID := '59f61ea6-444b-4902-972e-f60798ded767'; -- renommée ci-dessous, réutilisée en Terminale TI

  -- Nouvelles matières.
  v_allemand UUID;
  v_espagnol UUID;
  v_italien UUID;
  v_arabe UUID;
  v_chinois UUID;
  v_latin UUID;
  v_grec UUID;
  v_sysinfo_bd UUID; -- "Systèmes d'information et Bases de données" (Terminale TI)
  v_projet UUID; -- "Projet / Gestion de projet" (Terminale TI)

  -- Sources.
  v_src_arrete UUID;
  v_src_lycee_ti UUID;

  v_class UUID;
  v_subject UUID;
  v_general_a UUID[];
  v_general_cd UUID[];
  v_ti_general UUID[];
BEGIN
  -- ── Sources ───────────────────────────────────────────────────────────────────────────────────
  v_src_arrete := get_or_create_curriculum_source(
    'Arrêté n°239/23 du 14 juin 2023 (grille nationale du premier cycle général francophone)',
    'MINESEC', 'OFFICIAL_VERIFIED'
  );
  v_src_lycee_ti := get_or_create_curriculum_source(
    'Référentiel matières second cycle général et Technologies de l''Information — spécification administrateur pq learn (2026-09-18)',
    NULL, 'SECONDARY_CONFIRMED'
  );

  -- ── Nouvelles matières : langues vivantes au choix (§7) ─────────────────────────────────────
  v_allemand := get_or_create_subject(v_country, 'ALLEMAND', 'Allemand');
  v_espagnol := get_or_create_subject(v_country, 'ESPAGNOL', 'Espagnol');
  v_italien := get_or_create_subject(v_country, 'ITALIEN', 'Italien');
  v_arabe := get_or_create_subject(v_country, 'ARABE', 'Arabe');
  v_chinois := get_or_create_subject(v_country, 'CHINOIS', 'Chinois');
  v_latin := get_or_create_subject(v_country, 'LATIN', 'Latin');
  v_grec := get_or_create_subject(v_country, 'GREC', 'Grec');

  -- ── Nouvelles matières TI de Terminale (§18) ────────────────────────────────────────────────
  v_sysinfo_bd := get_or_create_subject(v_country, 'SYSTEME_INFORMATION_BASES_DONNEES', 'Systèmes d''information et Bases de données');
  v_projet := get_or_create_subject(v_country, 'PROJET_GESTION_PROJET', 'Projet / Gestion de projet');

  -- Alignement des noms sur le libellé exact du cahier (matières déjà existantes, non manually_edited).
  UPDATE subjects SET name = 'Maintenance, Réseaux et Multimédia' WHERE id = v_maintenance AND manually_edited = false;
  UPDATE subjects SET name = 'Réseaux, Internet et Sécurité informatique' WHERE id = v_reseaux AND manually_edited = false;

  -- ══ 6e / 5e / 4e / 3e : relie au modèle curriculum, remplace la LV2 générique (§7) ═══════════
  -- Contenu déjà correct depuis la migration 90 (vérifié identique au cahier actuel).
  -- IMPORTANT : ce rattachement générique doit s'exécuter AVANT l'insertion des langues
  -- optionnelles ci-dessous — sinon il les écrase en (is_mandatory=true, is_optional=false),
  -- puisqu'il relie sans distinction tout ce qui se trouve déjà dans subject_class_links pour ces
  -- classes (bug constaté et corrigé lors de la première exécution de cette migration).
  FOREACH v_class IN ARRAY ARRAY[v_6e, v_5e, v_4e, v_3e]
  LOOP
    FOR v_subject IN SELECT subject_id FROM subject_class_links WHERE class_node_id = v_class
    LOOP
      PERFORM upsert_subject_class_link(
        v_subject, v_class, 'OFFICIAL_VERIFIED', NULL, NULL,
        get_or_create_curriculum_for_class(v_subject, v_class, v_country), true, false, NULL, v_src_arrete
      );
    END LOOP;
  END LOOP;

  -- LV2 générique remplacée par les 5 langues concrètes, optionnelles (§7) — exécuté après le
  -- rattachement générique ci-dessus pour ne pas être écrasé par lui.
  DELETE FROM subject_class_links WHERE subject_id = v_lv2_generic AND class_node_id IN (v_4e, v_3e);
  FOREACH v_class IN ARRAY ARRAY[v_4e, v_3e]
  LOOP
    FOREACH v_subject IN ARRAY ARRAY[v_allemand, v_espagnol, v_italien, v_arabe, v_chinois]
    LOOP
      PERFORM link_optional_subject(v_subject, v_class, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_arrete, 'LANGUE_VIVANTE_II');
    END LOOP;
  END LOOP;

  -- ══ SECONDE A (§9) ═════════════════════════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id = v_2ndeA
    AND subject_id IN (v_philosophie, v_svt_generic, v_lv2_generic);
  v_general_a := ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_maths, v_informatique, v_sciences, v_eps
  ];
  FOREACH v_subject IN ARRAY v_general_a
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_2ndeA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;
  FOREACH v_subject IN ARRAY ARRAY[v_allemand, v_espagnol, v_italien, v_arabe, v_chinois]
  LOOP
    PERFORM link_optional_subject(v_subject, v_2ndeA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, 'LANGUE_VIVANTE_II');
  END LOOP;
  PERFORM link_optional_subject(v_latin, v_2ndeA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);
  PERFORM link_optional_subject(v_grec, v_2ndeA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);

  -- ══ SECONDE C (§10) ════════════════════════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id = v_2ndeC
    AND subject_id IN (v_philosophie, v_svt_generic);
  v_general_cd := ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_maths, v_physique, v_chimie, v_svteehb, v_informatique, v_eps
  ];
  FOREACH v_subject IN ARRAY v_general_cd
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_2ndeC, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;

  -- ══ PREMIÈRE A (§11) ═══════════════════════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id = v_1ereA AND subject_id IN (v_svt_generic, v_lv2_generic);
  FOREACH v_subject IN ARRAY ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_philosophie, v_maths, v_informatique, v_sciences, v_eps
  ]
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_1ereA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;
  FOREACH v_subject IN ARRAY ARRAY[v_allemand, v_espagnol, v_italien, v_arabe, v_chinois]
  LOOP
    PERFORM link_optional_subject(v_subject, v_1ereA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, 'LANGUE_VIVANTE_II');
  END LOOP;
  PERFORM link_optional_subject(v_latin, v_1ereA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);
  PERFORM link_optional_subject(v_grec, v_1ereA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);

  -- ══ PREMIÈRE C (§12) et PREMIÈRE D (§13) ═════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id IN (v_1ereC, v_1ereD) AND subject_id = v_svt_generic;
  v_general_cd := ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_philosophie, v_maths, v_physique, v_chimie, v_svteehb, v_informatique, v_eps
  ];
  FOREACH v_class IN ARRAY ARRAY[v_1ereC, v_1ereD]
  LOOP
    FOREACH v_subject IN ARRAY v_general_cd
    LOOP
      PERFORM link_mandatory_subject(v_subject, v_class, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
    END LOOP;
  END LOOP;

  -- ══ PREMIÈRE TI (§14) — jamais "Informatique" générique ═════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id = v_1ereTI AND subject_id = v_reseaux; -- fusionnée dans Maintenance
  FOREACH v_subject IN ARRAY ARRAY[v_algo, v_maintenance, v_sysinfo_premiere]
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_1ereTI, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;
  v_ti_general := ARRAY[
    v_francais, v_anglais, v_histoire, v_ecm, v_philosophie,
    v_maths, v_physique, v_chimie, v_svteehb, v_eps
  ];
  FOREACH v_subject IN ARRAY v_ti_general
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_1ereTI, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;

  -- ══ TERMINALE A (§15) ═════════════════════════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id = v_TleA AND subject_id IN (v_svt_generic, v_lv2_generic);
  FOREACH v_subject IN ARRAY ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_philosophie, v_maths, v_informatique, v_sciences, v_eps
  ]
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_TleA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;
  FOREACH v_subject IN ARRAY ARRAY[v_allemand, v_espagnol, v_italien, v_arabe, v_chinois]
  LOOP
    PERFORM link_optional_subject(v_subject, v_TleA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, 'LANGUE_VIVANTE_II');
  END LOOP;
  PERFORM link_optional_subject(v_latin, v_TleA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);
  PERFORM link_optional_subject(v_grec, v_TleA, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti, NULL);

  -- ══ TERMINALE C (§16) et TERMINALE D (§17) ════════════════════════════════════════════════════
  DELETE FROM subject_class_links WHERE class_node_id IN (v_TleC, v_TleD) AND subject_id = v_svt_generic;
  v_general_cd := ARRAY[
    v_francais, v_litterature, v_anglais, v_histoire, v_geographie, v_ecm,
    v_philosophie, v_maths, v_physique, v_chimie, v_svteehb, v_informatique, v_eps
  ];
  FOREACH v_class IN ARRAY ARRAY[v_TleC, v_TleD]
  LOOP
    FOREACH v_subject IN ARRAY v_general_cd
    LOOP
      PERFORM link_mandatory_subject(v_subject, v_class, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
    END LOOP;
  END LOOP;

  -- ══ TERMINALE TI (§18) — plus jamais à zéro matière, jamais "Informatique" générique ═════════
  FOREACH v_subject IN ARRAY ARRAY[v_algo, v_reseaux, v_sysinfo_bd, v_projet]
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_TleTI, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;
  FOREACH v_subject IN ARRAY v_ti_general
  LOOP
    PERFORM link_mandatory_subject(v_subject, v_TleTI, v_country, 'SECONDARY_SOURCE_CONFIRMED', v_src_lycee_ti);
  END LOOP;

  -- ── §43/§48 : marque comme incomplètes les spécialités techniques sans matière professionnelle
  -- (aucune n'en a encore — la structure STT/IND existe depuis la migration 88, ses matières
  -- professionnelles ne sont pas peuplées ici, le cahier interdisant explicitement de les inventer).
  UPDATE academic_nodes SET verification_status = 'incomplete'
  WHERE node_type = 'specialty'
    AND NOT EXISTS (SELECT 1 FROM subject_class_links l WHERE l.class_node_id = academic_nodes.id);
END $$;
