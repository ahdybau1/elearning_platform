-- Permet d'attacher des documents (PDF, Word, image, notes LaTeX...) à l'introduction d'un
-- chapitre, pas seulement du texte brut — même infrastructure d'upload que les médias de leçon
-- (bucket "media", table media_library), juste référencée depuis les chapitres.
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS intro_media_json JSONB DEFAULT '[]'::jsonb;
