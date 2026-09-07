-- D.8/D.9, U2.1 : revue humaine, publication atomique, lecture minimale.
-- La table reste admin-only : le RPC élève ne renvoie ni notes ni corrigé verrouillé.
BEGIN;
ALTER TABLE public.exam_paper_questions ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 1;
-- Pour les établissements, aucun ancien mécanisme de déverrouillage structuré n'existait.
-- Choix explicite admin, indépendant du lien vers le PDF historique.
ALTER TABLE public.establishment_papers ADD COLUMN IF NOT EXISTS is_correction_unlocked BOOLEAN NOT NULL DEFAULT FALSE;

CREATE OR REPLACE FUNCTION public.guard_exam_question_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_exam UUID;
  v_establishment UUID;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.exam_paper_id IS DISTINCT FROM OLD.exam_paper_id
      OR NEW.establishment_paper_id IS DISTINCT FROM OLD.establishment_paper_id) THEN
    RAISE EXCEPTION 'Une question ne peut pas changer de sujet';
  END IF;
  IF TG_OP = 'DELETE' THEN
    v_exam := OLD.exam_paper_id; v_establishment := OLD.establishment_paper_id;
  ELSE
    v_exam := NEW.exam_paper_id; v_establishment := NEW.establishment_paper_id;
  END IF;
  -- Même verrou parent que la publication, y compris pour une insertion concurrente.
  IF v_exam IS NOT NULL THEN
    PERFORM id FROM exam_papers WHERE id = v_exam FOR UPDATE;
    UPDATE exam_papers SET processing_status = 'waiting_review'
      WHERE id = v_exam AND processing_status = 'published';
  ELSE
    PERFORM id FROM establishment_papers WHERE id = v_establishment FOR UPDATE;
    UPDATE establishment_papers SET processing_status = 'waiting_review'
      WHERE id = v_establishment AND processing_status = 'published';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  IF TG_OP = 'UPDATE' THEN
    NEW.revision := OLD.revision + 1;
    IF OLD.status = 'approved' AND (NEW.statement IS DISTINCT FROM OLD.statement
        OR NEW.proposed_answer IS DISTINCT FROM OLD.proposed_answer) THEN
      NEW.status := 'waiting_review';
    END IF;
  END IF;
  IF NEW.status = 'approved' AND btrim(NEW.statement) = '' THEN
    RAISE EXCEPTION 'Un énoncé vide ne peut pas être approuvé';
  END IF;
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;
CREATE TRIGGER exam_question_change_guard BEFORE INSERT OR UPDATE OR DELETE
  ON public.exam_paper_questions FOR EACH ROW EXECUTE FUNCTION public.guard_exam_question_change();

CREATE OR REPLACE FUNCTION public.guard_exam_publication()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count INT; v_invalid INT;
BEGIN
  IF NEW.processing_status = 'published' THEN
    IF TG_OP = 'INSERT' THEN RAISE EXCEPTION 'Un sujet doit être relu avant publication'; END IF;
    IF OLD.processing_status NOT IN ('waiting_review', 'published') THEN
      RAISE EXCEPTION 'Le traitement du sujet doit être terminé avant publication';
    END IF;
    SELECT count(*), count(*) FILTER (WHERE status <> 'approved' OR btrim(statement) = '')
      INTO v_count, v_invalid FROM exam_paper_questions
      WHERE (TG_TABLE_NAME = 'exam_papers' AND exam_paper_id = NEW.id)
         OR (TG_TABLE_NAME = 'establishment_papers' AND establishment_paper_id = NEW.id);
    IF v_count = 0 OR v_invalid <> 0 THEN
      RAISE EXCEPTION 'Toutes les questions doivent être approuvées avant publication';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER exam_publication_guard BEFORE INSERT OR UPDATE ON public.exam_papers
  FOR EACH ROW EXECUTE FUNCTION public.guard_exam_publication();
CREATE TRIGGER establishment_publication_guard BEFORE INSERT OR UPDATE ON public.establishment_papers
  FOR EACH ROW EXECUTE FUNCTION public.guard_exam_publication();

