-- Exam Resource Factory — Tranche 1 (voir docs/CAHIER_IA_ZERO_COUT_MASTER.md, Annexe D.8-D.9).
-- Jusqu'ici, un sujet d'examen (national ou d'établissement) n'est qu'un fichier PDF plat
-- (document_url/correction_url) — jamais parsé, jamais interactif. Cette migration ajoute la
-- structure nécessaire pour que l'IA (OCR vision Gemini) découpe un sujet en questions révisables
-- par un admin avant publication, sans toucher au comportement existant (un sujet non traité reste
-- affiché exactement comme avant côté élève).

CREATE TABLE IF NOT EXISTS exam_paper_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Exactement un des deux parents : un sujet national OU un sujet d'établissement, jamais les deux
    -- (voir contrainte exam_paper_questions_one_parent ci-dessous).
    exam_paper_id UUID REFERENCES exam_papers(id) ON DELETE CASCADE,
    establishment_paper_id UUID REFERENCES establishment_papers(id) ON DELETE CASCADE,
    question_order INT NOT NULL,
    statement TEXT NOT NULL,              -- énoncé transcrit par l'OCR vision Gemini
    proposed_answer TEXT,                 -- corrigé proposé par l'IA (distinct d'un corrigé officiel humain)
    confidence NUMERIC(3,2),              -- confiance de transcription/correction déclarée par le modèle
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft','waiting_review','needs_changes','approved')),
    reviewer_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT exam_paper_questions_one_parent CHECK (
        (exam_paper_id IS NOT NULL AND establishment_paper_id IS NULL) OR
        (exam_paper_id IS NULL AND establishment_paper_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_exam_paper_questions_exam_paper ON exam_paper_questions(exam_paper_id);
CREATE INDEX IF NOT EXISTS idx_exam_paper_questions_establishment_paper ON exam_paper_questions(establishment_paper_id);

ALTER TABLE exam_papers ADD COLUMN IF NOT EXISTS processing_status TEXT NOT NULL DEFAULT 'not_started'
    CHECK (processing_status IN ('not_started','processing','waiting_review','published','failed'));
ALTER TABLE establishment_papers ADD COLUMN IF NOT EXISTS processing_status TEXT NOT NULL DEFAULT 'not_started'
    CHECK (processing_status IN ('not_started','processing','waiting_review','published','failed'));

-- RLS : réservé à l'admin dans cette tranche (rien n'est publié côté élève ici — voir contexte du plan).
ALTER TABLE exam_paper_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS exam_paper_questions_admin_select ON exam_paper_questions;
CREATE POLICY exam_paper_questions_admin_select ON exam_paper_questions FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS exam_paper_questions_admin_write ON exam_paper_questions;
CREATE POLICY exam_paper_questions_admin_write ON exam_paper_questions FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS exam_paper_questions_admin_update ON exam_paper_questions;
CREATE POLICY exam_paper_questions_admin_update ON exam_paper_questions FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS exam_paper_questions_admin_delete ON exam_paper_questions;
CREATE POLICY exam_paper_questions_admin_delete ON exam_paper_questions FOR DELETE USING (is_admin_user());

NOTIFY pgrst, 'reload schema';
