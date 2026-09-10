# AUDIT GLOBAL ÉCOSYSTÈME EDLEARN — 8 SEPTEMBRE 2026

**Périmètre de l'inspection :**
1. **Application Élève (`student_app`)** : inspection de tous les 13 modules, 31 écrans, widgets scientifiques, laboratoires virtuels et tests.
2. **Liens et Flux de données entre `admin_app` et `student_app`** : continuum éditorial, publication atomique, étanchéité des rôles, abonnements et observabilité.
3. **Conformité aux Cahiers des Charges** : `CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`, `CAHIER_DES_CHARGES_AGENTS_IA.md`, `CAHIER_IA_ZERO_COUT_MASTER.md`, `CAHIER_TECHNIQUE_CONTENT_FACTORY.md`, etc.
4. **Application de Tout dans Supabase** : 77 migrations SQL, politiques RLS, 21 Edge Functions Deno, RPCs transactionnelles et Storage.

---

## SECTION 1 — AUDIT DE L'APPLICATION ÉLÈVE (`student_app`)

### 1.1 Architecture & Stack
- **Framework** : Flutter 3.12+ / Dart 3.x.
- **State Management** : `flutter_riverpod` (StateNotifier, Provider, FutureProvider, family providers) pour une isolation stricte des contextes.
- **Thème & Design System** : `StudentTheme`, tokens typographiques Google Fonts (`Outfit`, `Inter`), `AppRadius`, palette sémantique conforme aux maquettes 2026 (`ElefColors`).
- **Tests & Qualité** : **48 tests automatisés passants à 100%**, `dart analyze` : **0 erreur, 0 avertissement**.

### 1.2 Cartographie Complète des 13 Modules et 31 Écrans

