-- CDC Partie 1 §6.3 : "l'expiration d'un abonnement payant n'est jamais silencieuse" — jusqu'ici AUCUN
-- mécanisme ne redescendait automatiquement un profil au palier gratuit à l'échéance, et les tables
-- `scheduled_reminders`/`notification_log` ne recevaient jamais de ligne automatiquement (vérifié : aucun
-- pg_cron n'existait sur ce projet). Ce fichier active pg_cron et implémente le cycle complet :
-- J-3 / J-1 / Jour J (bascule réelle vers 'gratuit') / relances J+1, J+7, J+30 post-expiration.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Nouveaux templates pour les relances post-expiration (J-3/J-1/Jour J étaient déjà seedés en 04_*.sql).
INSERT INTO notification_templates (event_key, channel, title_template, body_template) VALUES
    ('relance_j1', 'push', 'On vous garde une place', 'Votre abonnement {{class_name}} a expiré hier. Réabonnez-vous pour retrouver l''accès complet.'),
    ('relance_j7', 'push', 'Toujours envie de progresser ?', 'Cela fait 7 jours que votre abonnement {{class_name}} a expiré. Reprenez là où vous vous étiez arrêté.'),
    ('relance_j30', 'push', 'Votre classe vous attend', 'Un mois sans abonnement {{class_name}} — réabonnez-vous quand vous êtes prêt.')
ON CONFLICT (event_key) DO NOTHING;

CREATE OR REPLACE FUNCTION process_subscription_lifecycle() RETURNS void AS $$
DECLARE
    r RECORD;
    v_days_until INT;
    v_days_since INT;
    v_reminder_type TEXT;
    v_template_id UUID;
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

            SELECT id INTO v_template_id FROM notification_templates WHERE event_key = v_reminder_type;
            IF v_template_id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, sent_at)
                VALUES (r.profile_id, v_template_id, NOW());
            END IF;
        END IF;
    END LOOP;

    -- 2) Bascule réelle au palier gratuit : abonnements 'actif' dont l'échéance est passée.
    FOR r IN
        SELECT s.id AS sub_id, s.profile_id
        FROM subscriptions s
        WHERE s.status = 'actif' AND s.end_date::date < CURRENT_DATE
    LOOP
        UPDATE subscriptions SET status = 'expire' WHERE id = r.sub_id;
        UPDATE profiles SET subscription_tier = 'gratuit', updated_at = NOW() WHERE id = r.profile_id;

        IF NOT EXISTS (
            SELECT 1 FROM scheduled_reminders
            WHERE profile_id = r.profile_id AND reminder_type = 'jour_j_expiration'
        ) THEN
            INSERT INTO scheduled_reminders (profile_id, reminder_type, trigger_date, sent)
            VALUES (r.profile_id, 'jour_j_expiration', NOW(), true);

            SELECT id INTO v_template_id FROM notification_templates WHERE event_key = 'jour_j_expiration';
            IF v_template_id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, sent_at)
                VALUES (r.profile_id, v_template_id, NOW());
            END IF;
        END IF;
    END LOOP;

    -- 3) Relances dégressives post-expiration J+1 / J+7 / J+30, basées sur le dernier abonnement expiré
    -- de chaque profil actuellement au palier gratuit.
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

            SELECT id INTO v_template_id FROM notification_templates WHERE event_key = v_reminder_type;
            IF v_template_id IS NOT NULL THEN
                INSERT INTO notification_log (profile_id, template_id, sent_at)
                VALUES (r.profile_id, v_template_id, NOW());
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Planification : tous les jours à 00h10 UTC (01h10 heure du Cameroun), en heure creuse.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'subscription-lifecycle-daily') THEN
        PERFORM cron.unschedule('subscription-lifecycle-daily');
    END IF;
END $$;

SELECT cron.schedule(
    'subscription-lifecycle-daily',
    '10 0 * * *',
    $$SELECT process_subscription_lifecycle();$$
);
