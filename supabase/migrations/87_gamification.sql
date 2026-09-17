-- CDC Partie 1 §14 : badges, streak (jours consécutifs d'activité), points d'expérience cumulés —
-- rien n'existait avant (vérifié : aucune table de suivi de progression/complétion de leçon dans
-- les 86 migrations précédentes ; `profile_achievements_section.dart` était 100% décoratif, deux
-- lignes codées en dur "Actif"/"En cours"). Tout ce qui suit est calculé depuis de vraies preuves
-- d'activité (exercise_attempts, sessions — migration 86 — et la nouvelle lesson_completions),
-- jamais un chiffre inventé côté client.

-- 1) Preuve manquante : aucune trace de "cette leçon a été lue" n'existait nulle part.
CREATE TABLE IF NOT EXISTS lesson_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(profile_id, lesson_id)
);
ALTER TABLE lesson_completions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS lesson_completions_select ON lesson_completions;
CREATE POLICY lesson_completions_select ON lesson_completions
    FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS lesson_completions_insert ON lesson_completions;
CREATE POLICY lesson_completions_insert ON lesson_completions
    FOR INSERT WITH CHECK (owns_profile(profile_id));
-- Append-only (même posture que exercise_attempts, migration 64) : jamais de UPDATE/DELETE élève.
CREATE INDEX IF NOT EXISTS idx_lesson_completions_profile ON lesson_completions (profile_id);

-- 2) Barème administrable (évite les nombres magiques, seedé avec des valeurs raisonnables).
CREATE TABLE IF NOT EXISTS gamification_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    xp_per_lesson INT NOT NULL DEFAULT 10,
    xp_per_attempt INT NOT NULL DEFAULT 2,
    xp_per_correct_attempt INT NOT NULL DEFAULT 5,
    xp_per_active_day INT NOT NULL DEFAULT 3,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE gamification_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gamification_rules_select ON gamification_rules;
CREATE POLICY gamification_rules_select ON gamification_rules FOR SELECT USING (true);
INSERT INTO gamification_rules (id) SELECT uuid_generate_v4() WHERE NOT EXISTS (SELECT 1 FROM gamification_rules);

-- 3) Catalogue de badges (§14 : "chapitre terminé", "série de bonnes réponses", "régularité").
CREATE TABLE IF NOT EXISTS badge_definitions (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_key TEXT NOT NULL,
    criteria_type TEXT NOT NULL CHECK (criteria_type IN ('lessons_completed', 'correct_attempts', 'streak_days', 'chapters_completed')),
    criteria_threshold INT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    display_order INT NOT NULL DEFAULT 0
);
ALTER TABLE badge_definitions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS badge_definitions_select ON badge_definitions;
CREATE POLICY badge_definitions_select ON badge_definitions FOR SELECT USING (true);

INSERT INTO badge_definitions (code, name, description, icon_key, criteria_type, criteria_threshold, display_order) VALUES
    ('first_lesson', 'Première leçon', 'Terminer sa toute première leçon.', 'menu_book_rounded', 'lessons_completed', 1, 1),
    ('lessons_10', 'Dix leçons', 'Terminer 10 leçons.', 'menu_book_rounded', 'lessons_completed', 10, 2),
    ('lessons_50', 'Cinquante leçons', 'Terminer 50 leçons.', 'auto_stories_rounded', 'lessons_completed', 50, 3),
    ('first_chapter', 'Premier chapitre', 'Terminer toutes les leçons d''un chapitre.', 'flag_rounded', 'chapters_completed', 1, 4),
    ('chapters_5', 'Cinq chapitres', 'Terminer 5 chapitres complets.', 'military_tech_rounded', 'chapters_completed', 5, 5),
    ('correct_10', 'Dix bonnes réponses', 'Réussir 10 exercices.', 'check_circle_rounded', 'correct_attempts', 10, 6),
    ('correct_50', 'Cinquante bonnes réponses', 'Réussir 50 exercices.', 'workspace_premium_rounded', 'correct_attempts', 50, 7),
    ('streak_3', 'Trois jours de suite', 'Être actif 3 jours consécutifs.', 'local_fire_department_rounded', 'streak_days', 3, 8),
    ('streak_7', 'Une semaine de régularité', 'Être actif 7 jours consécutifs.', 'local_fire_department_rounded', 'streak_days', 7, 9),
    ('streak_30', 'Un mois de régularité', 'Être actif 30 jours consécutifs.', 'whatshot_rounded', 'streak_days', 30, 10)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS profile_badges (
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    badge_code TEXT NOT NULL REFERENCES badge_definitions(code) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (profile_id, badge_code)
);
ALTER TABLE profile_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profile_badges_select ON profile_badges;
CREATE POLICY profile_badges_select ON profile_badges
    FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());

-- 4) Résumé calculé (jamais stocké — même posture que get_student_skill_mastery, migration 64) :
-- XP, streak (jours consécutifs se terminant aujourd'hui ou hier — sinon le streak est "rompu",
-- retombe à 0, mais le record `longest_streak` reste visible), à partir de sources réelles :
-- exercise_attempts, lesson_completions, et les connexions réelles (sessions, migration 86).
CREATE OR REPLACE FUNCTION get_profile_gamification(p_profile_id UUID) RETURNS JSONB AS $$
DECLARE
    v_account_id UUID;
    v_rules RECORD;
    v_lessons_completed INT;
    v_attempts_count INT;
    v_correct_attempts INT;
    v_dates DATE[];
    v_active_days INT := 0;
    v_streak INT := 0;
    v_longest_streak INT := 0;
    v_current_run INT;
    v_last_active_date DATE;
    i INT;
