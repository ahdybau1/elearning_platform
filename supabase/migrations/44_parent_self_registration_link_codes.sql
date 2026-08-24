-- Migration 44: Inscription libre-service du parent + code de liaison élève↔parent (§17 du CDC)
--
-- Jusqu'ici, seul un admin pouvait créer un compte parent (admin-create-parent-account) et le lier
-- à un profil (parent_profile_links_admin_write). Le parent peut maintenant créer lui-même son
-- compte (déjà permis par la policy parent_accounts_insert de la migration 11 :
-- auth_user_id = auth.uid() OR is_admin_user() — jamais utilisée côté client jusqu'ici) et se lier
-- à un enfant via un code éphémère généré depuis l'app élève (Mon Profil), plutôt qu'un lien libre
-- non vérifié (risque : n'importe qui prétendant être le parent d'un profil mineur) ou le partage
-- du mot de passe de l'élève.
--
-- Rejouable sans erreur.

CREATE TABLE IF NOT EXISTS parent_link_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    used_by_parent_account_id UUID REFERENCES parent_accounts(id)
);

ALTER TABLE parent_link_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS parent_link_codes_select ON parent_link_codes;
CREATE POLICY parent_link_codes_select ON parent_link_codes FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS parent_link_codes_insert ON parent_link_codes;
CREATE POLICY parent_link_codes_insert ON parent_link_codes FOR INSERT WITH CHECK (owns_profile(profile_id));

-- SECURITY DEFINER : le parent qui rédime un code n'a par ailleurs aucun droit d'écriture sur
-- parent_profile_links (réservé à l'admin, migration 06) — cette fonction est la seule porte
-- d'entrée précise et contrôlée pour cette action spécifique, sans ouvrir la table en écriture
-- libre à tout parent authentifié.
CREATE OR REPLACE FUNCTION redeem_parent_link_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_link_code parent_link_codes%ROWTYPE;
    v_parent_id UUID;
BEGIN
    SELECT * INTO v_link_code FROM parent_link_codes WHERE code = p_code FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Code invalide.');
    END IF;
    IF v_link_code.used_at IS NOT NULL THEN
        RETURN json_build_object('error', 'Ce code a déjà été utilisé.');
    END IF;
    IF v_link_code.expires_at < NOW() THEN
        RETURN json_build_object('error', 'Ce code a expiré — demandez-en un nouveau à votre enfant.');
    END IF;

    SELECT id INTO v_parent_id FROM parent_accounts WHERE auth_user_id = auth.uid() AND is_active = true;
    IF v_parent_id IS NULL THEN
        RETURN json_build_object('error', 'Compte parent introuvable ou suspendu.');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM parent_profile_links
        WHERE parent_account_id = v_parent_id AND profile_id = v_link_code.profile_id
    ) THEN
        INSERT INTO parent_profile_links (parent_account_id, profile_id, relation_type)
        VALUES (v_parent_id, v_link_code.profile_id, 'parent');
    END IF;

    UPDATE parent_link_codes SET used_at = NOW(), used_by_parent_account_id = v_parent_id WHERE id = v_link_code.id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
