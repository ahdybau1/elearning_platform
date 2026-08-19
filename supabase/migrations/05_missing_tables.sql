-- Migration 05: Tables ajoutées depuis la V1 des migrations (Boutique, Dons, Passage de classe)
-- Ces tables existent déjà dans supabase/reset_project_schema.sql mais n'avaient jamais été
-- répercutées dans le dossier migrations/, qui était resté désynchronisé du schéma réellement
-- déployé (voir 02_migration_discipline.md, règle 4 : correspondance schéma <-> code).

-- Section 7 du CDC : Boutique & Documents payants à la carte
CREATE TABLE IF NOT EXISTS shop_documents (
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
CREATE TABLE IF NOT EXISTS charity_campaigns (
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

CREATE TABLE IF NOT EXISTS donations (
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
CREATE TABLE IF NOT EXISTS school_years (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- ex: '2026-2027'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT TRUE,
    promotion_campaign_open BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS promotion_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    from_class_node_id UUID NOT NULL REFERENCES academic_nodes(id),
    to_class_node_id UUID REFERENCES academic_nodes(id),
    school_year TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('valide', 'redoublement')),
    processed_at TIMESTAMPTZ DEFAULT NOW()
);
