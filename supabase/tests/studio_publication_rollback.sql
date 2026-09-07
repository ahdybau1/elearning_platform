-- Integration probe. Run as database owner; ALL writes are rolled back.
-- Replace __CONTENT_JSON__ with the escaped shared JSON regression fixture.
BEGIN;
SET LOCAL statement_timeout = '15s';
DO $setup$
DECLARE
  admin_id uuid;
  auth_id uuid;
  chapter_id uuid;
BEGIN
  SELECT a.id, a.auth_user_id INTO admin_id, auth_id
    FROM public.admin_users a WHERE a.is_active AND a.auth_user_id IS NOT NULL LIMIT 1;
  SELECT c.id INTO chapter_id FROM public.chapters c WHERE c.is_active LIMIT 1;
  IF auth_id IS NULL OR chapter_id IS NULL THEN RAISE EXCEPTION 'Missing test prerequisites'; END IF;
  PERFORM set_config('test.admin_id', admin_id::text, true);
  PERFORM set_config('test.auth_id', auth_id::text, true);
  PERFORM set_config('test.chapter_id', chapter_id::text, true);
  PERFORM set_config('test.lesson_id', gen_random_uuid()::text, true);
  PERFORM set_config('test.validation_id', gen_random_uuid()::text, true);
  PERFORM set_config('request.jwt.claim.sub', auth_id::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub',auth_id,'role','authenticated')::text, true);
END $setup$;
SET LOCAL ROLE authenticated;
INSERT INTO public.lessons(id,chapter_id,title,content_json,is_published,is_active,min_subscription_tier)
VALUES(current_setting('test.lesson_id')::uuid,current_setting('test.chapter_id')::uuid,
       '__studio_rollback_probe__','__CONTENT_JSON__'::jsonb,false,true,'gratuit');
INSERT INTO public.validation_queue(id,content_id,content_type,author_id,status)
VALUES(current_setting('test.validation_id')::uuid,current_setting('test.lesson_id')::uuid,
       'lesson',current_setting('test.admin_id')::uuid,'en_attente');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
SET LOCAL ROLE anon;
DO $draft$
BEGIN
  IF EXISTS(SELECT 1 FROM public.lessons WHERE id=current_setting('test.lesson_id')::uuid)
    THEN RAISE EXCEPTION 'Draft exposed'; END IF;
  BEGIN
    PERFORM public.approve_and_publish_content(current_setting('test.validation_id')::uuid,current_setting('test.admin_id')::uuid);
    RAISE EXCEPTION 'Anonymous approval unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Anonymous approval unexpectedly succeeded' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%Action réservée%' AND SQLSTATE <> '42501' THEN RAISE; END IF;
  END;
END $draft$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('test.auth_id'),true),
       set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.auth_id'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.approve_and_publish_content(current_setting('test.validation_id')::uuid,current_setting('test.admin_id')::uuid);
DO $review$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.validation_queue WHERE id=current_setting('test.validation_id')::uuid AND status='approuve')
    THEN RAISE EXCEPTION 'Review not approved'; END IF;
END $review$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
SET LOCAL ROLE anon;
DO $published$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.lessons WHERE id=current_setting('test.lesson_id')::uuid
    AND is_published AND content_json='__CONTENT_JSON__'::jsonb)
    THEN RAISE EXCEPTION 'Published fixture unavailable or changed'; END IF;
END $published$;
RESET ROLE;
UPDATE public.lessons SET is_active=false WHERE id=current_setting('test.lesson_id')::uuid;
SET LOCAL ROLE anon;
DO $archived$
BEGIN
  IF EXISTS(SELECT 1 FROM public.lessons WHERE id=current_setting('test.lesson_id')::uuid)
    THEN RAISE EXCEPTION 'Archived lesson exposed'; END IF;
END $archived$;
RESET ROLE;
SELECT 'PASS: draft hidden, anonymous approval refused, admin approval atomic, published JSON readable, archive hidden' AS result;
ROLLBACK;
