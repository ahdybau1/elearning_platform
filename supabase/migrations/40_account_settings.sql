-- Migration 40: Préférences réelles par compte (CDC §11.1 Paramètres)
--
-- settings_screen.dart n'avait aucune table à lire/écrire : chaque Switch/Slider vivait en bool/double
-- local (setState), perdu à la fermeture de l'app. Cette table donne un vrai support serveur, 1:1 avec
-- accounts. La langue d'interface n'a pas de colonne : elle reste fixée à 'fr' tant qu'aucune traduction
-- anglaise réelle n'existe (une préférence qui ne change rien serait aussi trompeuse que l'ancien état).
--
-- Rejouable sans erreur.

CREATE TABLE IF NOT EXISTS account_settings (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    notif_subscription BOOLEAN NOT NULL DEFAULT true,
    notif_forum BOOLEAN NOT NULL DEFAULT true,
    notif_revision BOOLEAN NOT NULL DEFAULT true,
    theme_mode TEXT NOT NULL DEFAULT 'dark' CHECK (theme_mode IN ('light', 'dark', 'system')),
    high_contrast BOOLEAN NOT NULL DEFAULT false,
    font_scale NUMERIC(3,2) NOT NULL DEFAULT 1.0 CHECK (font_scale BETWEEN 0.85 AND 1.4),
    -- Persisté dès maintenant mais sans effet visible : aucun lecteur vidéo n'existe encore côté
    -- lesson_reader_screen pour consommer ce réglage (§11.2/§18, hors périmètre de cette passe).
    subtitles_enabled BOOLEAN NOT NULL DEFAULT true,
    forum_profile_visible BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE account_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS account_settings_select ON account_settings;
CREATE POLICY account_settings_select ON account_settings FOR SELECT USING (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS account_settings_insert ON account_settings;
CREATE POLICY account_settings_insert ON account_settings FOR INSERT WITH CHECK (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS account_settings_update ON account_settings;
CREATE POLICY account_settings_update ON account_settings FOR UPDATE USING (owns_account(account_id) OR is_admin_user());
