-- ============================================================================
-- Matrice de Droits — combler les écarts d'application réelle
-- ============================================================================
-- Audit de l'écran "Matrice de Droits" (page-by-page rigor pass) demandé explicitement complet par
-- l'utilisateur ("tout et absolument tout doit y être mentionné") : deux des 5 fonctionnalités
-- affichées dans la matrice (`official_exams`, `ai_assistant`) n'étaient en réalité vérifiées par
-- AUCUNE policy RLS — modifier leur niveau d'accès dans l'admin ne changeait donc rien côté élève.
-- Et deux contenus payants réels (Boutique de documents, Épreuves d'Établissements/officielles)
-- n'avaient tout simplement AUCUNE ligne dans la matrice, donc aucun moyen de les restreindre par
-- palier — ils étaient accessibles à tous, y compris aux comptes gratuits.
--
-- Cette migration corrige ce qui peut l'être proprement avec l'infrastructure access_matrix
-- existante (une clé de fonctionnalité déjà déclarée `official_exams`, et l'ajout d'une nouvelle clé
-- `shop_documents` suivant exactement le même modèle que `courses`/`exercises_*`) :
--   - exam_papers (le contenu téléchargeable réel des Examens Officiels) est maintenant gate par
--     current_user_has_feature_access('official_exams'). Les métadonnées de l'examen
--     (official_exams) restent publiques : un élève doit pouvoir voir qu'un examen existe avant de
--     décider de payer pour y accéder.
--   - shop_documents est maintenant gate par current_user_has_feature_access('shop_documents').
--
-- `ai_assistant` et les Olympiades/Examens Blancs (`events`, mode de tarification 'payant' par
-- événement, sans table de suivi d'achat) sont volontairement LAISSÉS TELS QUELS ici — les corriger
-- nécessiterait soit de construire une fonctionnalité qui n'existe nulle part encore (assistant IA
-- élève), soit un système de suivi des achats individuels qui n'existe pas non plus. Signalés à
-- l'utilisateur comme chantiers séparés plutôt que devinés.

DROP POLICY IF EXISTS exam_papers_select ON exam_papers;
CREATE POLICY exam_papers_select ON exam_papers FOR SELECT USING (
    is_admin_user() OR current_user_has_feature_access('official_exams')
);

-- Nouvelle clé de fonctionnalité pour la Boutique de documents — même modèle binaire que
-- courses/exercises (le palier inclut le document ou non). Le champ `price` de shop_documents
-- reste disponible pour un futur parcours d'achat à l'unité, non construit ici.
DROP POLICY IF EXISTS shop_documents_select ON shop_documents;
CREATE POLICY shop_documents_select ON shop_documents FOR SELECT USING (
    is_admin_user() OR (is_active = true AND current_user_has_feature_access('shop_documents'))
);
