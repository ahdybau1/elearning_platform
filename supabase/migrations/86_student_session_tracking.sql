-- CDC Partie 1 §7.4 : « session unique stricte » — la fonction enforce_single_session() (migration
-- 31) et son trigger AFTER INSERT existent déjà et fonctionnent, mais `sessions` n'a jamais eu de
-- politique INSERT (vérifié : seules `sessions_select`/`sessions_update` existent) et
-- student_app n'écrit jamais dans cette table au login (vérifié : aucune occurrence dans
-- student_app/lib). Le mécanisme n'a donc jamais pu se déclencher pour un élève. Cette migration
-- comble la seule pièce manquante côté base ; le reste (écrire réellement la ligne, réagir à son
-- désactivation) est côté Flutter.

CREATE POLICY sessions_insert ON sessions
    FOR INSERT WITH CHECK (owns_account(account_id));

CREATE INDEX IF NOT EXISTS idx_sessions_account_active ON sessions (account_id, is_active, created_at DESC);

-- Détection temps réel de l'éviction (rejoué en repli par un nouveau contrôle ponctuel à chaque
-- retour au premier plan de l'app, car Realtime peut se couper pendant la mise en veille d'un
-- onglet web). Idempotent : ne rééchoue pas si déjà ajoutée par une exécution précédente.
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

NOTIFY pgrst, 'reload schema';
