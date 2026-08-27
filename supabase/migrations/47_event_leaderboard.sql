-- Migration 47 : classement public d'un événement (concours blanc / olympiade)
--
-- `event_results_select` (migration existante) limite volontairement chaque élève à ses PROPRES
-- résultats (owns_profile) — un classement national par nature doit montrer les résultats d'AUTRES
-- élèves, ce qui est structurellement impossible via une simple requête cliente sous cette RLS. Cette
-- fonction expose donc, de façon délibérée et minimale (rang, score, seulement le prénom + la classe,
-- jamais le nom de famille ni l'email), un classement en lecture seule pour un événement précis —
-- jamais d'autre donnée du compte.
--
-- Rejouable sans erreur.

CREATE OR REPLACE FUNCTION get_event_leaderboard(p_event_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE(rank INT, score NUMERIC, first_name TEXT, class_name TEXT) AS $$
    SELECT er.rank, er.score, a.first_name, an.name
    FROM event_results er
    JOIN profiles p ON p.id = er.profile_id
    JOIN accounts a ON a.id = p.account_id
    JOIN academic_nodes an ON an.id = p.class_node_id
    WHERE er.event_id = p_event_id
    ORDER BY er.rank ASC NULLS LAST, er.score DESC
    LIMIT p_limit;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION get_event_leaderboard(UUID, INT) TO authenticated;
