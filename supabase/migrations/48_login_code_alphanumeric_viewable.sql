-- Migration 48 : le code personnel devient alphanumérique (lettres/chiffres/caractères, plus de
-- limite à 6 chiffres) ET consultable par son propriétaire — l'ancien hash bcrypt à sens unique
-- (migration 45) empêchait structurellement toute consultation, ce qui n'est plus le comportement
-- voulu. Remplacé par un chiffrement symétrique réversible (pgcrypto `pgp_sym_encrypt`/
-- `pgp_sym_decrypt`) : seul le propriétaire authentifié (auth.uid()) peut le déchiffrer, via
-- `get_my_login_code()` — jamais exposé à un autre utilisateur, jamais en clair côté client tant
-- qu'il n'a pas explicitement demandé à le voir.
--
-- Les anciens hash bcrypt existants sont invalidés (NULL) : ils ne peuvent pas être déchiffrés avec
-- ce nouveau schéma, un élève ayant déjà défini un code devra le redéfinir une fois.
--
-- Rejouable sans erreur.

UPDATE accounts SET login_code_hash = NULL WHERE login_code_hash IS NOT NULL;

CREATE OR REPLACE FUNCTION set_login_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_account_id UUID;
BEGIN
    IF length(p_code) < 4 OR length(p_code) > 40 THEN
        RETURN json_build_object('error', 'Le code doit comporter entre 4 et 40 caractères.');
    END IF;

    SELECT id INTO v_account_id FROM accounts WHERE auth_user_id = auth.uid();
    IF v_account_id IS NULL THEN
        RETURN json_build_object('error', 'Compte introuvable.');
    END IF;

    UPDATE accounts
    SET login_code_hash = encode(pgp_sym_encrypt(p_code, 'elp_code_k7Qx2mZ9vR4tBw8nHj5Lp3Fy6Ds1Ac'), 'base64')
    WHERE id = v_account_id;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION verify_login_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_stored TEXT;
    v_decrypted TEXT;
BEGIN
    SELECT login_code_hash INTO v_stored FROM accounts WHERE auth_user_id = auth.uid();
    IF v_stored IS NULL THEN
        RETURN json_build_object('success', false, 'reason', 'no_code_set');
    END IF;

    BEGIN
        v_decrypted := pgp_sym_decrypt(decode(v_stored, 'base64'), 'elp_code_k7Qx2mZ9vR4tBw8nHj5Lp3Fy6Ds1Ac');
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('success', false);
    END;

    IF v_decrypted = p_code THEN
        RETURN json_build_object('success', true);
    END IF;
    RETURN json_build_object('success', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- Nouveau : consultation du propre code (jamais celui d'un autre — auth.uid() uniquement).
CREATE OR REPLACE FUNCTION get_my_login_code()
RETURNS JSON AS $$
DECLARE
    v_stored TEXT;
    v_decrypted TEXT;
BEGIN
    SELECT login_code_hash INTO v_stored FROM accounts WHERE auth_user_id = auth.uid();
    IF v_stored IS NULL THEN
        RETURN json_build_object('code', NULL);
    END IF;

    BEGIN
        v_decrypted := pgp_sym_decrypt(decode(v_stored, 'base64'), 'elp_code_k7Qx2mZ9vR4tBw8nHj5Lp3Fy6Ds1Ac');
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('code', NULL);
    END;

    RETURN json_build_object('code', v_decrypted);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION set_login_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_login_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_login_code() TO authenticated;
