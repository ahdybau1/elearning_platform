-- Migration 42: Accès réel d'un parent authentifié aux profils qui lui sont liés (CDC §17)
--
-- L'app élève n'a jamais utilisé la session parent_accounts.auth_user_id posée par la migration 11 —
-- l'« Espace Parent » était un simple PIN codé en dur sur la session ÉLÈVE. Deux bugs bloquaient même
-- un vrai parent authentifié : (1) parent_profile_links_select ne laissait lire un lien qu'au profil
-- élève lui-même ou à un admin, jamais au parent propriétaire du lien ; (2) aucune policy ne laissait
-- un parent lire profiles/subscriptions/transactions des profils qui lui sont liés.
--
-- is_active est vérifié explicitement : sans ça, suspendre un compte parent (migration 32) resterait
-- cosmétique — il garderait un accès complet aux données de ses enfants.
--
-- Rejouable sans erreur.

CREATE OR REPLACE FUNCTION is_linked_parent_of_profile(p_profile_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM parent_profile_links pl
        JOIN parent_accounts pa ON pa.id = pl.parent_account_id
        WHERE pl.profile_id = p_profile_id
          AND pa.auth_user_id = auth.uid()
          AND pa.is_active = true
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

DROP POLICY IF EXISTS parent_profile_links_select ON parent_profile_links;
CREATE POLICY parent_profile_links_select ON parent_profile_links FOR SELECT USING (
    owns_profile(profile_id)
    OR parent_account_id IN (SELECT id FROM parent_accounts WHERE auth_user_id = auth.uid() AND is_active = true)
    OR is_admin_user()
);

DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles FOR SELECT USING (
    owns_profile(id) OR is_linked_parent_of_profile(id) OR is_admin_user()
);

DROP POLICY IF EXISTS subscriptions_select ON subscriptions;
CREATE POLICY subscriptions_select ON subscriptions FOR SELECT USING (
    owns_profile(profile_id) OR is_linked_parent_of_profile(profile_id) OR is_admin_user()
);

DROP POLICY IF EXISTS transactions_select ON transactions;
CREATE POLICY transactions_select ON transactions FOR SELECT USING (
    owns_profile(profile_id) OR is_linked_parent_of_profile(profile_id) OR has_admin_role('super_admin')
);

-- Bug pré-existant relevé en même temps (migration 32 a ajouté is_active mais jamais mis à jour cette
-- policy) : un parent suspendu pouvait toujours lire sa propre ligne parent_accounts.
DROP POLICY IF EXISTS parent_accounts_select ON parent_accounts;
CREATE POLICY parent_accounts_select ON parent_accounts FOR SELECT USING (
    (auth_user_id = auth.uid() AND is_active = true) OR is_admin_user()
);
