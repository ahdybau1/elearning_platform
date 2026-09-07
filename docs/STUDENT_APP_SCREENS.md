# Inventaire Exhaustif des Écrans — Application Élève (STUDENT_APP_SCREENS)

**Date :** 2026-09-05  
**Codebase :** `student_app/lib/`

---

## 1. Module d'Accès, Onboarding & Profils

### 1.1 `RoleSelectionScreen`
- **Nom de l'écran :** Sélection du rôle (Élève vs Parent)
- **Route :** Déclenché par `AppRootGate` à la racine (pas d'URL nommée, état réactif)
- **Fichier :** `lib/features/onboarding/screens/role_selection_screen.dart`
- **Rôle :** Séparation stricte à l'entrée entre l'espace élève et l'espace parent (CDC §17).
- **Données :** `hasChosenStudentRoleProvider` (en mémoire Riverpod, jamais persisté par design).
- **Services :** Aucun (décision de routage local).
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** Visuel épuré mais un peu austère.
- **Priorité de refonte :** P2
- **Dépendances :** `AppRootGate`, `parent_auth_provider.dart`, `app_root_providers.dart`.

### 1.2 `DeviceAccountSelectorScreen`
- **Nom de l'écran :** Sélecteur de compte connu sur l'appareil
- **Route :** Déclenché par `StudentAuthGate` quand `deviceAccountsService.listKnown()` retourne $\ge 1$ compte.
- **Fichier :** `lib/features/onboarding/screens/device_account_selector_screen.dart`
- **Rôle :** Permettre le déverrouillage rapide par code personnel sur les appareils partagés dans une famille.
- **Données :** Liste de `DeviceKnownAccount` stockée en local dans `SharedPreferences`.
- **Services :** `DeviceAccountsService`.
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** UI fonctionnelle, manque de chaleur et d'animations subtiles de transition.
- **Priorité de refonte :** P2
- **Dépendances :** `device_accounts_service.dart`, `LoginCodeEntryScreen`, `StudentLoginScreen`.

### 1.3 `LoginCodeEntryScreen`
- **Nom de l'écran :** Déverrouillage par code personnel (PIN)
- **Route :** Push depuis `DeviceAccountSelectorScreen`.
- **Fichier :** `lib/features/onboarding/screens/login_code_entry_screen.dart`
- **Rôle :** Vérifier le code PIN à 4/6 chiffres propre au compte sélectionné sans ressaisir le mot de passe Supabase.
- **Données :** Compte sélectionné, code chiffré/hashé.
- **Services :** RPC Supabase `verify_personal_login_code`.
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** Clavier tactile sur écran pouvant être optimisé pour l'accessibilité.
- **Priorité de refonte :** P2
- **Dépendances :** `StudentAuthNotifier.unlockDeviceAccount`.

### 1.4 `StudentLoginScreen`
- **Nom de l'écran :** Connexion Élève par Email / Mot de passe
- **Route :** `/login` et affiché par défaut par `StudentAuthGate` si aucun compte connu.
- **Fichier :** `lib/features/onboarding/screens/student_login_screen.dart`
- **Rôle :** Authentification principale d'un compte élève existant ou premier accès sur un nouvel appareil.
- **Données :** Email, mot de passe.
- **Services :** Supabase Auth (`signInWithPassword`).
- **Statut :** **IMPROVE**
- **Problèmes :** Formulaire standard, gestion d'erreurs limitée aux snackbars brutes.
- **Priorité de refonte :** P1
- **Dépendances :** `student_auth_provider.dart`, lien vers inscription.

### 1.5 `OnboardingWizardScreen`
- **Nom de l'écran :** Assistant d'inscription élève (Wizard 7 étapes)
- **Route :** `/onboarding` et affiché par `StudentAuthGate` si compte sans profil.
- **Fichier :** `lib/features/onboarding/screens/onboarding_wizard_screen.dart`
- **Rôle :** Inscription complète : identité, téléphone, pays, section, enseignement, classe, série, choix abonnement/essai gratuit.
- **Données :** Descente de l'arbre académique réel (`academic_nodes`).
- **Services :** `StudentSupabaseService.fetchChildAcademicNodes`, Supabase Auth.
- **Statut :** **IMPROVE**
- **Problèmes :** Étapes très denses sur mobile, sélecteur d'arborescence académique lourd.
- **Priorité de refonte :** P1
- **Dépendances :** `student_providers.dart`, `academic_nodes`.

### 1.6 `ProfileSwitcherScreen`
- **Nom de l'écran :** Sélecteur de profil actif ("Qui apprend ?")
- **Route :** `/profiles` et affiché à l'ouverture si le compte possède plusieurs profils.
- **Fichier :** `lib/features/onboarding/screens/profile_switcher_screen.dart`
- **Rôle :** Choisir la classe active pour la session en cours parmi les profils du compte (modèle Netflix).
- **Données :** `authState.profiles` (profils rattachés à `accounts.id`).
- **Services :** `StudentAuthNotifier.selectProfile`.
- **Statut :** **IMPROVE**
- **Problèmes :** Cartes neutres, pas d'affichage de la progression ou du streak par profil.
- **Priorité de refonte :** P1
- **Dépendances :** `student_auth_provider.dart`.

---

## 2. Module Principal & Navigation

### 2.1 `MainNavigationScreen`
- **Nom de l'écran :** Conteneur de navigation principale
- **Route :** `/home`
- **Fichier :** `lib/features/home/screens/main_navigation_screen.dart`
- **Rôle :** Porter le conteneur principal de l'application et aiguiller entre les modules.
- **Données :** Profil actif, examen officiel associé à la classe.
- **Services :** `officialExamForClassProvider`.
- **Statut :** **REFACTOR**
- **Problèmes :** Utilise un `Drawer` Material de 14 items sur mobile. Inadapté à l'usage d'une main.
- **Priorité de refonte :** **P0** (Structure pivot)
- **Dépendances :** Tous les modules enfants.

### 2.2 `HomeDashboardScreen`
- **Nom de l'écran :** Accueil / Tableau de bord élève
- **Route :** Onglet 0 de `MainNavigationScreen`
- **Fichier :** `lib/features/home/screens/home_dashboard_screen.dart`
- **Rôle :** Point d'atterrissage quotidien de l'élève.
- **Données :** Profil actif, matières de la classe, trimestre scolaire réel, compte à rebours examen national, communauté WhatsApp.
- **Services :** `studentSubjectsProvider`, `currentTermInfoProvider`, `whatsappCommunityProvider`.
- **Statut :** **IMPROVE**
- **Problèmes :** Trop de bannières administratives empilées. Manque d'action d'apprentissage immédiate ("Continuer ma leçon").
- **Priorité de refonte :** **P0** (Premier écran vu quotidiennement)
- **Dépendances :** `PaywallModal`, `ChaptersListScreen`.

---

## 3. Module d'Apprentissage Pédagogique (Cours, Leçons, Exercices)

### 3.1 `SubjectsListScreen`
- **Nom de l'écran :** Liste des matières au programme
- **Route :** Page dans module "Apprentissage"
- **Fichier :** `lib/features/courses/screens/subjects_list_screen.dart`
- **Rôle :** Présenter les matières associées à la classe de l'élève (`subject_class_links`).
- **Données :** Liste de `Subject` (nom, code, id).
- **Services :** `studentSubjectsProvider(classNodeId)`.
- **Statut :** **IMPROVE**
- **Problèmes :** Simple liste verticale de tuiles uniformes. Manque d'indicateurs de complétion et de maîtrise.
- **Priorité de refonte :** **P0**
- **Dépendances :** `SubjectVisuals`, navigation vers `/chapters`.

### 3.2 `ChaptersListScreen`
- **Nom de l'écran :** Liste des chapitres d'une matière
- **Route :** `/chapters`
- **Fichier :** `lib/features/courses/screens/chapters_list_screen.dart`
- **Rôle :** Découpage du programme d'une matière en chapitres avec verrouillage temporel par trimestre.
- **Données :** Liste de `Chapter` avec `isUnlocked`, `termName`, `lessonsCount`, `exercisesCount`.
- **Services :** `studentChaptersProvider(ChaptersQuery(subjectId, classNodeId))`.
- **Statut :** **IMPROVE**
- **Problèmes :** Le bouton "Ouvrir le cours" ouvre directement le lecteur sans lister les leçons.
- **Priorité de refonte :** **P0**
- **Dépendances :** Navigation vers `/lesson-reader` et `/exercises`.

### 3.3 `LessonReaderScreen`
- **Nom de l'écran :** Lecteur de leçon enrichie
- **Route :** `/lesson-reader`
- **Fichier :** `lib/features/courses/screens/lesson_reader_screen.dart`
- **Rôle :** Lecture immersive du cours structuré (théorèmes, définitions, formules, exemples, pièges).
- **Données :** Liste de `Lesson` pour le chapitre, liste de `ContentBlock`.
- **Services :** `studentLessonsProvider(chapterId)`, `ForensicWatermarkService`.
- **Statut :** **REFACTOR**
- **Problèmes majeurs :**
  - **Ne lit que `lessons.first`** : masque les autres leçons du chapitre.
  - Pas de table des matières intra-leçon ni de navigation inter-leçons.
- **Priorité de refonte :** **P0** (Cœur pédagogique de l'application)
- **Dépendances :** `BlockRendererRegistry`, `PaywallModal`.

### 3.4 `ExerciseRunnerScreen`
- **Nom de l'écran :** Runner interactif de quiz et exercices
- **Route :** `/exercises`
- **Fichier :** `lib/features/courses/screens/exercise_runner_screen.dart`
- **Rôle :** Entraînement interactif de l'élève sur les questions du cours.
- **Données :** Liste d'exercices (QCM, texte libre, flashcard, manuscrit).
- **Services :** `studentExercisesProvider(chapterId)`, `recordExerciseAttempt`.
- **Statut :** **IMPROVE**
- **Problèmes :** Feedback de correction brut, manque d'explication pas-à-pas et d'actions de remédiation.
- **Priorité de refonte :** **P0**
- **Dépendances :** `Exercise`, `student_models.dart`.

### 3.5 `ExercisesHubScreen`
- **Nom de l'écran :** Hub central des exercices
- **Route :** Entrée du tiroir "Exercices"
- **Fichier :** `lib/features/courses/screens/exercises_hub_screen.dart`
- **Rôle :** Accès aux exercices transversaux ou classés par matière hors du parcours linéaire.
- **Données :** `fetchExercisesForClass`.
- **Services :** `classExercisesProvider(classNodeId)`.
- **Statut :** **IMPROVE**
- **Problèmes :** Navigation arborescente un peu austère.
- **Priorité de refonte :** P1
- **Dépendances :** `ExerciseChapterFoldersScreen`, `ExerciseRunnerScreen`.

### 3.6 `ExerciseChapterFoldersScreen`
- **Nom de l'écran :** Dossiers de chapitres d'exercices
- **Route :** Push depuis `ExercisesHubScreen`.
- **Fichier :** `lib/features/courses/screens/exercise_chapter_folders_screen.dart`
- **Rôle :** Lister les chapitres d'une matière ayant des exercices disponibles.
- **Données :** Liste d'exercices préfiltrés par matière.
- **Services :** Aucun (données transmises en argument).
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** RAS, fonctionnel.
- **Priorité de refonte :** P2
- **Dépendances :** `ExerciseRunnerScreen`.

---

## 4. Module d'Évaluation & Examens

### 4.1 `OfficialExamsScreen`
- **Nom de l'écran :** Anciens sujets d'examens officiels (BEPC, Probatoire, Bac)
- **Route :** Module "Évaluation"
- **Fichier :** `lib/features/exams/screens/official_exams_screen.dart`
- **Rôle :** Préparation aux examens nationaux du niveau de la classe de l'élève.
- **Données :** Sujets d'annales officielles par année et matière.
- **Services :** `officialExamForClassProvider`, `examPapersProvider`.
- **Statut :** **IMPROVE**
- **Problèmes :** Fiches de sujets sans méthodologie d'épreuve associée.
- **Priorité de refonte :** P1
- **Dépendances :** `ExamQuestionsScreen`.

### 4.2 `EstablishmentPapersScreen`
- **Nom de l'écran :** Épreuves par établissement partenaire
- **Route :** Module "Évaluation"
- **Fichier :** `lib/features/exams/screens/establishment_papers_screen.dart`
- **Rôle :** Explorer les devoirs et compositions d'autres lycées et collèges.
- **Données :** Liste des établissements, sujets par établissement et matière.
- **Services :** `establishmentsProvider`, `establishmentPapersProvider`.
- **Statut :** **IMPROVE**
- **Problèmes :** Filtrage un peu lourd sur mobile.
- **Priorité de refonte :** P1
- **Dépendances :** `Establishment`, `EstablishmentPaper`.

### 4.3 `ExamQuestionsScreen`
- **Nom de l'écran :** Questions d'examen publiées
- **Route :** Push depuis un sujet d'examen
- **Fichier :** `lib/features/exams/screens/exam_questions_screen.dart`
- **Rôle :** Consulter les questions unitaires validées d'une épreuve.
- **Données :** `publishedExamQuestionsProvider`.
- **Services :** `fetchPublishedExamQuestions`.
- **Statut :** **PARTIAL**
- **Problèmes :** Écran récent brut, manque d'interactivité.
- **Priorité de refonte :** P1
- **Dépendances :** Migration 74.

### 4.4 `MockExamArenaScreen`
- **Nom de l'écran :** Arène des examens blancs & Olympiades
- **Route :** `/mock-arena`
- **Fichier :** `lib/features/exams/screens/mock_exam_arena_screen.dart`
- **Rôle :** Concours virtuels nationaux avec chronomètre, résultats et palmarès.
- **Données :** Événements programmés, résultats individuels, classement anonymisé.
- **Services :** `eventsForClassProvider`, `myEventResultProvider`, `eventLeaderboardProvider`, `submitGradeDispute`.
- **Statut :** **IMPROVE**
- **Problèmes :** UI dense, chronomètre perfectible.
- **Priorité de refonte :** P1
- **Dépendances :** `MockEvent`, `MyEventResult`, `LeaderboardEntry`.

---

## 5. Module IA Tuteur & Communauté

### 5.1 `AiTutorChatScreen`
- **Nom de l'écran :** Tuteur Numérique IA
- **Route :** `/ai-tutor`
- **Fichier :** `lib/features/ai_tutor/screens/ai_tutor_chat_screen.dart`
- **Rôle :** Accompagnement individualisé par maïeutique sans donner la réponse brute.
- **Données :** Historique de messages de la session.
- **Services :** Supabase Edge Function `ai-tutor-chat` (Gemini Flash).
- **Statut :** **IMPROVE**
- **Problèmes :** Aucune transmission du contexte de la leçon en cours.
- **Priorité de refonte :** P1
- **Dépendances :** Edge Functions.

### 5.2 `ClassForumScreen`
- **Nom de l'écran :** Forum de classe
- **Route :** Module "Communauté"
- **Fichier :** `lib/features/community/screens/class_forum_screen.dart`
- **Rôle :** Questions et entraide entre élèves de la même classe sous modération.
- **Données :** Fil de discussion `ForumPost`.
- **Services :** `studentForumPostsProvider`, `createForumPost`.
- **Statut :** **IMPROVE**
- **Problèmes :** Interface de discussion basique, pas de tri par matière.
- **Priorité de refonte :** P2
- **Dépendances :** `forum_posts`.

### 5.3 `StudyCommunitiesScreen`
- **Nom de l'écran :** Communautés WhatsApp officielles
- **Route :** Module "Communauté"
- **Fichier :** `lib/features/community/screens/study_communities_screen.dart`
- **Rôle :** Rejoindre le groupe WhatsApp modéré de sa classe.
- **Données :** `WhatsappCommunity` de la classe active.
- **Services :** `whatsappCommunityProvider`.
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** Simple carte d'invitation avec lien externe (conforme au CDC).
- **Priorité de refonte :** P3
- **Dépendances :** `url_launcher`.

---

## 6. Module Profil, Paramètres, Abonnements & Support

### 6.1 `StudentProfileScreen`
- **Nom de l'écran :** Mon Profil
- **Route :** Onglet Profil
- **Fichier :** `lib/features/profile/screens/student_profile_screen.dart`
- **Rôle :** Identité élève, photo, informations personnelles, liaison parent, profils archivés.
- **Données :** `StudentAccount`, `StudentProfile`, `parent_profile_links`.
- **Services :** Supabase Storage avatars, `redeemParentInviteCode`, `fetchOrCreateParentLinkCode`.
- **Statut :** **IMPROVE**
- **Problèmes :** Fichier de 1074 lignes très lourd.
- **Priorité de refonte :** P1
- **Dépendances :** `image_picker`, `student_auth_provider.dart`.

### 6.2 `SettingsScreen`
- **Nom de l'écran :** Paramètres & Accessibilité
- **Route :** Module "Mon espace"
- **Fichier :** `lib/features/settings/screens/settings_screen.dart`
- **Rôle :** Gérer les préférences : notifications, mot de passe, contraste élevé, thème clair/sombre, taille de police.
- **Données :** `AccountSettings`.
- **Services :** `upsertAccountSettings`, `createDataRequest` (droit à l'oubli).
- **Statut :** **IMPROVE**
- **Problèmes :** Bien conçu techniquement mais présentation visuelle un peu austère.
- **Priorité de refonte :** P2
- **Dépendances :** `account_settings`.

### 6.3 `BoutiqueShopScreen`
- **Nom de l'écran :** Boutique de fiches & documents
- **Route :** Module "Services"
- **Fichier :** `lib/features/subscription/screens/boutique_shop_screen.dart`
- **Rôle :** Catalogue de fiches de synthèse téléchargeables.
- **Données :** `ShopDocument`.
- **Services :** `fetchShopDocuments`.
- **Statut :** **IMPROVE**
- **Problèmes :** Téléchargement en attente de passerelle, à maintenir transparent.
- **Priorité de refonte :** P2
- **Dépendances :** `shop_documents`.

### 6.4 `PaywallModal`
- **Nom de l'écran :** Modalité d'abonnement & Paywall
- **Route :** BottomSheet modal
- **Fichier :** `lib/features/subscription/screens/paywall_modal.dart`
- **Rôle :** Présentation des 3 formules d'abonnement (Découverte, Mensuel, Annuel).
- **Données :** Paliers tarifaires en FCFA.
- **Services :** Message d'information sur la passerelle Mobile Money.
- **Statut :** **IMPROVE**
- **Problèmes :** Formulaire de téléphone simulé, à simplifier sans fausse saisie.
- **Priorité de refonte :** P1
- **Dépendances :** `StudentProfile`.

### 6.5 `SupportTicketsScreen`
- **Nom de l'écran :** Support & Assistance
- **Route :** Module "Support"
- **Fichier :** `lib/features/support/screens/support_tickets_screen.dart`
- **Rôle :** Créer et suivre des tickets d'assistance avec l'administration.
- **Données :** `SupportTicket`.
- **Services :** `fetchSupportTickets`, `createSupportTicket`.
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** Très bien structuré.
- **Priorité de refonte :** P2
- **Dépendances :** `support_tickets`.

### 6.6 `DonationsScreen`
- **Nom de l'écran :** Soutien & Dons Caritatifs
- **Route :** Module "Services"
- **Fichier :** `lib/features/support/screens/donations_screen.dart`
- **Rôle :** Présenter les campagnes de soutien éducatif ou solidaire (CDC §12).
- **Données :** `CharityCampaign`.
- **Services :** `fetchCharityCampaigns`.
- **Statut :** **EXISTING / KEEP**
- **Problèmes :** Fonctionnel et propre.
- **Priorité de refonte :** P3
- **Dépendances :** `charity_campaigns`.

---

## 7. Module Espace Parent (Conteneur séparé)

### 7.1 `ParentDashboardScreen` & `ParentEntryScreen`
- **Nom de l'écran :** Espace Parent (Connexion et Tableau de bord de suivi)
- **Route :** `/parent-portal`
- **Fichier :** `lib/features/parent_portal/screens/*`
- **Rôle :** Supervision parentale distincte de l'élève (CDC §17).
- **Données :** `ParentAccount`, `LinkedChildProfile`, `ParentTransaction`.
- **Services :** `parent_auth_provider.dart`.
- **Statut :** **EXISTING / KEEP** (Isolation stricte préservée)
- **Problèmes :** Hors périmètre de refonte élève immédiate mais à préserver impérativement.
- **Priorité :** P3 (Ne pas toucher pendant la vague élève)
- **Dépendances :** `parent_accounts`.
