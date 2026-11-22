-- ============================================================================
-- 94 — Corrigés d'exercices invisibles avant la tentative (Lot 1, suite)
-- ============================================================================
-- Faille : `exercises.solution_json` (bonne réponse QCM + corrigé) était renvoyé à l'élève avec
-- l'énoncé. Pour les 355 exercices « évaluation » publiés, il suffisait de lire la réponse dans
-- la requête réseau. Le CDC §3.4 prévoit : entraînement → corrigé visible directement ;
-- évaluation → corrigé débloqué APRÈS tentative.
--
-- RLS filtre des lignes, pas des colonnes. Solution retenue, sans toucher à l'admin ni aux agents
-- IA (qui lisent la table directement, en admin ou en service_role) :
--   1. vue `exercises_for_student` : mêmes lignes que l'ancienne policy élève (classe du profil,
--      palier, trimestre — fonctions de la migration 93), toutes les colonnes de `exercises`,
--      mais `solution_json` vaut NULL tant que l'élève n'y a pas droit ;
--   2. la policy SELECT de la table `exercises` devient réservée aux admins.
-- L'app élève lit désormais la vue (student_supabase_service.dart) et, pour une évaluation,
-- relit l'exercice après avoir enregistré sa tentative (correction calculée côté serveur par le
-- trigger de la migration 93).
--
-- Prérequis : migration 93 (current_user_can_read_class_content, content_term_unlocked).
-- Non destructif : aucune donnée modifiée.
-- ============================================================================

-- L'élève connecté a-t-il déjà soumis une tentative sur cet exercice ?
create or replace function current_user_attempted_exercise(p_exercise_id uuid)
returns boolean as $$
    select exists (
        select 1
        from exercise_attempts a
        join profiles p on p.id = a.profile_id
        join accounts ac on ac.id = p.account_id
        where a.exercise_id = p_exercise_id
          and ac.auth_user_id = auth.uid()
    );
$$ language sql stable security definer set search_path = public;

-- Vue construite dynamiquement : elle reprend TOUTES les colonnes actuelles de `exercises`
-- (la production en a peut-être plus que le dépôt), sauf `solution_json` qui est conditionnée.
do $$
declare
    v_cols text;
begin
    select string_agg(format('e.%I', column_name), ', ' order by ordinal_position)
      into v_cols
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'exercises'
       and column_name <> 'solution_json';

    execute 'drop view if exists public.exercises_for_student';
    execute format($v$
        create view public.exercises_for_student with (security_barrier = true) as
        select %s,
               case
                   when e.type = 'entraînement' or current_user_attempted_exercise(e.id)
                   then e.solution_json
                   else null
               end as solution_json
        from public.exercises e
        where e.is_published = true
          and e.is_active = true
          and content_term_unlocked(coalesce(
                e.term_id,
                (select c.term_id from public.chapters c where c.id = e.chapter_id),
                (select c.term_id from public.lessons l join public.chapters c on c.id = l.chapter_id where l.id = e.lesson_id)
              ))
          and current_user_can_read_class_content(
                coalesce(
                    e.class_node_id,
                    (select c.class_node_id from public.chapters c where c.id = e.chapter_id),
                    (select c.class_node_id from public.lessons l join public.chapters c on c.id = l.chapter_id where l.id = e.lesson_id)
                ),
                case when e.type = 'évaluation' then 'exercises_evaluation' else 'exercises_training' end,
                e.min_subscription_tier
              )
    $v$, v_cols);
end $$;

comment on view public.exercises_for_student is
    'Lecture élève des exercices : filtrée par classe/palier/trimestre, corrigé masqué tant que non autorisé (migration 94).';

revoke all on public.exercises_for_student from anon, public;
grant select on public.exercises_for_student to authenticated;

-- La table elle-même n'est plus lisible que par les admins (les élèves passent par la vue).
drop policy if exists exercises_select on exercises;
create policy exercises_select on exercises for select using (is_admin_user());

-- Le trigger de correction (migration 93) lit `exercises` avec SECURITY DEFINER : non affecté.

notify pgrst, 'reload schema';
