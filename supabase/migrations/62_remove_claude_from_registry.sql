-- Retire Claude du registre IA-001 (demande explicite du porteur de projet, 2026-08-29) : le code
-- réel n'appelle plus Claude (ANTHROPIC_API_KEY n'a jamais été configurée — voir les commentaires
-- dans les Edge Functions concernées), les model_policy des versions enregistrées doivent refléter
-- la même réalité plutôt que mentir sur ce qui tourne vraiment.

UPDATE ai_agent_versions
SET model_policy = '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":true}'::jsonb
WHERE agent_id IN (
    SELECT id FROM ai_agents WHERE agent_id IN ('AIA-AGT-004', 'course_structuring', 'catalog_generation')
) AND version = '1.0.0';

UPDATE ai_agent_versions
SET model_policy = '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":false}'::jsonb
WHERE agent_id = (SELECT id FROM ai_agents WHERE agent_id = 'model_router_generate')
  AND version = '1.0.0';

UPDATE ai_agents
SET mission = 'Route vers Gemini par capability (reasoning_strong/pedagogy_small/classification_small) — §5 du cahier Agents IA. Un seul moteur configuré aujourd''hui (Gemini) ; la distinction par capability reste dans le contrat pour ne pas casser l''API le jour où un second moteur est ajouté.'
WHERE agent_id = 'model_router_generate';
