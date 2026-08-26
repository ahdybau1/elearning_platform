-- Migration 46: corrige un vrai bug de la migration 45 — `pgcrypto` (crypt/gen_salt) est installé
-- dans le schéma `extensions` sur ce projet Supabase, pas `public`. `SET search_path = public`
-- empêchait donc `set_login_code`/`verify_login_code` de résoudre `gen_salt`/`crypt`, provoquant
-- une erreur Postgres 42883 (« function ... does not exist ») que PostgREST renvoie en HTTP 404 —
-- ce qui ressemblait à tort à un problème de cache de schéma ou de permissions.
--
-- Rejouable sans erreur.

CREATE OR REPLACE FUNCTION set_login_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_account_id UUID;
BEGIN
    IF p_code !~ '^[0-9]{6}$' THEN
        RETURN json_build_object('error', 'Le code doit comporter exactement 6 chiffres.');
    END IF;

    SELECT id INTO v_account_id FROM accounts WHERE auth_user_id = auth.uid();
    IF v_account_id IS NULL THEN
        RETURN json_build_object('error', 'Compte introuvable.');
    END IF;

    UPDATE accounts SET login_code_hash = crypt(p_code, gen_salt('bf')) WHERE id = v_account_id;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION verify_login_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_hash TEXT;
BEGIN
    SELECT login_code_hash INTO v_hash FROM accounts WHERE auth_user_id = auth.uid();
    IF v_hash IS NULL THEN
        RETURN json_build_object('success', false, 'reason', 'no_code_set');
    END IF;
    IF v_hash = crypt(p_code, v_hash) THEN
        RETURN json_build_object('success', true);
    END IF;
    RETURN json_build_object('success', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;
