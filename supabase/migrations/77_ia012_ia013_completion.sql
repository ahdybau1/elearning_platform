-- Complète IA-012/IA-013 (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : les 3 agents catalogués en
-- 'draft' par la migration 76 ("buildables sans nouvelle infra, non construits faute de temps")
-- sont maintenant réellement implémentés.
--
-- TeacherAssistantAgent (AIA-AGT-018) : analyse de cohorte (moyenne de maîtrise par compétence sur
-- une classe), scope enseignant réellement vérifié via teacher_establishments.
-- AdminAssistantAgent (AIA-AGT-021) : synthèse plateforme en lecture seule (échecs IA récents,
-- tickets support ouverts par catégorie, contenu en attente de validation).
-- FraudRiskAgent (AIA-AGT-025) : un seul signal grounded dans le schéma réel (partage d'appareil
-- entre comptes distincts, sessions.device_fingerprint) — pas de signal de paiement/examen inventé
-- sans volume réel pour le calibrer.

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Ne prépare ni cours ni exercices ni corrections (déjà couverts par CourseGenerator/ExerciseAgent/CorrectionAgent) — se limite à l''analyse de cohorte, seule capacité non dupliquée ailleurs. N''accède jamais à une classe/matière hors du périmètre déclaré d''un enseignant (teacher_establishments).',
    catalogue_relation = 'Correspond à AIA-AGT-018 du catalogue officiel (§7). Construit (2026-09-06) : agrégation N+1 sur get_student_skill_mastery (IA-007), acceptable pour une classe, non benchmarké au-delà.',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-018';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","required":["class_node_id","subject_id"],"properties":{"class_node_id":{"type":"string"},"subject_id":{"type":"string"}}}'::jsonb,
    '{"type":"object","properties":{"students_count":{"type":"integer"},"skills":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-018'
ON CONFLICT (agent_id, version) DO NOTHING;

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Aucun SQL arbitraire, aucune modification RLS, aucune action mutante — strictement en lecture. Pas de "search admin docs"/"job status" : aucune infra de recherche documentaire ni de file de jobs n''existe sur ce projet, honnêtement omis plutôt que simulé.',
    catalogue_relation = 'Correspond à AIA-AGT-021 du catalogue officiel (§7). Construit (2026-09-06) : synthèse ai_agent_calls (échecs)/support_tickets (ouverts par catégorie)/validation_queue (en attente) — inexistante comme vue unique ailleurs dans admin_app.',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-021';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","properties":{"failure_limit":{"type":"integer"}}}'::jsonb,
    '{"type":"object","properties":{"recent_ai_failures":{"type":"array"},"open_support_tickets_by_category":{"type":"object"},"pending_content_validation":{"type":"integer"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-021'
ON CONFLICT (agent_id, version) DO NOTHING;

UPDATE ai_agents SET
    status = 'active',
    non_mission = 'Signal ≠ preuve : jamais de sanction automatique. Un seul signal construit (partage d''appareil) — aucun signal de paiement/examen inventé sans volume réel pour le calibrer honnêtement. Réservé aux rôles super_admin/admin_pays (données sensibles impliquant des comptes précis).',
    catalogue_relation = 'Correspond à AIA-AGT-025 du catalogue officiel (§7). Construit (2026-09-06) : sessions.device_fingerprint (migration 01, "anti-partage de compte" déjà prévu par le schéma).',
    updated_at = NOW()
WHERE agent_id = 'AIA-AGT-025';

INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT id, '1.0.0',
    '{"type":"object","properties":{"limit":{"type":"integer"}}}'::jsonb,
    '{"type":"object","properties":{"signals":{"type":"array"}}}'::jsonb,
    '{"preferred":[],"fallback":[],"mock_available":false}'::jsonb,
    'standard', 'production', 'gateway_native'
FROM ai_agents WHERE agent_id = 'AIA-AGT-025'
ON CONFLICT (agent_id, version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
