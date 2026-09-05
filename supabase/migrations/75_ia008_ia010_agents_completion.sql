-- Complète IA-008 et IA-010 (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : agents laissés en
-- status='draft' par les migrations 67/71, désormais réellement implémentés.
--
-- OCRAgent (AIA-AGT-014) : le porteur de projet avait explicitement refusé le 2026-08-29 un
-- raccourci "OCR via Gemini multimodal" pour cet agent (migration 67), en l'absence d'infra
-- OpenCV/PaddleOCR self-hébergée. Le 2026-09-04, ce même raccourci a été construit et approuvé pour
-- l'Exam Resource Factory (ai-exam-paper-processing) — décision explicitement reconfirmée le
-- 2026-09-06 : ce raccourci est maintenant accepté comme l'implémentation réelle d'OCRAgent, pas
-- seulement un outil ad hoc de l'Exam Resource Factory.
--
-- FormulaRecognitionAgent (AIA-AGT-015) : dépendait d'OCRAgent (résolu ci-dessus). Construit comme
-- un parseur/validateur SymPy (gateway/app/agents/formula_recognition_agent.py) sur une formule déjà
-- transcrite en texte par OCRAgent — pas une reconnaissance visuelle de formule manuscrite (aucun
-- moteur de ce type sur ce projet, voir docstring de l'agent pour le détail).
--
-- RevisionAgent (AIA-AGT-006) : le blocage du 2026-08-29 ("aucune constante calibrable sans
-- historique réel") est traité avec le même principe déjà accepté ailleurs dans ce projet pour une
-- contrainte identique (MASTERY_THRESHOLD, student_model/orchestrator.py) — heuristique honnêtement
-- documentée comme non calibrée, à revoir avec de vraies données d'usage.
--
-- ExamCoachAgent (AIA-AGT-007) : le blocage du 2026-08-29 ("corpus d'épreuves passées non audité")
-- est résolu par l'audit réel effectué pendant l'Exam Resource Factory (migrations 73-74) —
-- exam_paper_questions contient maintenant de vraies questions revues et approuvées par un humain.
--
-- SocraticAgent (AIA-AGT-002) et ExplanationAgent (AIA-AGT-003) restent explicitement en 'draft' —
-- décision reconfirmée le 2026-09-06 : leur comportement chevauche déjà TutorAgent sans besoin
-- identifié qui justifierait un agent séparé (règle d'or §25 du cahier).

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Le résultat OCR est une extraction candidate, jamais publiée directement — un admin relit et approuve chaque question extraite avant toute publication (voir exam_paper_questions.status et guard_exam_publication, migration 74).',
    catalogue_relation = 'Correspond à AIA-AGT-014 du catalogue officiel (§7). Implémenté via ai-exam-paper-processing (vision Gemini) — raccourci explicitement refusé le 2026-08-29 (migration 67), reconfirmé accepté le 2026-09-06 après validation sur l''Exam Resource Factory. Réservé admin (voir gateway/app/main.py, agents Content Factory).',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-014';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","properties":{"exam_paper_id":{"type":["string","null"]},"establishment_paper_id":{"type":["string","null"]}}}'::jsonb,
    '{"type":"object","properties":{"questions_count":{"type":"integer"}}}'::jsonb,
    '{"preferred":["gemini"],"fallback":[],"mock_available":true}'::jsonb,
    'standard', 'production', 'ai-exam-paper-processing'
FROM ai_agents WHERE agent_id = 'AIA-AGT-014'
ON CONFLICT (agent_id, version) DO NOTHING;

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Toute formule utilisée pour correction/calcul doit être parsée/validée ou envoyée en revue — un échec de parsing renvoie toujours needs_review=true, jamais un score/confiance inventé.',
    catalogue_relation = 'Correspond à AIA-AGT-015 du catalogue officiel (§7). Parseur/validateur SymPy sur une formule déjà transcrite en texte par OCRAgent (AIA-AGT-014) — pas de reconnaissance visuelle manuscrite (aucun moteur de ce type disponible).',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-015';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["expression"],"properties":{"expression":{"type":"string"},"variable":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"formula":{"type":"string"},"confidence":{"type":"number"},"parse_status":{"type":"string"},"semantic_validation":{"type":"boolean"},"needs_review":{"type":"boolean"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-015'
ON CONFLICT (agent_id, version) DO NOTHING;

UPDATE ai_agents SET
    status = 'active',
    catalogue_relation = 'Correspond à AIA-AGT-006 du catalogue officiel (§7). Modèle d''oubli par décroissance exponentielle (demi-vie non calibrée sur données réelles, voir gateway/app/agents/revision_agent.py) — même principe déjà accepté pour MASTERY_THRESHOLD (student_model/orchestrator.py). Échéances (calendrier d''examen) non intégrées : dépend d''ExamCoachAgent, non composé ici pour éviter de dupliquer cette connaissance.',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-006';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["subject_id"],"properties":{"subject_id":{"type":"string"},"available_minutes":{"type":"integer"}}}'::jsonb,
    '{"type":"object","properties":{"plan":{"type":"array"},"total_minutes":{"type":"integer"},"available_minutes":{"type":"integer"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-006'
ON CONFLICT (agent_id, version) DO NOTHING;

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Ne prétend jamais connaître une future épreuve confidentielle — les "simulations" sont exclusivement des annales déjà publiées et revues par un humain (exam_paper_questions.status=''approved''), jamais une prédiction du contenu d''une épreuve à venir.',
    catalogue_relation = 'Correspond à AIA-AGT-007 du catalogue officiel (§7). S''appuie sur le corpus réel audité pendant l''Exam Resource Factory (migrations 73-74) — appelle read_published_exam_questions (le même RPC que le futur écran élève) plutôt que de contourner son contrôle d''accès.',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-007';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["subject_id"],"properties":{"subject_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"exam":{"type":["object","null"]},"lacunes":{"type":"array"},"simulations":{"type":"array"},"next_actions":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-007'
ON CONFLICT (agent_id, version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
