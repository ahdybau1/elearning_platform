-- Migration 49 : un compte ne peut pas suivre deux fois la même classe (§2.3 du CDC)
--
-- Rien n'empêchait jusqu'ici de créer deux profils identiques (même account_id + même
-- class_node_id) — confirmé par l'utilisateur : « quelqu'un ne peut pas ajouter une classe
-- n'importe comment ». Si la classe est déjà suivie (active OU archivée), il faut la réactiver
-- depuis Mon Profil plutôt qu'en créer un doublon.
--
-- Rejouable sans erreur (idempotent via IF NOT EXISTS côté application).

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_account_class_unique'
    ) THEN
        ALTER TABLE profiles
            ADD CONSTRAINT profiles_account_class_unique UNIQUE (account_id, class_node_id);
    END IF;
END $$;
