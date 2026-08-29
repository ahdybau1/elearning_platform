-- IA-005 "Model Router" : enregistre ai-generate-text dans le registre IA-001 (migration 55), même
-- discipline que ai-embeddings-generate (migration 58).

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'model_router_generate',
    'Model Router — Generate Text',
    'Point d''entrée réel du choix de fournisseur par capability (reasoning_strong/pedagogy_small/classification_small) — §5 du cahier Agents IA. Route vers Claude (reasoning_strong, repli Gemini) ou Gemini (pedagogy_small/classification_small).',
    'Ne décide jamais du contenu généré ni de sa validation pédagogique — un simple point de routage, l''agent appelant reste responsable du prompt et de l''usage du résultat.',
    'Pas d''ID officiel dans le catalogue des 26 : c''est l''infrastructure de routage (Model Router) que le cahier décrit en Partie 3/§5, partagée par tous les agents, pas un agent pédagogique en soi.',
    'active',
    'edge_function:ai-generate-text'
)
ON CONFLICT (agent_id) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT a.id, '1.0.0',
    '{"type":"object","required":["capability","user_prompt"],"properties":{"capability":{"type":"string","enum":["reasoning_strong","pedagogy_small","classification_small"]},"system_prompt":{"type":"string"},"user_prompt":{"type":"string"},"max_tokens":{"type":"integer","minimum":64,"maximum":4096}}}'::jsonb,
    '{"type":"object","properties":{"text":{"type":"string"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":"string"},"_provider":{"type":"string"},"_duration_ms":{"type":"integer"}}}'::jsonb,
    -- ÉTAT RÉEL vérifié le 2026-08-29 (pas supposé) : ANTHROPIC_API_KEY absente des secrets du
    -- projet (npx supabase secrets list) — reasoning_strong retombe donc TOUJOURS sur Gemini
    -- aujourd'hui, comme les 3 autres agents de génération. Documenté ici plutôt que caché.
    '{"preferred":["claude-3-5-sonnet-20241022 (reasoning_strong, si ANTHROPIC_API_KEY configurée)","gemini-3.6-flash"],"fallback":["gemini-3.6-flash"],"mock_available":false,"known_gap":"ANTHROPIC_API_KEY non configurée au 2026-08-29 — reasoning_strong utilise Gemini en pratique"}'::jsonb,
    'standard', 'production', 'ai-generate-text'
FROM ai_agents a WHERE a.agent_id = 'model_router_generate'
ON CONFLICT (agent_id, version) DO NOTHING;
