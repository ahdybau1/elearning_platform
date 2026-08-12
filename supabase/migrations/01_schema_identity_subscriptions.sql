-- Migration 01: Identité, Profils, Abonnements et Paiements

-- Extensibilité UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Identité globale du compte
CREATE TABLE IF NOT EXISTS accounts (
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

-- 2. Compte Parent distinct
CREATE TABLE IF NOT EXISTS parent_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Profil Élève (1 profil = 1 classe + 1 abonnement + 1 progression)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL, -- FK vers academic_nodes (classe/série)
    status TEXT NOT NULL DEFAULT 'actif' CHECK (status IN ('actif', 'archive')),
    subscription_tier TEXT NOT NULL DEFAULT 'gratuit', -- gratuit, journalier, hebdomadaire, mensuel, annuel
    school_year TEXT NOT NULL, -- ex: '2026-2027'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Liaison Parent <-> Profil Élève
CREATE TABLE IF NOT EXISTS parent_profile_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_account_id UUID NOT NULL REFERENCES parent_accounts(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    relation_type TEXT DEFAULT 'parent', -- parent, tuteur
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_account_id, profile_id)
);

-- 5. Sessions uniques strictes (anti-partage de compte)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    device_fingerprint TEXT NOT NULL,
    platform TEXT NOT NULL, -- web, android, ios
    is_active BOOLEAN DEFAULT TRUE,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Paliers d'abonnement & Grille Tarifaire
CREATE TABLE IF NOT EXISTS subscription_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL, -- gratuit, journalier, hebdomadaire, mensuel, annuel
    country_id UUID NOT NULL,
    class_node_id UUID NOT NULL,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    duration_days INT NOT NULL DEFAULT 0, -- 0 pour gratuit, 1, 7, 30, 365
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Matrice de droits (Droits d'accès dynamiques par palier)
CREATE TABLE IF NOT EXISTS access_matrix (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL, -- courses, exercises_training, exercises_evaluation, official_exams, establishment_papers, ai_assistant, offline_download, etc.
    access_level TEXT NOT NULL CHECK (access_level IN ('complet', 'limite', 'aucun')),
    limit_parameter JSONB DEFAULT '{}'::jsonb, -- ex: {"daily_limit": 3, "chapters_limit": 2}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tier_id, feature_key)
);

-- 8. Abonnements actifs par profil
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id),
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'actif' CHECK (status IN ('actif', 'expire', 'essai', 'annule')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Compteur de cumul mensuel pour requalification automatique en Mensuel
CREATE TABLE IF NOT EXISTS monthly_spend_counter (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    month_year TEXT NOT NULL, -- ex: '2026-10'
    cumulative_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, month_year)
);

-- 10. Transactions de paiement (visibilité restreinte au Super-Admin)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    operator TEXT NOT NULL, -- Orange Money, MTN MoMo, Carte Bancaire
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'ambiguous')),
    aggregator_ref TEXT,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. File de réconciliation manuelle des paiements ambigus
CREATE TABLE IF NOT EXISTS payment_reconciliation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    issue_type TEXT NOT NULL, -- webhook_missed, amount_mismatch, status_mismatch
    notes TEXT,
    resolved_by UUID, -- admin user id
    resolved_at TIMESTAMPTZ,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Demandes de remboursement
CREATE TABLE IF NOT EXISTS refund_requests (
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

-- 13. Codes de parrainage
CREATE TABLE IF NOT EXISTS referral_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    code TEXT UNIQUE NOT NULL,
    uses_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