BEGIN
    SELECT account_id INTO v_account_id FROM profiles WHERE id = p_profile_id;

    SELECT * INTO v_rules FROM gamification_rules ORDER BY updated_at DESC LIMIT 1;
    IF NOT FOUND THEN
        v_rules.xp_per_lesson := 10; v_rules.xp_per_attempt := 2;
        v_rules.xp_per_correct_attempt := 5; v_rules.xp_per_active_day := 3;
    END IF;

    SELECT count(*) INTO v_lessons_completed FROM lesson_completions WHERE profile_id = p_profile_id;
    SELECT count(*), count(*) FILTER (WHERE is_correct = true)
        INTO v_attempts_count, v_correct_attempts
        FROM exercise_attempts WHERE profile_id = p_profile_id;

    SELECT array_agg(DISTINCT d ORDER BY d DESC) INTO v_dates
    FROM (
        SELECT created_at::date AS d FROM exercise_attempts WHERE profile_id = p_profile_id
        UNION
        SELECT completed_at::date FROM lesson_completions WHERE profile_id = p_profile_id
        UNION
        SELECT s.created_at::date FROM sessions s WHERE s.account_id = v_account_id
    ) t;

    v_active_days := COALESCE(array_length(v_dates, 1), 0);

    IF v_active_days > 0 THEN
        v_last_active_date := v_dates[1];

        IF v_last_active_date >= CURRENT_DATE - 1 THEN
            v_streak := 1;
            FOR i IN 2..array_length(v_dates, 1) LOOP
                IF v_dates[i] = v_dates[i - 1] - 1 THEN
                    v_streak := v_streak + 1;
                ELSE
                    EXIT;
                END IF;
            END LOOP;
        END IF;

        v_current_run := 1;
        v_longest_streak := 1;
        FOR i IN 2..array_length(v_dates, 1) LOOP
            IF v_dates[i] = v_dates[i - 1] - 1 THEN
                v_current_run := v_current_run + 1;
            ELSE
                v_current_run := 1;
            END IF;
            IF v_current_run > v_longest_streak THEN
                v_longest_streak := v_current_run;
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'xp', v_lessons_completed * v_rules.xp_per_lesson
            + v_attempts_count * v_rules.xp_per_attempt
            + v_correct_attempts * v_rules.xp_per_correct_attempt
            + v_active_days * v_rules.xp_per_active_day,
        'streak_days', v_streak,
        'longest_streak', v_longest_streak,
        'last_active_date', v_last_active_date,
        'lessons_completed', v_lessons_completed,
        'attempts_count', v_attempts_count,
        'correct_attempts', v_correct_attempts,
        'chapters_completed', (
            SELECT count(DISTINCT l.chapter_id)
            FROM lesson_completions lc
            JOIN lessons l ON l.id = lc.lesson_id
            WHERE lc.profile_id = p_profile_id
              AND NOT EXISTS (
                  SELECT 1 FROM lessons l2
                  WHERE l2.chapter_id = l.chapter_id
                    AND l2.is_published = true AND l2.is_active = true
                    AND NOT EXISTS (
                        SELECT 1 FROM lesson_completions lc2
                        WHERE lc2.lesson_id = l2.id AND lc2.profile_id = p_profile_id
                    )
              )
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 5) Attribution des badges : idempotent (ne retourne que les codes NOUVELLEMENT gagnés à cet
-- appel précis, pour que le client puisse célébrer une seule fois, jamais à chaque rafraîchissement).
CREATE OR REPLACE FUNCTION sync_profile_badges(p_profile_id UUID) RETURNS SETOF TEXT AS $$
DECLARE
    v_summary JSONB;
    v_badge RECORD;
    v_current_value INT;
    v_newly_earned TEXT[] := '{}';
BEGIN
    v_summary := get_profile_gamification(p_profile_id);
    FOR v_badge IN SELECT * FROM badge_definitions WHERE is_active LOOP
        v_current_value := CASE v_badge.criteria_type
            WHEN 'lessons_completed' THEN (v_summary->>'lessons_completed')::int
            WHEN 'correct_attempts' THEN (v_summary->>'correct_attempts')::int
            WHEN 'chapters_completed' THEN (v_summary->>'chapters_completed')::int
            WHEN 'streak_days' THEN GREATEST((v_summary->>'streak_days')::int, (v_summary->>'longest_streak')::int)
            ELSE 0
        END;
        IF v_current_value >= v_badge.criteria_threshold
           AND NOT EXISTS (SELECT 1 FROM profile_badges WHERE profile_id = p_profile_id AND badge_code = v_badge.code) THEN
            INSERT INTO profile_badges (profile_id, badge_code) VALUES (p_profile_id, v_badge.code)
            ON CONFLICT DO NOTHING;
            v_newly_earned := array_append(v_newly_earned, v_badge.code);
        END IF;
    END LOOP;
    RETURN QUERY SELECT unnest(v_newly_earned);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

NOTIFY pgrst, 'reload schema';
