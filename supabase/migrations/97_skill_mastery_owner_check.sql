-- 97 — get_student_skill_mastery : seul le propriétaire du profil (ou un admin, ou le serveur) lit
-- le suivi de compétences.
--
-- Constat (23/11/2026) : la fonction est SECURITY DEFINER et exécutable par tout utilisateur
-- connecté, sans vérifier à qui appartient p_profile_id. N'importe quel élève connaissant (ou
-- devinant via d'autres écrans) l'identifiant d'un profil pouvait lire les taux de réussite d'un
-- autre élève mineur. La signature et le résultat ne changent pas : l'app élève (suggestions du
-- tuteur) et ai-tutor-chat (clé de service) continuent de fonctionner.
create or replace function public.get_student_skill_mastery(p_profile_id uuid, p_subject_id uuid default null)
returns table(skill_id uuid, skill_name text, attempts_count bigint, correct_count bigint,
              mastery_level numeric, last_attempt_at timestamptz)
language sql stable security definer set search_path to 'public'
as $function$
    select es.skill_id, sk.name,
           count(*) as attempts_count,
           count(*) filter (where coalesce(ea.official_correct, ea.is_correct)) as correct_count,
           round(count(*) filter (where coalesce(ea.official_correct, ea.is_correct))::numeric / nullif(count(*), 0), 3) as mastery_level,
           max(ea.created_at) as last_attempt_at
      from exercise_attempts ea
      join exercise_skills es on es.exercise_id = ea.exercise_id
      join skills sk on sk.id = es.skill_id
     where ea.profile_id = p_profile_id
       and (p_subject_id is null or sk.subject_id = p_subject_id)
       and (owns_profile(p_profile_id) or is_admin_user() or coalesce(auth.role(), '') = 'service_role')
     group by es.skill_id, sk.name;
$function$;
