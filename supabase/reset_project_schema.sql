-- Reset the public schema and recreate the project schema for the Elearning Admin project.
-- WARNING: This removes everything in the public schema, including any unrelated tables,
-- views, functions, triggers, and data.

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Migration 01: Identité, Profils, Abonnements et Paiements

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    password_hash TEXT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE parent_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'actif' CHECK (status IN ('actif', 'archive')),
    subscription_tier TEXT NOT NULL DEFAULT 'gratuit',
    school_year TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE parent_profile_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_account_id UUID NOT NULL REFERENCES parent_accounts(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    relation_type TEXT DEFAULT 'parent',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_account_id, profile_id)
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    device_fingerprint TEXT NOT NULL,
    platform TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE subscription_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    country_id UUID NOT NULL,
    class_node_id UUID NOT NULL,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    duration_days INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE access_matrix (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL,
    access_level TEXT NOT NULL CHECK (access_level IN ('complet', 'limite', 'aucun')),
    limit_parameter JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tier_id, feature_key)
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id),
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'actif' CHECK (status IN ('actif', 'expire', 'essai', 'annule')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE monthly_spend_counter (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    month_year TEXT NOT NULL,
    cumulative_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, month_year)
);

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    operator TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'ambiguous')),
    aggregator_ref TEXT,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE payment_reconciliation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    issue_type TEXT NOT NULL,
    notes TEXT,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE refund_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id),
    reason_category TEXT NOT NULL CHECK (reason_category IN ('technique', 'insatisfaction', 'changement_situation')),
    motive TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'en_attente' CHECK (status IN ('en_attente', 'accepte', 'refuse')),
    decided_by UUID,
    decision_reason TEXT,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE referral_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    code TEXT UNIQUE NOT NULL,
    uses_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migration 02: Arbre Académique et Contenu Pédagogique

CREATE TABLE academic_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    node_type TEXT NOT NULL CHECK (node_type IN ('country', 'section', 'education_type', 'class', 'series')),
    name TEXT NOT NULL,
    code TEXT,
    country_id UUID REFERENCES academic_nodes(id),
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    country_id UUID REFERENCES academic_nodes(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE subject_class_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(subject_id, class_node_id)
);

