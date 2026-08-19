-- Migration 03: Communauté, Support, Administration, IA et Notifications

-- 1. Comptes Administrateurs / Enseignants
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin_pays', 'admin_contenu', 'enseignant', 'moderateur', 'support')),
    scope_json JSONB DEFAULT '{}'::jsonb, -- Périmètres : pays_id, classes, matières, établissements
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Liaison vers Supabase Auth (auth.users) — sans cette colonne, aucune policy RLS basée sur
-- auth.uid() ne peut jamais identifier un admin (voir 03_auth_flow.md, section 2.1 du CDC MVP).
ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id);

-- 2. Permissions individuelles nommées (Ajustables par Super-Admin)
CREATE TABLE IF NOT EXISTS admin_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL, -- ex: 'manage_academic_tree', 'view_financials', 'publish_content', 'moderate_forum'
    granted BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(admin_user_id, permission_key)
);

-- 3. Traçabilité totale - Audit Log
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID REFERENCES admin_users(id),
    action_type TEXT NOT NULL, -- CREATE, UPDATE, DELETE, PUBLISH, RECONCILE, REFUND
    entity_type TEXT NOT NULL, -- table name
    entity_id UUID,
    before_json JSONB,
    after_json JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Rattachement Enseignants Multi-établissements
CREATE TABLE IF NOT EXISTS teacher_establishments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    establishment_id UUID NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    subjects_scope JSONB DEFAULT '[]'::jsonb,
    classes_scope JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(teacher_id, establishment_id)
);

-- 5. Forum (Cloisonné par classe du profil actif)
CREATE TABLE IF NOT EXISTS forum_threads (
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

CREATE TABLE IF NOT EXISTS forum_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID NOT NULL REFERENCES forum_threads(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    moderation_status TEXT DEFAULT 'visible' CHECK (moderation_status IN ('visible', 'masque', 'supprime')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Communautés d'étude WhatsApp officielles
CREATE TABLE IF NOT EXISTS whatsapp_communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    invite_link TEXT NOT NULL,
    member_count_estimate INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Tickets de support client (Élève / Parent)
CREATE TABLE IF NOT EXISTS support_tickets (
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

-- 8. Événements : Examens Blancs & Olympiades
CREATE TABLE IF NOT EXISTS events (
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

CREATE TABLE IF NOT EXISTS event_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    score NUMERIC(5, 2) NOT NULL,
    rank INT,
    percentile NUMERIC(5, 2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS grade_disputes (
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

-- 9. Suivi des coûts des Agents IA (Claude / Gemini)
CREATE TABLE IF NOT EXISTS ai_agent_calls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_type TEXT NOT NULL, -- structuration, exercices, moderation, ocr
    provider TEXT NOT NULL, -- claude, gemini
    tokens_used INT NOT NULL DEFAULT 0,
    cost_estimate NUMERIC(8, 5) NOT NULL DEFAULT 0.00000,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_content_review (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id UUID NOT NULL,
    ai_findings_json JSONB NOT NULL,
    accepted BOOLEAN DEFAULT FALSE,
    reviewed_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Modèles & Journaux de Notifications
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_key TEXT UNIQUE NOT NULL, -- expiration_j3, spend_limit_reached, new_content, etc.
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email', 'sms', 'in_app')),
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    template_id UUID REFERENCES notification_templates(id),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    channel TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    opened_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS scheduled_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reminder_type TEXT NOT NULL, -- exam_countdown, sub_expire, review_spaced
    trigger_date TIMESTAMPTZ NOT NULL,
    sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Bannières d'annonces de la plateforme
CREATE TABLE IF NOT EXISTS announcements (
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
