-- IA-009 : enregistre CorrectionAgent (AIA-AGT-005) dans le registre IA-001 — Gateway-native (pas
-- d'Edge Function dédiée : appelle ai-generate-text via le Model Router, IA-005, déjà en place).

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'AIA-AGT-005',
    'CorrectionAgent',
    'Corriger une tentative de réponse rédigée (réponse courte/rédaction) à partir du corrigé de référence versionné, et expliquer les erreurs.',
    'N''écrit jamais official_correct (réservé à un admin, RLS migration 68) — sépare toujours machine_score/confidence/feedback de la note officielle, conformément à la règle explicite du cahier. Ne traite pas le QCM (déjà une correction déterministe exacte).',
    'Correspond à AIA-AGT-005 du catalogue officiel (§7). Construit pour IA-009 (Exercise vertical slice) avec ExerciseAgent (AIA-AGT-004, déjà réel) et la validation humaine (POST /v1/exercise-attempts/{id}/review).',
    'active',
    NULL
)
ON CONFLICT (agent_id) DO UPDATE SET
    mission = EXCLUDED.mission, non_mission = EXCLUDED.non_mission,
    catalogue_relation = EXCLUDED.catalogue_relation, status = EXCLUDED.status, updated_at = NOW();

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["attempt_id"],"properties":{"attempt_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"ai_score":{"type":"number"},"ai_confidence":{"type":"number"},"ai_feedback":{"type":"string"},"ai_misconceptions":{"type":"array","items":{"type":"string"}},"needs_human_review":{"type":"boolean"}}}'::jsonb,
    '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-005'
ON CONFLICT (agent_id, version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
