-- WP1 (contenus) — Ordre d'affichage des exercices (consigne #2 : « classement et réorganisation »).
-- Additif pur. `chapters` et `lessons` ont déjà `display_order` ; `exercises` ne l'avait pas (le
-- modèle Dart Exercise ne l'exposait pas non plus). Backfill par ancienneté, groupé par
-- chapitre + trimestre (le même regroupement que l'UI « dossiers par trimestre »).

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0;

WITH ord AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY COALESCE(chapter_id::text, ''), COALESCE(term_id::text, '')
               ORDER BY created_at
           ) AS rn
    FROM exercises
    WHERE display_order = 0
)
UPDATE exercises e
SET display_order = ord.rn
FROM ord
WHERE ord.id = e.id;

CREATE INDEX IF NOT EXISTS idx_exercises_order ON exercises (chapter_id, term_id, display_order);
