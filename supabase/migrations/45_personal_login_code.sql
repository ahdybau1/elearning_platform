-- Migration 45: Connexion rapide par code personnel — vérification stricte par compte (§7.3/§7.4)
--
-- Un code personnel (6 chiffres) permet à un élève de déverrouiller RAPIDEMENT une session déjà
-- réellement authentifiée (email + mot de passe) et déjà enregistrée localement sur CET appareil —
-- le code ne crée jamais de session à lui seul et ne sert jamais à retrouver le propriétaire d'un
-- code à partir du code seul. Règle de sécurité fondamentale : `verify_login_code` ne prend AUCUN
-- identifiant de compte en paramètre — elle vérifie exclusivement le compte de la session Supabase
-- Auth DÉJÀ restaurée côté client (auth.uid()), donc structurellement impossible de l'appeler pour
-- tester le code d'un autre élève. Le hash ne quitte jamais la base (pgcrypto/bcrypt), et aucune
-- des deux fonctions ne renvoie d'information permettant de savoir à qui un code appartient.
--
-- Rejouable sans erreur.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS login_code_hash TEXT;

-- Définit/change le code personnel du compte APPELANT uniquement (Profil → Sécurité → Mon code).
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Vérifie le code personnel du compte de LA SESSION DÉJÀ ACTIVE (auth.uid()) — jamais un compte
-- choisi par le client. Le flux applicatif attendu est : restaurer côté client la session déjà
-- enregistrée pour le profil sélectionné sur CET appareil (jamais une session arbitraire), PUIS
-- appeler cette fonction ; en cas d'échec, l'appelant doit immédiatement abandonner cette session
-- restaurée sans jamais afficher les données du compte.
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
