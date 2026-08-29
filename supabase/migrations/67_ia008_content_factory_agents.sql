-- IA-008 "Content Factory agents" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) :
-- OCRAgent — FormulaRecognitionAgent — DocumentStructuringAgent — CurriculumMappingAgent —
-- PedagogicalValidationAgent.
--
-- Décision explicite du porteur de projet (2026-08-29) : OCRAgent (AIA-AGT-014) et
-- FormulaRecognitionAgent (AIA-AGT-015) exigent un vrai moteur de vision par ordinateur
-- (OpenCV/PaddleOCR auto-hébergé, nommés explicitement par le cahier) — aucune infra de ce type
-- n'existe, différés jusqu'à une décision d'hébergement explicite (même posture que l'Agent
-- Orchestrator/LangGraph, déjà différé). Enregistrés ici en status='draft' : le registre reste honnête
-- sur ce qui existe vs ce qui est catalogué mais pas construit, plutôt que silencieusement absent.
--
-- DocumentStructuringAgent (AIA-AGT-016), CurriculumMappingAgent (AIA-AGT-017) et
-- PedagogicalValidationAgent (AIA-AGT-024) sont réellement construits.

INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'AIA-AGT-014',
    'OCRAgent',
    'Extraire texte, structure grossière et zones utiles de PDF/image/scan.',
    'Ne publie jamais un résultat OCR comme vérité — extraction candidate uniquement.',
    'Correspond à AIA-AGT-014 du catalogue officiel (§7). DIFFÉRÉ (2026-08-29) : exige OpenCV/PaddleOCR auto-hébergé (nommés par le cahier) ou une API cloud dédiée — aucune infra de ce type n''existe sur ce projet. Décision explicite du porteur de projet de différer plutôt que de construire un raccourci (ex: OCR via Gemini multimodal) qui s''écarterait du choix technique du cahier.',
    'draft',
    NULL
),
(
    'AIA-AGT-015',
    'FormulaRecognitionAgent',
    'Reconnaître formules imprimées/manuscrites et produire une représentation structurée (LaTeX/AST) vérifiable.',
    NULL,
    'Correspond à AIA-AGT-015 du catalogue officiel (§7). DIFFÉRÉ (2026-08-29) : dépend d''OCRAgent (AIA-AGT-014), lui-même différé.',
    'draft',
    NULL
),
(
    'AIA-AGT-016',
    'DocumentStructuringAgent',
    'Transformer une source texte déjà importée en Structured Content compatible Content Factory, sans inventer de contenu — traçabilité littérale (source_excerpt) obligatoire par bloc.',
    'Ne publie jamais directement (l''admin relit dans lessons_manager_screen.dart). Ne prend en entrée que du texte déjà extrait — pas d''image/PDF scanné (dépendrait d''OCRAgent, différé).',
    'Correspond à AIA-AGT-016 du catalogue officiel (§7). Distinct de "course_structuring" (agent existant sans ID officiel) : celui-ci GÉNÈRE depuis des notes brèves, celui-ci STRUCTURE une source déjà écrite en préservant sa traçabilité littérale.',
    'active',
    NULL
),
(
    'AIA-AGT-017',
    'CurriculumMappingAgent',
    'Proposer le rattachement d''un contenu aux pays/versions/classes/séries/matières/chapitres/leçons/compétences, avec confiance et preuve.',
    'Ne modifie jamais un rattachement existant — produit des candidats. Mapping ambigu ou à fort impact -> needs_human_review=true, jamais tranché seul.',
    'Correspond à AIA-AGT-017 du catalogue officiel (§7). Implémenté avec un matcher lexical (chapters/skills, échelle réelle du projet aujourd''hui) + recherche sémantique sur le corpus RAG déjà ingéré (IA-004) — pas de "Curriculum Graph" formel séparé, la hiérarchie academic_nodes réelle en tient lieu.',
    'active',
    NULL
),
(
    'AIA-AGT-024',
    'PedagogicalValidationAgent',
    'Précontrôler exactitude, alignement curriculum, structure, cohérence d''un contenu avant publication humaine.',
    'Pré-validateur uniquement — ne publie ni ne bloque rien lui-même, la publication humaine reste requise (règle explicite du cahier).',
    'Correspond à AIA-AGT-024 du catalogue officiel (§7). Couverture réelle honnête : rattachement curriculaire + structure des blocs + détection de contenu factice/mock (spécifique à ce projet) + vérification symbolique best-effort des formules. PAS encore : vérification de citations contre une source RAG, accessibilité fine (alt-text), détection de plagiat — différés, à ajouter sur besoin réel plutôt que par anticipation.',
    'active',
    NULL
)
ON CONFLICT (agent_id) DO UPDATE SET
    mission = EXCLUDED.mission, non_mission = EXCLUDED.non_mission,
    catalogue_relation = EXCLUDED.catalogue_relation, status = EXCLUDED.status, updated_at = NOW();

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["raw_source_text"],"properties":{"raw_source_text":{"type":"string","minLength":20},"subject_name":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"blocks":{"type":"array","items":{"type":"object","properties":{"type":{"type":"string"},"heading":{"type":"string"},"body":{"type":"string"},"source_excerpt":{"type":"string"},"formulas":{"type":"array","items":{"type":"string"}}}}},"ambiguities":{"type":"array","items":{"type":"string"}},"confidence":{"type":"number"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":["string","null"]},"_duration_ms":{"type":"integer"}}}'::jsonb,
    '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'ai-document-structuring'
FROM ai_agents WHERE agent_id = 'AIA-AGT-016'
ON CONFLICT (agent_id, version) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["text"],"properties":{"text":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"chapter_candidates":{"type":"array"},"skill_candidates":{"type":"array"},"needs_human_review":{"type":"boolean"}}}'::jsonb,
    '{"preferred":["gemini-embedding-001"],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-017'
ON CONFLICT (agent_id, version) DO NOTHING;

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["lesson_id"],"properties":{"lesson_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"checklist":{"type":"array"},"errors":{"type":"array","items":{"type":"string"}},"warnings":{"type":"array","items":{"type":"string"}},"blocking_issues":{"type":"array","items":{"type":"string"}},"confidence":{"type":"number"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-024'
ON CONFLICT (agent_id, version) DO NOTHING;

-- Liens tools réels (§2 : allowlist, pas d'accès générique).
INSERT INTO ai_agent_tools (agent_version_id, tool_id)
SELECT av.id, t.id FROM ai_agent_versions av, ai_tools t
WHERE av.agent_id = (SELECT id FROM ai_agents WHERE agent_id = 'AIA-AGT-017') AND av.version = '1.0.0' AND t.tool_key = 'rag_search'
ON CONFLICT DO NOTHING;

INSERT INTO ai_agent_tools (agent_version_id, tool_id)
SELECT av.id, t.id FROM ai_agent_versions av, ai_tools t
WHERE av.agent_id = (SELECT id FROM ai_agents WHERE agent_id = 'AIA-AGT-024') AND av.version = '1.0.0' AND t.tool_key = 'sympy_solve'
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
