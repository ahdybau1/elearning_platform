-- Section 12 : Dons & Œuvres Caritatives — `charity_campaigns.collected_amount` n'était mis à jour
-- par AUCUN mécanisme (ni trigger, ni code applicatif) : la barre de progression affichée à l'admin
-- restait figée à sa valeur d'insertion (0) quel que soit le nombre de dons réellement enregistrés.
-- Ce trigger synchronise `collected_amount` sur chaque INSERT/UPDATE/DELETE de `donations`.

CREATE OR REPLACE FUNCTION sync_campaign_collected_amount() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.charity_campaign_id IS NOT NULL THEN
            UPDATE charity_campaigns
            SET collected_amount = collected_amount + NEW.amount
            WHERE id = NEW.charity_campaign_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.charity_campaign_id IS NOT NULL THEN
            UPDATE charity_campaigns
            SET collected_amount = collected_amount - OLD.amount
            WHERE id = OLD.charity_campaign_id;
        END IF;
        IF NEW.charity_campaign_id IS NOT NULL THEN
            UPDATE charity_campaigns
            SET collected_amount = collected_amount + NEW.amount
            WHERE id = NEW.charity_campaign_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.charity_campaign_id IS NOT NULL THEN
            UPDATE charity_campaigns
            SET collected_amount = collected_amount - OLD.amount
            WHERE id = OLD.charity_campaign_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_campaign_collected_amount ON donations;
CREATE TRIGGER trg_sync_campaign_collected_amount
    AFTER INSERT OR UPDATE OR DELETE ON donations
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_collected_amount();

-- Rattrape les campagnes déjà créées avant l'ajout du trigger : recalcule depuis les dons existants.
UPDATE charity_campaigns cc
SET collected_amount = COALESCE((
    SELECT SUM(d.amount) FROM donations d WHERE d.charity_campaign_id = cc.id
), 0);
