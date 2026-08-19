-- ============================================================================
-- Matrice de Droits — catalogue de fonctionnalités gérable par l'admin
-- ============================================================================
-- L'utilisateur veut pouvoir ajouter/modifier/supprimer lui-même les fonctionnalités listées dans
-- la Matrice de Droits ("tu dois aussi me permettre d'en ajouter d'autres"), et couvrir davantage
-- de contenu réel de l'app (Groupes WhatsApp explicitement demandés). La liste était jusqu'ici codée
-- en dur côté Dart (_featureDefinitions) — remplacée par une vraie table pilotée par l'admin.

CREATE TABLE matrix_features (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    icon_name TEXT NOT NULL DEFAULT 'lock',
    -- Une fonctionnalité peut exister dans ce catalogue avant que son application technique (RLS)
    -- ne soit construite (ex: Assistant IA élève, qui n'existe pas encore ailleurs dans le code) —
    -- ce booléen permet à l'UI de le signaler honnêtement plutôt que de laisser croire à une
    -- restriction réelle. Il est déclaratif : ce n'est PAS ce booléen qui applique quoi que ce
    -- soit, seule une policy RLS utilisant current_user_has_feature_access() le fait réellement.
    is_enforced BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE matrix_features ENABLE ROW LEVEL SECURITY;
CREATE POLICY matrix_features_select ON matrix_features FOR SELECT USING (is_admin_user());
CREATE POLICY matrix_features_super_admin_write ON matrix_features FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY matrix_features_super_admin_update ON matrix_features FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY matrix_features_super_admin_delete ON matrix_features FOR DELETE USING (has_admin_role('super_admin'));

INSERT INTO matrix_features (feature_key, label, icon_name, is_enforced, display_order) VALUES
    ('courses', 'Cours & Leçons (Lecture)', 'menu_book', TRUE, 0),
    ('exercises_training', 'Exercices d''Entraînement', 'quiz', TRUE, 1),
    ('exercises_evaluation', 'Exercices d''Évaluation (Corrigés)', 'assignment_turned_in', TRUE, 2),
    ('official_exams', 'Examens Officiels (BEPC / Bac)', 'school', TRUE, 3),
    ('shop_documents', 'Boutique de Documents', 'storefront', TRUE, 4),
    ('whatsapp_groups', 'Groupes WhatsApp de Classe', 'groups', TRUE, 5),
    ('ai_assistant', 'Assistant IA (Questions/Jour)', 'psychology', FALSE, 6),
    ('olympiads', 'Olympiades & Examens Blancs', 'emoji_events', FALSE, 7),
    ('pdf_export', 'Impression / Export PDF (filigrane)', 'print', FALSE, 8)
ON CONFLICT (feature_key) DO NOTHING;

-- Groupes WhatsApp explicitement demandés par l'utilisateur : gate en plus de la vérification
-- d'appartenance à la classe déjà en place (les deux conditions doivent être vraies).
DROP POLICY IF EXISTS whatsapp_communities_select ON whatsapp_communities;
CREATE POLICY whatsapp_communities_select ON whatsapp_communities FOR SELECT USING (
    is_admin_user()
    OR (
        is_active = true
        AND current_user_has_feature_access('whatsapp_groups')
        AND EXISTS (
            SELECT 1 FROM profiles p JOIN accounts a ON a.id = p.account_id
            WHERE a.auth_user_id = auth.uid() AND p.class_node_id = whatsapp_communities.class_node_id
        )
    )
);
