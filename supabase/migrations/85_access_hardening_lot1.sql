-- ============================================================================
-- 85 — Durcissement des accès (Lot 1 de l'audit du 2026-11-22)
-- ============================================================================
-- Non destructif : aucune table/colonne supprimée, aucune donnée modifiée. Uniquement des
-- fonctions (CREATE OR REPLACE), des triggers et le remplacement de 3 policies SELECT.
--
-- Failles corrigées (toutes vérifiées sur une base locale rejouant les migrations 01→84) :
--
-- F1. Un élève pouvait s'attribuer n'importe quel palier : `profiles_update` autorise le
--     propriétaire à modifier TOUTES les colonnes, y compris `subscription_tier`, et
--     `profiles_insert` le laisse créer un profil directement en 'annuel'.
--     → trigger `guard_profile_client_writes` : côté client (auth.uid() non nul, non admin),
--       le palier est forcé à 'gratuit' à la création et immuable ensuite ; la classe et le
--       compte d'un profil sont immuables (CDC §2.4 : pas de changement de classe) ; le statut
--       ne peut basculer qu'entre 'actif' et 'archive'. Le webhook de paiement, le cron
--       d'expiration (service_role / postgres, auth.uid() nul) et les admins ne sont pas touchés.
--
-- F2. Cloisonnement par classe absent côté serveur : `current_user_has_feature_access` vérifie
--     qu'UN profil quelconque du compte a le droit, sans regarder la classe du contenu. Un
--     abonnement en 3e ouvrait par l'API les leçons de Terminale (CDC §2.3/§2.4 violés).
--     → `current_user_can_read_class_content(classe, feature, palier_min)` : exige un profil
--       ACTIF du compte, DE LA CLASSE du contenu, dont le palier inclut la fonctionnalité.
--
-- F3. Hiérarchie des paliers ignorée : un contenu marqué 'mensuel' était ouvert à tout palier
--     ayant la fonctionnalité (ex. journalier). → `tier_rank()` selon CDC §6.1
--     (Gratuit < Journalier < Hebdomadaire < Mensuel < Annuel). Un palier minimum inconnu
--     garde l'ancien comportement (fonctionnalité seule) plutôt que de tout bloquer.
--
-- F4. Déblocage trimestriel (CDC §3.3) calculé seulement dans l'app : le contenu des
--     trimestres futurs se lisait directement par l'API. → `content_term_unlocked(term_id)`.
--     Cumulatif : visible dès que le trimestre a commencé (fuseau Africa/Douala), sans
--     trimestre = visible.
--
-- F5. Scores falsifiables : `is_correct` était fourni par l'app, et un élève pouvait aussi
--     insérer `official_correct = true` (que la maîtrise utilise en priorité, migration 72).
--     → trigger `grade_exercise_attempt` : pour un insert client, `is_correct` est recalculé
--       côté serveur pour les QCM (selected_index vs solution_json.correct_index), mis à NULL
--       sinon, et tous les champs de revue IA/humaine sont remis à NULL.
--
-- Reste ouvert (lots suivants, nécessite des changements côté app) : `solution_json` reste
-- lisible avant tentative ; les documents du bucket "media" sont en lecture publique.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Vrai seulement pour une requête d'un utilisateur final (élève/parent) : JWT présent et pas
-- admin. Les appels service_role (Edge Functions, webhook) et le cron (postgres) ont
-- auth.uid() nul et ne sont jamais concernés par les gardes ci-dessous.
create or replace function is_end_user_request()
returns boolean as $$
    select auth.uid() is not null and not is_admin_user();
$$ language sql stable security definer set search_path = public;

-- CDC §6.1 : Gratuit < Journalier < Hebdomadaire < Mensuel < Annuel. NULL si nom inconnu.
create or replace function tier_rank(p_tier text)
returns int as $$
    select case lower(trim(coalesce(p_tier, '')))
        when 'gratuit' then 0
        when 'essai' then 0
        when 'journalier' then 1
        when 'hebdomadaire' then 2
        when 'mensuel' then 3
        when 'annuel' then 4
        else null
    end;
$$ language sql immutable;

-- CDC §3.3 : contenu visible dès que son trimestre a commencé (cumulatif). Sans trimestre :
-- visible. Trimestre désactivé : traité comme n'importe quel autre (la date fait foi).
create or replace function content_term_unlocked(p_term_id uuid)
returns boolean as $$
    select p_term_id is null or exists (
        select 1 from terms t
        where t.id = p_term_id
          and t.start_date <= (now() at time zone 'Africa/Douala')::date
    );
$$ language sql stable security definer set search_path = public;

-- F2 + F3 : l'utilisateur a-t-il un profil ACTIF de CETTE classe dont le palier ouvre ce contenu ?
-- p_feature_key NULL = contenu gratuit (seule l'appartenance à la classe est exigée).
create or replace function current_user_can_read_class_content(
    p_class_node_id uuid,
    p_feature_key text,
    p_min_tier text
)
returns boolean as $$
    select p_class_node_id is not null and exists (
        select 1
        from profiles p
        join accounts a on a.id = p.account_id
        where a.auth_user_id = auth.uid()
          and p.status = 'actif'
          and p.class_node_id = p_class_node_id
          and (
              coalesce(tier_rank(p_min_tier), 0) = 0
              or (
                  coalesce(tier_rank(p.subscription_tier), 0) >= coalesce(tier_rank(p_min_tier), 0)
                  and exists (
                      select 1
                      from subscription_tiers st
                      join access_matrix am on am.tier_id = st.id
                      where st.class_node_id = p.class_node_id
                        and st.name = p.subscription_tier
                        and am.feature_key = p_feature_key
                        and am.access_level <> 'aucun'
                  )
              )
          )
    );
$$ language sql stable security definer set search_path = public;

-- ---------------------------------------------------------------------------
-- F2/F3/F4 — policies de lecture du contenu
-- ---------------------------------------------------------------------------

drop policy if exists lessons_select on lessons;
create policy lessons_select on lessons for select using (
    is_admin_user()
    or (
        is_published = true
        and is_active = true
        and exists (
            select 1 from chapters c
            where c.id = lessons.chapter_id
              and c.is_active = true
              and content_term_unlocked(c.term_id)
              and current_user_can_read_class_content(c.class_node_id, 'courses', lessons.min_subscription_tier)
        )
    )
);

drop policy if exists exercises_select on exercises;
create policy exercises_select on exercises for select using (
    is_admin_user()
    or (
        is_published = true
        and is_active = true
        and content_term_unlocked(coalesce(
            exercises.term_id,
            (select c.term_id from chapters c where c.id = exercises.chapter_id),
            (select c.term_id from lessons l join chapters c on c.id = l.chapter_id where l.id = exercises.lesson_id)
        ))
        and current_user_can_read_class_content(
            coalesce(
                exercises.class_node_id,
                (select c.class_node_id from chapters c where c.id = exercises.chapter_id),
                (select c.class_node_id from lessons l join chapters c on c.id = l.chapter_id where l.id = exercises.lesson_id)
            ),
            case when exercises.type = 'évaluation' then 'exercises_evaluation' else 'exercises_training' end,
            exercises.min_subscription_tier
        )
    )
);

-- Sujets officiels : la classe vient de l'examen parent. Pas de palier minimum par sujet :
-- la fonctionnalité 'official_exams' du palier fait foi (comportement de la migration 26).
drop policy if exists exam_papers_select on exam_papers;
create policy exam_papers_select on exam_papers for select using (
    is_admin_user()
    or exists (
        select 1 from official_exams e
        where e.id = exam_papers.exam_id
          and current_user_can_read_class_content(e.class_node_id, 'official_exams', 'journalier')
    )
);

-- ---------------------------------------------------------------------------
-- F1 — garde sur les écritures client de `profiles`
-- ---------------------------------------------------------------------------

create or replace function guard_profile_client_writes()
returns trigger as $$
begin
    if not is_end_user_request() then
        return new;
    end if;

    if tg_op = 'INSERT' then
        new.subscription_tier := 'gratuit';
        new.status := 'actif';
        return new;
    end if;

    -- UPDATE par l'élève lui-même
    if new.subscription_tier is distinct from old.subscription_tier then
        raise exception 'Le palier d''abonnement ne peut être modifié que par un paiement confirmé.'
            using errcode = '42501';
    end if;
    if new.class_node_id is distinct from old.class_node_id or new.account_id is distinct from old.account_id then
        raise exception 'La classe d''un profil ne peut pas être changée : créez un nouveau profil.'
            using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and not (old.status in ('actif', 'archive') and new.status in ('actif', 'archive')) then
        raise exception 'Changement de statut non autorisé.' using errcode = '42501';
    end if;
    return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_guard_profile_client_writes on profiles;
create trigger trg_guard_profile_client_writes
    before insert or update on profiles
    for each row execute function guard_profile_client_writes();

-- ---------------------------------------------------------------------------
-- F5 — correction serveur des tentatives
-- ---------------------------------------------------------------------------

create or replace function grade_exercise_attempt()
returns trigger as $$
declare
    v_format text;
    v_correct_index text;
    v_selected text;
begin
    if not is_end_user_request() then
        return new;
    end if;

    -- Champs de revue : jamais fournis par l'élève.
    new.official_correct := null;
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.ai_score := null;
    new.ai_confidence := null;
    new.ai_feedback := null;
    new.ai_misconceptions := null;
    new.needs_human_review := false;

    select e.format, e.solution_json ->> 'correct_index'
      into v_format, v_correct_index
      from exercises e where e.id = new.exercise_id;

    v_selected := new.submitted_answer ->> 'selected_index';

    if v_format = 'qcm' and v_correct_index is not null and v_selected is not null then
        new.is_correct := (v_selected = v_correct_index);
    else
        -- Réponse libre : jamais auto-validée côté client (statut honnête « non évalué »).
        new.is_correct := null;
    end if;
    return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_grade_exercise_attempt on exercise_attempts;
create trigger trg_grade_exercise_attempt
    before insert on exercise_attempts
    for each row execute function grade_exercise_attempt();
