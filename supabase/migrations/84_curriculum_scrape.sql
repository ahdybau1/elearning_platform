-- Agent de SCRAPING de curriculum : découverte de sources (recherche web) + crawl récursif en
-- profondeur, multi-pays. Alimente ensuite curriculum_import_items (migration 83) → arbre.
-- Additif pur.
--
-- Découverte à coût zéro : (1) index CommonCrawl (énumère les URL réellement indexées sous un
-- motif de domaine officiel), (2) outil google_search de Gemini quand le quota le permet,
-- (3) API Wikipédia (aperçu du système éducatif), (4) registre curaté de domaines officiels.
-- Crawl : BFS respectant robots.txt, budget de profondeur/pages, filtrage par pertinence,
-- piloté par la file de jobs (pg_cron), reprenable et annulable.

-- ── 1. Registre curaté de sources officielles par pays ──
CREATE TABLE IF NOT EXISTS curriculum_source_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_code TEXT NOT NULL,          -- ISO-3166 alpha-2 en minuscules (cm, fr, ci, sn, ga, bj…)
    country_name TEXT NOT NULL,
    system_hint TEXT,                    -- ex: 'general_francophone', 'technique', 'anglophone' (optionnel)
    domain_pattern TEXT NOT NULL,        -- motif pour l'index CommonCrawl, ex: '*.minesec.gov.cm'
    seed_url TEXT,                       -- point d'entrée direct pour le crawl (optionnel)
    label TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'ministry'
        CHECK (kind IN ('ministry', 'inspection', 'repository', 'encyclopedia', 'establishment', 'other')),
    priority INT NOT NULL DEFAULT 5,     -- 1 = à explorer en premier
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_curriculum_registry_country ON curriculum_source_registry (country_code, priority);

-- ── 2. Un run de scraping ──
CREATE TABLE IF NOT EXISTS curriculum_scrape_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scope_country_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    scope_node_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    country_code TEXT,
    scope_label TEXT NOT NULL,
    max_depth INT NOT NULL DEFAULT 2,
    max_pages INT NOT NULL DEFAULT 120,
    status TEXT NOT NULL DEFAULT 'discovering'
        CHECK (status IN ('discovering', 'crawling', 'extracting', 'proposed', 'failed', 'cancelled')),
    cancel_requested BOOLEAN NOT NULL DEFAULT FALSE,
    discovery JSONB NOT NULL DEFAULT '{}'::jsonb,   -- {commoncrawl:[...], grounding:[...], wikipedia:[...], registry:[...]}
    stats JSONB NOT NULL DEFAULT '{}'::jsonb,       -- {domains, pages_queued, pages_fetched, pages_failed, findings, items}
    import_id UUID REFERENCES curriculum_imports(id) ON DELETE SET NULL,
    error_message TEXT,
    created_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. La frontière de crawl + le journal des pages ──
CREATE TABLE IF NOT EXISTS curriculum_crawl_pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL REFERENCES curriculum_scrape_runs(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    url_key TEXT NOT NULL,               -- URL normalisée pour la déduplication
    domain TEXT NOT NULL,
    depth INT NOT NULL DEFAULT 0,
    discovered_via TEXT,                 -- commoncrawl | grounding | wikipedia | registry | link
    relevance NUMERIC(4, 3) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'fetching', 'fetched', 'failed', 'skipped_robots', 'skipped_offtopic', 'skipped_type')),
    http_status INT,
    title TEXT,
    content_hash TEXT,
    text_len INT NOT NULL DEFAULT 0,
    extracted BOOLEAN NOT NULL DEFAULT FALSE,
    error_message TEXT,
    fetched_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, url_key)
);
CREATE INDEX IF NOT EXISTS idx_crawl_pages_run_status ON curriculum_crawl_pages (run_id, status, relevance DESC);

-- ── 4. Extractions par page (avant agrégation dans curriculum_import_items) ──
CREATE TABLE IF NOT EXISTS curriculum_crawl_findings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL REFERENCES curriculum_scrape_runs(id) ON DELETE CASCADE,
    page_id UUID NOT NULL REFERENCES curriculum_crawl_pages(id) ON DELETE CASCADE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,     -- sortie brute du Model Router (structuré, non inventé)
    provider TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_crawl_findings_run ON curriculum_crawl_findings (run_id);

-- ── 5. RLS ──
ALTER TABLE curriculum_source_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE curriculum_scrape_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE curriculum_crawl_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE curriculum_crawl_findings ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['curriculum_source_registry','curriculum_scrape_runs','curriculum_crawl_pages','curriculum_crawl_findings']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_select ON %I', t, t);
    EXECUTE format('CREATE POLICY %I_select ON %I FOR SELECT USING (is_admin_user())', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_write ON %I', t, t);
    EXECUTE format('CREATE POLICY %I_write ON %I FOR ALL USING (has_admin_role(''super_admin'')) WITH CHECK (has_admin_role(''super_admin''))', t, t);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION touch_scrape_run_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_scrape_runs_touch ON curriculum_scrape_runs;
CREATE TRIGGER trg_scrape_runs_touch BEFORE UPDATE ON curriculum_scrape_runs
    FOR EACH ROW EXECUTE FUNCTION touch_scrape_run_updated_at();

-- ── 6. Seed du registre : sources officielles francophones (pq learn = Cameroun d'abord, multi-pays) ──
INSERT INTO curriculum_source_registry (country_code, country_name, system_hint, domain_pattern, seed_url, label, kind, priority) VALUES
('cm', 'Cameroun', 'general', '*.minesec.gov.cm', 'https://www.minesec.gov.cm/', 'MINESEC — Ministère des Enseignements Secondaires', 'ministry', 1),
('cm', 'Cameroun', 'general', '*.gov.cm', NULL, 'Domaines gouvernementaux camerounais (.gov.cm)', 'ministry', 3),
('cm', 'Cameroun', 'general', '*.iaipedagogie.cm', NULL, 'Inspections de pédagogie (Cameroun)', 'inspection', 2),
('cm', 'Cameroun', NULL, 'fr.wikipedia.org', 'https://fr.wikipedia.org/wiki/Syst%C3%A8me_%C3%A9ducatif_au_Cameroun', 'Wikipédia — Système éducatif au Cameroun', 'encyclopedia', 4),
('fr', 'France', 'general', 'eduscol.education.fr', 'https://eduscol.education.fr/', 'Éduscol — programmes officiels (France)', 'ministry', 1),
('fr', 'France', 'general', '*.education.gouv.fr', NULL, 'Ministère de l''Éducation nationale (France)', 'ministry', 2),
('ci', 'Côte d''Ivoire', 'general', '*.men-dpfc.org', 'https://www.men-dpfc.org/', 'DPFC — programmes éducatifs (Côte d''Ivoire)', 'ministry', 1),
('ci', 'Côte d''Ivoire', 'general', '*.education.gouv.ci', NULL, 'Ministère de l''Éducation nationale (Côte d''Ivoire)', 'ministry', 2),
('sn', 'Sénégal', 'general', '*.education.sn', 'https://www.education.sn/', 'Ministère de l''Éducation nationale (Sénégal)', 'ministry', 1),
('ga', 'Gabon', 'general', '*.education.gouv.ga', NULL, 'Ministère de l''Éducation nationale (Gabon)', 'ministry', 1),
('bj', 'Bénin', 'general', '*.enseignement.gouv.bj', NULL, 'Ministère des Enseignements Secondaire (Bénin)', 'ministry', 1)
ON CONFLICT DO NOTHING;
