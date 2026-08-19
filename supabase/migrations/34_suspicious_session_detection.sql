-- Section 25 du CDC : "détection de changements fréquents d'appareil (signal possible de partage de
-- compte à investiguer)". La page admin "Sessions & Anti-Partage" affichait un seuil statique
-- ("Seuil: 3 bascules / jour") sans jamais réellement le calculer — aucune requête n'existait pour
-- déterminer quels comptes dépassent ce seuil. Cette fonction le fait réellement, à partir du nombre de
-- lignes `sessions` créées aujourd'hui par compte (chaque nouvelle connexion insère une ligne, cf.
-- 31_enforce_single_session.sql).

-- SECURITY DEFINER + accès direct aux emails/noms de comptes tiers : doit rester interdit à un élève,
-- donc vérifié en interne plutôt que délégué à la seule policy RLS de `accounts`/`sessions`.
CREATE OR REPLACE FUNCTION get_suspicious_session_accounts(p_min_switches INT DEFAULT 3)
RETURNS TABLE (
    account_id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    switch_count BIGINT
) AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
    END IF;

    RETURN QUERY
    SELECT s.account_id, a.first_name, a.last_name, a.email, COUNT(*) AS switch_count
    FROM sessions s
    JOIN accounts a ON a.id = s.account_id
    WHERE s.created_at >= CURRENT_DATE
    GROUP BY s.account_id, a.first_name, a.last_name, a.email
    HAVING COUNT(*) >= p_min_switches
    ORDER BY switch_count DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION get_suspicious_session_accounts(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_suspicious_session_accounts(INT) TO authenticated;
