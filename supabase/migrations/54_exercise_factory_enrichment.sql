-- CF-003 enrichissement (docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md) : rapproche `exercises` du
-- schéma cible U2.4 (hints/skills/prerequisites/provenance) sans casser l'existant. Choix délibéré :
-- `skills`/`prerequisites` en tags texte libre (TEXT[]) plutôt qu'une taxonomie de compétences figée
-- avec table de référence — une vraie taxonomie/Competency Graph (U9 du cahier) est un chantier séparé
-- qui mérite d'être conçu avec l'équipe pédagogique, pas inventé ici. Les tags restent migrables vers
-- une taxonomie stricte plus tard sans perte de données.
--
-- `hints` (indices progressifs) n'a volontairement PAS de nouvelle colonne : ce sont des contenus
-- pédagogiques destinés à l'élève au même titre que l'énoncé, donc rangés dans
-- `instructions_json['hints']` — cohérent avec 'statement'/'options'/'media' déjà présents là.
--
-- Purement additif : nouvelles colonnes nullables/par défaut, aucune ligne existante affectée.

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS skills TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS prerequisites TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS provenance TEXT NOT NULL DEFAULT 'manual';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'exercises_provenance_check'
    ) THEN
        ALTER TABLE exercises
            ADD CONSTRAINT exercises_provenance_check CHECK (provenance IN ('manual', 'ai_generated', 'imported'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_exercises_skills ON exercises USING GIN (skills);
