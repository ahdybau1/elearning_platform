-- CDC Partie 1 §6.3/§6.4 : centre de notifications réel côté élève, et correction d'un bug de
-- production confirmé (vérifié en direct le 2026-09-18 avant d'écrire ce correctif) :
-- `process_subscription_lifecycle()` (migration 30) insère dans `notification_log` sans les
-- colonnes `title`/`body`/`channel`, toutes `NOT NULL` sans défaut. Cette fonction tourne chaque
-- jour depuis des semaines avec le statut « succeeded » et 0 ligne dans `notification_log` — non
-- pas parce qu'elle fonctionne, mais parce qu'aucun abonnement réel n'a encore atteint J-3/J-1/
-- expiration (`subscriptions` ne contient que des données de test). Le jour où un vrai abonnement
-- payant approchera de son échéance, l'INSERT échouerait et ferait échouer toute la fonction —
-- confirmé en lisant `handle_monthly_spend_accumulation` (migration 04) qui, elle, peuple bien
-- title/body/channel directement et fonctionne réellement.

-- 1) Corrige process_subscription_lifecycle() : résout title/body/channel depuis le template au
--    lieu de ne stocker que template_id (jamais suffisant vu la contrainte NOT NULL réelle).
CREATE OR REPLACE FUNCTION process_subscription_lifecycle() RETURNS void AS $$
DECLARE
    r RECORD;
    v_days_until INT;
    v_days_since INT;
    v_reminder_type TEXT;
    v_template RECORD;
