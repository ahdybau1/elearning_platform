-- Migration 50 : avertit (sans bloquer) quand un profil "identique" existe déjà sur un AUTRE compte
-- pour la même classe (confirmé par l'utilisateur : la règle doit valoir aussi entre deux comptes
-- différents, pas seulement dans un même compte — voir migration 49 pour ce cas-là).
--
-- Volontairement un AVERTISSEMENT, pas un blocage dur : prénom + nom + date de naissance identiques
-- n'est qu'un indice (de vrais jumeaux dans la même classe existent). La fonction ne renvoie qu'un
-- booléen — jamais l'identité du compte trouvé, pour ne fuiter aucune donnée personnelle d'un autre
-- élève. SECURITY DEFINER car la RLS de `accounts` interdit normalement de voir les comptes des
-- autres élèves, ce qui est le comportement correct partout ailleurs.
--
-- Rejouable sans erreur.

CREATE OR REPLACE FUNCTION check_duplicate_person_profile(
    p_first_name TEXT,
    p_last_name TEXT,
    p_birth_date DATE,
    p_class_node_id UUID,
    p_exclude_account_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM profiles pr
        JOIN accounts a ON a.id = pr.account_id
        WHERE pr.class_node_id = p_class_node_id
          AND pr.status = 'actif'
          AND lower(trim(a.first_name)) = lower(trim(p_first_name))
          AND lower(trim(a.last_name)) = lower(trim(p_last_name))
          AND a.birth_date = p_birth_date
          AND (p_exclude_account_id IS NULL OR a.id <> p_exclude_account_id)
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION check_duplicate_person_profile(TEXT, TEXT, DATE, UUID, UUID) TO authenticated, anon;