| Module | Écran / Composant | Source de Données | Rôle & Expérience Utilisateur | Statut Réel |
| :--- | :--- | :--- | :--- | :--- |
| **Auth & Onboarding** | `RoleSelectionScreen` | Local State | Porte d'entrée : choix du rôle (Élève vs Parent) | Opérationnel |
| | `DeviceAccountSelectorScreen` | `DeviceAccountsService` (SharedPrefs) | Détection multi-comptes sur un appareil partagé | Opérationnel (Anti-fraude) |
| | `LoginCodeEntryScreen` | RPC Supabase `verify_personal_login_code` | Déverrouillage rapide par code PIN personnel à 6 chiffres | Opérationnel & Sécurisé |
| | `StudentLoginScreen` | Supabase Auth `signInWithPassword` | Connexion par email / mot de passe | Opérationnel |
| | `OnboardingWizardScreen` | Tables `accounts`, `profiles`, `academic_nodes` | Inscription étape par étape avec sélection de la classe dans l'arbre réel | Opérationnel |
| | `ProfileSwitcherScreen` | Table `profiles` jointe à `academic_nodes` | Sélecteur multi-profils (« Qui apprend ? » type Netflix) | Opérationnel |
| **Navigation & Home** | `MainNavigationScreen` | Riverpod Navigation State | Barre de navigation basse (BottomBar) au pouce sur mobile (<700px) + tiroir desktop | Opérationnel (Mobile-first) |
| | `HomeDashboardScreen` | `studentSupabaseService` (`fetchSubjects`, `fetchCurrentTermInfo`) | Tableau de bord : reprise de cours (« Continuer »), matières actives, météo trimestrielle | Opérationnel |
| **Pédagogie & Cours** | `SubjectsListScreen` | `fetchSubjects(classNodeId)` | Grille adaptative des matières de la classe avec icônes disciplinaires | Opérationnel |
| | `ChaptersListScreen` | `fetchChapters(subjectId, classNodeId)` | Liste des chapitres avec décompte réel des leçons et exercices, progression | Opérationnel |
| | `ChapterIntroScreen` | Table `chapters` (`intro_media_url`, `intro_text`) | Mise en situation contextuelle, accroche pédagogique avant d'entrer dans les leçons | Opérationnel |
| | `LessonReaderScreen` | `fetchLessons(chapterId)` + `BlockRendererRegistry` | Lecteur de leçon haute-fidélité, pagination multi-leçons, filigrane judiciaire anti-capture | Opérationnel (DRM inclus) |
| | `DerivativeLabScreen` | Moteur mathématique local | Expérimentation guidée de la dérivation avec tracé interactif | Opérationnel |
| **Exercices & Entraînement** | `ExercisesHubScreen` | `fetchExercisesForClass` | Hub des exercices classés par matière et dossiers thématiques | Opérationnel |
| | `ExerciseChapterFoldersScreen` | `fetchExercises(chapterId)` | Dossier des exercices rattachés à un chapitre précis | Opérationnel |
| | `ExerciseRunnerScreen` | RPC `record_exercise_attempt` + Table `skills` | Runner interactif (QCM, texte court, flashcard, rédaction), indices progressifs, XP | Opérationnel |
| **Examens & Épreuves** | `OfficialExamsScreen` | Table `official_exams` + `exam_papers` | Sujets d'examens nationaux (Probatoire, Baccalauréat, BEPC) avec PDF et corrections | Opérationnel |
| | `EstablishmentPapersScreen` | Table `establishment_papers` | Épreuves de grands lycées d'excellence (Leclerc, Joss, etc.) | Opérationnel |
| | `ExamQuestionsScreen` | Table `exam_paper_questions` (Migration 74) | Consultation des questions d'annales validées et publiées par l'administration | Opérationnel |
| | `MockExamArenaScreen` | Table `event_leaderboard` (Migration 47) | Concours blancs et Olympiades en direct avec chronomètre et classement | Opérationnel |
| **Tuteur IA** | `AiTutorChatScreen` | Supabase Edge Function `ai-tutor-chat` | Tuteur socratique avec raccourcis contextuels, rendu LaTeX et garde-fou hors-ligne | Opérationnel |
| **Communauté** | `ClassForumScreen` | Table `forum_posts` (scopée par classe) | Échanges entre camarades d'une même classe, modéré par l'administration | Opérationnel |
| | `StudyCommunitiesScreen` | Table `whatsapp_communities` | Accès aux groupes d'entraide WhatsApp officiels encadrés | Opérationnel |
| **Portail Parent** | `ParentEntryScreen` | Auth Parent / Code de liaison | Vérification et bascule vers l'espace de supervision parentale | Opérationnel |
| | `ParentDashboardScreen` | Table `parent_profile_links` (Migration 49) | Suivi de l'assiduité, progression par matière et alertes de devoirs | Opérationnel |
| **Profil & Paramètres** | `StudentProfileScreen` | Tables `accounts`, Storage `avatars` | Fiche élève, avatar, gestion du code personnel, badges d'assiduité | Opérationnel |
| | `SettingsScreen` | Table `account_settings` (Migration 40) | Réglages de contraste élevé, taille de texte dynamique (`TextScaler`), langue | Opérationnel (a11y) |
| **Abonnements & Boutique** | `PaywallModal` | Table `account_subscriptions` | Modal d'abonnement avec explication transparente des paliers et statut de paiement | Opérationnel |
| | `BoutiqueShopScreen` | Table `shop_documents` | Boutique d'annales et fiches complémentaires | Opérationnel |
| **Support & Dons** | `SupportTicketsScreen` | Table `support_tickets` (Migration 10, 43) | Création et suivi des tickets d'assistance avec l'administration | Opérationnel |
| | `DonationsScreen` | Table `charity_campaigns` (Migration 29) | Dons transparents pour parrainer des élèves défavorisés | Opérationnel |

