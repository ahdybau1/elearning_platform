-- IA-001 "Contracts" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : premier work package de la couche
-- Agents IA telle que l'ordre du cahier l'impose — IA-000 (audit) est fait (docs/AUDIT_REPORT.md),
-- ceci est IA-001 : registre d'agents, contrats de tools, schéma de capability. PAS encore de
-- Sovereign AI Gateway FastAPI (IA-002+) : ces tables décrivent/versionnent les agents, elles ne
-- remplacent aucune fonction Deno existante et n'exigent aucune nouvelle infrastructure.
--
-- Conforme au modèle conceptuel §17 du cahier (ai_agents, ai_agent_versions, ai_tools,
-- ai_agent_tools font partie des 24 tables cibles listées là-bas). Additif pur.

CREATE TABLE IF NOT EXISTS ai_agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Identifiant stable de l'agent. Reprend l'ID officiel AIA-AGT-0XX du catalogue (§7 du cahier)
    -- quand une correspondance réelle et honnête existe ; sinon un slug propre à l'implémentation
    -- réelle (ex: 'catalog_generation', 'course_structuring') — jamais un ID AIA-AGT-0XX inventé
    -- pour un agent qui ne correspond pas vraiment à une entrée du catalogue officiel.
    agent_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    mission TEXT NOT NULL,
    non_mission TEXT,
    catalogue_relation TEXT, -- note honnête de correspondance/écart avec le catalogue des 26 agents
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'deprecated')),
    owner TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_agent_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID NOT NULL REFERENCES ai_agents(id) ON DELETE CASCADE,
    version TEXT NOT NULL,
    input_schema JSONB NOT NULL,
    output_schema JSONB NOT NULL,
    model_policy JSONB DEFAULT '{}'::jsonb, -- {"preferred": [...], "fallback": [...]}
    quota_class TEXT NOT NULL DEFAULT 'standard',
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'candidate', 'production', 'retired')),
    -- Lien vers l'implémentation réelle aujourd'hui : le nom de l'Edge Function Deno qui exécute
    -- effectivement cet agent (pas de LangGraph/FastAPI tant qu'IA-002+ n'est pas fait).
    edge_function_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (agent_id, version)
);

CREATE TABLE IF NOT EXISTS ai_tools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tool_key TEXT UNIQUE NOT NULL,
    description TEXT,
    input_schema JSONB,
    output_schema JSONB,
    timeout_ms INT NOT NULL DEFAULT 10000,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_agent_tools (
    agent_version_id UUID NOT NULL REFERENCES ai_agent_versions(id) ON DELETE CASCADE,
    tool_id UUID NOT NULL REFERENCES ai_tools(id) ON DELETE CASCADE,
    PRIMARY KEY (agent_version_id, tool_id)
);

-- RLS : lecture par tout admin actif (registre = information de pilotage, pas une donnée
-- financière — cf. la restriction stricte séparée déjà en place pour les tables financières),
-- écriture réservée super_admin tant que les rôles fins IA (AI_ADMIN, AI_ENGINEER — U8 du cahier)
-- n'existent pas encore dans admin_users.role.
ALTER TABLE ai_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_agent_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_agent_tools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_agents_select ON ai_agents;
CREATE POLICY ai_agents_select ON ai_agents FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_agents_write ON ai_agents;
CREATE POLICY ai_agents_write ON ai_agents FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_agent_versions_select ON ai_agent_versions;
CREATE POLICY ai_agent_versions_select ON ai_agent_versions FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_agent_versions_write ON ai_agent_versions;
CREATE POLICY ai_agent_versions_write ON ai_agent_versions FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_tools_select ON ai_tools;
CREATE POLICY ai_tools_select ON ai_tools FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_tools_write ON ai_tools;
CREATE POLICY ai_tools_write ON ai_tools FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_agent_tools_select ON ai_agent_tools;
CREATE POLICY ai_agent_tools_select ON ai_agent_tools FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_agent_tools_write ON ai_agent_tools;
CREATE POLICY ai_agent_tools_write ON ai_agent_tools FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

