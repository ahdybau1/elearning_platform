-- IA-003 "Tool Gateway" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §12) : enregistre les 3 premiers
-- tools RÉELLEMENT implémentés et appelables (gateway/app/tools/), pas une liste théorique. La
-- table ai_tools existait déjà (migration 55) mais restait vide — honnêtement, puisqu'aucun tool
-- n'existait encore.
--
-- ai_agent_tools reste vide volontairement : aucun agent réel (les 5 Edge Functions Deno) n'appelle
-- encore ces tools aujourd'hui — les lier maintenant laisserait croire que TutorAgent/ExerciseAgent
-- utilisent déjà sympy_solve/search_validated_content, ce qui serait faux. Le branchement réel d'un
-- agent sur un tool est IA-007 ("premier vertical slice"), pas IA-003.

INSERT INTO ai_tools (tool_key, description, input_schema, output_schema, timeout_ms) VALUES
(
    'get_curriculum_context',
    'Remonte l''arbre académique (academic_nodes) depuis une classe/série jusqu''à la racine pays. Lecture seule, PostgREST filtré par ID — aucun SQL arbitraire.',
    '{"type":"object","required":["class_node_id"],"properties":{"class_node_id":{"type":"string","format":"uuid"}}}'::jsonb,
    '{"type":"object","properties":{"path":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"node_type":{"type":"string"},"name":{"type":"string"}}}}}}'::jsonb,
    10000
),
(
    'search_validated_content',
    'Recherche dans les leçons réellement publiées (is_published=true, is_active=true) d''une matière ou d''un chapitre, avec mot-clé optionnel sur le titre. Ne retourne jamais un brouillon.',
    '{"type":"object","properties":{"subject_id":{"type":"string","format":"uuid"},"chapter_id":{"type":"string","format":"uuid"},"keyword":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":20,"default":5}}}'::jsonb,
    '{"type":"object","properties":{"results":{"type":"array","items":{"type":"object","properties":{"lesson_id":{"type":"string"},"title":{"type":"string"},"chapter_title":{"type":"string"},"subject_name":{"type":"string"},"excerpt":{"type":"string"}}}}}}'::jsonb,
    10000
),
(
    'sympy_solve',
    'Calcul mathématique EXACT via SymPy (solve/simplify/evaluate) — jamais confié au LLM (§6 du cahier technique frameworks). Namespace SymPy restreint, longueur d''expression plafonnée, timeout 5s.',
    '{"type":"object","required":["expression"],"properties":{"expression":{"type":"string","maxLength":200},"variable":{"type":"string","default":"x"},"mode":{"type":"string","enum":["solve","simplify","evaluate"],"default":"solve"}}}'::jsonb,
    '{"type":"object","properties":{"result":{"type":["array","string"]}}}'::jsonb,
    5000
)
ON CONFLICT (tool_key) DO NOTHING;
