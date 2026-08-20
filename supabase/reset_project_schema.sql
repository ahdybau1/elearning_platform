-- Reset the public schema and recreate the project schema for the Elearning Admin project.
-- WARNING: This removes everything in the public schema, including any unrelated tables,
-- views, functions, triggers, and data.

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Accorder les privilèges d'accès au schéma public pour Supabase (anon, authenticated, service_role)
-- NOTE : ces GRANT ne sont pas la faille de sécurité — c'est le modèle standard Supabase (GRANT large
-- au niveau table, RLS comme véritable filtre ligne par ligne). La sécurité réelle est appliquée par
-- les policies RLS plus bas, pas par ces GRANT.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role, postgres;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role, postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role, postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role, postgres;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;


-- ============================================================================
-- ARBRE ACADÉMIQUE (créé en premier : tout le reste en dépend par FK)
-- ============================================================================

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
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
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
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- IDENTITÉ, PROFILS, ABONNEMENTS ET PAIEMENTS
-- ============================================================================

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE REFERENCES auth.users(id),
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
    auth_user_id UUID UNIQUE REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    phone TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id),
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
    country_id UUID NOT NULL REFERENCES academic_nodes(id),
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id),
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

-- Catalogue des fonctionnalités affichées dans la Matrice de Droits, géré par l'admin lui-même
-- (avant : liste codée en dur côté Dart, aucun moyen d'en ajouter/modifier/supprimer depuis l'UI).
CREATE TABLE matrix_features (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    icon_name TEXT NOT NULL DEFAULT 'lock',
    -- Déclaratif uniquement : ce n'est PAS ce booléen qui applique une restriction, seule une
    -- policy RLS utilisant current_user_has_feature_access() le fait réellement. Il permet à l'UI
    -- de signaler honnêtement les fonctionnalités pas encore appliquées techniquement.
    is_enforced BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
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

-- ============================================================================
-- CONTENU PÉDAGOGIQUE
-- ============================================================================

CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    -- Classe/Série précise à laquelle ce chapitre appartient (Section 3.2 du CDC). Sans cette
    -- colonne, un chapitre créé sous une matière liée à plusieurs classes (via
    -- subject_class_links, qui ne fait qu'indiquer "cette matière est enseignée dans cette
    -- classe") apparaîtrait dans toutes ces classes, même quand leurs programmes n'ont rien à
    -- voir (ex: 3e vs Terminale C). Le vrai jumelage volontaire de classes se fait par
    -- duplication explicite (duplicate_chapter_to_class), jamais par ce partage implicite.
    class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    term_id UUID REFERENCES terms(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    introduction TEXT,
    intro_media_json JSONB DEFAULT '[]'::jsonb,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chapters_class_node_id ON chapters(class_node_id);

CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    display_order INT DEFAULT 0,
    is_published BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    min_subscription_tier TEXT DEFAULT 'gratuit',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lesson_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
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
    -- Classe/Série + Trimestre ciblés (Section 3.2 du CDC, même logique que chapters.class_node_id
    -- ci-dessus). Pour un exercice Niveau 1/2 (lié à une leçon/un chapitre), ces deux colonnes sont
    -- automatiquement dérivées du chapitre parent par le trigger trg_sync_exercise_class_scope —
    -- ne jamais les écrire directement dans ce cas. Pour un exercice Niveau 3 (indépendant, type
    -- examen, ni chapitre ni leçon), l'admin les renseigne explicitement : c'est le seul moyen
    -- d'indiquer quel niveau cible un exercice type examen.
    class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    term_id UUID REFERENCES terms(id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN ('entraînement', 'évaluation')),
    difficulty TEXT NOT NULL CHECK (difficulty IN ('facile', 'intermédiaire', 'approfondissement')),
    format TEXT NOT NULL CHECK (format IN ('qcm', 'reponse_courte', 'redaction', 'manuscrit_scan', 'flashcard')),
    title TEXT NOT NULL,
    instructions_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    solution_json JSONB DEFAULT '{}'::jsonb,
    min_subscription_tier TEXT DEFAULT 'gratuit',
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exercises_class_node_id ON exercises(class_node_id);

CREATE TABLE exercise_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dérive class_node_id/term_id depuis le chapitre parent à chaque INSERT/UPDATE d'un exercice
-- Niveau 1/2 (voir migration 17_exercises_class_scoping.sql). Point unique de vérité plutôt que
-- de dupliquer la règle dans chaque endroit du code Dart qui crée/modifie un exercice.
CREATE OR REPLACE FUNCTION sync_exercise_class_scope() RETURNS TRIGGER AS $$
DECLARE
    v_class_node_id UUID;
    v_term_id UUID;
BEGIN
    IF NEW.chapter_id IS NOT NULL THEN
        SELECT class_node_id, term_id INTO v_class_node_id, v_term_id
        FROM chapters WHERE id = NEW.chapter_id;
        NEW.class_node_id := v_class_node_id;
        NEW.term_id := v_term_id;
    ELSIF NEW.lesson_id IS NOT NULL THEN
        SELECT c.class_node_id, c.term_id INTO v_class_node_id, v_term_id
        FROM lessons l JOIN chapters c ON c.id = l.chapter_id WHERE l.id = NEW.lesson_id;
        NEW.class_node_id := v_class_node_id;
        NEW.term_id := v_term_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_exercise_class_scope
BEFORE INSERT OR UPDATE OF chapter_id, lesson_id ON exercises
FOR EACH ROW EXECUTE FUNCTION sync_exercise_class_scope();

-- Propage un changement de classe/trimestre du chapitre vers tous ses exercices descendants —
-- sans ce trigger, reclasser un chapitre laisserait ses exercices pointer vers l'ancienne classe.
CREATE OR REPLACE FUNCTION cascade_chapter_class_scope_to_exercises() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.class_node_id IS DISTINCT FROM OLD.class_node_id
       OR NEW.term_id IS DISTINCT FROM OLD.term_id THEN
        UPDATE exercises SET class_node_id = NEW.class_node_id, term_id = NEW.term_id
        WHERE chapter_id = NEW.id
           OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cascade_chapter_class_scope
AFTER UPDATE OF class_node_id, term_id ON chapters
FOR EACH ROW EXECUTE FUNCTION cascade_chapter_class_scope_to_exercises();

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
    content_id UUID NOT NULL UNIQUE,
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
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
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

-- ============================================================================
-- COMMUNAUTÉ, SUPPORT, ADMINISTRATION, IA ET NOTIFICATIONS
-- ============================================================================

CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE REFERENCES auth.users(id),
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
    reply_message TEXT,
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

-- Section 7 du CDC : Boutique & Documents payants à la carte
CREATE TABLE shop_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 500.00,
    document_url TEXT NOT NULL,
    preview_url TEXT,
    downloads_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Section 12 du CDC : Dons & Œuvres Caritatives
CREATE TABLE charity_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    target_amount NUMERIC(12, 2) NOT NULL,
    collected_amount NUMERIC(12, 2) DEFAULT 0.00,
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE donations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_name TEXT NOT NULL,
    donor_email TEXT,
    donor_phone TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    currency TEXT DEFAULT 'XAF',
    operator TEXT DEFAULT 'Mobile Money',
    charity_campaign_id UUID REFERENCES charity_campaigns(id) ON DELETE SET NULL,
    receipt_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Section 23 du CDC : Année Scolaire & Campagne de Passage de Classe
CREATE TABLE school_years (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- ex: '2026-2027'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT TRUE,
    promotion_campaign_open BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE promotion_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    from_class_node_id UUID NOT NULL REFERENCES academic_nodes(id),
    to_class_node_id UUID REFERENCES academic_nodes(id),
    school_year TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('valide', 'redoublement')),
    processed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- FONCTIONS UTILITAIRES RLS
-- Toutes en SECURITY DEFINER : elles doivent pouvoir lire admin_users/accounts/profiles
-- indépendamment de la visibilité RLS de l'appelant sur ces tables (sinon risque de blocage
-- circulaire), et search_path est fixé pour éviter le détournement de search_path classique
-- des fonctions SECURITY DEFINER.
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

-- Un profil connecté a-t-il un accès "complet" ou "limite" (donc != 'aucun') à une fonctionnalité
-- donnée de la matrice de droits, pour au moins un de ses profils actifs ? Utilisé pour le
-- gating RLS du contenu pédagogique (cas particulier documenté dans le skill 01_rls_security.md).
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

-- Désactive un nœud de l'Arbre Académique ET tous ses descendants (CTE récursive sur parent_id) en
-- une seule transaction. Un simple UPDATE sur la seule ligne ciblée laisserait les enfants actifs
-- et visibles dès que "Afficher les nœuds inactifs" est coché — incohérent avec ce que la boîte de
-- confirmation de l'admin affirme.
CREATE OR REPLACE FUNCTION deactivate_academic_node_cascade(p_node_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_affected_ids UUID[];
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    WITH RECURSIVE descendants AS (
        SELECT id FROM academic_nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id FROM academic_nodes n
        JOIN descendants d ON n.parent_id = d.id
    )
    SELECT array_agg(id) INTO v_affected_ids FROM descendants;

    UPDATE academic_nodes SET is_active = FALSE, updated_at = NOW() WHERE id = ANY(v_affected_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'deactivate_cascade', 'academic_node', p_node_id,
            jsonb_build_object('affected_ids', v_affected_ids));

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION deactivate_academic_node_cascade(UUID, UUID) TO authenticated;

-- Symétrique de deactivate_academic_node_cascade : réactive un nœud ET tous ses descendants en une
-- seule transaction (réactiver un par un via "Modifier" laissait les descendants inactifs).
CREATE OR REPLACE FUNCTION reactivate_academic_node_cascade(p_node_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_affected_ids UUID[];
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    WITH RECURSIVE descendants AS (
        SELECT id FROM academic_nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id FROM academic_nodes n
        JOIN descendants d ON n.parent_id = d.id
    )
    SELECT array_agg(id) INTO v_affected_ids FROM descendants;

    UPDATE academic_nodes SET is_active = TRUE, updated_at = NOW() WHERE id = ANY(v_affected_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'reactivate_cascade', 'academic_node', p_node_id,
            jsonb_build_object('affected_ids', v_affected_ids));

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION reactivate_academic_node_cascade(UUID, UUID) TO authenticated;

-- Suppression PHYSIQUE réelle (contrairement à "Supprimer Définitivement" côté UI qui, avant cette
-- fonction, ne faisait qu'un alias de la désactivation). Réservée aux nœuds déjà désactivés (on
-- force le passage par "Désactiver" d'abord) ; vérifie explicitement qu'aucun élève n'est rattaché
-- au sous-arbre, et intercepte toute autre violation de FK (abonnements, annonces, historiques de
-- promotion...) pour renvoyer un message clair plutôt qu'une erreur Postgres brute.
CREATE OR REPLACE FUNCTION permanently_delete_academic_node(p_node_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_node RECORD;
    v_affected_ids UUID[];
    v_student_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_node FROM academic_nodes WHERE id = p_node_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nœud introuvable';
    END IF;
    IF v_node.is_active THEN
        RAISE EXCEPTION 'Désactivez ce nœud avant de le supprimer définitivement';
    END IF;

    WITH RECURSIVE descendants AS (
        SELECT id FROM academic_nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id FROM academic_nodes n
        JOIN descendants d ON n.parent_id = d.id
    )
    SELECT array_agg(id) INTO v_affected_ids FROM descendants;

    SELECT COUNT(*) INTO v_student_count
    FROM profiles WHERE class_node_id = ANY(v_affected_ids);
    IF v_student_count > 0 THEN
        RAISE EXCEPTION 'Suppression impossible : % élève(s) encore rattaché(s) à ce nœud ou à ses descendants', v_student_count;
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'academic_node', p_node_id,
            jsonb_build_object('node_name', v_node.name, 'node_type', v_node.node_type, 'affected_ids', v_affected_ids));

    BEGIN
        DELETE FROM academic_nodes WHERE id = ANY(v_affected_ids);
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Suppression impossible : ce nœud ou l''un de ses descendants est encore référencé ailleurs dans le système (abonnements, annonces ciblées, historiques de promotion...). Retirez ces dépendances d''abord, ou laissez-le simplement désactivé.';
    END;

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_academic_node(UUID, UUID) TO authenticated;

-- Fusionne deux Classes ou deux Séries (Section 3.2 du CDC, écran Arbre Académique) : réattribue
-- vers le nœud cible tout ce qui référence le nœud source (élèves, rattachements matière↔classe,
-- paliers tarifaires, examens, communautés, boutique...), réattache ses éventuels enfants directs,
-- puis le désactive (jamais de suppression physique — on garde l'historique). Fait exprès une seule
-- fonction SECURITY DEFINER atomique plutôt que des appels séquentiels côté client : ~10 tables sont
-- concernées, une réussite partielle laisserait les données dans un état incohérent.
CREATE OR REPLACE FUNCTION merge_academic_class_nodes(
    p_source_id UUID,
    p_target_id UUID,
    p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_source_type TEXT;
    v_target_type TEXT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    IF p_source_id = p_target_id THEN
        RAISE EXCEPTION 'Impossible de fusionner un nœud avec lui-même';
    END IF;

    SELECT node_type INTO v_source_type FROM academic_nodes WHERE id = p_source_id;
    SELECT node_type INTO v_target_type FROM academic_nodes WHERE id = p_target_id;

    IF v_source_type IS NULL OR v_target_type IS NULL THEN
        RAISE EXCEPTION 'Nœud source ou cible introuvable';
    END IF;

    IF v_source_type != v_target_type THEN
        RAISE EXCEPTION 'Les deux nœuds doivent être du même type (% != %)', v_source_type, v_target_type;
    END IF;

    IF v_source_type NOT IN ('class', 'series') THEN
        RAISE EXCEPTION 'Seules les Classes et Séries peuvent être fusionnées';
    END IF;

    -- Élèves rattachés
    UPDATE profiles SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Rattachements matière↔classe (dédoublonnage requis : UNIQUE(subject_id, class_node_id))
    DELETE FROM subject_class_links scl
    WHERE scl.class_node_id = p_source_id
      AND EXISTS (
        SELECT 1 FROM subject_class_links t
        WHERE t.class_node_id = p_target_id AND t.subject_id = scl.subject_id
      );
    UPDATE subject_class_links SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Paliers tarifaires, examens officiels, épreuves d'établissement
    UPDATE subscription_tiers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE official_exams SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE establishment_papers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Communauté (forum, groupes WhatsApp)
    UPDATE forum_threads SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE whatsapp_communities SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Événements et annonces ciblées
    UPDATE events SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE announcements SET target_class_id = p_target_id WHERE target_class_id = p_source_id;

    -- Boutique de documents
    UPDATE shop_documents SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Contenu pédagogique : chapters.class_node_id déclenche trg_cascade_chapter_class_scope, qui
    -- répercute automatiquement sur les exercices Niveau 1/2. La ligne exercises directe reste
    -- nécessaire pour les exercices Niveau 3 (indépendants), que le trigger ne peut pas atteindre
    -- puisqu'ils n'ont ni chapter_id ni lesson_id.
    UPDATE chapters SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE exercises SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Ré-attache les éventuels enfants directs du nœud source (ex: des Séries sous une Classe)
    UPDATE academic_nodes SET parent_id = p_target_id WHERE parent_id = p_source_id;

    -- Désactivation du nœud source (pas de suppression : historique conservé)
    UPDATE academic_nodes SET is_active = FALSE, updated_at = NOW() WHERE id = p_source_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'merge', 'academic_node', p_target_id,
        jsonb_build_object('source_id', p_source_id, 'node_type', v_source_type),
        jsonb_build_object('target_id', p_target_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION merge_academic_class_nodes(UUID, UUID, UUID) TO authenticated;

-- Archiver un chapitre ne touchait QUE `chapters.is_active`, laissant ses leçons actives et
-- incohérentes avec un chapitre marqué "ARCHIVÉ" — même bug de fond que la suppression de nœuds
-- avant migration 20. Ces 4 fonctions apportent le même traitement en cascade + suppression
-- définitive réelle que l'Arbre Académique (migration 21). Contrairement aux nœuds académiques,
-- chapters/lessons/lesson_versions/exercises sont tous en ON DELETE CASCADE entre eux et sans
-- table de progression élève qui les référencerait sans CASCADE — la suppression définitive n'a
-- donc pas besoin d'un garde-fou "élèves rattachés", juste d'exiger l'archivage préalable.
CREATE OR REPLACE FUNCTION deactivate_chapter_cascade(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    UPDATE chapters SET is_active = FALSE, updated_at = NOW() WHERE id = p_chapter_id;
    UPDATE lessons SET is_active = FALSE, updated_at = NOW() WHERE chapter_id = p_chapter_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'deactivate_cascade', 'chapter', p_chapter_id, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION deactivate_chapter_cascade(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION reactivate_chapter_cascade(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    UPDATE chapters SET is_active = TRUE, updated_at = NOW() WHERE id = p_chapter_id;
    UPDATE lessons SET is_active = TRUE, updated_at = NOW() WHERE chapter_id = p_chapter_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'reactivate_cascade', 'chapter', p_chapter_id, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION reactivate_chapter_cascade(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION permanently_delete_chapter(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_chapter RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_chapter FROM chapters WHERE id = p_chapter_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Chapitre introuvable';
    END IF;
    IF v_chapter.is_active THEN
        RAISE EXCEPTION 'Archivez ce chapitre avant de le supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'chapter', p_chapter_id,
            jsonb_build_object(
                'chapter_title', v_chapter.title,
                'lesson_count', (SELECT COUNT(*) FROM lessons WHERE chapter_id = p_chapter_id),
                'exercise_count', (SELECT COUNT(*) FROM exercises WHERE chapter_id = p_chapter_id
                                   OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = p_chapter_id))
            ));

    DELETE FROM chapters WHERE id = p_chapter_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_chapter(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION permanently_delete_lesson(p_lesson_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_lesson RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_lesson FROM lessons WHERE id = p_lesson_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Leçon introuvable';
    END IF;
    IF v_lesson.is_active THEN
        RAISE EXCEPTION 'Archivez cette leçon avant de la supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'lesson', p_lesson_id,
            jsonb_build_object(
                'lesson_title', v_lesson.title,
                'exercise_count', (SELECT COUNT(*) FROM exercises WHERE lesson_id = p_lesson_id)
            ));

    DELETE FROM lessons WHERE id = p_lesson_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_lesson(UUID, UUID) TO authenticated;

-- Un exercice est une feuille (aucun enfant) : contrairement aux Chapitres, pas besoin de variante
-- "cascade" pour l'archivage — juste une suppression définitive réelle, symétrique de
-- permanently_delete_lesson. exercise_versions est en ON DELETE CASCADE sur exercises(id).
CREATE OR REPLACE FUNCTION permanently_delete_exercise(p_exercise_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_exercise RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_exercise FROM exercises WHERE id = p_exercise_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Exercice introuvable';
    END IF;
    IF v_exercise.is_active THEN
        RAISE EXCEPTION 'Archivez cet exercice avant de le supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'exercise', p_exercise_id,
            jsonb_build_object('exercise_title', v_exercise.title));

    DELETE FROM exercises WHERE id = p_exercise_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_exercise(UUID, UUID) TO authenticated;

-- `approveContent` faisait deux écritures séparées (marquer la queue "approuve", PUIS publier le
-- contenu) : si la seconde échouait, la queue restait "approuvée" sans que le contenu soit publié,
-- une incohérence invisible et non récupérable. Cette fonction regroupe les deux dans une seule
-- transaction SECURITY DEFINER.
CREATE OR REPLACE FUNCTION approve_and_publish_content(p_validation_id UUID, p_reviewer_id UUID)
RETURNS VOID AS $$
DECLARE
    v_content_type TEXT;
    v_content_id UUID;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT content_type, content_id INTO v_content_type, v_content_id
    FROM validation_queue WHERE id = p_validation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Entrée de validation introuvable';
    END IF;

    UPDATE validation_queue
    SET status = 'approuve', reviewer_id = p_reviewer_id, reviewed_at = NOW()
    WHERE id = p_validation_id;

    IF v_content_type = 'lesson' THEN
        UPDATE lessons SET is_published = TRUE WHERE id = v_content_id;
    ELSIF v_content_type = 'exercise' THEN
        UPDATE exercises SET is_published = TRUE WHERE id = v_content_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION approve_and_publish_content(UUID, UUID) TO authenticated;

-- `chapters.subject_id` est en ON DELETE CASCADE : supprimer une matière supprimerait TOUS ses
-- chapitres (et leurs leçons/exercices) dans TOUTES les classes qui l'utilisent — un rayon d'action
-- bien plus large qu'un chapitre isolé. On bloque donc tant qu'il reste des chapitres rattachés, en
-- plus d'exiger l'archivage préalable (même principe que les autres suppressions définitives).
CREATE OR REPLACE FUNCTION permanently_delete_subject(p_subject_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_subject RECORD;
    v_chapter_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_subject FROM subjects WHERE id = p_subject_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Matière introuvable';
    END IF;
    IF v_subject.is_active THEN
        RAISE EXCEPTION 'Archivez cette matière avant de la supprimer définitivement';
    END IF;

    SELECT COUNT(*) INTO v_chapter_count FROM chapters WHERE subject_id = p_subject_id;
    IF v_chapter_count > 0 THEN
        RAISE EXCEPTION 'Suppression impossible : % chapitre(s) (et leurs leçons/exercices) sont encore rattachés à cette matière. Supprimez-les d''abord.', v_chapter_count;
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'subject', p_subject_id,
            jsonb_build_object('subject_name', v_subject.name));

    DELETE FROM subjects WHERE id = p_subject_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_subject(UUID, UUID) TO authenticated;

-- Duplique un chapitre (et ses leçons) vers une autre classe/série — cas légitime de programmes
-- identiques entre classes (ex: séries jumelées). Duplication réelle et indépendante, jamais une
-- référence partagée, pour qu'une modification ultérieure sur l'une n'affecte jamais l'autre.
CREATE OR REPLACE FUNCTION duplicate_chapter_to_class(
    p_chapter_id UUID,
    p_target_class_node_id UUID,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_new_chapter_id UUID;
    v_term_id UUID;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    INSERT INTO chapters (subject_id, term_id, class_node_id, title, introduction, intro_media_json, display_order, is_active)
    SELECT subject_id, term_id, p_target_class_node_id, title, introduction, intro_media_json, display_order, is_active
    FROM chapters WHERE id = p_chapter_id
    RETURNING id, term_id INTO v_new_chapter_id, v_term_id;

    -- Duplique les leçons avec un id généré à l'avance, pour connaître le mapping ancien->nouveau
    -- dans la même requête (un simple INSERT...SELECT ne permet pas de RETURNING l'id source).
    WITH old_lessons AS (
        SELECT id AS old_id, uuid_generate_v4() AS new_id, title, content_json, display_order, is_active, min_subscription_tier
        FROM lessons WHERE chapter_id = p_chapter_id
    ), inserted_lessons AS (
        INSERT INTO lessons (id, chapter_id, title, content_json, display_order, is_published, is_active, min_subscription_tier)
        SELECT new_id, v_new_chapter_id, title, content_json, display_order, FALSE, is_active, min_subscription_tier
        FROM old_lessons
        RETURNING id
    )
    -- Exercices Niveau 1 (rattachés à une leçon dupliquée) : re-parentés vers la nouvelle leçon.
    INSERT INTO exercises (lesson_id, chapter_id, type, difficulty, format, title, instructions_json,
                            solution_json, min_subscription_tier, is_published, is_active,
                            class_node_id, term_id)
    SELECT ol.new_id, NULL, e.type, e.difficulty, e.format, e.title, e.instructions_json,
           e.solution_json, e.min_subscription_tier, FALSE, e.is_active,
           p_target_class_node_id, v_term_id
    FROM exercises e
    JOIN old_lessons ol ON ol.old_id = e.lesson_id
    JOIN inserted_lessons il ON il.id = ol.new_id;

    -- Exercices Niveau 2 (rattachés directement au chapitre, pas à une leçon précise) : dupliqués
    -- directement contre le nouveau chapitre.
    INSERT INTO exercises (lesson_id, chapter_id, type, difficulty, format, title, instructions_json,
                            solution_json, min_subscription_tier, is_published, is_active,
                            class_node_id, term_id)
    SELECT NULL, v_new_chapter_id, type, difficulty, format, title, instructions_json,
           solution_json, min_subscription_tier, FALSE, is_active,
           p_target_class_node_id, v_term_id
    FROM exercises WHERE chapter_id = p_chapter_id AND lesson_id IS NULL;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'duplicate_to_class', 'chapter', v_new_chapter_id,
        jsonb_build_object('source_chapter_id', p_chapter_id),
        jsonb_build_object('target_class_node_id', p_target_class_node_id)
    );

    RETURN v_new_chapter_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_class(UUID, UUID, UUID) TO authenticated;

-- ============================================================================
-- CLASSES JUMELÉES (relation réelle et persistée, distincte de la fusion destructive ci-dessus)
-- ============================================================================
-- "Jumelage" de classes/séries — jusqu'ici un concept purement informel (un simple commentaire de
-- code), jamais une donnée persistée. Cette section en fait une relation N-aire réelle,
-- interrogeable et réversible : "ces classes partagent le même programme et peuvent se propager du
-- contenu entre elles", sans aucune fusion/désactivation. N-aire (pas juste des paires) car les
-- séries camerounaises sont souvent 3+ en parallèle.
CREATE TABLE class_twin_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label TEXT,
    -- Un jumelage est précis PAR MATIÈRE : deux classes peuvent partager le programme en Maths
    -- sans le partager en Français. Une classe peut donc appartenir à plusieurs groupes (un par
    -- matière) — pas de contrainte UNIQUE sur class_node_id ci-dessous.
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE class_twin_group_members (
    group_id UUID NOT NULL REFERENCES class_twin_groups(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (group_id, class_node_id)
);

ALTER TABLE class_twin_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_twin_group_members ENABLE ROW LEVEL SECURITY;

-- Purement un outil d'auteur admin, jamais consommé par l'app élève : lecture ET écriture
-- réservées aux admins.
CREATE POLICY class_twin_groups_admin_all ON class_twin_groups FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());
CREATE POLICY class_twin_group_members_admin_all ON class_twin_group_members FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE OR REPLACE FUNCTION declare_class_twin_group(
    p_class_node_ids UUID[],
    p_subject_id UUID,
    p_label TEXT,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_group_id UUID;
    v_type_count INT;
    v_missing_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;
    IF array_length(p_class_node_ids, 1) IS NULL OR array_length(p_class_node_ids, 1) < 2 THEN
        RAISE EXCEPTION 'Un groupe jumelé nécessite au moins 2 classes/séries';
    END IF;
    IF p_subject_id IS NULL THEN
        RAISE EXCEPTION 'Un jumelage doit préciser la matière concernée';
    END IF;

    SELECT COUNT(DISTINCT node_type) INTO v_type_count
    FROM academic_nodes WHERE id = ANY(p_class_node_ids) AND node_type IN ('class', 'series');
    IF v_type_count != 1 THEN
        RAISE EXCEPTION 'Toutes les classes du groupe doivent être du même type (Classe ou Série)';
    END IF;

    SELECT COUNT(*) INTO v_missing_count
    FROM unnest(p_class_node_ids) cid
    WHERE NOT EXISTS (
        SELECT 1 FROM subject_class_links WHERE class_node_id = cid AND subject_id = p_subject_id
    );
    IF v_missing_count > 0 THEN
        RAISE EXCEPTION 'Cette matière n''est pas enseignée dans toutes les classes sélectionnées';
    END IF;

    INSERT INTO class_twin_groups (label, subject_id, created_by) VALUES (p_label, p_subject_id, p_admin_id)
    RETURNING id INTO v_group_id;
    INSERT INTO class_twin_group_members (group_id, class_node_id)
    SELECT v_group_id, unnest(p_class_node_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'twin_declare', 'class_twin_group', v_group_id,
            jsonb_build_object('class_node_ids', p_class_node_ids, 'subject_id', p_subject_id));

    RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION add_class_to_twin_group(p_group_id UUID, p_class_node_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    INSERT INTO class_twin_group_members (group_id, class_node_id) VALUES (p_group_id, p_class_node_id);
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'twin_add_member', 'class_twin_group', p_group_id, jsonb_build_object('class_node_id', p_class_node_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION remove_class_from_twin_group(p_group_id UUID, p_class_node_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    DELETE FROM class_twin_group_members WHERE group_id = p_group_id AND class_node_id = p_class_node_id;
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'twin_remove_member', 'class_twin_group', p_group_id, jsonb_build_object('class_node_id', p_class_node_id));
    DELETE FROM class_twin_groups g
    WHERE g.id = p_group_id AND (SELECT COUNT(*) FROM class_twin_group_members WHERE group_id = p_group_id) < 2;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION dissolve_class_twin_group(p_group_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'twin_dissolve', 'class_twin_group', p_group_id,
        (SELECT jsonb_agg(class_node_id) FROM class_twin_group_members WHERE group_id = p_group_id));
    DELETE FROM class_twin_groups WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION declare_class_twin_group(UUID[], UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_class_to_twin_group(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_class_from_twin_group(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION dissolve_class_twin_group(UUID, UUID) TO authenticated;

-- Aperçu d'impact avant une FUSION (pas un jumelage) — une seule fonction agrégée plutôt que 10
-- requêtes séparées côté client. Sert la modale de fusion de l'Arbre Académique.
CREATE OR REPLACE FUNCTION get_class_node_merge_impact(p_class_node_id UUID)
RETURNS TABLE(entity_key TEXT, entity_label TEXT, row_count BIGINT) AS $$
    SELECT 'profiles', 'Élèves rattachés', COUNT(*) FROM profiles WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'subject_class_links', 'Matières liées', COUNT(*) FROM subject_class_links WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'chapters', 'Chapitres', COUNT(*) FROM chapters WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'exercises', 'Exercices', COUNT(*) FROM exercises WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'subscription_tiers', 'Paliers tarifaires', COUNT(*) FROM subscription_tiers WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'official_exams', 'Examens officiels', COUNT(*) FROM official_exams WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'establishment_papers', 'Épreuves d''établissement', COUNT(*) FROM establishment_papers WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'forum_threads', 'Sujets du forum', COUNT(*) FROM forum_threads WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'whatsapp_communities', 'Communautés WhatsApp', COUNT(*) FROM whatsapp_communities WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'events', 'Événements', COUNT(*) FROM events WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'announcements', 'Annonces ciblées', COUNT(*) FROM announcements WHERE target_class_id = p_class_node_id
    UNION ALL SELECT 'shop_documents', 'Documents boutique', COUNT(*) FROM shop_documents WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'children_nodes', 'Nœuds enfants (ex: Séries)', COUNT(*) FROM academic_nodes WHERE parent_id = p_class_node_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_class_node_merge_impact(UUID) TO authenticated;

-- Duplique un chapitre vers TOUTES les classes de son groupe jumelé, en une seule transaction —
-- boucler duplicate_chapter_to_class depuis Dart laisserait un groupe à moitié synchronisé si un
-- appel intermédiaire échouait. Réutilise duplicate_chapter_to_class telle quelle.
CREATE OR REPLACE FUNCTION duplicate_chapter_to_twin_group(p_chapter_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_group_id UUID;
    v_source_class_id UUID;
    v_chapter_subject_id UUID;
    v_target_id UUID;
    v_results UUID[] := ARRAY[]::UUID[];
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;

    SELECT class_node_id, subject_id INTO v_source_class_id, v_chapter_subject_id
    FROM chapters WHERE id = p_chapter_id;
    IF v_source_class_id IS NULL THEN RAISE EXCEPTION 'Chapitre introuvable ou sans classe associée'; END IF;

    -- Une classe pouvant appartenir à plusieurs groupes (un par matière), on résout celui dont la
    -- matière correspond à celle du chapitre dupliqué, pas "le" groupe de la classe.
    SELECT m.group_id INTO v_group_id
    FROM class_twin_group_members m
    JOIN class_twin_groups g ON g.id = m.group_id
    WHERE m.class_node_id = v_source_class_id AND g.subject_id = v_chapter_subject_id;
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Cette classe ne fait partie d''aucun groupe jumelé pour cette matière';
    END IF;

    FOR v_target_id IN
        SELECT class_node_id FROM class_twin_group_members WHERE group_id = v_group_id AND class_node_id != v_source_class_id
    LOOP
        v_results := array_append(v_results, duplicate_chapter_to_class(p_chapter_id, v_target_id, p_admin_id));
    END LOOP;

    RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_twin_group(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION get_chapter_duplication_impact(p_chapter_id UUID)
RETURNS TABLE(lesson_count BIGINT, exercise_count BIGINT) AS $$
    SELECT
      (SELECT COUNT(*) FROM lessons WHERE chapter_id = p_chapter_id),
      (SELECT COUNT(*) FROM exercises WHERE chapter_id = p_chapter_id
         OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = p_chapter_id));
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_chapter_duplication_impact(UUID) TO authenticated;

-- ============================================================================
-- TRIGGER MÉTIER : CUMUL MENSUEL ET REQUALIFICATION AUTOMATIQUE (Section 38 du CDC)
-- SECURITY DEFINER : ce trigger peut être déclenché par une mise à jour de transactions faite par
-- un admin authentifié (écran de réconciliation), pas seulement par le webhook en service_role ; il
-- doit pouvoir écrire dans monthly_spend_counter/subscriptions/notification_log quel que soit le
-- rôle appelant.
-- ============================================================================

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trigger_monthly_spend_accumulation
AFTER INSERT OR UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION handle_monthly_spend_accumulation();


-- Section 12 : synchronise `charity_campaigns.collected_amount` sur chaque mouvement de `donations`
-- (aucun autre mécanisme ne le fait — sans ce trigger la barre de progression reste figée à 0).
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_sync_campaign_collected_amount
    AFTER INSERT OR UPDATE OR DELETE ON donations
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_collected_amount();


-- Section 6.3 du CDC : cycle de vie complet de l'expiration d'un abonnement (rappels J-3/J-1/Jour J,
-- bascule réelle au palier gratuit, relances dégressives J+1/J+7/J+30), exécuté quotidiennement via pg_cron.
CREATE OR REPLACE FUNCTION process_subscription_lifecycle() RETURNS void AS $$
DECLARE
    r RECORD;
    v_days_until INT;
    v_days_since INT;
    v_reminder_type TEXT;
    v_template_id UUID;
BEGIN
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


-- CDC Partie 1 §7.4, Partie 2 §25, exemple chiffré §40 : nouvelle connexion → déconnexion immédiate et
-- automatique de l'ancienne session, quel que soit le client qui insère la nouvelle ligne `sessions`.
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

-- Section 25 : détection réelle des comptes changeant d'appareil de façon suspecte (>= N bascules/jour).
CREATE OR REPLACE FUNCTION get_suspicious_session_accounts(p_min_switches INT DEFAULT 3)
RETURNS TABLE (
    account_id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    switch_count BIGINT
) AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
    END IF;

    RETURN QUERY
    SELECT s.account_id, a.first_name, a.last_name, a.email, COUNT(*) AS switch_count
    FROM sessions s
    JOIN accounts a ON a.id = s.account_id
    WHERE s.created_at >= CURRENT_DATE
    GROUP BY s.account_id, a.first_name, a.last_name, a.email
    HAVING COUNT(*) >= p_min_switches
    ORDER BY switch_count DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION get_suspicious_session_accounts(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_suspicious_session_accounts(INT) TO authenticated;


-- ============================================================================
-- TRIGGER D'AUDIT LOG AUTOMATIQUE POUR ACTION ADMIN
-- SECURITY DEFINER : déclenché par des DML faites par des admins authentifiés (pas service_role),
-- doit pouvoir écrire dans audit_log même si l'appelant n'a pas de policy INSERT sur cette table.
-- ============================================================================

CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    SELECT id INTO v_admin_id FROM admin_users WHERE auth_user_id = auth.uid();
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        v_admin_id,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)::jsonb ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER audit_academic_nodes AFTER INSERT OR UPDATE OR DELETE ON academic_nodes FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_subscription_tiers AFTER INSERT OR UPDATE OR DELETE ON subscription_tiers FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_access_matrix AFTER INSERT OR UPDATE OR DELETE ON access_matrix FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_admin_users AFTER INSERT OR UPDATE OR DELETE ON admin_users FOR EACH ROW EXECUTE FUNCTION log_admin_action();

-- UPDATE/DELETE seulement (pas INSERT, très majoritairement une auto-inscription élève, pas un geste
-- admin — cf. 35_extend_audit_log_accounts.sql pour la justification complète).
CREATE TRIGGER audit_accounts AFTER UPDATE OR DELETE ON accounts FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_parent_accounts AFTER UPDATE OR DELETE ON parent_accounts FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE TRIGGER audit_profiles AFTER UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION log_admin_action();


-- ============================================================================
-- ROW LEVEL SECURITY — activation sur toutes les tables
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
ALTER TABLE matrix_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_spend_counter ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_reconciliation ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_versions ENABLE ROW LEVEL SECURITY;
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

-- ---- Arbre académique : lecture publique (nécessaire à l'onboarding élève avant connexion),
-- ---- écriture admin uniquement.
CREATE POLICY academic_nodes_select ON academic_nodes FOR SELECT USING (is_active = true OR is_admin_user());
CREATE POLICY academic_nodes_admin_write ON academic_nodes FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY academic_nodes_admin_update ON academic_nodes FOR UPDATE USING (is_admin_user());
CREATE POLICY academic_nodes_admin_delete ON academic_nodes FOR DELETE USING (is_admin_user());

CREATE POLICY subjects_select ON subjects FOR SELECT USING (is_active = true OR is_admin_user());
CREATE POLICY subjects_admin_write ON subjects FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY subjects_admin_update ON subjects FOR UPDATE USING (is_admin_user());
CREATE POLICY subjects_admin_delete ON subjects FOR DELETE USING (is_admin_user());

CREATE POLICY subject_class_links_select ON subject_class_links FOR SELECT USING (true);
CREATE POLICY subject_class_links_admin_write ON subject_class_links FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY subject_class_links_admin_update ON subject_class_links FOR UPDATE USING (is_admin_user());
CREATE POLICY subject_class_links_admin_delete ON subject_class_links FOR DELETE USING (is_admin_user());

CREATE POLICY terms_select ON terms FOR SELECT USING (true);
CREATE POLICY terms_admin_write ON terms FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY terms_admin_update ON terms FOR UPDATE USING (is_admin_user());
CREATE POLICY terms_admin_delete ON terms FOR DELETE USING (is_admin_user());

-- ---- Identité : propriétaire uniquement, + lecture/suspension admin pour le support (CDC 3.5).
CREATE POLICY accounts_select ON accounts FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());
CREATE POLICY accounts_insert ON accounts FOR INSERT WITH CHECK (auth_user_id = auth.uid());
CREATE POLICY accounts_update ON accounts FOR UPDATE USING (auth_user_id = auth.uid() OR is_admin_user());

CREATE POLICY parent_accounts_select ON parent_accounts FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());
CREATE POLICY parent_accounts_insert ON parent_accounts FOR INSERT WITH CHECK (auth_user_id = auth.uid() OR is_admin_user());
CREATE POLICY parent_accounts_update ON parent_accounts FOR UPDATE USING (auth_user_id = auth.uid() OR is_admin_user());
CREATE POLICY parent_accounts_delete ON parent_accounts FOR DELETE USING (is_admin_user());

CREATE POLICY profiles_select ON profiles FOR SELECT USING (owns_profile(id) OR is_admin_user());
CREATE POLICY profiles_insert ON profiles FOR INSERT WITH CHECK (owns_account(account_id) OR is_admin_user());
CREATE POLICY profiles_update ON profiles FOR UPDATE USING (owns_profile(id) OR is_admin_user());

CREATE POLICY parent_profile_links_select ON parent_profile_links FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY parent_profile_links_admin_write ON parent_profile_links FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY parent_profile_links_admin_update ON parent_profile_links FOR UPDATE USING (is_admin_user());

CREATE POLICY sessions_select ON sessions FOR SELECT USING (owns_account(account_id) OR is_admin_user());
CREATE POLICY sessions_update ON sessions FOR UPDATE USING (owns_account(account_id) OR is_admin_user());

-- ---- Abonnements & paiements
CREATE POLICY subscription_tiers_select ON subscription_tiers FOR SELECT USING (true);
CREATE POLICY subscription_tiers_super_admin_write ON subscription_tiers FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY subscription_tiers_super_admin_update ON subscription_tiers FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY subscription_tiers_super_admin_delete ON subscription_tiers FOR DELETE USING (has_admin_role('super_admin'));

CREATE POLICY access_matrix_select ON access_matrix FOR SELECT USING (true);
CREATE POLICY access_matrix_super_admin_write ON access_matrix FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY access_matrix_super_admin_update ON access_matrix FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY access_matrix_super_admin_delete ON access_matrix FOR DELETE USING (has_admin_role('super_admin'));

CREATE POLICY matrix_features_select ON matrix_features FOR SELECT USING (is_admin_user());
CREATE POLICY matrix_features_super_admin_write ON matrix_features FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY matrix_features_super_admin_update ON matrix_features FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY matrix_features_super_admin_delete ON matrix_features FOR DELETE USING (has_admin_role('super_admin'));

CREATE POLICY subscriptions_select ON subscriptions FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

CREATE POLICY monthly_spend_counter_select ON monthly_spend_counter FOR SELECT USING (owns_profile(profile_id) OR has_admin_role('super_admin'));

CREATE POLICY transactions_select ON transactions FOR SELECT USING (owns_profile(profile_id) OR has_admin_role('super_admin'));
CREATE POLICY transactions_super_admin_update ON transactions FOR UPDATE USING (has_admin_role('super_admin'));

CREATE POLICY payment_reconciliation_super_admin_select ON payment_reconciliation FOR SELECT USING (has_admin_role('super_admin'));
CREATE POLICY payment_reconciliation_super_admin_insert ON payment_reconciliation FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY payment_reconciliation_super_admin_update ON payment_reconciliation FOR UPDATE USING (has_admin_role('super_admin'));

CREATE POLICY refund_requests_select ON refund_requests FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY refund_requests_insert ON refund_requests FOR INSERT WITH CHECK (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY refund_requests_admin_update ON refund_requests FOR UPDATE USING (is_admin_user());

CREATE POLICY referral_codes_select ON referral_codes FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY referral_codes_insert ON referral_codes FOR INSERT WITH CHECK (owns_profile(profile_id));
CREATE POLICY referral_codes_admin_update ON referral_codes FOR UPDATE USING (is_admin_user());

-- ---- Contenu pédagogique : lecture publique conditionnée par publication + palier (cas particulier
-- ---- documenté dans 01_rls_security.md), écriture réservée aux admins/enseignants (admin_users).
CREATE POLICY chapters_select ON chapters FOR SELECT USING (is_active = true OR is_admin_user());
CREATE POLICY chapters_admin_write ON chapters FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY chapters_admin_update ON chapters FOR UPDATE USING (is_admin_user());
CREATE POLICY chapters_admin_delete ON chapters FOR DELETE USING (is_admin_user());

CREATE POLICY lessons_select ON lessons FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND is_active = true
        AND (min_subscription_tier = 'gratuit' OR current_user_has_feature_access('courses'))
    )
);
CREATE POLICY lessons_admin_write ON lessons FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY lessons_admin_update ON lessons FOR UPDATE USING (is_admin_user());
CREATE POLICY lessons_admin_delete ON lessons FOR DELETE USING (is_admin_user());

CREATE POLICY lesson_versions_admin_all ON lesson_versions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY content_catalog_select ON content_catalog FOR SELECT USING (true);
CREATE POLICY content_catalog_admin_write ON content_catalog FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY content_catalog_admin_update ON content_catalog FOR UPDATE USING (is_admin_user());
CREATE POLICY content_catalog_admin_delete ON content_catalog FOR DELETE USING (is_admin_user());

CREATE POLICY exercises_select ON exercises FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND is_active = true
        AND (
            min_subscription_tier = 'gratuit'
            OR (type = 'entraînement' AND current_user_has_feature_access('exercises_training'))
            OR (type = 'évaluation' AND current_user_has_feature_access('exercises_evaluation'))
        )
    )
);
CREATE POLICY exercises_admin_write ON exercises FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY exercises_admin_update ON exercises FOR UPDATE USING (is_admin_user());
CREATE POLICY exercises_admin_delete ON exercises FOR DELETE USING (is_admin_user());

CREATE POLICY exercise_versions_admin_all ON exercise_versions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY media_library_select ON media_library FOR SELECT USING (true);
CREATE POLICY media_library_admin_write ON media_library FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY media_library_admin_update ON media_library FOR UPDATE USING (is_admin_user());
CREATE POLICY media_library_admin_delete ON media_library FOR DELETE USING (is_admin_user());

CREATE POLICY validation_queue_admin_all ON validation_queue FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY official_exams_select ON official_exams FOR SELECT USING (true);
CREATE POLICY official_exams_admin_write ON official_exams FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY official_exams_admin_update ON official_exams FOR UPDATE USING (is_admin_user());
CREATE POLICY official_exams_admin_delete ON official_exams FOR DELETE USING (is_admin_user());

-- Les métadonnées de l'examen (official_exams) restent publiques ; le contenu téléchargeable réel
-- (les épreuves elles-mêmes) est gate par la Matrice de Droits, clé 'official_exams' — avant cette
-- policy, la matrice affichait un bouton qui ne restreignait en réalité jamais rien ici.
CREATE POLICY exam_papers_select ON exam_papers FOR SELECT USING (
    is_admin_user() OR current_user_has_feature_access('official_exams')
);
CREATE POLICY exam_papers_admin_write ON exam_papers FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY exam_papers_admin_update ON exam_papers FOR UPDATE USING (is_admin_user());
CREATE POLICY exam_papers_admin_delete ON exam_papers FOR DELETE USING (is_admin_user());

CREATE POLICY establishments_select ON establishments FOR SELECT USING (true);
CREATE POLICY establishments_admin_write ON establishments FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY establishments_admin_update ON establishments FOR UPDATE USING (is_admin_user());
CREATE POLICY establishments_admin_delete ON establishments FOR DELETE USING (is_admin_user());

CREATE POLICY establishment_papers_select ON establishment_papers FOR SELECT USING (true);
CREATE POLICY establishment_papers_admin_write ON establishment_papers FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY establishment_papers_admin_update ON establishment_papers FOR UPDATE USING (is_admin_user());
CREATE POLICY establishment_papers_admin_delete ON establishment_papers FOR DELETE USING (is_admin_user());

-- ---- Administration : accès à son propre profil admin, tout le reste réservé au super_admin.
CREATE POLICY admin_users_select ON admin_users FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());
CREATE POLICY admin_users_super_admin_insert ON admin_users FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY admin_users_super_admin_update ON admin_users FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY admin_users_super_admin_delete ON admin_users FOR DELETE USING (has_admin_role('super_admin'));

CREATE POLICY admin_permissions_select ON admin_permissions FOR SELECT USING (
    has_admin_role('super_admin') OR admin_user_id IN (SELECT id FROM admin_users WHERE auth_user_id = auth.uid())
);
CREATE POLICY admin_permissions_super_admin_write ON admin_permissions FOR INSERT WITH CHECK (has_admin_role('super_admin'));
CREATE POLICY admin_permissions_super_admin_update ON admin_permissions FOR UPDATE USING (has_admin_role('super_admin'));
CREATE POLICY admin_permissions_super_admin_delete ON admin_permissions FOR DELETE USING (has_admin_role('super_admin'));

CREATE POLICY audit_log_select ON audit_log FOR SELECT USING (
    has_admin_role('super_admin') OR admin_user_id IN (SELECT id FROM admin_users WHERE auth_user_id = auth.uid())
);

CREATE POLICY teacher_establishments_admin_all ON teacher_establishments FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

-- ---- Communauté (préparé pour l'app élève, cloisonné par classe via profils du compte connecté).
CREATE POLICY forum_threads_select ON forum_threads FOR SELECT USING (
    is_admin_user()
    OR EXISTS (
        SELECT 1 FROM profiles p JOIN accounts a ON a.id = p.account_id
        WHERE a.auth_user_id = auth.uid() AND p.class_node_id = forum_threads.class_node_id
    )
);
CREATE POLICY forum_threads_insert ON forum_threads FOR INSERT WITH CHECK (owns_account(author_id));
CREATE POLICY forum_threads_admin_update ON forum_threads FOR UPDATE USING (is_admin_user() OR owns_account(author_id));

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
CREATE POLICY forum_posts_insert ON forum_posts FOR INSERT WITH CHECK (owns_account(author_id));
CREATE POLICY forum_posts_admin_update ON forum_posts FOR UPDATE USING (is_admin_user());
CREATE POLICY forum_posts_admin_delete ON forum_posts FOR DELETE USING (is_admin_user());

-- Gate en plus par la Matrice de Droits (clé 'whatsapp_groups', explicitement demandée) — les deux
-- conditions (appartenance à la classe ET palier donnant accès) doivent être vraies.
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
CREATE POLICY whatsapp_communities_admin_write ON whatsapp_communities FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY whatsapp_communities_admin_update ON whatsapp_communities FOR UPDATE USING (is_admin_user());
CREATE POLICY whatsapp_communities_admin_delete ON whatsapp_communities FOR DELETE USING (is_admin_user());

CREATE POLICY support_tickets_select ON support_tickets FOR SELECT USING (owns_account(account_id) OR is_admin_user());
CREATE POLICY support_tickets_insert ON support_tickets FOR INSERT WITH CHECK (owns_account(account_id));
CREATE POLICY support_tickets_admin_update ON support_tickets FOR UPDATE USING (is_admin_user());

-- ---- Événements
CREATE POLICY events_select ON events FOR SELECT USING (true);
CREATE POLICY events_admin_write ON events FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY events_admin_update ON events FOR UPDATE USING (is_admin_user());
CREATE POLICY events_admin_delete ON events FOR DELETE USING (is_admin_user());

CREATE POLICY event_results_select ON event_results FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY event_results_admin_write ON event_results FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY event_results_admin_update ON event_results FOR UPDATE USING (is_admin_user());

CREATE POLICY grade_disputes_select ON grade_disputes FOR SELECT USING (
    is_admin_user()
    OR EXISTS (SELECT 1 FROM event_results er WHERE er.id = grade_disputes.event_result_id AND owns_profile(er.profile_id))
);
CREATE POLICY grade_disputes_insert ON grade_disputes FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM event_results er WHERE er.id = grade_disputes.event_result_id AND owns_profile(er.profile_id))
);
CREATE POLICY grade_disputes_admin_update ON grade_disputes FOR UPDATE USING (is_admin_user());

-- ---- IA : lecture des coûts réservée au super_admin, écriture uniquement via service_role (aucune
-- ---- policy INSERT/UPDATE pour anon/authenticated = bloqué par défaut pour ces rôles).
CREATE POLICY ai_agent_calls_super_admin_select ON ai_agent_calls FOR SELECT USING (has_admin_role('super_admin'));

CREATE POLICY ai_content_review_admin_all ON ai_content_review FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY notification_templates_admin_all ON notification_templates FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY notification_log_select ON notification_log FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

CREATE POLICY scheduled_reminders_select ON scheduled_reminders FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

-- ---- Annonces, boutique, dons, années scolaires
CREATE POLICY announcements_select ON announcements FOR SELECT USING (true);
CREATE POLICY announcements_admin_write ON announcements FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY announcements_admin_update ON announcements FOR UPDATE USING (is_admin_user());
CREATE POLICY announcements_admin_delete ON announcements FOR DELETE USING (is_admin_user());

-- Gate par la Matrice de Droits (clé 'shop_documents', même modèle binaire que courses/exercises) —
-- avant cette policy, la Boutique était intégralement publique dès qu'un document était actif,
-- sans aucune ligne dans la matrice pour le restreindre par palier.
CREATE POLICY shop_documents_select ON shop_documents FOR SELECT USING (
    is_admin_user() OR (is_active = true AND current_user_has_feature_access('shop_documents'))
);
CREATE POLICY shop_documents_admin_write ON shop_documents FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY shop_documents_admin_update ON shop_documents FOR UPDATE USING (is_admin_user());
CREATE POLICY shop_documents_admin_delete ON shop_documents FOR DELETE USING (is_admin_user());

CREATE POLICY charity_campaigns_select ON charity_campaigns FOR SELECT USING (is_active = true OR is_admin_user());
CREATE POLICY charity_campaigns_admin_write ON charity_campaigns FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY charity_campaigns_admin_update ON charity_campaigns FOR UPDATE USING (is_admin_user());

CREATE POLICY donations_admin_all ON donations FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

CREATE POLICY school_years_select ON school_years FOR SELECT USING (true);
CREATE POLICY school_years_admin_write ON school_years FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY school_years_admin_update ON school_years FOR UPDATE USING (is_admin_user());

CREATE POLICY promotion_records_select ON promotion_records FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
CREATE POLICY promotion_records_admin_write ON promotion_records FOR INSERT WITH CHECK (is_admin_user());
CREATE POLICY promotion_records_admin_update ON promotion_records FOR UPDATE USING (is_admin_user());


-- ============================================================================
-- SEED DATA INITIAL (Cameroun, Sections, Classes, Séries, Matières & Super-Admin)
-- ============================================================================

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
    (v_tier_gratuit_id, 'shop_documents', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'official_exams', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'ai_assistant', 'limite', '{"daily_questions": 3}'::jsonb),
    (v_tier_journalier_id, 'shop_documents', 'aucun', '{}'::jsonb),
    (v_tier_mensuel_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'official_exams', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'ai_assistant', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'shop_documents', 'complet', '{}'::jsonb),
    (v_tier_gratuit_id, 'whatsapp_groups', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'whatsapp_groups', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'whatsapp_groups', 'complet', '{}'::jsonb);

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

    -- Catalogue pédagogique par matière (Section 16.0 du CDC)
    -- Mathématiques
    INSERT INTO content_catalog (subject_id, element_type, description) VALUES
    (v_math_id, 'Définition', 'Énoncé formel d''une notion mathématique'),
    (v_math_id, 'Propriété', 'Propriété ou règle déduite'),
    (v_math_id, 'Théorème', 'Théorème fondamental avec hypothèses et conclusions'),
    (v_math_id, 'Démonstration', 'Preuve mathématique rigoureuse'),
    (v_math_id, 'Exemple', 'Exemple d''application directe'),
    (v_math_id, 'Méthode', 'Guide méthodologique de résolution pas à pas'),
    (v_math_id, 'Exercice d''application', 'Exercice guidé de fixation'),
    (v_math_id, 'Exercice d''approfondissement', 'Exercice complexe de synthèse');

    -- Physique-Chimie
    INSERT INTO content_catalog (subject_id, element_type, description) VALUES
    (v_physique_id, 'Définition', 'Grandeur ou concept physique/chimique'),
    (v_physique_id, 'Loi', 'Loi physique fondamentale'),
    (v_physique_id, 'Formule', 'Relation mathématique entre grandeurs'),
    (v_physique_id, 'Expérience / Protocole', 'Protocole expérimental avec matériel et étapes'),
    (v_physique_id, 'Schéma', 'Schéma ou circuit annoté'),
    (v_physique_id, 'Application numérique', 'Calcul guidé avec unités SI'),
    (v_physique_id, 'Exercice', 'Exercice de réinvestissement');

    -- Français & Littérature
    INSERT INTO content_catalog (subject_id, element_type, description) VALUES
    (v_français_id, 'Texte support', 'Extrait littéraire ou texte d''étude'),
    (v_français_id, 'Biographie d''auteur', 'Repères biographiques et contexte d''écriture'),
    (v_français_id, 'Notion grammaticale', 'Règle de syntaxe ou d''accord'),
    (v_français_id, 'Figure de style', 'Procédé d''écriture et effet produit'),
    (v_français_id, 'Méthodologie', 'Guide de dissertation ou commentaire composé'),
    (v_français_id, 'Exercice de langue', 'Exercice d''application grammaticale');

    -- Modèles de notification officiels (Section 6.4 du CDC)
    INSERT INTO notification_templates (event_key, channel, title_template, body_template) VALUES
    ('j3_expiration', 'push', 'Échéance proche', 'Votre abonnement {{class_name}} se termine dans 3 jours. Renouvelez pour garder l''accès complet.'),
    ('j1_expiration', 'in_app', 'Dernier jour', 'Dernier jour ! Votre abonnement {{class_name}} expire demain.'),
    ('jour_j_expiration', 'in_app', 'Passage au palier gratuit', 'Votre abonnement a expiré. Vous êtes maintenant en accès gratuit. Réabonnez-vous pour retrouver l''accès complet à {{class_name}}.'),
    ('cumul_mensuel_atteint', 'in_app', 'Requalification Mensuelle', 'Bonne nouvelle ! Vous avez cumulé assez de paiements ce mois-ci pour débloquer l''accès Mensuel jusqu''à la fin du mois.'),
    ('relance_expiration', 'push', 'Reprenez vos révisions', 'Reprenez votre entraînement sur {{class_name}} et conservez votre progression !'),
    ('paiement_ambigu', 'in_app', 'Vérification en cours', 'Votre paiement Mobile Money est en cours de vérification manuelle par notre équipe.'),
    ('passage_classe', 'push', 'Campagne de passage de classe', 'Félicitations pour votre année ! Confirmez dès maintenant votre passage en classe supérieure.'),
    ('remboursement_decision', 'email', 'Décision sur votre demande de remboursement', 'Votre demande de remboursement a été traitée : {{decision_status}}. Motif : {{decision_reason}}'),
    ('relance_j1', 'push', 'On vous garde une place', 'Votre abonnement {{class_name}} a expiré hier. Réabonnez-vous pour retrouver l''accès complet.'),
    ('relance_j7', 'push', 'Toujours envie de progresser ?', 'Cela fait 7 jours que votre abonnement {{class_name}} a expiré. Reprenez là où vous vous étiez arrêté.'),
    ('relance_j30', 'push', 'Votre classe vous attend', 'Un mois sans abonnement {{class_name}} — réabonnez-vous quand vous êtes prêt.');

    INSERT INTO admin_users (email, first_name, last_name, role)
    VALUES ('ahdybau@gmail.com', 'Super', 'Administrateur', 'super_admin')
    RETURNING id INTO v_super_admin_id;

    -- Auto-liaison au compte Supabase Auth s'il existe déjà (script auto-réparant : ce script
    -- DROP SCHEMA CASCADE à chaque exécution, ce qui efface systématiquement admin_users.auth_user_id
    -- — sans cette étape, il faudrait relier le compte manuellement après CHAQUE exécution du reset).
    -- Ne fait rien si l'utilisateur Auth n'existe pas encore (à créer une seule fois via le Dashboard).
    UPDATE admin_users
    SET auth_user_id = (SELECT id FROM auth.users WHERE auth.users.email = admin_users.email)
    WHERE admin_users.email = 'ahdybau@gmail.com'
      AND EXISTS (SELECT 1 FROM auth.users WHERE auth.users.email = admin_users.email);
END $$;

-- Fonction pour obtenir le trimestre actuel selon le pays et la date du jour (Déblocage temporel progressif)
CREATE OR REPLACE FUNCTION current_term_id(p_country_id UUID)
RETURNS UUID AS $$
    SELECT id FROM terms
    WHERE country_id = p_country_id
      AND CURRENT_DATE >= start_date
      AND CURRENT_DATE <= end_date
    LIMIT 1;
$$ LANGUAGE sql STABLE;

-- Fonction de vérification de session unique (Anti-partage de compte)
CREATE OR REPLACE FUNCTION register_user_session(
    p_account_id UUID,
    p_device_fingerprint TEXT,
    p_platform TEXT
)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
BEGIN
    -- Désactiver les anciennes sessions actives de ce compte (déconnexion immédiate)
    UPDATE sessions
    SET is_active = FALSE
    WHERE account_id = p_account_id AND is_active = TRUE;

    -- Créer la nouvelle session active
    INSERT INTO sessions (account_id, device_fingerprint, platform, is_active, last_active_at)
    VALUES (p_account_id, p_device_fingerprint, p_platform, TRUE, NOW())
    RETURNING id INTO v_session_id;

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Garantir tous les privilèges sur toutes les tables existantes et futures
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role, postgres;

-- Activer la réplication Supabase Realtime pour les tables interactives
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE academic_nodes;
        ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
        ALTER PUBLICATION supabase_realtime ADD TABLE subscription_tiers;
        ALTER PUBLICATION supabase_realtime ADD TABLE access_matrix;
        ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
        ALTER PUBLICATION supabase_realtime ADD TABLE validation_queue;
        ALTER PUBLICATION supabase_realtime ADD TABLE forum_posts;
        ALTER PUBLICATION supabase_realtime ADD TABLE support_tickets;
        ALTER PUBLICATION supabase_realtime ADD TABLE grade_disputes;
        ALTER PUBLICATION supabase_realtime ADD TABLE payment_reconciliation;
        ALTER PUBLICATION supabase_realtime ADD TABLE refund_requests;
        ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
        ALTER PUBLICATION supabase_realtime ADD TABLE shop_documents;
        ALTER PUBLICATION supabase_realtime ADD TABLE charity_campaigns;
        ALTER PUBLICATION supabase_realtime ADD TABLE school_years;
    END IF;
END $$;

-- ============================================================================
-- BUCKET DE STOCKAGE POUR LES MÉDIAS (images/vidéos/audio/documents des leçons, exercices, etc.)
-- ============================================================================
-- Le schéma `storage` n'est pas touché par le DROP SCHEMA public CASCADE plus haut, donc ce bloc
-- est idempotent même sur une base déjà initialisée.

INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS media_public_read ON storage.objects;
CREATE POLICY media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'media');

DROP POLICY IF EXISTS media_admin_insert ON storage.objects;
CREATE POLICY media_admin_insert ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'media' AND is_admin_user());

DROP POLICY IF EXISTS media_admin_update ON storage.objects;
CREATE POLICY media_admin_update ON storage.objects
    FOR UPDATE USING (bucket_id = 'media' AND is_admin_user());

DROP POLICY IF EXISTS media_admin_delete ON storage.objects;
CREATE POLICY media_admin_delete ON storage.objects
    FOR DELETE USING (bucket_id = 'media' AND is_admin_user());

-- ============================================================================
-- ÉTAPE MANUELLE REQUISE UNE SEULE FOIS (PAS À CHAQUE EXÉCUTION)
-- ============================================================================
-- Le bloc de seed plus haut relie désormais automatiquement admin_users.auth_user_id à l'utilisateur
-- Supabase Auth correspondant (par email), à CHAQUE exécution de ce script — donc rejouer ce script
-- ne casse plus la connexion admin comme avant.
--
-- Mais ça suppose que l'utilisateur Supabase Auth existe déjà. S'il n'existe pas encore :
-- 1. Dashboard Supabase > Authentication > Add user > créer ahdybau@gmail.com avec un mot de passe
--    fort — PAS "123456".
-- 2. Rejouer ce script une fois (ou exécuter seul le bloc UPDATE ci-dessus) pour finaliser la
--    liaison.