-- Seed : les 5 agents RÉELLEMENT déployés aujourd'hui (voir docs/AUDIT_REPORT.md), avec leur
-- véritable mission (reprise de leur prompt système réel, pas inventée) et leur vraie
-- correspondance — ou son absence honnête — avec le catalogue officiel des 26 agents.
INSERT INTO ai_agents (agent_id, name, mission, non_mission, catalogue_relation, status, owner) VALUES
(
    'AIA-AGT-001',
    'TutorAgent (Tuteur Numérique)',
    'Tutorat conversationnel maïeutique pour l''élève : guide pas à pas sans donner directement la solution finale, reste dans le programme officiel de sa classe, explique le "pourquoi" des erreurs.',
    'Ne calcule pas de note officielle, ne remplace pas un enseignant, ne bloque pas totalement le hors-programme.',
    'Correspond à AIA-AGT-001 du catalogue officiel (§7). Version actuelle sans RAG ni Student Model read ni tools (sympy_solve, etc.) — voir input_schema/model_policy de la version enregistrée.',
    'active',
    'edge_function:ai-tutor-chat'
),
(
    'AIA-AGT-004',
    'ExerciseAgent (Génération d''Exercices)',
    'Générer des exercices alignés sur compétences/difficulté/format/curriculum, avec corrigé pas-à-pas justifié, indices progressifs et compétences mobilisées taguées.',
    'Ne publie jamais directement (passe par validation_queue) ; ne calcule pas de barème réel (aucun barème n''existe encore en base).',
    'Correspond à AIA-AGT-004 du catalogue officiel (§7).',
    'active',
    'edge_function:ai-exercise-generation'
),
(
    'course_structuring',
    'Course Generator (Structuration de Cours)',
    'Générer un cours structuré (sections typées théorème/définition/formule/méthode/exemple, pièges classiques, conseils d''examen, quiz) à partir de notes brutes et du catalogue pédagogique de la matière.',
    'Ne publie jamais directement ; n''importe pas de document existant (voir non_mission de DocumentStructuringAgent, plus proche mais différent).',
    'Pas d''ID officiel dans le catalogue des 26 : c''est un "Course Generator" au sens du cahier technique Content Factory (§7), distinct de DocumentStructuringAgent (AIA-AGT-016, qui structure une source IMPORTÉE, pas générée à partir de notes). Ne pas confondre les deux dans un futur mapping.',
    'active',
    'edge_function:ai-course-structuring'
),
(
    'catalog_generation',
    'Catalog Type Generator',
    'Proposer des types d''éléments pédagogiques (théorème, définition, protocole...) pour une matière donnée, en few-shot sur des exemples déjà validés — alimente le catalogue §16.0 utilisé par les autres agents de génération.',
    'Ne modifie jamais le catalogue existant sans validation admin explicite.',
    'Pas d''ID officiel dans le catalogue des 26 : outil de configuration du Content Factory (§16.0), pas un agent pédagogique au sens strict.',
    'active',
    'edge_function:ai-catalog-types-generation'
),
(
    'AIA-AGT-020',
    'ModerationAgent',
    'Détecter et prioriser les contenus de forum potentiellement contraires aux règles (filtre regex local d''abord, puis Gemini pour les contournements orthographiques), masquer automatiquement en attendant revue humaine.',
    'Ne prononce jamais de sanction lourde automatiquement — la décision finale reste humaine (modérateur).',
    'Correspond à AIA-AGT-020 du catalogue officiel (§7).',
    'active',
    'edge_function:ai-moderation'
)
ON CONFLICT (agent_id) DO NOTHING;

