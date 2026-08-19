-- La table `subjects` n'avait pas de colonne is_active, contrairement à toutes les autres entités
-- pédagogiques (chapters, lessons, exercises...) qui suivent le pattern "archiver, jamais
-- supprimer" (voir 16_exercises_archive.sql). Sans elle la seule action possible sur une matière
-- obsolète était sa suppression physique, qui casserait en cascade chapters/exam_papers/
-- establishment_papers/shop_documents/content_catalog/forum_threads (toutes référencées par
-- subjects.id).
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- Symétrique de chapters_select/lessons_select : une matière archivée ne doit plus apparaître
-- côté app élève, seuls les admins la voient encore (pour pouvoir la réactiver).
DROP POLICY IF EXISTS subjects_select ON subjects;
CREATE POLICY subjects_select ON subjects FOR SELECT USING (is_active = true OR is_admin_user());
