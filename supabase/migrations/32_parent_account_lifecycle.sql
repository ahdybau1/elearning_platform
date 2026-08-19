-- CDC §5.3 : "Rechercher, voir les profils liés, modifier/suspendre/réactiver/supprimer" — la page Comptes
-- Parents ne proposait que Créer et Rattacher un élève, sans aucun cycle de vie du compte lui-même
-- (contrairement à `accounts`/`profiles`, `parent_accounts` n'avait même pas de colonne `is_active`).

ALTER TABLE parent_accounts ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
