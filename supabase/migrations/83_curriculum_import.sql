-- Collecte de programmes scolaires → Arbre Académique (demande porteur #1/#2).
-- Chaîne : recherche de sources → collecte → extraction → structuration → **intégration réelle**
-- dans academic_nodes / subjects / subject_class_links / chapters, avec dédup, statut « À vérifier »,
-- suivi d'import et annulation. Additif pur ; aucune donnée existante supprimée.

-- ── 1. Traçabilité de provenance + statut de vérification sur les entités de l'arbre ──
ALTER TABLE academic_nodes ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'ok'
    CHECK (verification_status IN ('ok', 'ambiguous', 'incomplete'));
ALTER TABLE academic_nodes ADD COLUMN IF NOT EXISTS curriculum_import_id UUID;
ALTER TABLE academic_nodes ADD COLUMN IF NOT EXISTS manually_edited BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE subjects ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'ok'
    CHECK (verification_status IN ('ok', 'ambiguous', 'incomplete'));
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS curriculum_import_id UUID;
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS manually_edited BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE chapters ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'ok'
    CHECK (verification_status IN ('ok', 'ambiguous', 'incomplete'));
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS curriculum_import_id UUID;
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS manually_edited BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS source_id UUID REFERENCES ai_rag_sources(id) ON DELETE SET NULL;
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS source_year TEXT;

-- ── 2. Un run d'import de curriculum ──
CREATE TABLE IF NOT EXISTS curriculum_imports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scope_country_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    scope_node_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,  -- section/education_type sous lequel importer
    scope_label TEXT NOT NULL,
    seed_urls TEXT[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'collecting'
        CHECK (status IN ('collecting', 'proposed', 'partially_applied', 'applied', 'cancelled', 'failed')),
    summary JSONB NOT NULL DEFAULT '{}'::jsonb,      -- {proposed, matched, applied, ambiguous, gaps:[...]}
    sources_consulted JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [{url, title, http_status, year, ok}]
    gaps JSONB NOT NULL DEFAULT '[]'::jsonb,          -- programmes introuvables / incomplets / ambigus
    error_message TEXT,
    created_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    applied_at TIMESTAMPTZ
);

-- ── 3. Un élément proposé (classe / série / matière / chapitre) ──
CREATE TABLE IF NOT EXISTS curriculum_import_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    import_id UUID NOT NULL REFERENCES curriculum_imports(id) ON DELETE CASCADE,
    item_kind TEXT NOT NULL CHECK (item_kind IN ('class', 'series', 'subject', 'chapter')),
    proposed_name TEXT NOT NULL,
    proposed_code TEXT,
    display_order INT NOT NULL DEFAULT 0,
    parent_path TEXT NOT NULL DEFAULT '',            -- chemin lisible pour l'humain
    parent_ref JSONB NOT NULL DEFAULT '{}'::jsonb,   -- {class_name, series_name, subject_name} pour résoudre le parent
    matched_node_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    matched_subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    matched_chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    match_confidence NUMERIC(4, 3) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'proposed'
        CHECK (status IN ('proposed', 'verified', 'applied', 'rejected', 'skipped_duplicate')),
    verification_status TEXT NOT NULL DEFAULT 'ok'
        CHECK (verification_status IN ('ok', 'ambiguous', 'incomplete')),
    source_id UUID REFERENCES ai_rag_sources(id) ON DELETE SET NULL,
    source_title TEXT,
    source_url TEXT,
    source_year TEXT,
    source_excerpt TEXT,                             -- extrait littéral qui justifie l'élément
    applied_entity_id UUID,                          -- ce qui a été créé/mis à jour à l'application
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_curriculum_items_import ON curriculum_import_items (import_id, item_kind, display_order);
CREATE INDEX IF NOT EXISTS idx_curriculum_items_status ON curriculum_import_items (status);

-- ── 4. RLS — lecture tout admin, écriture super_admin ──
ALTER TABLE curriculum_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE curriculum_import_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS curriculum_imports_select ON curriculum_imports;
CREATE POLICY curriculum_imports_select ON curriculum_imports FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS curriculum_imports_write ON curriculum_imports;
CREATE POLICY curriculum_imports_write ON curriculum_imports FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS curriculum_import_items_select ON curriculum_import_items;
CREATE POLICY curriculum_import_items_select ON curriculum_import_items FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS curriculum_import_items_write ON curriculum_import_items;
CREATE POLICY curriculum_import_items_write ON curriculum_import_items FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

CREATE OR REPLACE FUNCTION touch_curriculum_import_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_curriculum_imports_touch ON curriculum_imports;
CREATE TRIGGER trg_curriculum_imports_touch BEFORE UPDATE ON curriculum_imports
    FOR EACH ROW EXECUTE FUNCTION touch_curriculum_import_updated_at();
