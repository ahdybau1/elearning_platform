-- Migration 49 : liaison parent-enfant enrichie (§17 du CDC)
--
-- Trois mécanismes, tous via RPC SECURITY DEFINER (jamais d'accès direct table — `parent_profile_links`
-- n'a même pas de policy DELETE/INSERT ouverte aux rôles normaux, c'est volontaire) :
--
-- 1. auto_link_known_device_accounts : à l'inscription/connexion d'un parent, le CLIENT transmet la
--    liste des comptes élève déjà réellement authentifiés sur CET appareil (registre local, voir
--    device_accounts_service.dart) — signal purement local/appareil, jamais une empreinte serveur —
--    et ils sont liés automatiquement, sans code à saisir.
-- 2. get_or_create_parent_invite_code / redeem_parent_invite_code : sens parent → enfant (le parent
--    génère un code, le donne à son enfant qui le saisit) — symétrique du mécanisme existant
--    parent_link_codes (sens enfant → parent, migration 44), avec un code toujours différent des deux.
-- 3. parent_unlink_child : un parent peut délier un enfant ; AUCUNE fonction équivalente n'existe côté
--    élève — un élève ne peut jamais se délier de son parent, restriction volontaire et absente par
--    conception plutôt que bloquée après coup.
--
-- Rejouable sans erreur.

CREATE TABLE IF NOT EXISTS parent_invite_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    parent_account_id UUID NOT NULL REFERENCES parent_accounts(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE parent_invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS parent_invite_codes_select ON parent_invite_codes;
CREATE POLICY parent_invite_codes_select ON parent_invite_codes FOR SELECT
    USING (
        parent_account_id IN (SELECT id FROM parent_accounts WHERE auth_user_id = auth.uid())
        OR is_admin_user()
    );

CREATE OR REPLACE FUNCTION get_or_create_parent_invite_code()
RETURNS JSON AS $$
DECLARE
    v_parent_id UUID;
    v_existing TEXT;
    v_code TEXT;
BEGIN
    SELECT id INTO v_parent_id FROM parent_accounts WHERE auth_user_id = auth.uid() AND is_active = true;
    IF v_parent_id IS NULL THEN
        RETURN json_build_object('error', 'Compte parent introuvable.');
    END IF;

    SELECT code INTO v_existing FROM parent_invite_codes
        WHERE parent_account_id = v_parent_id AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 1;
    IF v_existing IS NOT NULL THEN
        RETURN json_build_object('code', v_existing);
    END IF;

    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    INSERT INTO parent_invite_codes (code, parent_account_id, expires_at)
        VALUES (v_code, v_parent_id, NOW() + INTERVAL '24 hours');
    RETURN json_build_object('code', v_code);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION redeem_parent_invite_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_parent_id UUID;
    v_account_id UUID;
BEGIN
    SELECT parent_account_id INTO v_parent_id FROM parent_invite_codes
        WHERE code = p_code AND expires_at > NOW();
    IF v_parent_id IS NULL THEN
        RETURN json_build_object('error', 'Code invalide ou expiré.');
    END IF;

    SELECT id INTO v_account_id FROM accounts WHERE auth_user_id = auth.uid();
    IF v_account_id IS NULL THEN
        RETURN json_build_object('error', 'Compte élève introuvable.');
    END IF;

    INSERT INTO parent_profile_links (parent_account_id, profile_id)
    SELECT v_parent_id, p.id FROM profiles p
    WHERE p.account_id = v_account_id AND p.status = 'actif'
    ON CONFLICT DO NOTHING;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION auto_link_known_device_accounts(p_account_ids UUID[])
RETURNS JSON AS $$
DECLARE
    v_parent_id UUID;
BEGIN
    SELECT id INTO v_parent_id FROM parent_accounts WHERE auth_user_id = auth.uid() AND is_active = true;
    IF v_parent_id IS NULL THEN
        RETURN json_build_object('error', 'Compte parent introuvable.');
    END IF;

    INSERT INTO parent_profile_links (parent_account_id, profile_id)
    SELECT v_parent_id, p.id FROM profiles p
    WHERE p.account_id = ANY(p_account_ids) AND p.status = 'actif'
    ON CONFLICT DO NOTHING;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION parent_unlink_child(p_profile_id UUID)
RETURNS JSON AS $$
DECLARE
    v_parent_id UUID;
BEGIN
    SELECT id INTO v_parent_id FROM parent_accounts WHERE auth_user_id = auth.uid() AND is_active = true;
    IF v_parent_id IS NULL THEN
        RETURN json_build_object('error', 'Compte parent introuvable.');
    END IF;

    DELETE FROM parent_profile_links WHERE parent_account_id = v_parent_id AND profile_id = p_profile_id;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_or_create_parent_invite_code() TO authenticated;
GRANT EXECUTE ON FUNCTION redeem_parent_invite_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_link_known_device_accounts(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION parent_unlink_child(UUID) TO authenticated;
