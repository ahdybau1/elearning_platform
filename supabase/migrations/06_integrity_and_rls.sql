-- Migration 06: Intégrité référentielle manquante + RLS complète (auth.uid()) sur tout le schéma
--
-- Corrige les points 2.3, 2.4 et 2.5 du cahier des charges MVP :
--   - profiles.class_node_id / subscription_tiers.class_node_id / subscription_tiers.country_id
--     n'avaient jamais reçu leur contrainte FOREIGN KEY (academic_nodes est créée dans une
--     migration postérieure à 01) ;
--   - la quasi-totalité du schéma n'avait aucun RLS ;
--   - les rares policies existantes (04_rls_triggers_seed.sql) reposaient sur
--     current_setting('app.current_admin_id', true), jamais défini par aucun code client, donc
--     inertes (elles n'ont jamais laissé passer personne).
--
-- Rejouable sans erreur : DROP POLICY IF EXISTS avant chaque CREATE POLICY, DROP CONSTRAINT IF
-- EXISTS avant chaque ADD CONSTRAINT, ALTER TABLE ... ENABLE ROW LEVEL SECURITY est déjà idempotent
-- nativement. Voir 01_rls_security.md et 02_migration_discipline.md.

-- ============================================================================
-- 1. CONTRAINTES FK MANQUANTES (section 6.4 du CDC MVP)
-- ============================================================================

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS fk_profiles_class_node;
ALTER TABLE profiles
    ADD CONSTRAINT fk_profiles_class_node
    FOREIGN KEY (class_node_id) REFERENCES academic_nodes(id);

ALTER TABLE subscription_tiers DROP CONSTRAINT IF EXISTS fk_tiers_class_node;
ALTER TABLE subscription_tiers
    ADD CONSTRAINT fk_tiers_class_node
    FOREIGN KEY (class_node_id) REFERENCES academic_nodes(id);

ALTER TABLE subscription_tiers DROP CONSTRAINT IF EXISTS fk_tiers_country;
ALTER TABLE subscription_tiers
    ADD CONSTRAINT fk_tiers_country
    FOREIGN KEY (country_id) REFERENCES academic_nodes(id);

-- ============================================================================
-- 2. FONCTIONS UTILITAIRES RLS (SECURITY DEFINER — voir 01_rls_security.md)
-- ============================================================================

CREATE OR REPLACE FUNCTION is_admin_user()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM admin_users
        WHERE auth_user_id = auth.uid() AND is_active = true
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION has_admin_role(VARIADIC roles TEXT[])
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM admin_users
        WHERE auth_user_id = auth.uid() AND is_active = true AND role = ANY(roles)
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION owns_account(p_account_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM accounts WHERE id = p_account_id AND auth_user_id = auth.uid()
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION owns_profile(p_profile_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles p
        JOIN accounts a ON a.id = p.account_id
        WHERE p.id = p_profile_id AND a.auth_user_id = auth.uid()
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION current_user_has_feature_access(p_feature_key TEXT)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM profiles p
        JOIN accounts a ON a.id = p.account_id
        JOIN subscription_tiers st ON st.class_node_id = p.class_node_id AND st.name = p.subscription_tier
        JOIN access_matrix am ON am.tier_id = st.id
        WHERE a.auth_user_id = auth.uid()
          AND p.status = 'actif'
          AND am.feature_key = p_feature_key
          AND am.access_level != 'aucun'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- ============================================================================
-- 3. ENABLE ROW LEVEL SECURITY (idempotent) SUR TOUTES LES TABLES
-- ============================================================================

ALTER TABLE academic_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE subject_class_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_profile_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_spend_counter ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_reconciliation ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE validation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE official_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE establishments ENABLE ROW LEVEL SECURITY;
ALTER TABLE establishment_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_establishments ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE grade_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_agent_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_content_review ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE charity_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_records ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. SUPPRESSION DES ANCIENNES POLICIES MORTES (04_rls_triggers_seed.sql, current_setting-based)
-- ============================================================================

DROP POLICY IF EXISTS admin_users_select_policy ON admin_users;
DROP POLICY IF EXISTS super_admin_transactions_policy ON transactions;
DROP POLICY IF EXISTS super_admin_audit_log_policy ON audit_log;
-- Au cas où ce fichier est rejoué après une exécution antérieure de reset_project_schema.sql
DROP POLICY IF EXISTS admin_users_all_policy ON admin_users;
DROP POLICY IF EXISTS subscription_tiers_all_policy ON subscription_tiers;
DROP POLICY IF EXISTS access_matrix_all_policy ON access_matrix;
DROP POLICY IF EXISTS transactions_all_policy ON transactions;
DROP POLICY IF EXISTS monthly_spend_counter_all_policy ON monthly_spend_counter;
DROP POLICY IF EXISTS audit_log_all_policy ON audit_log;

-- ============================================================================
-- 5. POLICIES — un DROP POLICY IF EXISTS puis un CREATE POLICY par règle, pour rester rejouable.
-- ============================================================================

DROP POLICY IF EXISTS academic_nodes_select ON academic_nodes;
CREATE POLICY academic_nodes_select ON academic_nodes FOR SELECT USING (is_active = true OR is_admin_user());
DROP POLICY IF EXISTS academic_nodes_admin_write ON academic_nodes;
CREATE POLICY academic_nodes_admin_write ON academic_nodes FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS academic_nodes_admin_update ON academic_nodes;
CREATE POLICY academic_nodes_admin_update ON academic_nodes FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS academic_nodes_admin_delete ON academic_nodes;
CREATE POLICY academic_nodes_admin_delete ON academic_nodes FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS subjects_select ON subjects;
CREATE POLICY subjects_select ON subjects FOR SELECT USING (true);
DROP POLICY IF EXISTS subjects_admin_write ON subjects;
CREATE POLICY subjects_admin_write ON subjects FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS subjects_admin_update ON subjects;
CREATE POLICY subjects_admin_update ON subjects FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS subjects_admin_delete ON subjects;
CREATE POLICY subjects_admin_delete ON subjects FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS subject_class_links_select ON subject_class_links;
CREATE POLICY subject_class_links_select ON subject_class_links FOR SELECT USING (true);
DROP POLICY IF EXISTS subject_class_links_admin_write ON subject_class_links;
CREATE POLICY subject_class_links_admin_write ON subject_class_links FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS subject_class_links_admin_update ON subject_class_links;
CREATE POLICY subject_class_links_admin_update ON subject_class_links FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS subject_class_links_admin_delete ON subject_class_links;
CREATE POLICY subject_class_links_admin_delete ON subject_class_links FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS terms_select ON terms;
CREATE POLICY terms_select ON terms FOR SELECT USING (true);
DROP POLICY IF EXISTS terms_admin_write ON terms;
CREATE POLICY terms_admin_write ON terms FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS terms_admin_update ON terms;
CREATE POLICY terms_admin_update ON terms FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS terms_admin_delete ON terms;
CREATE POLICY terms_admin_delete ON terms FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS accounts_select ON accounts;
CREATE POLICY accounts_select ON accounts FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());
DROP POLICY IF EXISTS accounts_insert ON accounts;
CREATE POLICY accounts_insert ON accounts FOR INSERT WITH CHECK (auth_user_id = auth.uid());
DROP POLICY IF EXISTS accounts_update ON accounts;
CREATE POLICY accounts_update ON accounts FOR UPDATE USING (auth_user_id = auth.uid() OR is_admin_user());

DROP POLICY IF EXISTS parent_accounts_admin_select ON parent_accounts;
CREATE POLICY parent_accounts_admin_select ON parent_accounts FOR SELECT USING (is_admin_user());

DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles FOR SELECT USING (owns_profile(id) OR is_admin_user());
DROP POLICY IF EXISTS profiles_insert ON profiles;
CREATE POLICY profiles_insert ON profiles FOR INSERT WITH CHECK (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS profiles_update ON profiles;
CREATE POLICY profiles_update ON profiles FOR UPDATE USING (owns_profile(id) OR is_admin_user());

DROP POLICY IF EXISTS parent_profile_links_select ON parent_profile_links;
CREATE POLICY parent_profile_links_select ON parent_profile_links FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS parent_profile_links_admin_write ON parent_profile_links;
CREATE POLICY parent_profile_links_admin_write ON parent_profile_links FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS parent_profile_links_admin_update ON parent_profile_links;
CREATE POLICY parent_profile_links_admin_update ON parent_profile_links FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS sessions_select ON sessions;
CREATE POLICY sessions_select ON sessions FOR SELECT USING (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS sessions_update ON sessions;
CREATE POLICY sessions_update ON sessions FOR UPDATE USING (owns_account(account_id) OR is_admin_user());

DROP POLICY IF EXISTS subscription_tiers_select ON subscription_tiers;
CREATE POLICY subscription_tiers_select ON subscription_tiers FOR SELECT USING (true);
DROP POLICY IF EXISTS subscription_tiers_super_admin_write ON subscription_tiers;
CREATE POLICY subscription_tiers_super_admin_write ON subscription_tiers FOR INSERT WITH CHECK (has_admin_role('super_admin'));
DROP POLICY IF EXISTS subscription_tiers_super_admin_update ON subscription_tiers;
CREATE POLICY subscription_tiers_super_admin_update ON subscription_tiers FOR UPDATE USING (has_admin_role('super_admin'));
DROP POLICY IF EXISTS subscription_tiers_super_admin_delete ON subscription_tiers;
CREATE POLICY subscription_tiers_super_admin_delete ON subscription_tiers FOR DELETE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS access_matrix_select ON access_matrix;
CREATE POLICY access_matrix_select ON access_matrix FOR SELECT USING (true);
DROP POLICY IF EXISTS access_matrix_super_admin_write ON access_matrix;
CREATE POLICY access_matrix_super_admin_write ON access_matrix FOR INSERT WITH CHECK (has_admin_role('super_admin'));
DROP POLICY IF EXISTS access_matrix_super_admin_update ON access_matrix;
CREATE POLICY access_matrix_super_admin_update ON access_matrix FOR UPDATE USING (has_admin_role('super_admin'));
DROP POLICY IF EXISTS access_matrix_super_admin_delete ON access_matrix;
CREATE POLICY access_matrix_super_admin_delete ON access_matrix FOR DELETE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS subscriptions_select ON subscriptions;
CREATE POLICY subscriptions_select ON subscriptions FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

DROP POLICY IF EXISTS monthly_spend_counter_select ON monthly_spend_counter;
CREATE POLICY monthly_spend_counter_select ON monthly_spend_counter FOR SELECT USING (owns_profile(profile_id) OR has_admin_role('super_admin'));

DROP POLICY IF EXISTS transactions_select ON transactions;
CREATE POLICY transactions_select ON transactions FOR SELECT USING (owns_profile(profile_id) OR has_admin_role('super_admin'));
DROP POLICY IF EXISTS transactions_super_admin_update ON transactions;
CREATE POLICY transactions_super_admin_update ON transactions FOR UPDATE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS payment_reconciliation_super_admin_select ON payment_reconciliation;
CREATE POLICY payment_reconciliation_super_admin_select ON payment_reconciliation FOR SELECT USING (has_admin_role('super_admin'));
DROP POLICY IF EXISTS payment_reconciliation_super_admin_insert ON payment_reconciliation;
CREATE POLICY payment_reconciliation_super_admin_insert ON payment_reconciliation FOR INSERT WITH CHECK (has_admin_role('super_admin'));
DROP POLICY IF EXISTS payment_reconciliation_super_admin_update ON payment_reconciliation;
CREATE POLICY payment_reconciliation_super_admin_update ON payment_reconciliation FOR UPDATE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS refund_requests_select ON refund_requests;
CREATE POLICY refund_requests_select ON refund_requests FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS refund_requests_insert ON refund_requests;
CREATE POLICY refund_requests_insert ON refund_requests FOR INSERT WITH CHECK (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS refund_requests_admin_update ON refund_requests;
CREATE POLICY refund_requests_admin_update ON refund_requests FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS referral_codes_select ON referral_codes;
CREATE POLICY referral_codes_select ON referral_codes FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS referral_codes_insert ON referral_codes;
CREATE POLICY referral_codes_insert ON referral_codes FOR INSERT WITH CHECK (owns_profile(profile_id));
DROP POLICY IF EXISTS referral_codes_admin_update ON referral_codes;
CREATE POLICY referral_codes_admin_update ON referral_codes FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS chapters_select ON chapters;
CREATE POLICY chapters_select ON chapters FOR SELECT USING (is_active = true OR is_admin_user());
DROP POLICY IF EXISTS chapters_admin_write ON chapters;
CREATE POLICY chapters_admin_write ON chapters FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS chapters_admin_update ON chapters;
CREATE POLICY chapters_admin_update ON chapters FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS chapters_admin_delete ON chapters;
CREATE POLICY chapters_admin_delete ON chapters FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS lessons_select ON lessons;
CREATE POLICY lessons_select ON lessons FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND (min_subscription_tier = 'gratuit' OR current_user_has_feature_access('courses'))
    )
);
DROP POLICY IF EXISTS lessons_admin_write ON lessons;
CREATE POLICY lessons_admin_write ON lessons FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS lessons_admin_update ON lessons;
CREATE POLICY lessons_admin_update ON lessons FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS lessons_admin_delete ON lessons;
CREATE POLICY lessons_admin_delete ON lessons FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS content_catalog_select ON content_catalog;
CREATE POLICY content_catalog_select ON content_catalog FOR SELECT USING (true);
DROP POLICY IF EXISTS content_catalog_admin_write ON content_catalog;
CREATE POLICY content_catalog_admin_write ON content_catalog FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS content_catalog_admin_update ON content_catalog;
CREATE POLICY content_catalog_admin_update ON content_catalog FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS content_catalog_admin_delete ON content_catalog;
CREATE POLICY content_catalog_admin_delete ON content_catalog FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS exercises_select ON exercises;
CREATE POLICY exercises_select ON exercises FOR SELECT USING (
    is_admin_user()
    OR (
        min_subscription_tier = 'gratuit'
        OR (type = 'entraînement' AND current_user_has_feature_access('exercises_training'))
        OR (type = 'évaluation' AND current_user_has_feature_access('exercises_evaluation'))
    )
);
DROP POLICY IF EXISTS exercises_admin_write ON exercises;
CREATE POLICY exercises_admin_write ON exercises FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS exercises_admin_update ON exercises;
CREATE POLICY exercises_admin_update ON exercises FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS exercises_admin_delete ON exercises;
CREATE POLICY exercises_admin_delete ON exercises FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS exercise_versions_admin_all ON exercise_versions;
CREATE POLICY exercise_versions_admin_all ON exercise_versions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS media_library_select ON media_library;
CREATE POLICY media_library_select ON media_library FOR SELECT USING (true);
DROP POLICY IF EXISTS media_library_admin_write ON media_library;
CREATE POLICY media_library_admin_write ON media_library FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS media_library_admin_update ON media_library;
CREATE POLICY media_library_admin_update ON media_library FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS media_library_admin_delete ON media_library;
CREATE POLICY media_library_admin_delete ON media_library FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS validation_queue_admin_all ON validation_queue;
CREATE POLICY validation_queue_admin_all ON validation_queue FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS official_exams_select ON official_exams;
CREATE POLICY official_exams_select ON official_exams FOR SELECT USING (true);
DROP POLICY IF EXISTS official_exams_admin_write ON official_exams;
CREATE POLICY official_exams_admin_write ON official_exams FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS official_exams_admin_update ON official_exams;
CREATE POLICY official_exams_admin_update ON official_exams FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS official_exams_admin_delete ON official_exams;
CREATE POLICY official_exams_admin_delete ON official_exams FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS exam_papers_select ON exam_papers;
CREATE POLICY exam_papers_select ON exam_papers FOR SELECT USING (true);
DROP POLICY IF EXISTS exam_papers_admin_write ON exam_papers;
CREATE POLICY exam_papers_admin_write ON exam_papers FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS exam_papers_admin_update ON exam_papers;
CREATE POLICY exam_papers_admin_update ON exam_papers FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS exam_papers_admin_delete ON exam_papers;
CREATE POLICY exam_papers_admin_delete ON exam_papers FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS establishments_select ON establishments;
CREATE POLICY establishments_select ON establishments FOR SELECT USING (true);
DROP POLICY IF EXISTS establishments_admin_write ON establishments;
CREATE POLICY establishments_admin_write ON establishments FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS establishments_admin_update ON establishments;
CREATE POLICY establishments_admin_update ON establishments FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS establishments_admin_delete ON establishments;
CREATE POLICY establishments_admin_delete ON establishments FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS establishment_papers_select ON establishment_papers;
CREATE POLICY establishment_papers_select ON establishment_papers FOR SELECT USING (true);
DROP POLICY IF EXISTS establishment_papers_admin_write ON establishment_papers;
CREATE POLICY establishment_papers_admin_write ON establishment_papers FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS establishment_papers_admin_update ON establishment_papers;
CREATE POLICY establishment_papers_admin_update ON establishment_papers FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS establishment_papers_admin_delete ON establishment_papers;
CREATE POLICY establishment_papers_admin_delete ON establishment_papers FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS admin_users_select ON admin_users;
CREATE POLICY admin_users_select ON admin_users FOR SELECT USING (auth_user_id = auth.uid() OR has_admin_role('super_admin'));
DROP POLICY IF EXISTS admin_users_super_admin_insert ON admin_users;
CREATE POLICY admin_users_super_admin_insert ON admin_users FOR INSERT WITH CHECK (has_admin_role('super_admin'));
DROP POLICY IF EXISTS admin_users_super_admin_update ON admin_users;
CREATE POLICY admin_users_super_admin_update ON admin_users FOR UPDATE USING (has_admin_role('super_admin'));
DROP POLICY IF EXISTS admin_users_super_admin_delete ON admin_users;
CREATE POLICY admin_users_super_admin_delete ON admin_users FOR DELETE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS admin_permissions_select ON admin_permissions;
CREATE POLICY admin_permissions_select ON admin_permissions FOR SELECT USING (
    has_admin_role('super_admin') OR admin_user_id IN (SELECT id FROM admin_users WHERE auth_user_id = auth.uid())
);
DROP POLICY IF EXISTS admin_permissions_super_admin_write ON admin_permissions;
CREATE POLICY admin_permissions_super_admin_write ON admin_permissions FOR INSERT WITH CHECK (has_admin_role('super_admin'));
DROP POLICY IF EXISTS admin_permissions_super_admin_update ON admin_permissions;
CREATE POLICY admin_permissions_super_admin_update ON admin_permissions FOR UPDATE USING (has_admin_role('super_admin'));
DROP POLICY IF EXISTS admin_permissions_super_admin_delete ON admin_permissions;
CREATE POLICY admin_permissions_super_admin_delete ON admin_permissions FOR DELETE USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS audit_log_select ON audit_log;
CREATE POLICY audit_log_select ON audit_log FOR SELECT USING (
    has_admin_role('super_admin') OR admin_user_id IN (SELECT id FROM admin_users WHERE auth_user_id = auth.uid())
);

DROP POLICY IF EXISTS teacher_establishments_admin_all ON teacher_establishments;
CREATE POLICY teacher_establishments_admin_all ON teacher_establishments FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS forum_threads_select ON forum_threads;
CREATE POLICY forum_threads_select ON forum_threads FOR SELECT USING (
    is_admin_user()
    OR EXISTS (
        SELECT 1 FROM profiles p JOIN accounts a ON a.id = p.account_id
        WHERE a.auth_user_id = auth.uid() AND p.class_node_id = forum_threads.class_node_id
    )
);
DROP POLICY IF EXISTS forum_threads_insert ON forum_threads;
CREATE POLICY forum_threads_insert ON forum_threads FOR INSERT WITH CHECK (owns_account(author_id));
DROP POLICY IF EXISTS forum_threads_admin_update ON forum_threads;
CREATE POLICY forum_threads_admin_update ON forum_threads FOR UPDATE USING (is_admin_user() OR owns_account(author_id));

DROP POLICY IF EXISTS forum_posts_select ON forum_posts;
CREATE POLICY forum_posts_select ON forum_posts FOR SELECT USING (
    is_admin_user()
    OR (
        moderation_status != 'supprime'
        AND EXISTS (
            SELECT 1 FROM forum_threads t
            JOIN profiles p ON p.class_node_id = t.class_node_id
            JOIN accounts a ON a.id = p.account_id
            WHERE t.id = forum_posts.thread_id AND a.auth_user_id = auth.uid()
        )
    )
);
DROP POLICY IF EXISTS forum_posts_insert ON forum_posts;
CREATE POLICY forum_posts_insert ON forum_posts FOR INSERT WITH CHECK (owns_account(author_id));
DROP POLICY IF EXISTS forum_posts_admin_update ON forum_posts;
CREATE POLICY forum_posts_admin_update ON forum_posts FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS forum_posts_admin_delete ON forum_posts;
CREATE POLICY forum_posts_admin_delete ON forum_posts FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS whatsapp_communities_select ON whatsapp_communities;
CREATE POLICY whatsapp_communities_select ON whatsapp_communities FOR SELECT USING (
    is_admin_user()
    OR (
        is_active = true
        AND EXISTS (
            SELECT 1 FROM profiles p JOIN accounts a ON a.id = p.account_id
            WHERE a.auth_user_id = auth.uid() AND p.class_node_id = whatsapp_communities.class_node_id
        )
    )
);
DROP POLICY IF EXISTS whatsapp_communities_admin_write ON whatsapp_communities;
CREATE POLICY whatsapp_communities_admin_write ON whatsapp_communities FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS whatsapp_communities_admin_update ON whatsapp_communities;
CREATE POLICY whatsapp_communities_admin_update ON whatsapp_communities FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS whatsapp_communities_admin_delete ON whatsapp_communities;
CREATE POLICY whatsapp_communities_admin_delete ON whatsapp_communities FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS support_tickets_select ON support_tickets;
CREATE POLICY support_tickets_select ON support_tickets FOR SELECT USING (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS support_tickets_insert ON support_tickets;
CREATE POLICY support_tickets_insert ON support_tickets FOR INSERT WITH CHECK (owns_account(account_id));
DROP POLICY IF EXISTS support_tickets_admin_update ON support_tickets;
CREATE POLICY support_tickets_admin_update ON support_tickets FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS events_select ON events;
CREATE POLICY events_select ON events FOR SELECT USING (true);
DROP POLICY IF EXISTS events_admin_write ON events;
CREATE POLICY events_admin_write ON events FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS events_admin_update ON events;
CREATE POLICY events_admin_update ON events FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS events_admin_delete ON events;
CREATE POLICY events_admin_delete ON events FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS event_results_select ON event_results;
CREATE POLICY event_results_select ON event_results FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS event_results_admin_write ON event_results;
CREATE POLICY event_results_admin_write ON event_results FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS event_results_admin_update ON event_results;
CREATE POLICY event_results_admin_update ON event_results FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS grade_disputes_select ON grade_disputes;
CREATE POLICY grade_disputes_select ON grade_disputes FOR SELECT USING (
    is_admin_user()
    OR EXISTS (SELECT 1 FROM event_results er WHERE er.id = grade_disputes.event_result_id AND owns_profile(er.profile_id))
);
DROP POLICY IF EXISTS grade_disputes_insert ON grade_disputes;
CREATE POLICY grade_disputes_insert ON grade_disputes FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM event_results er WHERE er.id = grade_disputes.event_result_id AND owns_profile(er.profile_id))
);
DROP POLICY IF EXISTS grade_disputes_admin_update ON grade_disputes;
CREATE POLICY grade_disputes_admin_update ON grade_disputes FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS ai_agent_calls_super_admin_select ON ai_agent_calls;
CREATE POLICY ai_agent_calls_super_admin_select ON ai_agent_calls FOR SELECT USING (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_content_review_admin_all ON ai_content_review;
CREATE POLICY ai_content_review_admin_all ON ai_content_review FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS notification_templates_admin_all ON notification_templates;
CREATE POLICY notification_templates_admin_all ON notification_templates FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS notification_log_select ON notification_log;
CREATE POLICY notification_log_select ON notification_log FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

DROP POLICY IF EXISTS scheduled_reminders_select ON scheduled_reminders;
CREATE POLICY scheduled_reminders_select ON scheduled_reminders FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

DROP POLICY IF EXISTS announcements_select ON announcements;
CREATE POLICY announcements_select ON announcements FOR SELECT USING (true);
DROP POLICY IF EXISTS announcements_admin_write ON announcements;
CREATE POLICY announcements_admin_write ON announcements FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS announcements_admin_update ON announcements;
CREATE POLICY announcements_admin_update ON announcements FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS announcements_admin_delete ON announcements;
CREATE POLICY announcements_admin_delete ON announcements FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS shop_documents_select ON shop_documents;
CREATE POLICY shop_documents_select ON shop_documents FOR SELECT USING (is_active = true OR is_admin_user());
DROP POLICY IF EXISTS shop_documents_admin_write ON shop_documents;
CREATE POLICY shop_documents_admin_write ON shop_documents FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS shop_documents_admin_update ON shop_documents;
CREATE POLICY shop_documents_admin_update ON shop_documents FOR UPDATE USING (is_admin_user());
DROP POLICY IF EXISTS shop_documents_admin_delete ON shop_documents;
CREATE POLICY shop_documents_admin_delete ON shop_documents FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS charity_campaigns_select ON charity_campaigns;
CREATE POLICY charity_campaigns_select ON charity_campaigns FOR SELECT USING (is_active = true OR is_admin_user());
DROP POLICY IF EXISTS charity_campaigns_admin_write ON charity_campaigns;
CREATE POLICY charity_campaigns_admin_write ON charity_campaigns FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS charity_campaigns_admin_update ON charity_campaigns;
CREATE POLICY charity_campaigns_admin_update ON charity_campaigns FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS donations_admin_all ON donations;
CREATE POLICY donations_admin_all ON donations FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS school_years_select ON school_years;
CREATE POLICY school_years_select ON school_years FOR SELECT USING (true);
DROP POLICY IF EXISTS school_years_admin_write ON school_years;
CREATE POLICY school_years_admin_write ON school_years FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS school_years_admin_update ON school_years;
CREATE POLICY school_years_admin_update ON school_years FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS promotion_records_select ON promotion_records;
CREATE POLICY promotion_records_select ON promotion_records FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS promotion_records_admin_write ON promotion_records;
CREATE POLICY promotion_records_admin_write ON promotion_records FOR INSERT WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS promotion_records_admin_update ON promotion_records;
CREATE POLICY promotion_records_admin_update ON promotion_records FOR UPDATE USING (is_admin_user());

-- ============================================================================
-- 6. ÉTAPE MANUELLE OBLIGATOIRE APRÈS EXÉCUTION DE CETTE MIGRATION
-- ============================================================================
-- Identique à reset_project_schema.sql : tant que admin_users.auth_user_id n'est pas renseigné pour
-- le compte super-admin existant, is_admin_user()/has_admin_role() renvoient toujours faux pour lui
-- et l'app admin reste bloquée en lecture — c'est le comportement attendu (voir 03_auth_flow.md).
--
-- 1. Créer un utilisateur Supabase Auth réel pour l'email admin existant, avec un mot de passe fort.
-- 2. UPDATE admin_users SET auth_user_id = (SELECT id FROM auth.users WHERE email = admin_users.email)
--    WHERE email = 'VOTRE_EMAIL_ADMIN';
