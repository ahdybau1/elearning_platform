-- Paramètres globaux de l'application (admin + student_app) : branding, contact support, textes
-- légaux, mode maintenance, version minimale, langues activées (préparation i18n). Table à ligne
-- unique (comme un singleton de configuration) plutôt qu'un magasin clé/valeur générique, pour
-- rester cohérent avec le style typé du reste du schéma.
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    app_name TEXT NOT NULL DEFAULT 'E-Learning',
    tagline TEXT,
    support_email TEXT,
    support_phone TEXT,
    support_whatsapp_link TEXT,
    terms_url TEXT,
    privacy_policy_url TEXT,
    legal_notice_url TEXT,
    maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
    maintenance_message TEXT,
    min_supported_app_version TEXT,
    enabled_languages TEXT[] NOT NULL DEFAULT ARRAY['fr'],
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

INSERT INTO app_settings (app_name, tagline, enabled_languages)
SELECT 'E-Learning', 'Votre Plateforme d''Excellence', ARRAY['fr']
WHERE NOT EXISTS (SELECT 1 FROM app_settings);

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Aucune donnée sensible dans cette table (aucun secret) — lecture publique nécessaire pour que
-- student_app puisse afficher le mode maintenance avant même la connexion.
DROP POLICY IF EXISTS app_settings_public_select ON app_settings;
CREATE POLICY app_settings_public_select ON app_settings FOR SELECT USING (true);

-- Écriture réservée au super-admin : le mode maintenance peut rendre toute la plateforme
-- indisponible, ce n'est pas un réglage anodin délégable à tous les rôles admin.
DROP POLICY IF EXISTS app_settings_super_admin_update ON app_settings;
CREATE POLICY app_settings_super_admin_update ON app_settings FOR UPDATE
    USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));