-- Versions : le VRAI contrat d'entrée/sortie de chaque Edge Function déployée aujourd'hui (relu
-- directement dans supabase/functions/*/index.ts, pas inventé), pas encore l'enveloppe standard
-- complète du §4 du cahier (citations/tool_trace_summary/safety n'existent pas encore réellement).
-- model_policy documente le vrai ordre de repli Claude -> Gemini -> mock déjà en place.
INSERT INTO ai_agent_versions (agent_id, version, input_schema, output_schema, model_policy, quota_class, status, edge_function_name)
SELECT a.id, '1.0.0',
    input_schema, output_schema, model_policy, quota_class, 'production', edge_function_name
FROM ai_agents a
JOIN (VALUES
    ('AIA-AGT-001',
     '{"type":"object","required":["message"],"properties":{"message":{"type":"string"},"subject_name":{"type":"string"},"class_name":{"type":"string"},"history":{"type":"array","items":{"type":"object","properties":{"sender":{"type":"string"},"text":{"type":"string"}}}}}}'::jsonb,
     '{"type":"object","properties":{"reply":{"type":"string"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":"string"},"_duration_ms":{"type":"integer"}}}'::jsonb,
     '{"preferred":["gemini-3.6-flash"],"fallback":[],"mock_available":false}'::jsonb,
     'standard', 'ai-tutor-chat'),
    ('AIA-AGT-004',
     '{"type":"object","properties":{"subject_id":{"type":"string"},"chapter_id":{"type":"string"},"type":{"type":"string"},"difficulty":{"type":"string"},"format":{"type":"string"},"count":{"type":"integer","minimum":1,"maximum":20},"raw_notes":{"type":"string"},"prompt_directives":{"type":"string"}}}'::jsonb,
     '{"type":"object","properties":{"exercises":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"statement":{"type":"string"},"correction":{"type":"string"},"options":{"type":["array","null"]},"correct_index":{"type":["integer","null"]},"hints":{"type":"array","items":{"type":"string"}},"skills":{"type":"array","items":{"type":"string"}}}}},"_mock":{"type":"boolean"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":["string","null"]},"_duration_ms":{"type":"integer"}}}'::jsonb,
     '{"preferred":["claude-3-5-sonnet-20241022"],"fallback":["gemini-1.5-flash"],"mock_available":true}'::jsonb,
     'standard', 'ai-exercise-generation'),
    ('course_structuring',
     '{"type":"object","properties":{"chapter_id":{"type":"string"},"subject_id":{"type":"string"},"raw_notes":{"type":"string"},"prompt_directives":{"type":"string"}}}'::jsonb,
     '{"type":"object","properties":{"title":{"type":"string"},"summary":{"type":"string"},"sections":{"type":"array","items":{"type":"object","properties":{"heading":{"type":"string"},"type":{"type":"string"},"body":{"type":"string"},"latex_formulas":{"type":"array","items":{"type":"string"}}}}},"common_traps":{"type":"array","items":{"type":"string"}},"exam_tips":{"type":"array","items":{"type":"string"}},"quiz_questions":{"type":"array"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":["string","null"]},"_duration_ms":{"type":"integer"}}}'::jsonb,
     '{"preferred":["claude-3-5-sonnet-20241022"],"fallback":["gemini-1.5-flash"],"mock_available":true}'::jsonb,
     'standard', 'ai-course-structuring'),
    ('catalog_generation',
     '{"type":"object","required":["subject_name"],"properties":{"subject_id":{"type":"string"},"subject_name":{"type":"string"},"education_level":{"type":"string"},"count":{"type":"integer"},"raw_notes":{"type":"string"}}}'::jsonb,
     '{"type":"object","properties":{"types":{"type":"array","items":{"type":"object","properties":{"element_type":{"type":"string"},"description":{"type":"string"}}}},"_mock":{"type":"boolean"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_model":{"type":["string","null"]},"_duration_ms":{"type":"integer"}}}'::jsonb,
     '{"preferred":["claude-3-5-sonnet-20241022"],"fallback":["gemini-1.5-flash"],"mock_available":true}'::jsonb,
     'standard', 'ai-catalog-types-generation'),
    ('AIA-AGT-020',
     '{"type":"object","properties":{"post_id":{"type":"string"},"content":{"type":"string"},"image_url":{"type":"string"}}}'::jsonb,
     '{"type":"object","properties":{"approved":{"type":"boolean"},"flagged":{"type":"boolean"},"reason":{"type":"string"},"_request_id":{"type":"string"},"_agent_version":{"type":"string"},"_duration_ms":{"type":"integer"}}}'::jsonb,
     '{"preferred":["gemini-1.5-flash"],"fallback":["local_regex"],"mock_available":false}'::jsonb,
     'low', 'ai-moderation')
) AS v(agent_id, input_schema, output_schema, model_policy, quota_class, edge_function_name)
ON v.agent_id = a.agent_id
ON CONFLICT (agent_id, version) DO NOTHING;
