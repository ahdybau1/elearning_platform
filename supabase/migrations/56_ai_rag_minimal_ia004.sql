-- IA-004 "RAG minimal" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22 et §10) : sources validées,
-- ingestion, pgvector, filtres curriculum/permission, citations. Schéma seulement dans cette
-- migration — le pipeline d'ingestion réel (Edge Function, choix du provider d'embeddings) est un
-- travail séparé, volontairement non fait ici pour ne pas se précipiter dessus.
--
-- Point important vérifié en relisant docs/CAHIER_TECHNIQUE_FRAMEWORKS_OUTILS_IA.md avant de
-- commencer (le porteur de projet a explicitement demandé de toujours consulter les cahiers) :
-- « Vecteurs RAG | PostgreSQL + pgvector | ... | défaut souverain ». pgvector est une extension
-- PostgreSQL standard, déjà disponible sur ce projet Supabase (vérifié : pg_available_extensions,
-- version 0.8.2) — contrairement à l'Agent Orchestrator (LangGraph)/aux modèles auto-hébergés
-- (vLLM/Ollama), le stockage RAG ne nécessite AUCUNE nouvelle infrastructure hors Supabase.

CREATE EXTENSION IF NOT EXISTS vector;

-- Une source validée (§10 : "documents non fiables isolés"). Peut pointer vers un contenu déjà
-- canonique (leçon publiée, sujet d'examen...) pour ne jamais dupliquer, ou vers un import dédié.
CREATE TABLE IF NOT EXISTS ai_rag_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('lesson', 'exercise', 'exam_paper', 'establishment_paper', 'manual_upload')),
    source_ref_table TEXT, -- ex: 'lessons' — nullable pour un manual_upload sans entité source
    source_ref_id UUID,
    -- Portée curriculum obligatoire : c'est ce qui permet le filtrage RLS/retrieval par classe et
    -- empêche qu'un chunk d'une classe fuite vers le RAG d'une autre (§10 du cahier).
    class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    -- Une source est un draft tant qu'aucun admin ne l'a marquée validée — jamais indexée avant.
    validated BOOLEAN NOT NULL DEFAULT FALSE,
    validated_by UUID REFERENCES admin_users(id),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Une exécution d'ingestion (peut échouer, être relancée — voir "réindexation contrôlée et
-- observable" au §10). Plusieurs ingestions possibles pour une même source (nouvelle version).
CREATE TABLE IF NOT EXISTS ai_rag_ingestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID NOT NULL REFERENCES ai_rag_sources(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    embedding_provider TEXT, -- ex: 'gemini-text-embedding-004' — traçabilité, pas de valeur par défaut supposée
    chunk_count INT NOT NULL DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Dimension 768 : celle du modèle d'embeddings Gemini (text-embedding-004), déjà le seul provider
-- réellement intégré et gratuit sur ce projet (GEMINI_API_KEY déjà configurée en production — voir
-- ai-tutor-chat). Choix pragmatique et réversible par migration future si le provider change, pas
-- un verrouillage définitif.
CREATE TABLE IF NOT EXISTS ai_rag_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ingestion_id UUID NOT NULL REFERENCES ai_rag_ingestions(id) ON DELETE CASCADE,
    source_id UUID NOT NULL REFERENCES ai_rag_sources(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(768),
    -- Dénormalisé depuis ai_rag_sources pour un filtre retrieval direct sans jointure sur le chemin
    -- chaud (§10 : "retrieval filtré").
    class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_rag_chunks_embedding ON ai_rag_chunks
    USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_ai_rag_chunks_scope ON ai_rag_chunks (class_node_id, subject_id);

-- RLS : ces tables ne sont interrogées aujourd'hui par aucun client élève direct (le retrieval, une
-- fois construit, passera par une Edge Function avec la clé service_role — comme les autres agents
-- IA). Accès direct réservé aux admins, écriture réservée super_admin, même politique que le
-- registre d'agents (migration 55) tant que les rôles fins IA n'existent pas.
ALTER TABLE ai_rag_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_rag_ingestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_rag_chunks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_rag_sources_select ON ai_rag_sources;
CREATE POLICY ai_rag_sources_select ON ai_rag_sources FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_rag_sources_write ON ai_rag_sources;
CREATE POLICY ai_rag_sources_write ON ai_rag_sources FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_rag_ingestions_select ON ai_rag_ingestions;
CREATE POLICY ai_rag_ingestions_select ON ai_rag_ingestions FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_rag_ingestions_write ON ai_rag_ingestions;
CREATE POLICY ai_rag_ingestions_write ON ai_rag_ingestions FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_rag_chunks_select ON ai_rag_chunks;
CREATE POLICY ai_rag_chunks_select ON ai_rag_chunks FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_rag_chunks_write ON ai_rag_chunks;
CREATE POLICY ai_rag_chunks_write ON ai_rag_chunks FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));
