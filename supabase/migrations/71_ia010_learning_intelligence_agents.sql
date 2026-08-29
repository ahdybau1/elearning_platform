-- IA-010 "Learning intelligence" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : DiagnosticAgent,
-- MisconceptionAgent, RevisionAgent, RecommendationAgent, SocraticAgent, ExplanationAgent,
-- ExamCoachAgent.
--
-- Construits (Gateway-native, s'appuient sur le Student Model/Competency Graph réels d'IA-007 et les
-- ai_misconceptions réels de CorrectionAgent, IA-009) : DiagnosticAgent (AIA-AGT-008),
-- MisconceptionAgent (AIA-AGT-009), RecommendationAgent (AIA-AGT-010).
--
-- Enregistrés en status='draft' (catalogués honnêtement, pas silencieusement absents — même posture
-- que OCRAgent/FormulaRecognitionAgent en IA-008) :
-- - SocraticAgent (AIA-AGT-002) : le comportement maïeutique qu'il décrit (progression par questions,
--   jamais la solution directe) est DÉJÀ le comportement réel de TutorAgent (ai-tutor-chat, voir son
--   system prompt) — mais le contrat structuré exigé (next_question/hint_level/diagnostic_signal/
--   stop_condition) n'existe pas séparément. Construire un agent séparé dupliquerait TutorAgent sans
--   ajouter de valeur claire tant que le premier n'a pas de limite identifiée en usage réel.
-- - RevisionAgent (AIA-AGT-006) : nécessite un modèle d'oubli (spaced-repetition) — aucune constante
--   réelle calibrable sans historique d'usage en volume (même principe que les quotas IA-006 : ne pas
--   inventer un chiffre avant d'avoir de vraies données).
-- - ExplanationAgent (AIA-AGT-003) : chevauche largement TutorAgent + RAG déjà réels ; sa valeur ajoutée
--   (reformulation à plusieurs niveaux de détail explicitement choisis) mérite un vrai besoin exprimé
--   plutôt qu'une construction anticipée.
-- - ExamCoachAgent (AIA-AGT-007) : dépend d'un vrai corpus d'épreuves passées exploitable
--   (`exam_papers`/`official_exams` existent en schéma mais leur contenu réel n'a pas été audité pour
--   cette passe) — à reprendre avec un audit dédié de ces tables plutôt que construit à l'aveugle ici.

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'AIA-AGT-008', 'DiagnosticAgent',
    'Estimer les compétences acquises/manquantes à partir de preuves diagnostiques réelles (tentatives d''exercices).',
    'Ne pose pas d''étiquette définitive sur l''élève — chaque estimation reste contestable et vient avec sa confiance et ses preuves.',
    'Correspond à AIA-AGT-008 du catalogue officiel (§7). Pas d''IRT/BKT (hors périmètre d''un vertical slice, aucune donnée réelle en volume pour calibrer) : estimate = mastery_level réel (get_student_skill_mastery, IA-007), confidence = fonction déclarée du nombre de preuves, evidence = vrais IDs de exercise_attempts.',
    'active', NULL
),
(
    'AIA-AGT-009', 'MisconceptionAgent',
    'Détecter des erreurs conceptuelles récurrentes à partir des tentatives corrigées, et les proposer comme hypothèses.',
    'N''écrit jamais status=confirmed (réservé à un admin, RLS migration 70) — une hypothèse reste toujours "candidate" à l''écriture par l''agent.',
    'Correspond à AIA-AGT-009 du catalogue officiel (§7). Agrège les ai_misconceptions déjà produits par CorrectionAgent (IA-009) — n''invente aucune nouvelle analyse, un vrai regroupement textuel des signaux déjà réels.',
    'active', NULL
),
(
    'AIA-AGT-010', 'RecommendationAgent',
    'Traduire la compétence recommandée par le Learning Orchestrator (IA-007) en activités concrètes réelles (leçons/exercices), en respectant les droits d''abonnement réels.',
    'Ne contourne jamais le palier d''abonnement minimum d''un exercice (exercises.min_subscription_tier) — un exercice hors droits est exclu, pas juste signalé.',
    'Correspond à AIA-AGT-010 du catalogue officiel (§7). Déterministe, sans LLM (conforme à la règle du cahier "le moteur déterministe doit fonctionner sans LLM").',
    'active', NULL
),
(
    'AIA-AGT-002', 'SocraticAgent',
    'Faire progresser l''élève par questions graduées plutôt que donner immédiatement la solution.',
    NULL,
    'Correspond à AIA-AGT-002 du catalogue officiel (§7). DIFFÉRÉ en tant qu''agent séparé (2026-08-29) : le comportement maïeutique décrit est déjà réellement implémenté dans le system prompt de TutorAgent (ai-tutor-chat) — le contrat structuré propre à cet agent (next_question/hint_level/diagnostic_signal/stop_condition) n''existe pas séparément, pas de besoin identifié qui le justifie pour l''instant.',
    'draft', NULL
),
(
    'AIA-AGT-006', 'RevisionAgent',
    'Construire une séance de révision selon maîtrise, oubli estimé, échéances et temps disponible.',
    NULL,
    'Correspond à AIA-AGT-006 du catalogue officiel (§7). DIFFÉRÉ (2026-08-29) : nécessite un modèle de courbe d''oubli — aucune constante calibrable sans historique réel en volume (même principe que les quotas non fixés avant benchmark, IA-006).',
    'draft', NULL
),
(
    'AIA-AGT-003', 'ExplanationAgent',
    'Reformuler une notion validée selon niveau, langue, style, accessibilité et difficulté.',
    NULL,
    'Correspond à AIA-AGT-003 du catalogue officiel (§7). DIFFÉRÉ (2026-08-29) : chevauche largement TutorAgent + RAG déjà réels ; construit sur besoin exprimé plutôt qu''anticipé.',
    'draft', NULL
),
(
    'AIA-AGT-007', 'ExamCoachAgent',
    'Préparer aux examens officiels (BEPC, Probatoire, Baccalauréat...) via plan, priorités, simulations.',
    NULL,
    'Correspond à AIA-AGT-007 du catalogue officiel (§7). DIFFÉRÉ (2026-08-29) : dépend d''un audit réel du contenu de exam_papers/official_exams (existent en schéma, contenu non audité pour cette passe) avant de construire dessus.',
    'draft', NULL
)
ON CONFLICT (agent_id) DO UPDATE SET
    mission = EXCLUDED.mission, non_mission = EXCLUDED.non_mission,
    catalogue_relation = EXCLUDED.catalogue_relation, status = EXCLUDED.status, updated_at = NOW();

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["subject_id"],"properties":{"subject_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"skill_estimates":{"type":"array"},"next_diagnostic_action":{"type":["object","null"]}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-008'
ON CONFLICT (agent_id, version) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["subject_id"],"properties":{"subject_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"misconceptions":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-009'
ON CONFLICT (agent_id, version) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["subject_id"],"properties":{"subject_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"skill":{"type":["object","null"]},"candidates":{"type":"array"},"reason":{"type":"string"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-010'
ON CONFLICT (agent_id, version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
