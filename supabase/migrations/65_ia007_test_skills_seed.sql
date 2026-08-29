-- IA-007 : peuplement du Competency Graph pour "une matière/leçon test" (§22), au sens strict du
-- cahier — la seule matière avec un vrai chapitre + leçon + exercices en base aujourd'hui est SVT /
-- "ECOSYSTEME DE LA TERRE" (voir docs/CONTENT_FACTORY_GAP_ANALYSIS.md : Mathématiques n'a ZÉRO leçon
-- publiée). Constat honnête : la leçon "LA TERRE ET SON RELIEF" déjà ingérée en RAG (IA-004) contient
-- en réalité un contenu MOCK de développement (content_json._mock = true, sur le second degré, sans
-- rapport avec le titre SVT) et les 6 exercices du chapitre sont des fixtures CF-003 ("Énoncé généré
-- factice"). Les compétences ci-dessous sont donc calées sur la STRUCTURE réelle des blocs de la
-- leçon mock (definition / theoreme / methode), pas sur un vrai programme SVT — exactement la même
-- posture que IA-004, qui a testé le pipeline RAG bout en bout sur cette même leçon de test sans
-- prétendre qu'il s'agissait de contenu pédagogique réel. Prochaine vraie curation à faire une fois du
-- contenu réel publié (hors périmètre de ce vertical slice).

INSERT INTO skills (id, subject_id, class_node_id, chapter_id, code, name, description) VALUES
    ('a1000000-0000-4000-8000-000000000001', '9f5d6151-08f1-4a27-ba2b-1eb3d46837e2', 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d', '1c722e4f-240b-4261-8e13-83153c4c778f', 'DEFINITIONS', 'Définitions et notions fondamentales', 'Connaître et énoncer précisément les définitions de base du chapitre.'),
    ('a1000000-0000-4000-8000-000000000002', '9f5d6151-08f1-4a27-ba2b-1eb3d46837e2', 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d', '1c722e4f-240b-4261-8e13-83153c4c778f', 'THEOREMES', 'Théorèmes et propriétés majeures', 'Énoncer et appliquer les théorèmes/propriétés du chapitre, avec leurs conditions d''application.'),
    ('a1000000-0000-4000-8000-000000000003', '9f5d6151-08f1-4a27-ba2b-1eb3d46837e2', 'c7a4cb54-0e5b-481a-8fe5-58d771dc434d', '1c722e4f-240b-4261-8e13-83153c4c778f', 'METHODE', 'Méthode de résolution pas-à-pas', 'Dérouler la méthode complète de résolution en évitant les pièges classiques.')
ON CONFLICT (id) DO NOTHING;

-- Competency Graph : METHODE nécessite THEOREMES, qui nécessite DEFINITIONS (chaîne de prérequis
-- simple, cohérente avec la structure pédagogique réelle des blocs de la leçon : on définit avant de
-- démontrer, on démontre avant d'appliquer une méthode).
INSERT INTO skill_prerequisites (skill_id, prerequisite_skill_id) VALUES
    ('a1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001'),
    ('a1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002')
ON CONFLICT DO NOTHING;

-- Lien réel vers les 6 exercices existants du chapitre test (fixtures CF-003, voir note ci-dessus) —
-- répartis sur les 3 compétences pour pouvoir tester le Mastery Engine sur plusieurs compétences.
INSERT INTO exercise_skills (exercise_id, skill_id) VALUES
    ('3bf1dc09-20a7-4c4e-a406-e082464e5061', 'a1000000-0000-4000-8000-000000000001'),
    ('269ffd54-1a7a-4d45-b5cb-12323114829b', 'a1000000-0000-4000-8000-000000000001'),
    ('ce3128ea-79f0-42f8-b137-2fe4b62bb495', 'a1000000-0000-4000-8000-000000000002'),
    ('4a2ee110-e2a6-4d89-97d9-46d397e48418', 'a1000000-0000-4000-8000-000000000002'),
    ('8501eea7-7eff-468f-8d24-2b81329203f3', 'a1000000-0000-4000-8000-000000000003'),
    ('62f0ce3c-bf97-403b-a04a-11e2277b395f', 'a1000000-0000-4000-8000-000000000003')
ON CONFLICT DO NOTHING;
