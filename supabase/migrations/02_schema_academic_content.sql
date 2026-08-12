-- Migration 02: Arbre Académique et Contenu Pédagogique

-- 1. Noeud générique de l'Arbre Académique (profondeur variable selon le pays)
CREATE TABLE IF NOT EXISTS academic_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE,
    node_type TEXT NOT NULL CHECK (node_type IN ('country', 'section', 'education_type', 'class', 'series')),
    name TEXT NOT NULL,
    code TEXT, -- ex: 'CM', 'FR_SEC', 'GEN', '3E', 'BAC_C'
    country_id UUID REFERENCES academic_nodes(id), -- Auto-référence vers la racine pays
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Matières
CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL, -- ex: Mathématiques, SVT, Physique-Chimie, Histoire-Géo
    code TEXT NOT NULL,
    country_id UUID REFERENCES academic_nodes(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Association Matière <-> Classe/Série (Portée classe ou groupe de classes liées)
CREATE TABLE IF NOT EXISTS subject_class_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(subject_id, class_node_id)
);

-- 4. Découpage Temporel (Trimestres - gérés uniquement côté back-end, invisibles élève)
CREATE TABLE IF NOT EXISTS terms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- Trimestre 1, Trimestre 2, Trimestre 3
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    school_year TEXT NOT NULL, -- ex: '2026-2027'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Chapitres
CREATE TABLE IF NOT EXISTS chapters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    term_id UUID REFERENCES terms(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    introduction TEXT, -- Texte d'ouverture du chapitre
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Leçons (Cours)
CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- Contenu structuré (paragraphes, médias, formules)
    display_order INT DEFAULT 0,
    is_published BOOLEAN DEFAULT FALSE,
    min_subscription_tier TEXT DEFAULT 'gratuit',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Catalogue d'éléments pédagogiques par matière (Pour guidage IA et templates)
CREATE TABLE IF NOT EXISTS content_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    element_type TEXT NOT NULL, -- définition, théorème, propriété, méthode, exemple, exercice
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Exercices (3 niveaux d'indépendance)
CREATE TABLE IF NOT EXISTS exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE, -- Niveau 1: Rattaché leçon
    chapter_id UUID REFERENCES chapters(id) ON DELETE CASCADE, -- Niveau 2: Rattaché chapitre (si lesson_id NULL)
    type TEXT NOT NULL CHECK (type IN ('entraînement', 'évaluation')),
    difficulty TEXT NOT NULL CHECK (difficulty IN ('facile', 'intermédiaire', 'approfondissement')),
    format TEXT NOT NULL CHECK (format IN ('qcm', 'reponse_courte', 'redaction', 'manuscrit_scan', 'flashcard')),
    title TEXT NOT NULL,
    instructions_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- Énoncé, questions, options
    solution_json JSONB DEFAULT '{}'::jsonb, -- Corrigé et barème
    min_subscription_tier TEXT DEFAULT 'gratuit',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Versioning des contenus publiés
CREATE TABLE IF NOT EXISTS exercise_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Médiathèque centralisée
CREATE TABLE IF NOT EXISTS media_library (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filename TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('image', 'video', 'audio', 'document')),
    url TEXT NOT NULL,
    size_bytes BIGINT,
    uploaded_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. File de validation du contenu
CREATE TABLE IF NOT EXISTS validation_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id UUID NOT NULL, -- ID leçon ou exercice
    content_type TEXT NOT NULL CHECK (content_type IN ('lesson', 'exercise')),
    author_id UUID NOT NULL, -- Enseignant ou Admin contenu
    status TEXT NOT NULL DEFAULT 'en_attente' CHECK (status IN ('brouillon', 'en_attente', 'approuve', 'rejete', 'a_corriger')),
    ai_report_json JSONB DEFAULT '{}'::jsonb, -- Rapport d'analyse auto (orthographe, cohérence)
    reviewer_id UUID,
    review_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Examens officiels nationaux (BEPC, Probatoire, Baccalauréat)
CREATE TABLE IF NOT EXISTS official_exams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- BEPC, Probatoire C, Baccalauréat A4
    exam_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Sujets et corrections des examens officiels
CREATE TABLE IF NOT EXISTS exam_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID NOT NULL REFERENCES official_exams(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    year INT NOT NULL,
    document_url TEXT NOT NULL, -- PDF du sujet
    correction_url TEXT, -- PDF du corrigé
    is_correction_unlocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. Établissements scolaires physiques
CREATE TABLE IF NOT EXISTS establishments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Épreuves par établissement (Devoirs, compositions internes)
CREATE TABLE IF NOT EXISTS establishment_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    establishment_id UUID NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL REFERENCES academic_nodes(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    year INT NOT NULL,
    document_url TEXT NOT NULL,
    correction_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