CREATE TABLE terms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    school_year TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    term_id UUID REFERENCES terms(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    introduction TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    display_order INT DEFAULT 0,
    is_published BOOLEAN DEFAULT FALSE,
    min_subscription_tier TEXT DEFAULT 'gratuit',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE content_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    element_type TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES chapters(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('entraînement', 'évaluation')),
    difficulty TEXT NOT NULL CHECK (difficulty IN ('facile', 'intermédiaire', 'approfondissement')),
    format TEXT NOT NULL CHECK (format IN ('qcm', 'reponse_courte', 'redaction', 'manuscrit_scan', 'flashcard')),
    title TEXT NOT NULL,
    instructions_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    solution_json JSONB DEFAULT '{}'::jsonb,
    min_subscription_tier TEXT DEFAULT 'gratuit',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercise_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE media_library (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filename TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('image', 'video', 'audio', 'document')),
    url TEXT NOT NULL,
    size_bytes BIGINT,
    uploaded_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE validation_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id UUID NOT NULL,
    content_type TEXT NOT NULL CHECK (content_type IN ('lesson', 'exercise')),
    author_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'en_attente' CHECK (status IN ('brouillon', 'en_attente', 'approuve', 'rejete', 'a_corriger')),
    ai_report_json JSONB DEFAULT '{}'::jsonb,
    reviewer_id UUID,
    review_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE official_exams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    exam_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exam_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID NOT NULL REFERENCES official_exams(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    year INT NOT NULL,
    document_url TEXT NOT NULL,
    correction_url TEXT,
    is_correction_unlocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE establishments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE establishment_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    establishment_id UUID NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    year INT NOT NULL,
    document_url TEXT NOT NULL,
    correction_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migration 03: Communauté, Support, Administration, IA et Notifications

CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin_pays', 'admin_contenu', 'enseignant', 'moderateur', 'support')),
    scope_json JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL,
    granted BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(admin_user_id, permission_key)
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID REFERENCES admin_users(id),
    action_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    before_json JSONB,
    after_json JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE teacher_establishments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    establishment_id UUID NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    subjects_scope JSONB DEFAULT '[]'::jsonb,
    classes_scope JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(teacher_id, establishment_id)
);

CREATE TABLE forum_threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE forum_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID NOT NULL REFERENCES forum_threads(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    moderation_status TEXT DEFAULT 'visible' CHECK (moderation_status IN ('visible', 'masque', 'supprime')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE whatsapp_communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    invite_link TEXT NOT NULL,
    member_count_estimate INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('paiement', 'technique', 'contenu', 'autre')),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    requester_type TEXT NOT NULL CHECK (requester_type IN ('eleve', 'parent')),
    status TEXT NOT NULL DEFAULT 'ouvert' CHECK (status IN ('ouvert', 'en_cours', 'repondu', 'ferme')),
    assigned_to UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL CHECK (type IN ('examen_blanc', 'olympiade')),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    pricing_mode TEXT NOT NULL DEFAULT 'inclus' CHECK (pricing_mode IN ('inclus', 'payant')),
    price NUMERIC(10, 2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE event_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    score NUMERIC(5, 2) NOT NULL,
    rank INT,
    percentile NUMERIC(5, 2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE grade_disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_result_id UUID NOT NULL REFERENCES event_results(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ouvert' CHECK (status IN ('ouvert', 'en_cours', 'resolu', 'rejete')),
    original_score NUMERIC(5, 2) NOT NULL,
    revised_score NUMERIC(5, 2),
    assigned_reviewer_id UUID REFERENCES admin_users(id),
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_agent_calls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_type TEXT NOT NULL,
    provider TEXT NOT NULL,
    tokens_used INT NOT NULL DEFAULT 0,
    cost_estimate NUMERIC(8, 5) NOT NULL DEFAULT 0.00000,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_content_review (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id UUID NOT NULL,
    ai_findings_json JSONB NOT NULL,
    accepted BOOLEAN DEFAULT FALSE,
    reviewed_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_key TEXT UNIQUE NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email', 'sms', 'in_app')),
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    template_id UUID REFERENCES notification_templates(id),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    channel TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    opened_at TIMESTAMPTZ
);

CREATE TABLE scheduled_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reminder_type TEXT NOT NULL,
    trigger_date TIMESTAMPTZ NOT NULL,
    sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    urgency TEXT NOT NULL DEFAULT 'info' CHECK (urgency IN ('info', 'warning', 'urgent')),
    target_country_id UUID REFERENCES academic_nodes(id),
    target_class_id UUID REFERENCES academic_nodes(id),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION handle_monthly_spend_accumulation()
RETURNS TRIGGER AS $$
DECLARE
    v_month_year TEXT;
    v_class_node_id UUID;
    v_monthly_price NUMERIC(10, 2);
    v_new_total NUMERIC(10, 2);
    v_mensuel_tier_id UUID;
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.status = 'success') OR (TG_OP = 'UPDATE' AND NEW.status = 'success' AND OLD.status != 'success') THEN
        v_month_year := TO_CHAR(NEW.created_at, 'YYYY-MM');
        SELECT class_node_id INTO v_class_node_id FROM profiles WHERE id = NEW.profile_id;
        INSERT INTO monthly_spend_counter (profile_id, month_year, cumulative_amount, updated_at)
        VALUES (NEW.profile_id, v_month_year, NEW.amount, NOW())
        ON CONFLICT (profile_id, month_year)
        DO UPDATE SET 
            cumulative_amount = monthly_spend_counter.cumulative_amount + EXCLUDED.cumulative_amount,
            updated_at = NOW()
        RETURNING cumulative_amount INTO v_new_total;
        SELECT id, price INTO v_mensuel_tier_id, v_monthly_price 
        FROM subscription_tiers 
        WHERE class_node_id = v_class_node_id AND name = 'mensuel'
        LIMIT 1;
        IF v_monthly_price IS NOT NULL AND v_new_total >= v_monthly_price THEN
            UPDATE profiles 
            SET subscription_tier = 'mensuel', updated_at = NOW()
            WHERE id = NEW.profile_id;
            INSERT INTO subscriptions (profile_id, tier_id, start_date, end_date, status)
            VALUES (
                NEW.profile_id, 
                v_mensuel_tier_id, 
                NOW(), 
                (DATE_TRUNC('month', NOW()) + INTERVAL '1 month' - INTERVAL '1 day')::TIMESTAMPTZ,
                'actif'
            );
            INSERT INTO notification_log (profile_id, title, body, channel)
            VALUES (
                NEW.profile_id,
                'Félicitations ! Accès Mensuel Débloqué',
                'Vous avez cumulé assez de paiements ce mois-ci pour débloquer l''accès complet jusqu''à la fin du mois !',
                'in_app'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_monthly_spend_accumulation
AFTER INSERT OR UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION handle_monthly_spend_accumulation();

CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        NULLIF(current_setting('app.current_admin_id', true), '')::UUID,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)::jsonb ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_academic_nodes AFTER INSERT OR UPDATE OR DELETE ON academic_nodes FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_subscription_tiers AFTER INSERT OR UPDATE OR DELETE ON subscription_tiers FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_access_matrix AFTER INSERT OR UPDATE OR DELETE ON access_matrix FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_admin_users AFTER INSERT OR UPDATE OR DELETE ON admin_users FOR EACH ROW EXECUTE FUNCTION log_admin_action();

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_spend_counter ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY super_admin_transactions_policy ON transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admin_users 
            WHERE id = NULLIF(current_setting('app.current_admin_id', true), '')::UUID 
            AND role = 'super_admin'
        )
    );

CREATE POLICY super_admin_audit_log_policy ON audit_log
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admin_users 
            WHERE id = NULLIF(current_setting('app.current_admin_id', true), '')::UUID 
            AND role = 'super_admin'
        )
    );