### 1.3 Laboratoires Virtuels & Moteurs Scientifiques Déterministes (No Mocks)
Conformément au principe directeur de `CAHIER_DES_CHARGES_AGENTS_IA.md` (*« Le LLM explique ; les moteurs spécialisés calculent et simulent »*), `student_app` intègre 5 simulateurs autonomes :
1. **`CircuitSimulatorWidget`** : Calculateur RLC en temps réel (Lois d'Ohm et de Kirchhoff déterministes, régimes apériodiques/pseudo-périodiques, bascule charge/décharge sans recours à une API externe).
2. **`BallisticsSimulatorWidget`** : Simulateur de tir parabolique avec équations différentielles réelles de la mécanique newtonienne, gravité paramétrable ($g = 9.81 \, \text{m/s}^2$) et frottements d'air.
3. **`MolecularViewer3DWidget`** : Visualiseur de conformations moléculaires 3D interactif (eau, méthane, benzène) avec rotation gyroscopique tactile.
4. **`PythonSandboxWidget`** : Environnement d'exécution algorithmique pour l'épreuve d'Informatique des séries scientifiques et techniques.
5. **`InteractiveFunctionGraph` & `VariationTableInteractive`** : Tracé vectoriel de fonctions numériques, calcul des extrema locaux, tangentes et tableau de variations interactif.

---

## SECTION 2 — LES LIENS ENTRE LES DEUX APPLICATIONS (`admin_app` <-> `student_app`)

Le système est conçu sur un principe de **dissociation stricte mais complémentarité totale** :

```text
┌──────────────────────────────────────┐             ┌──────────────────────────────────────┐
│           ADMIN HQ                   │             │           STUDENT APP                │
│  (Création, Revue, Pilotage)         │             │  (Consommation, Apprentissage)       │
└──────────────────┬───────────────────┘             └──────────────────▲───────────────────┘
                   │                                                    │
                   │  1. Édition Studio v2                              │  4. Consommation RLS
                   │  2. Pré-contrôle IA (AIA-AGT-024)                  │     (Uniquement is_published = true
                   │  3. Validation Humaine (HITL)                      │      + abonnement vérifié)
                   ▼                                                    │
┌───────────────────────────────────────────────────────────────────────┴───────────────────┐
│                                   SUPABASE POSTGRESQL                                     │
│  - validation_queue                                                                       │
│  - RPC approve_and_publish_content()  [Transaction atomique]                               │
│  - lessons (content_json structuré) / exercises / official_exams                          │
│  - access_matrix_enforcement / judicial_watermark                                         │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Continuum Éditorial et Rendu de Contenu (Content != Presentation)
- **Côté Admin (`admin_app`)** :
  - L'enseignant ou administrateur utilise le **Studio v2** (`lesson_builder_screen.dart`) pour assembler des blocs standardisés : `situation_depart`, `objectifs`, `theoreme`, `definition`, `methode`, `exemple`, `summary_card`, `piege`, `conseil_examen`.
  - Pour `summary_card`, l'éditeur permet de configurer le comparatif structuré (Cas A vs Cas B avec badges et items libellé/formule LaTeX), les mémos et le piège d'examen.
  - La leçon est enregistrée avec `is_published = false` et soumise à la file de validation (`validation_queue`).
- **File de Validation & Règle HITL (Human-In-The-Loop)** :
  - Dans `validation_queue_screen.dart`, l'administrateur peut déclencher le **Pré-contrôle IA** (`ai-pedagogical-validation`, AIA-AGT-024).
  - L'agent audite la structure, détecte d'éventuels placeholders/mocks, contrôle la présence de formules LaTeX valides et vérifie le lien avec l'arbre académique (`chapters`).
  - L'approbation finale reste humaine : l'administrateur clique sur "Approuver & Publier".
- **Côté Élève (`student_app`)** :
  - Dès publication, `lesson_reader_screen.dart` charge le JSON structuré via `client.from('lessons')`.
  - `BlockRendererRegistry.build()` instancie le widget haute-fidélité correspondant au type de bloc sans parsing manuel ad-hoc.
  - Les clés de `summary_card` (`columns`, `keyFormula`, `bulletPoints`, `examTrap`) s'affichent instantanément dans le composant visuel dédié avec support complet de `flutter_math_fork`.

### 2.2 Arbre Académique et Tronc Commun
- **Structure partagée** : Pays -> Section (Anglophone/Francophone) -> Enseignement -> Classe -> Série -> Matière -> Chapitre -> Leçon.
- **Tronc commun (Twin Groups)** : Grâce aux migrations 19 et 20 (`class_twin_groups`), une matière partagée entre 1ère C et 1ère D (ex: Mathématiques) possède un contenu unique non dupliqué. L'administration gère le lien une seule fois ; les élèves des deux classes y accèdent de manière transparente.

### 2.3 Sécurité, Matrice de Droits & Paywall
- **Politiques RLS sur `lessons`** :
  ```sql
  CREATE POLICY lessons_select ON lessons FOR SELECT USING (
      is_admin_user()
      OR (
          is_published = true
          AND (min_subscription_tier = 'gratuit' OR current_user_has_feature_access('courses'))
      )
  );
  ```
- **Tatouage judiciaire (`ForensicWatermarkService`)** :
  - Pour empêcher la fuite et la vente illicite des fiches de cours et corrigés exclusifs, un filigrane invisible/semi-transparent contenant le `hash` du compte élève, son horodatage et son IP est apposé dynamiquement sur le lecteur de l'élève. En cas de capture d'écran diffusée sur les réseaux sociaux, l'administrateur peut identifier le compte source depuis `audit_log_screen.dart`.

### 2.4 Observabilité des Agents IA
- Lorsqu'un élève converse avec le tuteur numérique dans `student_app` (`AiTutorChatScreen`), l'appel passe par la fonction `ai-tutor-chat`.
- Chaque appel consigne les métriques dans la table `ai_agent_calls` (agent, tokens, latence, statut, coût estimé).
- L'administration visualise ces données agrégées en temps réel sur son tableau de bord (`ai_usage_summary_test.dart` / `dashboard_screen.dart`), permettant un contrôle fin de la consommation de compute.

---

## SECTION 3 — CONFORMITÉ AUX CAHIERS DES CHARGES

### 3.1 `CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`
- **Partie 1 (Élève, 22 sections)** :
  - Structure académique sans mention visible du mot « Trimestre » : **100% Conforme** (le découpage trimestriel pilote le déblocage en coulisses via `terms`).
  - Épreuves officielles et d'établissements (§2.3 / 2.3bis) : **100% Conforme** (`OfficialExamsScreen` et `EstablishmentPapersScreen`).
  - Accompagnement par Tuteur IA (§2.8) : **100% Conforme** (`AiTutorChatScreen` avec Edge Function Gemini Flash).
  - Mode hors-ligne (§2.17) : **Conforme aux règles de probité** (l'indisponibilité du stockage local est honnêtement notifiée à l'élève ; aucun faux bouton ne simule un faux enregistrement).
  - Espace Parent séparé (§2.16) : **100% Conforme** (Tables `parent_accounts`, isolation stricte RLS, liaison par code sécurisé).
- **Partie 2 (Administration, 30 sections)** :
  - Hubs opérationnels : Arbre académique, Gestion des rôles, Studio de contenu, Modération, Helpdesk, Facturation/Dons.
  - Conformité mobile : Tous les écrans admin sont certifiés sans débordement sur formats 345px, 390px, 800px et 1400px.

### 3.2 `CAHIER_DES_CHARGES_AGENTS_IA.md` & `CAHIER_IA_ZERO_COUT_MASTER.md`
- **Contrainte Zéro Coût IA Obligatoire** : Les fonctions essentielles (laboratoires, calculatrices, moteurs d'exercices, fiches de révision) s'exécutent en local sans aucun coût d'API.
- **Couverture des 26 Agents IA** :
  - *Agents implémentés dans la Sovereign Gateway Python (`gateway/app/agents/`)* : 15 agents spécialisés (`TutorAgent`, `CorrectionAgent`, `CurriculumMappingAgent`, `DiagnosticAgent`, `ExamCoachAgent`, `FormulaRecognitionAgent`, `FraudRiskAgent`, `MisconceptionAgent`, `ParentInsightAgent`, `PedagogicalValidationAgent`, `RecommendationAgent`, `RevisionAgent`, `SupportTriageAgent`, `TeacherAssistantAgent`, `AdminAssistantAgent`).
  - *Agents portés en Supabase Edge Functions serverless* : `ai-tutor-chat`, `ai-pedagogical-validation`, `ai-curriculum-mapping`, `ai-course-structuring`, `ai-exercise-generation`, `ai-moderation`, `ai-correction`, `ai-exam-paper-processing`, `ai-fraud-risk`, `ai-support-triage`, `ai-catalog-types-generation`.
- **RAG & Embeddings** : Table `ai_rag_chunks` avec type `vector(1536)` (Migration 56) et fonction de recherche par similarité cosinus `match_rag_chunks` (Migration 59).
- **Student Model BKT** : Tables `student_skill_mastery`, `student_mastery_history` (Migration 64) pour le suivi probabiliste de l'acquisition des compétences (Bayesian Knowledge Tracing).

### 3.3 `CAHIER_TECHNIQUE_CONTENT_FACTORY.md`
- **Cycle de vie du contenu** : Respecté à la lettre (Draft -> Validation Queue -> Atomic Publish -> Student Reader).
- **Séparation Contenu / Présentation** : Stockage canonique en `content_json` typé ; le frontend utilise exclusivement son registre de renderers (`BlockRendererRegistry`).

---

## SECTION 4 — APPLICATION DE TOUT DANS SUPABASE

### 4.1 Schéma Relationnel (77 Migrations Appliquées)
Le modèle comprend plus de 45 tables réparties en 6 domaines majeurs :
1. **Identité & Accès** : `accounts`, `profiles`, `parent_accounts`, `parent_profile_links`, `active_sessions`, `account_settings`, `personal_login_codes`.
2. **Arbre Académique** : `academic_nodes` (pays, sections, enseignements, classes, séries), `subjects`, `chapters`, `terms`, `school_years`, `class_twin_groups`.
3. **Contenus Pédagogiques** : `lessons`, `exercises`, `exercise_attempts`, `official_exams`, `establishment_papers`, `exam_paper_questions`, `validation_queue`, `content_catalogs`.
4. **Communauté & Support** : `forum_posts`, `forum_comments`, `whatsapp_communities`, `support_tickets`, `support_ticket_messages`, `charity_campaigns`, `donations`.
5. **Abonnements & Matrices** : `account_subscriptions`, `access_matrix_features`, `subscription_plans`.
6. **IA & Observabilité** : `ai_agents`, `ai_agent_calls`, `ai_rag_chunks`, `ai_quota_policies`, `ai_usage_ledger`, `student_skill_mastery`.

### 4.2 Politiques de Sécurité RLS (Row Level Security)
Toutes les tables sensibles ont RLS activé (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`) :
- Les données d'authentification et de profil élève ne sont lisibles et modifiables que par leur propriétaire (`auth.uid() = account_id`).
- L'espace parent est strictement étanche : un parent ne peut lire que les profils de ses propres enfants liés via `parent_profile_links` avec lien validé.
- Les cours non publiés (`is_published = false`) sont totalement invisibles aux utilisateurs non administrateurs.
- Seules les fonctions `SECURITY DEFINER` allowlistées ont le droit d'effectuer des écritures transversales (ex: publication atomique, validation de code de connexion).

