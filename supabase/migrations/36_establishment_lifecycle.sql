-- Section 4.1 du CDC : "Créer/modifier/désactiver un établissement" — la table n'a jamais eu de colonne
-- pour porter cet état, cohérent avec le vocabulaire "Archiver/Désarchiver" déjà unifié partout ailleurs
-- dans l'admin (jamais "Désactiver" seul).
ALTER TABLE establishments ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
