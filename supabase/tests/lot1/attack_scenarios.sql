-- Scénarios d'attaque du Lot 1. Chaque ligne affiche OK si la protection tient, FAILLE sinon.
\pset tuples_only on
\pset format unaligned
set role authenticated;

-- Élève A : 3e, mensuel
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-00000000000a',false);
select case when count(*)=2 then 'OK  ' else 'FAILLE' end || ' S1 A lit ses 2 leçons 3e du trimestre en cours (vu: '||count(*)||')' from lessons where id in ('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002');
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S2 A (3e) ne lit pas les leçons de Terminale (vu: '||count(*)||')' from lessons where id in ('50000000-0000-0000-0000-000000000004','50000000-0000-0000-0000-000000000005');
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S3 A ne lit pas la leçon du trimestre futur (vu: '||count(*)||')' from lessons where id='50000000-0000-0000-0000-000000000003';
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S4 A ne lit pas les exercices de Terminale (vu: '||count(*)||')' from exercises where id='60000000-0000-0000-0000-000000000003';

-- Élève C : 3e, journalier (a la fonctionnalité courses mais pas le palier mensuel)
select set_config('request.jwt.claim.sub','c0000000-0000-0000-0000-00000000000c',false);
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S5 C (journalier) ne lit pas une leçon réservée au mensuel (vu: '||count(*)||')' from lessons where id='50000000-0000-0000-0000-000000000002';
select case when count(*)=1 then 'OK  ' else 'FAILLE' end || ' S6 C lit la leçon gratuite de sa classe (vu: '||count(*)||')' from lessons where id='50000000-0000-0000-0000-000000000001';

-- Élève B : 3e, gratuit
select set_config('request.jwt.claim.sub','b0000000-0000-0000-0000-00000000000b',false);
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S7 B (gratuit) ne lit pas la leçon mensuelle (vu: '||count(*)||')' from lessons where id='50000000-0000-0000-0000-000000000002';
do $$ begin
  begin
    update profiles set subscription_tier='annuel' where id='b2000000-0000-0000-0000-00000000000b';
  exception when others then null; end;
end $$;
reset role;
select case when subscription_tier='gratuit' then 'OK  ' else 'FAILLE' end || ' S8 B ne peut pas se passer lui-même en annuel (palier: '||subscription_tier||')' from profiles where id='b2000000-0000-0000-0000-00000000000b';
set role authenticated;
do $$ begin
  begin
    insert into profiles(id,account_id,class_node_id,subscription_tier,school_year) values ('b3000000-0000-0000-0000-00000000000b','b1000000-0000-0000-0000-00000000000b','10000000-0000-0000-0000-00000000000c','annuel','2026-2027');
  exception when others then null; end;
end $$;
reset role;
select case when coalesce(max(subscription_tier),'absent') in ('gratuit','absent') then 'OK  ' else 'FAILLE' end || ' S9 B ne peut pas créer un profil directement en annuel (palier: '||coalesce(max(subscription_tier),'absent')||')' from profiles where id='b3000000-0000-0000-0000-00000000000b';
set role authenticated;
do $$ begin
  begin
    update profiles set class_node_id='10000000-0000-0000-0000-00000000000c' where id='b2000000-0000-0000-0000-00000000000b';
  exception when others then null; end;
end $$;
reset role;
select case when class_node_id='10000000-0000-0000-0000-000000000003' then 'OK  ' else 'FAILLE' end || ' S10 B ne peut pas changer la classe de son profil' from profiles where id='b2000000-0000-0000-0000-00000000000b';
set role authenticated;
-- Non-régression : archiver / réactiver son profil reste possible
update profiles set status='archive' where id='b2000000-0000-0000-0000-00000000000b';
update profiles set status='actif' where id='b2000000-0000-0000-0000-00000000000b';
reset role;
select case when status='actif' then 'OK  ' else 'FAILLE' end || ' S11 (non-régression) B peut toujours archiver puis réactiver son profil' from profiles where id='b2000000-0000-0000-0000-00000000000b';
set role authenticated;
-- Tricher sur une tentative : mauvaise réponse (index 0, la bonne est 1) déclarée juste
insert into exercise_attempts(id,profile_id,exercise_id,is_correct,submitted_answer,official_correct) values
 ('80000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-00000000000b','60000000-0000-0000-0000-000000000001',true,'{"selected_index":0}',true),
 ('80000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-00000000000b','60000000-0000-0000-0000-000000000001',false,'{"selected_index":1}',null),
 ('80000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-00000000000b','60000000-0000-0000-0000-000000000002',true,'{"text":"blabla"}',true);