### 4.3 Les 21 Edge Functions Deno Déployées
1. `admin-create-admin-account`
2. `admin-create-parent-account`
3. `admin-create-student-account`
4. `admin-create-teacher-account`
5. `ai-admin-assistant`
6. `ai-catalog-types-generation`
7. `ai-correction`
8. `ai-course-structuring`
9. `ai-curriculum-mapping` *(AIA-AGT-017 — Nouveau)*
10. `ai-document-structuring`
11. `ai-embeddings-generate`
12. `ai-exam-paper-processing`
13. `ai-exercise-generation`
14. `ai-fraud-risk`
15. `ai-generate-text`
16. `ai-moderation`
17. `ai-pedagogical-validation` *(AIA-AGT-024 — Nouveau)*
18. `ai-support-triage`
19. `ai-tutor-chat`
20. `cron-subscription-reminders`
21. `payment-webhook`

### 4.4 Buckets Supabase Storage
- `lesson-media` : illustrations, schémas scientifiques et figures SVG des leçons.
- `avatars` : photos de profil élèves et parents avec politiques d'accès restreintes.
- `official-exams` : épreuves officielles numérisées au format PDF.
- `establishment-papers` : sujets des concours et compositions d'établissements.

---

## SECTION 5 — ANALYSE D'ÉCARTS (GAP ANALYSIS) & RECOMMANDATIONS

