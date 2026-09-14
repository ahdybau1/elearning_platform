-- WP3 — CENTRE SOURCES & INGESTION (consigne #6 : « terminer le scraping et l'ingestion des
-- ressources »). Additif pur. Étend `ai_rag_sources` / `ai_rag_ingestions` (migration 56) et ajoute
-- une file de jobs générique (`ai_ingestion_jobs`) + les documents extraits en attente de revue
-- humaine (`ai_extracted_documents`).
--
-- Traitement en arrière-plan = pg_cron (déjà actif) qui avance le chemin déterministe (texte collé)
-- + une Edge Function worker (`ingestion-worker`) déclenchée depuis l'admin pour le chemin URL /
-- classification / embeddings (non bloquant, progression et reprise portées par la ligne de job).
-- OCR d'images/PDF scannés : hors périmètre coût zéro (aucun moteur vision auto-hébergé déployé) —
-- exposé explicitement « indisponible », jamais simulé.

-- ─────────────────────────────────────────────────────────────────────
-- 1. ai_rag_sources : élargir les types + métadonnées de collecte
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE ai_rag_sources DROP CONSTRAINT IF EXISTS ai_rag_sources_source_type_check;
ALTER TABLE ai_rag_sources ADD CONSTRAINT ai_rag_sources_source_type_check
    CHECK (source_type IN ('lesson', 'exercise', 'exam_paper', 'establishment_paper',
                           'manual_upload', 'url', 'document'));

ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS raw_text TEXT;               -- texte collé (manual_upload)
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS crawl_rules JSONB NOT NULL DEFAULT '{}'::jsonb;
    -- { include: [str], exclude: [str], max_depth: int, max_pages: int }
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS schedule TEXT;              -- expression cron, NULL = manuel
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS access_terms_ack BOOLEAN NOT NULL DEFAULT FALSE;
    -- l'admin atteste avoir vérifié robots.txt / conditions d'utilisation avant collecte
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS provenance TEXT;
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS collected_at TIMESTAMPTZ;
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'paused', 'archived'));
ALTER TABLE ai_rag_sources ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES admin_users(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────────────
-- 2. ai_ingestion_jobs : file de jobs générique (progression, reprise, annulation)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID NOT NULL REFERENCES ai_rag_sources(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL CHECK (job_type IN ('extract', 'crawl', 'classify', 'embed')),
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running', 'paused', 'failed', 'done', 'cancelled')),
    progress_pct INT NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    error_history JSONB NOT NULL DEFAULT '[]'::jsonb,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    result JSONB NOT NULL DEFAULT '{}'::jsonb,
    cancel_requested BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ai_ingestion_jobs_status ON ai_ingestion_jobs (status, created_at);
CREATE INDEX IF NOT EXISTS idx_ai_ingestion_jobs_source ON ai_ingestion_jobs (source_id);

-- ─────────────────────────────────────────────────────────────────────
-- 3. ai_extracted_documents : sortie d'extraction en attente de revue humaine
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_extracted_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID NOT NULL REFERENCES ai_rag_sources(id) ON DELETE CASCADE,
    job_id UUID REFERENCES ai_ingestion_jobs(id) ON DELETE SET NULL,
    title TEXT,
    extracted_text TEXT NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,          -- { url, word_count, fetched_at, http_status, ... }
    content_hash TEXT,                                     -- empreinte de déduplication
    is_duplicate BOOLEAN NOT NULL DEFAULT FALSE,
    duplicate_of UUID REFERENCES ai_extracted_documents(id) ON DELETE SET NULL,
    -- Classement pédagogique proposé (issu de ai-curriculum-mapping) — jamais appliqué sans revue.
    classification JSONB NOT NULL DEFAULT '{}'::jsonb,
    proposed_class_node_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    proposed_subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    proposed_chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    review_status TEXT NOT NULL DEFAULT 'preview'
        CHECK (review_status IN ('preview', 'validated', 'rejected')),
    reviewed_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_extracted_docs_source ON ai_extracted_documents (source_id);
CREATE INDEX IF NOT EXISTS idx_ai_extracted_docs_hash ON ai_extracted_documents (content_hash);
CREATE INDEX IF NOT EXISTS idx_ai_extracted_docs_review ON ai_extracted_documents (review_status);

-- ─────────────────────────────────────────────────────────────────────
-- 4. RLS — lecture tout admin, écriture super_admin (aligné migrations 55/56).
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE ai_ingestion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_extracted_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_ingestion_jobs_select ON ai_ingestion_jobs;
CREATE POLICY ai_ingestion_jobs_select ON ai_ingestion_jobs FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_ingestion_jobs_write ON ai_ingestion_jobs;
CREATE POLICY ai_ingestion_jobs_write ON ai_ingestion_jobs FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_extracted_documents_select ON ai_extracted_documents;
CREATE POLICY ai_extracted_documents_select ON ai_extracted_documents FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_extracted_documents_write ON ai_extracted_documents;
CREATE POLICY ai_extracted_documents_write ON ai_extracted_documents FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

-- ─────────────────────────────────────────────────────────────────────
-- 5. Chemin déterministe en arrière-plan (texte collé) : pg_cron pur SQL, sans appel externe.
--    Normalise le texte, calcule l'empreinte, détecte les doublons, crée l'extrait en 'preview'.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION advance_ingestion_queue() RETURNS INT AS $$
DECLARE
    j RECORD;
    v_src RECORD;
    v_text TEXT;
    v_hash TEXT;
    v_dup UUID;
    v_processed INT := 0;
BEGIN
    FOR j IN
        SELECT * FROM ai_ingestion_jobs
        WHERE status = 'queued' AND job_type = 'extract' AND NOT cancel_requested
        ORDER BY created_at
        LIMIT 20
    LOOP
        SELECT * INTO v_src FROM ai_rag_sources WHERE id = j.source_id;
        -- Seul le texte déjà présent (collé) est traité ici ; URL / document = worker Edge.
        IF v_src.source_type NOT IN ('manual_upload', 'document')
           OR COALESCE(v_src.raw_text, '') = '' THEN
            CONTINUE;
        END IF;

        UPDATE ai_ingestion_jobs
        SET status = 'running', started_at = NOW(), updated_at = NOW(), attempts = attempts + 1
        WHERE id = j.id;

        -- Normalisation simple : compaction des espaces/lignes vides multiples.
        v_text := regexp_replace(v_src.raw_text, E'[ \\t]+', ' ', 'g');
        v_text := regexp_replace(v_text, E'\\n{3,}', E'\\n\\n', 'g');
        v_text := btrim(v_text);
        v_hash := md5(v_text);

        SELECT id INTO v_dup FROM ai_extracted_documents
        WHERE content_hash = v_hash AND source_id <> j.source_id
        LIMIT 1;

        INSERT INTO ai_extracted_documents
            (source_id, job_id, title, extracted_text, metadata, content_hash, is_duplicate, duplicate_of)
        VALUES (
            j.source_id, j.id, COALESCE(v_src.title, 'Document collé'),
            v_text,
            jsonb_build_object('word_count', array_length(regexp_split_to_array(v_text, E'\\s+'), 1),
                               'method', 'paste', 'processed_at', NOW()),
            v_hash, v_dup IS NOT NULL, v_dup
        );

        UPDATE ai_ingestion_jobs
        SET status = 'done', progress_pct = 100, finished_at = NOW(), updated_at = NOW(),
            result = jsonb_build_object('extracted', 1, 'duplicate', v_dup IS NOT NULL)
        WHERE id = j.id;

        UPDATE ai_rag_sources SET collected_at = NOW() WHERE id = j.source_id;
        v_processed := v_processed + 1;
    END LOOP;
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Planification : toutes les 2 minutes. (Le worker Edge gère URL/classify/embed sur déclenchement.)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-ingestion-queue') THEN
        PERFORM cron.schedule('process-ingestion-queue', '*/2 * * * *',
                              'SELECT advance_ingestion_queue();');
    END IF;
END $$;
