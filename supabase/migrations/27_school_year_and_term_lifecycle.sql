-- ============================================================================
-- Cycle de vie complet pour Années Scolaires et Trimestres
-- ============================================================================
-- Audit de l'écran "Année & Campagne Passage" (page-by-page rigor pass) : ni `school_years` ni
-- `terms` n'avaient de colonne `is_active`, et aucune fonction de mise à jour n'existait pour l'un
-- ou l'autre — seule la création était possible (createSchoolYear/createTerm), sans aucun moyen de
-- corriger une erreur de saisie ou de retirer un trimestre/une année obsolète. L'utilisateur a
-- explicitement signalé ce manque : "on fait comment pour les trimestres, on fait comment pour les
-- archivage, modif, etc".

ALTER TABLE terms ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE school_years ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
