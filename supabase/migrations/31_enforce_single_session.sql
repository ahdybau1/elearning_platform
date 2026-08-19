-- CDC Partie 1 §7.4, Partie 2 §25, exemple chiffré §40 : "Nouvelle connexion détectée → déconnexion
-- immédiate et automatique de l'ancienne session […] aucune exception." La table `sessions` existait déjà
-- mais rien ne désactivait l'ancienne session à la création d'une nouvelle — `revokeSession` côté admin
-- n'est qu'un geste manuel. Ce trigger applique la règle au niveau base de données, quel que soit le
-- client (élève, futur parent) qui insère la nouvelle session.
--
-- La détection temps réel côté client (écran "Compte utilisé sur un autre appareil" + écoute Realtime sur
-- sa propre ligne `sessions`) reste à construire côté student_app, qui ne crée aujourd'hui aucune ligne
-- dans `sessions` au login — ce trigger est la moitié base de données de la fonctionnalité, prête dès que
-- le client écrit dans cette table.

CREATE OR REPLACE FUNCTION enforce_single_session() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active THEN
        UPDATE sessions
        SET is_active = false
        WHERE account_id = NEW.account_id
          AND id <> NEW.id
          AND is_active = true;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_enforce_single_session ON sessions;
CREATE TRIGGER trg_enforce_single_session
    AFTER INSERT ON sessions
    FOR EACH ROW EXECUTE FUNCTION enforce_single_session();