reset role;
select case when is_correct=false and official_correct is null then 'OK  ' else 'FAILLE' end || ' S12 Une mauvaise réponse déclarée juste est enregistrée fausse (is_correct='||coalesce(is_correct::text,'null')||', official_correct='||coalesce(official_correct::text,'null')||')' from exercise_attempts where id='80000000-0000-0000-0000-000000000001';
select case when is_correct=true then 'OK  ' else 'FAILLE' end || ' S13 (non-régression) Une bonne réponse QCM est bien comptée juste' from exercise_attempts where id='80000000-0000-0000-0000-000000000002';
select case when is_correct is null and official_correct is null then 'OK  ' else 'FAILLE' end || ' S14 Une réponse libre ne peut pas s''auto-valider (is_correct='||coalesce(is_correct::text,'null')||')' from exercise_attempts where id='80000000-0000-0000-0000-000000000003';
-- Service (webhook/cron) : pas d'utilisateur final dans la requête (auth.uid() nul)
select set_config('request.jwt.claim.sub','',false);
update profiles set subscription_tier='mensuel' where id='c2000000-0000-0000-0000-00000000000c';
select case when subscription_tier='mensuel' then 'OK  ' else 'FAILLE' end || ' S15 (non-régression) le serveur peut toujours changer un palier après paiement' from profiles where id='c2000000-0000-0000-0000-00000000000c';

-- ── Corrigés (migration 94) : les élèves lisent la vue exercises_for_student ──
set role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-00000000000a',false);
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S16 A ne lit plus directement la table exercises (vu: '||count(*)||')' from exercises;
select case when solution_json is null then 'OK  ' else 'FAILLE' end || ' S17 Corrigé d''une évaluation masqué avant la tentative' from exercises_for_student where id='60000000-0000-0000-0000-000000000004';
select case when (solution_json->>'correct_index')='1' then 'OK  ' else 'FAILLE' end || ' S18 (non-régression) Corrigé d''un entraînement visible directement' from exercises_for_student where id='60000000-0000-0000-0000-000000000001';
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S19 A ne voit pas les exercices de Terminale dans la vue (vu: '||count(*)||')' from exercises_for_student where id='60000000-0000-0000-0000-000000000003';
insert into exercise_attempts(profile_id,exercise_id,submitted_answer) values ('a2000000-0000-0000-0000-00000000000a','60000000-0000-0000-0000-000000000004','{"selected_index":0}');
select case when (solution_json->>'correct_index')='1' then 'OK  ' else 'FAILLE' end || ' S20 Corrigé de l''évaluation visible après la tentative' from exercises_for_student where id='60000000-0000-0000-0000-000000000004';
select set_config('request.jwt.claim.sub','b0000000-0000-0000-0000-00000000000b',false);
select case when solution_json is null then 'OK  ' else 'FAILLE' end || ' S21 B (autre élève, sans tentative) ne voit pas ce corrigé' from exercises_for_student where id='60000000-0000-0000-0000-000000000004';
reset role;

-- Élève D : Terminale D (série), lit le contenu commun posé sur la classe « Terminale »
set role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-00000000000d',false);
select case when count(*)=1 then 'OK  ' else 'FAILLE' end || ' S22 D (Terminale D) lit la leçon commune posée sur « Terminale » (vu: '||count(*)||')' from lessons where id='50000000-0000-0000-0000-0000000000a1';
select case when count(*)=0 then 'OK  ' else 'FAILLE' end || ' S23 D ne lit pas les leçons de 3e ni de Tle C (vu: '||count(*)||')' from lessons where id in ('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000004');
reset role;