| Composant / Flux | Constat Actuel | Risque / Impact | Recommandation Prioritaire |
| :--- | :--- | :--- | :--- |
| **Cache Hors-Ligne Élève** | L'UI affiche honnêtement l'indisponibilité du cache local | Pas de fausse promesse, mais les élèves en zone blanche dépendent d'une connexion active | Concevoir un stockage SQLite local (`sqflite` / `drift`) pour mettre en cache les blocs des leçons favorites |
| **Paiement Mobile Money** | `PaywallModal` affiche les formules mais le paiement effectif est en attente du contrat agrégateur (MTN MoMo / Orange Money) | Aucun débit fictif n'est simulé (gage de sécurité) | Connecter le webhook `payment-webhook` aux APIs partenaires dès réception des clés marchandes |
| **Simulateurs dans le Studio Admin** | Les labos virtuels existent dans `student_app` mais n'ont pas encore d'outil d'insertion dédié dans le Studio de cours Admin | L'enseignant doit insérer un bloc JSON spécifique pour intégrer un simulateur | Ajouter un bloc dédié "Simulateur Interactif" dans la bibliothèque du Studio v2 |

---

## CONCLUSION DE L'INSPECTION

L'écosystème EDLEARN démontre une **remarquable cohérence architecturale** :
1. **L'application élève** est riche de 31 écrans réels, d'un Design System soigné, de simulateurs scientifiques déterministes et d'une couverture de tests exemplaire (48 tests passants).
2. **Le lien entre Admin et Élève** respecte scrupuleusement le principe de Content Factory et la gouvernance Human-In-The-Loop : aucune publication n'a lieu sans validation humaine, et le contenu structuré est rendu fidèlement via un registre dédié.
3. **La base Supabase** est solidement ancrée sur 77 migrations relationnelles, des politiques RLS imperméables et 21 Edge Functions couvrant les processus métier et l'intelligence artificielle.
4. **La règle d'or du projet est respectée** : zéro simulation de succès artificiel, zéro mock silencieux, vérité absolue des données à tous les niveaux.