BEGIN
    -- 1) Rappels J-3 / J-1 / Jour J pour les abonnements encore actifs qui arrivent à échéance.
    FOR r IN
        SELECT s.id AS sub_id, s.profile_id, s.end_date
        FROM subscriptions s
        WHERE s.status = 'actif'
          AND s.end_date::date >= CURRENT_DATE
          AND s.end_date::date <= CURRENT_DATE + INTERVAL '3 days'
    LOOP
        v_days_until := (r.end_date::date - CURRENT_DATE);
        v_reminder_type := CASE v_days_until
            WHEN 3 THEN 'j3_expiration'
            WHEN 1 THEN 'j1_expiration'
            WHEN 0 THEN 'jour_j_expiration'
            ELSE NULL
        END;
        IF v_reminder_type IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM scheduled_reminders
               WHERE profile_id = r.profile_id AND reminder_type = v_reminder_type
           ) THEN
            INSERT INTO scheduled_reminders (profile_id, reminder_type, trigger_date, sent)
            VALUES (r.profile_id, v_reminder_type, NOW(), true);

            SELECT id, title_template, body_template, channel INTO v_template
            FROM notification_templates WHERE event_key = v_reminder_type;
            IF v_template.id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, title, body, channel, sent_at)
                VALUES (r.profile_id, v_template.id, v_template.title_template, v_template.body_template, v_template.channel, NOW());
            END IF;
        END IF;
    END LOOP;

    -- 2) Bascule au palier réellement dû : le dernier palier payant non expiré, sinon 'gratuit'.
    --    CDC §38.4 : « le profil retombe à son dernier palier réellement souscrit et non expiré »,
    --    pas systématiquement au gratuit (ex: un abonnement Annuel encore valide pendant qu'un
    --    Mensuel plus récent expire ne doit pas écraser l'Annuel).
    FOR r IN
        SELECT s.id AS sub_id, s.profile_id
        FROM subscriptions s
        WHERE s.status = 'actif' AND s.end_date::date < CURRENT_DATE
    LOOP
        UPDATE subscriptions SET status = 'expire' WHERE id = r.sub_id;

        UPDATE profiles p
        SET subscription_tier = COALESCE(
                (SELECT st.name
                 FROM subscriptions s2
                 JOIN subscription_tiers st ON st.id = s2.tier_id
                 WHERE s2.profile_id = r.profile_id
                   AND s2.status = 'actif'
                   AND s2.end_date::date >= CURRENT_DATE
                 ORDER BY st.rank DESC NULLS LAST, s2.end_date DESC
                 LIMIT 1),
                'gratuit'
            ),
            updated_at = NOW()
        WHERE p.id = r.profile_id;

        IF NOT EXISTS (
            SELECT 1 FROM scheduled_reminders
            WHERE profile_id = r.profile_id AND reminder_type = 'jour_j_expiration'
        ) THEN
            INSERT INTO scheduled_reminders (profile_id, reminder_type, trigger_date, sent)
            VALUES (r.profile_id, 'jour_j_expiration', NOW(), true);

            SELECT id, title_template, body_template, channel INTO v_template
            FROM notification_templates WHERE event_key = 'jour_j_expiration';
            IF v_template.id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, title, body, channel, sent_at)
                VALUES (r.profile_id, v_template.id, v_template.title_template, v_template.body_template, v_template.channel, NOW());
            END IF;
        END IF;
    END LOOP;

    -- 3) Relances dégressives post-expiration J+1 / J+7 / J+30.
    FOR r IN
        SELECT DISTINCT ON (s.profile_id) s.profile_id, s.end_date
        FROM subscriptions s
        JOIN profiles p ON p.id = s.profile_id
        WHERE s.status = 'expire' AND p.subscription_tier = 'gratuit'
        ORDER BY s.profile_id, s.end_date DESC
    LOOP
        v_days_since := (CURRENT_DATE - r.end_date::date);
        v_reminder_type := CASE v_days_since
            WHEN 1 THEN 'relance_j1'
            WHEN 7 THEN 'relance_j7'
            WHEN 30 THEN 'relance_j30'
            ELSE NULL
        END;
        IF v_reminder_type IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM scheduled_reminders
               WHERE profile_id = r.profile_id AND reminder_type = v_reminder_type
           ) THEN
            INSERT INTO scheduled_reminders (profile_id, reminder_type, trigger_date, sent)
            VALUES (r.profile_id, v_reminder_type, NOW(), true);

            SELECT id, title_template, body_template, channel INTO v_template
            FROM notification_templates WHERE event_key = v_reminder_type;
            IF v_template.id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, title, body, channel, sent_at)
                VALUES (r.profile_id, v_template.id, v_template.title_template, v_template.body_template, v_template.channel, NOW());
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2) subscription_tiers.rank : nécessaire pour comparer deux paliers actifs au moment du fallback
--    ci-dessus (Gratuit < Journalier < Hebdomadaire < Mensuel < Annuel, §6.1). Additif, jamais lu
--    nulle part avant, donc sans risque de régression.
ALTER TABLE subscription_tiers ADD COLUMN IF NOT EXISTS rank INT;
UPDATE subscription_tiers SET rank = CASE name
    WHEN 'gratuit' THEN 0
    WHEN 'journalier' THEN 1
    WHEN 'hebdomadaire' THEN 2
    WHEN 'mensuel' THEN 3
    WHEN 'annuel' THEN 4
    ELSE 0
END WHERE rank IS NULL;

-- 3) scheduled_reminders : le garde-fou actuel est (profile_id, reminder_type) POUR TOUJOURS, donc
--    un rappel d'examen (Phase suivante, §19) ne pourrait jamais se redéclencher l'année scolaire
--    suivante. ref_id permet de rattacher un rappel à une occurrence précise (ex: tel official_exam
--    précis) tout en gardant le comportement actuel identique pour les rappels d'abonnement (ref_id
--    NULL partout ci-dessus, donc toujours le même index unique qu'avant pour eux).
ALTER TABLE scheduled_reminders ADD COLUMN IF NOT EXISTS ref_id UUID;
CREATE UNIQUE INDEX IF NOT EXISTS idx_scheduled_reminders_unique
    ON scheduled_reminders (profile_id, reminder_type, COALESCE(ref_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- 4) L'élève doit pouvoir marquer une notification comme lue (seule écriture qui lui revient).
DROP POLICY IF EXISTS notification_log_update_own ON notification_log;
CREATE POLICY notification_log_update_own ON notification_log
    FOR UPDATE USING (owns_profile(profile_id)) WITH CHECK (owns_profile(profile_id));

CREATE INDEX IF NOT EXISTS idx_notification_log_profile_sent ON notification_log (profile_id, sent_at DESC);

NOTIFY pgrst, 'reload schema';
