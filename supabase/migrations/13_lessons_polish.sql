-- Complète l'écran "Leçons & Cours" : archivage des leçons (cohérent avec chapters.is_active et
-- academic_nodes.is_active) et historique de versions (symétrique de exercise_versions, jusqu'ici
-- seules les leçons n'avaient aucun suivi de version malgré la promesse affichée à l'écran).

ALTER TABLE lessons ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS lesson_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lesson_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_versions_admin_all ON lesson_versions;
CREATE POLICY lesson_versions_admin_all ON lesson_versions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

-- Une leçon archivée (is_active = false) ne doit plus être visible côté élève même si elle était
-- publiée au moment de l'archivage.
DROP POLICY IF EXISTS lessons_select ON lessons;
CREATE POLICY lessons_select ON lessons FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND is_active = true
        AND (min_subscription_tier = 'gratuit' OR current_user_has_feature_access('courses'))
    )
);
