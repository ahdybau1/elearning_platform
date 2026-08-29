-- Bug trouvé en testant DiagnosticAgent (IA-010) : get_student_skill_mastery (migration 64, IA-007)
-- ne lisait QUE `is_correct` (posé uniquement côté client pour le QCM) — une tentative reponse_courte/
-- redaction validée par un admin via official_correct (IA-009, migration 68) ne comptait donc JAMAIS
-- dans la maîtrise de l'élève, même après validation humaine positive. Corrigé : le signal de
-- correction utilisé est COALESCE(official_correct, is_correct) — la validation humaine prime quand
-- elle existe, sinon on retombe sur le signal déterministe du QCM.

CREATE OR REPLACE FUNCTION get_student_skill_mastery(p_profile_id UUID, p_subject_id UUID DEFAULT NULL)
RETURNS TABLE (
    skill_id UUID,
    skill_name TEXT,
    attempts_count BIGINT,
    correct_count BIGINT,
    mastery_level NUMERIC,
    last_attempt_at TIMESTAMPTZ
) AS $$
    SELECT es.skill_id, sk.name,
           COUNT(*) AS attempts_count,
           COUNT(*) FILTER (WHERE COALESCE(ea.official_correct, ea.is_correct)) AS correct_count,
           ROUND(COUNT(*) FILTER (WHERE COALESCE(ea.official_correct, ea.is_correct))::numeric / NULLIF(COUNT(*), 0), 3) AS mastery_level,
           MAX(ea.created_at) AS last_attempt_at
    FROM exercise_attempts ea
    JOIN exercise_skills es ON es.exercise_id = ea.exercise_id
    JOIN skills sk ON sk.id = es.skill_id
    WHERE ea.profile_id = p_profile_id
      AND (p_subject_id IS NULL OR sk.subject_id = p_subject_id)
    GROUP BY es.skill_id, sk.name;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

NOTIFY pgrst, 'reload schema';
