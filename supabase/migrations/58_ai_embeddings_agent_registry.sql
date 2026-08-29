-- IA-004 partie 2 (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : enregistre ai-embeddings-generate
-- dans le registre IA-001 (migration 55), même discipline que les 5 agents déjà enregistrés — pas
-- une nouvelle fonction "invisible" du registre.

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'embeddings_generation',
    'Embeddings Generator (RAG)',
    'Générer des vecteurs d''embeddings (768 dimensions) pour un lot de textes, via Gemini gemini-embedding-001 — alimente ai_rag_chunks (migration 56).',
    'Ne décide jamais quel contenu ingérer ni ne filtre par permission/scope — c''est le rôle de l''appelant (pipeline d''ingestion RAG).',
    'Pas d''ID officiel dans le catalogue des 26 : c''est un outil d''infrastructure RAG (§10 du cahier), pas un agent pédagogique au sens strict — même statut que catalog_generation.',
    'active',
    'edge_function:ai-embeddings-generate'
)
ON CONFLICT (agent_id) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT a.id, '1.0.0',
    '{"type":"object","required":["texts"],"properties":{"texts":{"type":"array","items":{"type":"string"},"maxItems":100}}}'::jsonb,
    '{"type":"object","properties":{"embeddings":{"type":"array","items":{"type":"array","items":{"type":"number"}}},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":"string"},"_duration_ms":{"type":"integer"}}}'::jsonb,
    '{"preferred":["gemini-embedding-001"],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'ai-embeddings-generate'
FROM ai_agents a WHERE a.agent_id = 'embeddings_generation'
ON CONFLICT (agent_id, version) DO NOTHING;