-- Initial seed data

DO $$
DECLARE
    v_country_id UUID;
    v_francophone_id UUID;
    v_anglophone_id UUID;
    v_gen_fr_id UUID;
    v_tech_fr_id UUID;
    v_3e_id UUID;
    v_2nde_id UUID;
    v_1ere_id UUID;
    v_tle_id UUID;
    v_tle_c_id UUID;
    v_tle_a4_id UUID;
    v_tle_ti_id UUID;
    v_math_id UUID;
    v_physique_id UUID;
    v_svt_id UUID;
    v_français_id UUID;
    v_histo_id UUID;
    v_tier_gratuit_id UUID;
    v_tier_journalier_id UUID;
    v_tier_mensuel_id UUID;
    v_super_admin_id UUID;
BEGIN
    INSERT INTO academic_nodes (node_type, name, code, parent_id)
    VALUES ('country', 'Cameroun', 'CM', NULL)
    RETURNING id INTO v_country_id;

    UPDATE academic_nodes SET country_id = v_country_id WHERE id = v_country_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('section', 'Section Francophone', 'FR', v_country_id, v_country_id)
    RETURNING id INTO v_francophone_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('section', 'Section Anglophone (Sub-system)', 'EN', v_country_id, v_country_id)
    RETURNING id INTO v_anglophone_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('education_type', 'Enseignement Général', 'GEN_FR', v_francophone_id, v_country_id)
    RETURNING id INTO v_gen_fr_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('education_type', 'Enseignement Technique', 'TECH_FR', v_francophone_id, v_country_id)
    RETURNING id INTO v_tech_fr_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 3ème', '3E', v_gen_fr_id, v_country_id, 4)
    RETURNING id INTO v_3e_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 2nde', '2NDE', v_gen_fr_id, v_country_id, 5)
    RETURNING id INTO v_2nde_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 1ère', '1ERE', v_gen_fr_id, v_country_id, 6)
    RETURNING id INTO v_1ere_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de Terminale', 'TLE', v_gen_fr_id, v_country_id, 7)
    RETURNING id INTO v_tle_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale C (Scientifique Math/Physique)', 'TLE_C', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_c_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale A4 (Littéraire)', 'TLE_A4', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_a4_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale TI (Technologies de l''Information)', 'TLE_TI', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_ti_id;

    INSERT INTO subjects (name, code, country_id) VALUES ('Mathématiques', 'MATH', v_country_id) RETURNING id INTO v_math_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Physique-Chimie', 'PHY_CHIM', v_country_id) RETURNING id INTO v_physique_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Sciences de la Vie et de la Terre', 'SVT', v_country_id) RETURNING id INTO v_svt_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Français & Littérature', 'FRANCAIS', v_country_id) RETURNING id INTO v_français_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Histoire - Géographie', 'HIST_GEO', v_country_id) RETURNING id INTO v_histo_id;

    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_math_id, v_3e_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_math_id, v_tle_c_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_physique_id, v_tle_c_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_français_id, v_3e_id);

    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('gratuit', v_country_id, v_3e_id, 0.00, 0)
    RETURNING id INTO v_tier_gratuit_id;

    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('journalier', v_country_id, v_3e_id, 150.00, 1)
    RETURNING id INTO v_tier_journalier_id;

    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('mensuel', v_country_id, v_3e_id, 2500.00, 30)
    RETURNING id INTO v_tier_mensuel_id;

    INSERT INTO access_matrix (tier_id, feature_key, access_level, limit_parameter) VALUES
    (v_tier_gratuit_id, 'courses', 'limite', '{"chapters_limit": 2}'::jsonb),
    (v_tier_gratuit_id, 'exercises_training', 'limite', '{"daily_limit": 5}'::jsonb),
    (v_tier_gratuit_id, 'exercises_evaluation', 'aucun', '{}'::jsonb),
    (v_tier_gratuit_id, 'official_exams', 'aucun', '{}'::jsonb),
    (v_tier_gratuit_id, 'ai_assistant', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'official_exams', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'ai_assistant', 'limite', '{"daily_questions": 3}'::jsonb),
    (v_tier_mensuel_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'official_exams', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'ai_assistant', 'complet', '{}'::jsonb);

    INSERT INTO admin_users (email, first_name, last_name, role)
    VALUES ('ahdybau@gmail.com', 'Super', 'Administrateur', 'super_admin')
    RETURNING id INTO v_super_admin_id;
END $$;
