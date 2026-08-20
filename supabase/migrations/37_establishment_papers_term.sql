-- Retour utilisateur : les épreuves d'établissement (devoirs/compositions internes) sont, dans la
-- réalité d'un établissement, données par trimestre — contrairement aux examens officiels nationaux
-- (BEPC/Probatoire/Bac) qui n'ont lieu qu'une fois par an et pour lesquels le trimestre n'a pas de sens.
-- Nullable : une épreuve existante ou un cas "hors trimestre" (ex : synthèse annuelle) reste possible.
ALTER TABLE establishment_papers ADD COLUMN IF NOT EXISTS term_id UUID REFERENCES terms(id) ON DELETE SET NULL;
