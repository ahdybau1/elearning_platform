-- IA-007 : enregistre la vraie capacité enrichie du TutorAgent (AIA-AGT-001) — nouvelle version
-- 1.1.0 (RAG + math tool + Student Model read + cache), liens ai_agent_tools réels vers rag_search et
-- sympy_solve. La version 1.0.0 reste en base (status passe à 'retired', pas supprimée : historique).

UPDATE ai_agent_versions SET status = 'retired' WHERE agent_id = (SELECT id FROM ai_agents WHERE agent_id = 'AIA-AGT-001') AND version = '1.0.0';

UPDATE ai_agents SET
    catalogue_relation = 'Correspond à AIA-AGT-001 du catalogue officiel (§7). Depuis IA-007 (2026-08-29, vertical slice) : RAG scopé matière/classe avec citations, tool sympy_solve (déclenchement heuristique), lecture réelle du Student Model (get_student_skill_mastery), cache de réponses (ai_tutor_cache). Pas encore d''Agent Orchestrator (LangGraph) : l''enchaînement RAG->tools->prompt reste écrit à la main dans gateway/app/agents/tutor_agent.py, différé jusqu''à IA-009+.',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-001';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT
    id,
    '1.1.0',
    '{"type":"object","required":["message"],"properties":{"message":{"type":"string"},"subject_name":{"type":"string"},"class_name":{"type":"string"},"history":{"type":"array","items":{"type":"object","properties":{"sender":{"type":"string"},"text":{"type":"string"}}}},"rag_context":{"type":["string","null"],"description":"Construit par la Gateway (RAG scopé matière/classe), pas fourni par le client direct."},"student_model_summary":{"type":["string","null"],"description":"Construit par la Gateway depuis get_student_skill_mastery."},"tool_context":{"type":["string","null"],"description":"Résultat sympy_solve si un fragment mathématique a été détecté dans le message."}}}'::jsonb,
    '{"type":"object","properties":{"reply":{"type":"string"},"citations":{"type":"array","items":{"type":"object","properties":{"chunk_id":{"type":"string"},"source_id":{"type":"string"},"source_title":{"type":["string","null"]},"content":{"type":"string"},"similarity":{"type":"number"}}}},"tool_trace_summary":{"type":"array"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":["string","null"]},"_duration_ms":{"type":"integer"}}}'::jsonb,
    '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'ai-tutor-chat'
FROM ai_agents WHERE agent_id = 'AIA-AGT-001'
ON CONFLICT (agent_id, version) DO NOTHING;

-- rag_search et sympy_solve sont déjà enregistrés dans ai_tools (migrations 57/60) — seul le lien
-- vers cette nouvelle version de AIA-AGT-001 est nouveau ici.
INSERT INTO ai_agent_tools (agent_version_id, tool_id)
SELECT av.id, t.id
FROM ai_agent_versions av, ai_tools t
WHERE av.agent_id = (SELECT id FROM ai_agents WHERE agent_id = 'AIA-AGT-001')
  AND av.version = '1.1.0'
  AND t.tool_key IN ('rag_search', 'sympy_solve')
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
