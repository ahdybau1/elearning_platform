-- IA-012 "Staff/famille" et IA-013 "Operations" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22).
-- Aucun de ces 9 agents n'existait dans le registre avant cette migration (vérifié via ai_agents,
-- 2026-09-06) — ni actif, ni même catalogué en draft.
--
-- Construits (Gateway-native, s'appuient sur des tables/RPC déjà réelles) :
-- - ParentInsightAgent (AIA-AGT-019) : Student Model (IA-007) + parent_profile_links (migration 01).
-- - SupportTriageAgent (AIA-AGT-022) : support_tickets (migration 03), déterministe par mots-clés.
--
-- Catalogués honnêtement en 'draft' (pas silencieusement absents, même posture qu'OCRAgent en
-- août) — PAS construits dans cette passe :
-- - TeacherAssistantAgent (AIA-AGT-018), AdminAssistantAgent (AIA-AGT-021), FraudRiskAgent
--   (AIA-AGT-025) : buildables sans nouvelle infra (tables déjà réelles), mais non construits dans
--   cette passe faute de temps — à reprendre, pas bloqués par un manque d'infra contrairement aux
--   agents ci-dessous.
-- - GameContentAgent (AIA-AGT-011), MusicLearningAgent (AIA-AGT-012), LabAssistantAgent
--   (AIA-AGT-013) : dépendent chacun d'une infra qui n'existe nulle part sur ce projet (audit du
--   2026-09-06) — aucun GameTemplateEngine, aucun moteur audio/TTS, aucun simulateur scientifique
--   (ngspice/RDKit/3Dmol.js/OpenModelica). Construire l'agent sans le moteur produirait une sortie
--   qu'aucune interface ne peut consommer — contraire à la règle d'or §25 (ne pas afficher de l'IA
--   sans utilité mesurable).
-- - TranslationAgent (AIA-AGT-023) : dépend d'un glossaire versionné/translation memory — aucune
--   infra i18n de contenu n'existe (seul un placeholder "i18n prep" existe côté Paramètres Système).
-- - InfrastructureOpsAgent (AIA-AGT-026) : dépend de jobs/files d'attente/Compute Fabric — aucune
--   infra de ce type n'existe (explicitement différée avec IA-014, cahier §22).

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'AIA-AGT-019', 'ParentInsightAgent',
    'Transformer les données autorisées d''un enfant lié en synthèse claire et actionnable pour un parent.',
    'Pas de surveillance punitive. Pas d''accès aux conversations (TutorAgent) ni à aucune donnée privée hors Student Model. Langage non stigmatisant.',
    'Correspond à AIA-AGT-019 du catalogue officiel (§7). Autorisation vérifiée via parent_profile_links (migration 01) — voir gateway/app/auth.py verify_parent_child_access. Données déterministes (Student Model, IA-007), pas de LLM.',
    'active', NULL
),
(
    'AIA-AGT-022', 'SupportTriageAgent',
    'Calculer priorité et équipe de routage pour un ticket support déjà catégorisé par le demandeur.',
    'N''écrit jamais support_tickets.assigned_to lui-même — une suggestion affichée à l''admin, jamais une décision prise à sa place. Ne demande ni ne traite aucun secret.',
    'Correspond à AIA-AGT-022 du catalogue officiel (§7). Déterministe par mots-clés (aucune base de solutions documentées disponible pour "suggested_response" — renvoyé honnêtement null plutôt qu''inventé).',
    'active', NULL
),
(
    'AIA-AGT-018', 'TeacherAssistantAgent',
    'Aider enseignants/auteurs à préparer cours, exercices, corrections, plans, feedbacks et analyses de cohorte dans leur scope.',
    NULL,
    'Correspond à AIA-AGT-018 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : buildable sans nouvelle infra (Content/Exercise Factory déjà réels), non construit dans cette passe faute de temps.',
    'draft', NULL
),
(
    'AIA-AGT-021', 'AdminAssistantAgent',
    'Aider un administrateur à comprendre l''état de la plateforme et préparer des actions, en lecture seule par défaut.',
    'Aucun SQL arbitraire, aucune modification RLS directe, aucune action mutante sans confirmation explicite.',
    'Correspond à AIA-AGT-021 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : buildable sans nouvelle infra (ai_agent_calls/audit_log déjà réels), non construit dans cette passe faute de temps.',
    'draft', NULL
),
(
    'AIA-AGT-025', 'FraudRiskAgent',
    'Produire des signaux de risque sur paiements, examens, comptes, promotions ou usages anormaux.',
    'Signal ≠ preuve. Pas de sanction automatique lourde sur seul score IA.',
    'Correspond à AIA-AGT-025 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : buildable sans nouvelle infra (transactions/exercise_attempts déjà réels), non construit dans cette passe faute de temps.',
    'draft', NULL
),
(
    'AIA-AGT-011', 'GameContentAgent',
    'Générer du contenu/configuration de serious games liés aux compétences.',
    NULL,
    'Correspond à AIA-AGT-011 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : aucun GameTemplateEngine n''existe sur ce projet (audit réel) — construire l''agent sans moteur produirait une sortie inexploitable.',
    'draft', NULL
),
(
    'AIA-AGT-012', 'MusicLearningAgent',
    'Transformer des objectifs pédagogiques en contenus musicaux mémorisables et activités de transfert.',
    NULL,
    'Correspond à AIA-AGT-012 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : aucun moteur audio/TTS n''existe sur ce projet (audit réel, aucune dépendance flutter_tts/audioplayers/just_audio) — implications de licence (clonage vocal) non tranchées.',
    'draft', NULL
),
(
    'AIA-AGT-013', 'LabAssistantAgent',
    'Guider l''élève dans un laboratoire virtuel et expliquer les résultats d''un simulateur déterministe.',
    NULL,
    'Correspond à AIA-AGT-013 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : aucun simulateur scientifique (ngspice/RDKit/3Dmol.js/OpenModelica) n''existe sur ce projet (audit réel, gateway/requirements.txt ne contient que sympy).',
    'draft', NULL
),
(
    'AIA-AGT-023', 'TranslationAgent',
    'Traduire interfaces/contenus autorisés en conservant sens pédagogique, terminologie et formules.',
    NULL,
    'Correspond à AIA-AGT-023 du catalogue officiel (§7). DIFFÉRÉ (2026-09-06) : aucun glossaire versionné/translation memory n''existe (seul un placeholder "i18n prep" existe côté Paramètres Système admin).',
    'draft', NULL
),
(
    'AIA-AGT-026', 'InfrastructureOpsAgent',
    'Observer jobs, modèles, nœuds Compute Fabric, files d''attente, erreurs et capacité.',
    NULL,
    'Correspond à AIA-AGT-026 du catalogue officiel (§7). DIFFÉRÉ (cahier §22, IA-014 "seulement après benchmarks et besoins observés") : aucune infra de jobs/files d''attente/Compute Fabric n''existe sur ce projet.',
    'draft', NULL
)
ON CONFLICT (agent_id) DO UPDATE SET
    mission = EXCLUDED.mission, non_mission = EXCLUDED.non_mission,
    catalogue_relation = EXCLUDED.catalogue_relation, status = EXCLUDED.status, updated_at = NOW();

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["profile_id"],"properties":{"profile_id":{"type":"string"},"subject_id":{"type":["string","null"]}}}'::jsonb,
    '{"type":"object","properties":{"progress_summary":{"type":"string"},"strengths":{"type":"array"},"areas_to_support":{"type":"array"},"recommendations":{"type":"array"},"alerts":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-019'
ON CONFLICT (agent_id, version) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["ticket_id"],"properties":{"ticket_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"category":{"type":"string"},"priority":{"type":"string"},"routing_target":{"type":"string"},"suggested_response":{"type":["string","null"]},"required_context":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-022'
ON CONFLICT (agent_id, version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