CREATE OR REPLACE FUNCTION public.review_exam_paper_question(
  p_question_id UUID, p_expected_revision BIGINT, p_statement TEXT,
  p_proposed_answer TEXT, p_status TEXT, p_reviewer_notes TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_question exam_paper_questions; v_parent_status TEXT; v_before JSONB;
BEGIN
  IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs' USING ERRCODE = '42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('approved','waiting_review','needs_changes')
      OR p_statement IS NULL OR btrim(p_statement) = '' THEN
    RAISE EXCEPTION 'Énoncé ou statut invalide';
  END IF;
  SELECT * INTO v_question FROM exam_paper_questions WHERE id = p_question_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Question introuvable'; END IF;
  IF v_question.exam_paper_id IS NOT NULL THEN
    SELECT processing_status INTO v_parent_status FROM exam_papers WHERE id = v_question.exam_paper_id FOR UPDATE;
  ELSE
    SELECT processing_status INTO v_parent_status FROM establishment_papers WHERE id = v_question.establishment_paper_id FOR UPDATE;
  END IF;
  IF v_parent_status = 'processing' THEN RAISE EXCEPTION 'Traitement IA en cours'; END IF;
  SELECT * INTO v_question FROM exam_paper_questions WHERE id = p_question_id FOR UPDATE;
  IF NOT FOUND OR p_expected_revision IS NULL OR v_question.revision <> p_expected_revision THEN
    RAISE EXCEPTION 'Cette question a changé. Conservez votre texte et rechargez la révision.' USING ERRCODE = '40001';
  END IF;
  v_before := to_jsonb(v_question);
  -- L'approbation suit l'écriture dans la même transaction (le trigger invalide les anciennes approbations).
  UPDATE exam_paper_questions SET statement = btrim(p_statement), proposed_answer = nullif(btrim(p_proposed_answer), ''),
    reviewer_notes = nullif(btrim(p_reviewer_notes), ''), status = 'waiting_review' WHERE id = p_question_id;
  UPDATE exam_paper_questions SET status = p_status WHERE id = p_question_id RETURNING * INTO v_question;
  INSERT INTO audit_log(admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    SELECT id, 'UPDATE', 'exam_paper_questions', p_question_id, v_before, to_jsonb(v_question)
      FROM admin_users WHERE auth_user_id = auth.uid() AND is_active;
  RETURN to_jsonb(v_question);
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_exam_paper(p_exam_paper_id UUID DEFAULT NULL, p_establishment_paper_id UUID DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id UUID; v_table TEXT;
BEGIN
  IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs' USING ERRCODE = '42501'; END IF;
  IF (p_exam_paper_id IS NULL) = (p_establishment_paper_id IS NULL) THEN RAISE EXCEPTION 'Fournir exactement un sujet'; END IF;
  IF p_exam_paper_id IS NOT NULL THEN
    v_id := p_exam_paper_id; v_table := 'exam_papers';
    PERFORM id FROM exam_papers WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Sujet introuvable'; END IF;
    UPDATE exam_papers SET processing_status = 'published' WHERE id = v_id;
  ELSE
    v_id := p_establishment_paper_id; v_table := 'establishment_papers';
    PERFORM id FROM establishment_papers WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Sujet introuvable'; END IF;
    UPDATE establishment_papers SET processing_status = 'published' WHERE id = v_id;
  END IF;
  INSERT INTO audit_log(admin_user_id, action_type, entity_type, entity_id, after_json)
    SELECT id, 'PUBLISH', v_table, v_id, jsonb_build_object('processing_status','published')
      FROM admin_users WHERE auth_user_id = auth.uid() AND is_active;
END;
$$;

CREATE OR REPLACE FUNCTION public.read_published_exam_questions(
  p_profile_id UUID, p_exam_paper_id UUID DEFAULT NULL, p_establishment_paper_id UUID DEFAULT NULL
) RETURNS TABLE(id UUID, question_order INT, statement TEXT, proposed_answer TEXT)
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public AS $$
DECLARE v_class UUID; v_tier TEXT; v_paper_class UUID; v_status TEXT; v_unlocked BOOLEAN; v_feature TEXT;
BEGIN
  IF auth.uid() IS NULL OR (p_exam_paper_id IS NULL) = (p_establishment_paper_id IS NULL) THEN
    RAISE EXCEPTION 'Accès refusé' USING ERRCODE = '42501';
  END IF;
  SELECT p.class_node_id, p.subscription_tier INTO v_class, v_tier FROM profiles p
    JOIN accounts a ON a.id = p.account_id
    WHERE p.id = p_profile_id AND a.auth_user_id = auth.uid() AND p.status = 'actif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Profil non autorisé' USING ERRCODE = '42501'; END IF;
  IF p_exam_paper_id IS NOT NULL THEN
    SELECT e.class_node_id, p.processing_status, p.is_correction_unlocked
      INTO v_paper_class, v_status, v_unlocked FROM exam_papers p
      JOIN official_exams e ON e.id = p.exam_id WHERE p.id = p_exam_paper_id;
    v_feature := 'official_exams';
  ELSE
    SELECT p.class_node_id, p.processing_status, p.is_correction_unlocked
      INTO v_paper_class, v_status, v_unlocked FROM establishment_papers p WHERE p.id = p_establishment_paper_id;
    v_feature := 'establishment_papers';
  END IF;
  IF v_paper_class IS DISTINCT FROM v_class OR v_status IS DISTINCT FROM 'published' THEN
    RAISE EXCEPTION 'Sujet indisponible pour ce profil' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM subscription_tiers st JOIN access_matrix am ON am.tier_id = st.id
      WHERE st.class_node_id = v_class AND st.name = v_tier
        AND am.feature_key = v_feature AND am.access_level IN ('complet','limite')) THEN
    RAISE EXCEPTION 'Accès non inclus dans cet abonnement' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY SELECT q.id, q.question_order, q.statement,
    CASE WHEN v_unlocked THEN q.proposed_answer ELSE NULL::TEXT END
    FROM exam_paper_questions q WHERE q.status = 'approved'
      AND (q.exam_paper_id = p_exam_paper_id OR q.establishment_paper_id = p_establishment_paper_id)
    ORDER BY q.question_order, q.id;
END;
$$;

REVOKE ALL ON FUNCTION public.review_exam_paper_question(UUID,BIGINT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_exam_paper(UUID,UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.read_published_exam_questions(UUID,UUID,UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_exam_paper_question(UUID,BIGINT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_exam_paper(UUID,UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.read_published_exam_questions(UUID,UUID,UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
