# État Actuel de l'Application Élève (STUDENT_APP_CURRENT_STATE)

**Date d'audit :** 2026-09-05  
**Cible :** `student_app` (Flutter 3.x, Riverpod 2.6.1, Supabase Flutter 2.17.1, GoRouter déclaré mais Navigator standard utilisé)  
**Référence :** `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md` et inspection approfondie du code réel.

---

## 1. Matrice Globale d'État de l'Application Élève

Légende des statuts obligatoires :
- **EXISTING / KEEP** : Existe, fonctionne correctement avec le backend réel, doit être scrupuleusement conservé.
- **IMPROVE** : Existe et fonctionne, mais l'expérience UI/UX, ergonomie ou clarté doit être améliorée.
- **REFACTOR** : Existe, mais son implémentation frontend doit être restructurée sans altérer son comportement métier ou ses contrats de données.
- **PARTIAL** : Fonctionnalité partiellement développée (manque des écrans, étapes, gestion d'erreurs ou liaisons).
- **MISSING** : Prévue dans le cahier des charges mais absente du codebase de l'application élève.
- **DEPRECATED / REMOVE** : Élément obsolète ou vestige technique (avec justification explicite).

| Module | Fonctionnalité | Écran / Composant | État | Frontend | Backend | Données | Problèmes identifiés | Action requise |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth & Accès** | Choix du rôle (Élève vs Parent) | `RoleSelectionScreen` | **EXISTING / KEEP** | Flutter UI + Riverpod | Supabase Auth | Réelles (`hasChosenStudentRole`) | Écran austère mais fonctionnel | Conserver la logique de porte, polir le design visuel |
| **Auth & Accès** | Détection multi-comptes sur l'appareil | `DeviceAccountSelectorScreen` | **EXISTING / KEEP** | Flutter UI + SharedPreferences | Local (`DeviceAccountsService`) | Réelles | Bonne mécanique de sécurité anti-partage | Conserver, adapter aux tokens du Design System |
| **Auth & Accès** | Déverrouillage par code PIN personnel | `LoginCodeEntryScreen` | **EXISTING / KEEP** | Flutter UI | RPC `verify_personal_login_code` | Réelles | Fonctionne bien | Conserver, harmoniser le pavé numérique et le retour visuel |
| **Auth & Accès** | Connexion Email / Mot de passe | `StudentLoginScreen` | **IMPROVE** | Formulaire Flutter standard | Supabase `signInWithPassword` | Réelles | UX brute, gestion d'erreurs en snackbar basique | Améliorer microcopy, états de chargement, accessibilité clavier |
| **Auth & Accès** | Inscription multi-étapes (Wizard) | `OnboardingWizardScreen` | **IMPROVE** | Wizard multi-steps (7 étapes) | Tables `accounts`, `profiles`, RPCs | Réelles | Étapes denses, sélecteur académique lourd sur petit écran | Fluidifier les étapes, aérer l'arborescence, mobile-first |
| **Auth & Accès** | Sélecteur de profil actif ("Qui apprend ?") | `ProfileSwitcherScreen` | **IMPROVE** | Cartes de profils | Table `profiles` jointe à `academic_nodes` | Réelles | Grille basique, pas d'état de progression visible | Rendre attractif, afficher classe, streak et avatar |
| **Navigation** | Structure de navigation principale | `MainNavigationScreen` | **REFACTOR** | Navigation drawer sur mobile (<700px) / Sidebar sur desktop | Riverpod (`_selectedFlatIndex`) | Réelles | Calqué sur l'Admin (6 groupes, 14 tiroirs). Anti-ergonomique sur smartphone | Passer à une BottomNavigationBar mobile-first (5 onglets clés) + Hub secondaire |
| **Accueil** | Tableau de bord élève | `HomeDashboardScreen` | **IMPROVE** | Dashboard avec cartes verticales | Supabase (`fetchSubjects`, `fetchCurrentTermInfo`, countdown) | Réelles | Trop verbeux, sensation de portail administratif, manque de punch pédagogique | Recentrer sur "Que faire maintenant ?", continuer leçon, défi du jour |
| **Académique** | Liste des matières | `SubjectsListScreen` | **IMPROVE** | ListView avec `SubjectVisuals` | `fetchSubjects(classNodeId)` | Réelles | Liste linéaire sans indicateur de complétion ou maîtrise | Vue dynamique (grille adaptative / tuiles), badges de complétion |
| **Académique** | Liste des chapitres d'une matière | `ChaptersListScreen` | **IMPROVE** | ListView avec cartes de chapitres | `fetchChapters(subjectId, classNodeId)` | Réelles | Le bouton "Ouvrir le cours" ouvre directement sans montrer la liste des leçons | Restructurer pour afficher les leçons du chapitre, les objectifs et l'introduction |
| **Pédagogie** | Lecteur de leçon structurée | `LessonReaderScreen` | **REFACTOR** | SingleChildScrollView + `BlockRendererRegistry` | `fetchLessons(chapterId)` | Réelles | Ne lit que `lessons.first` ! Pas de navigation inter-leçons dans un chapitre | Gérer le sommaire du chapitre, pagination inter-leçons, temps de lecture, reprise |
| **Pédagogie** | Registre de blocs pédagogiques | `BlockRendererRegistry` | **EXISTING / KEEP** | Widgets spécifiques par type de bloc (théorème, formule, piège...) | Colonne JSON structurée `content_json` | Réelles | Très bonne architecture découplée (Content != Presentation) | Conserver scrupuleusement, étendre le rendu formules et graphiques |
| **Pédagogie** | Filigrane de sécurité (DRM logiciel) | `ForensicWatermarkService` | **EXISTING / KEEP** | Overlay semi-transparent | Identité compte élève | Réelles | Protège contre les captures | Conserver |
| **Exercices** | Hub des exercices de la classe | `ExercisesHubScreen` | **IMPROVE** | Dossiers par matière + transversaux | `fetchExercisesForClass` | Réelles | Arborescence brute | Enrichir avec niveaux de difficulté, filtres par compétence |
| **Exercices** | Dossiers de chapitres d'exercices | `ExerciseChapterFoldersScreen` | **EXISTING / KEEP** | ListView de chapitres | `fetchExercisesForClass` | Réelles | Navigation claire | Conserver et appliquer les tokens de style |
| **Exercices** | Moteur d'exécution des quiz & exercices | `ExerciseRunnerScreen` | **IMPROVE** | Runner interactif (QCM, texte court, rédaction, flashcard, manuscrit) | `recordExerciseAttempt` | Réelles | Fonctionnel (XP, indices progressifs), mais feedback et corrigé perfectibles | Pédagogie de l'erreur enrichie, célébration visuelle de réussite, explication détaillée |
| **Examens** | Anciens sujets officiels nationaux | `OfficialExamsScreen` | **IMPROVE** | Filtre par matière / année | `fetchOfficialExamForClass`, `fetchExamPapers` | Réelles | Documents bruts | Ajouter fiches conseils méthodologiques, timer de simulation |
| **Examens** | Épreuves d'établissements partenaires | `EstablishmentPapersScreen` | **IMPROVE** | Filtre par lycée / matière | `fetchEstablishments`, `fetchEstablishmentPapers` | Réelles | Liste austère | Mettre en valeur l'établissement d'origine, filtrage rapide |
| **Examens** | Questions publiées d'examen | `ExamQuestionsScreen` | **PARTIAL** | Écran nouvellement introduit (migration 74) | `fetchPublishedExamQuestions` | Réelles | Écran brut de lecture de questions | Intégrer dans le parcours officiel d'entraînement |
| **Examens** | Arène d'examens blancs & Olympiades | `MockExamArenaScreen` | **IMPROVE** | Liste d'événements, scores et leaderboards | `fetchEventsForClass`, `fetchEventLeaderboard` | Réelles | Très riche fonctionnellement, UI perfectible | Moderniser le classement, chronomètre non stressant, feedback |
| **IA Tuteur** | Chat avec le Tuteur Numérique | `AiTutorChatScreen` | **IMPROVE** | Chat conversationnel | Edge Function `ai-tutor-chat` (Gemini Flash) | Réelles | Simple boîte de chat ; manque de contexte précis (matière/leçon) | Injecter le contexte de la leçon courante, support formules, maïeutique guidée |
| **Communauté** | Forum de classe modéré | `ClassForumScreen` | **IMPROVE** | Fil de discussion cloisonné par classe | `fetchForumPosts`, `createForumPost` | Réelles | Interface forum basique | Ajouter filtres par matière, statut résolu, signalement propre |
| **Communauté** | Groupes WhatsApp officiels | `StudyCommunitiesScreen` | **EXISTING / KEEP** | Lien vers groupe WhatsApp de classe | `fetchWhatsappCommunity` | Réelles | Conforme au contexte camerounais/africain | Conserver tel quel |
| **Abonnements** | Paywall modal & offres | `PaywallModal` | **IMPROVE** | BottomSheet avec 3 formules | `account_subscriptions` (tables Supabase) | Réelles | Affiche un faux formulaire Mobile Money qui informe de l'attente passerelle | Clarifier les droits par palier, garder le message honnête sans simuler de paiement |
| **Boutique** | Boutique d'annales & fiches | `BoutiqueShopScreen` | **IMPROVE** | Grille de documents PDF | `fetchShopDocuments` | Réelles | Téléchargement non branché (mode honnête) | Conserver l'honnêteté, améliorer la prévisualisation des fiches |
| **Support** | Tickets de support utilisateur | `SupportTicketsScreen` | **EXISTING / KEEP** | Liste et création de tickets avec suivi | `fetchSupportTickets`, `createSupportTicket` | Réelles | Très fonctionnel | Conserver, soigner les états vides et statuts |
| **Soutien** | Dons & Campagnes caritatives | `DonationsScreen` | **EXISTING / KEEP** | Cartes de causes caritatives | `fetchCharityCampaigns` | Réelles | Conforme au CDC §12 | Conserver |
| **Profil** | Profil élève & gestion de compte | `StudentProfileScreen` | **IMPROVE** | Édition nom, avatar, photo upload, link parent | `accounts`, storage `avatars`, `parent_profile_links` | Réelles | Page très longue (1074 lignes) monolithique | Découper en sous-composants, mettre en valeur les statistiques et badges |
| **Paramètres** | Paramètres & Accessibilité | `SettingsScreen` | **IMPROVE** | Réglages thème, contraste, taille police, mot de passe | `account_settings` | Réelles | Fonctionne très bien avec `TextScaler` et `StudentTheme.resolve` | Conserver la robustesse technique, organiser par onglets clairs |
| **Espace Parent**| Portail de supervision des parents | `ParentDashboardScreen` / `ParentEntryScreen` | **EXISTING / KEEP** | Espace parent complet, comptes séparés | `parent_accounts`, `parent_profile_links` | Réelles | Module distinct conforme au CDC §17 | Ne pas casser, préserver l'isolation stricte avec l'élève |
| **Simulations** | Simulateurs interactifs / labos | *Aucun écran dédié* | **MISSING** | Néant | Néant | Néant | Absent du code actuel | À concevoir dans l'architecture modulaire future |
| **Gamification**| Badges, streaks, trophées | *Partiel dans l'arène / XP dans runner* | **PARTIAL** | Calcul XP basique dans `ExerciseRunnerScreen` | Colonne `xp` / scores événements | Réelles | Pas de page dédiée de visualisation des récompenses / streak | Prévoir composant Streak & Récompenses sans transformer en casino |
| **Offline** | Cache de cours et synchronisation | *Bouton désactivé avec snackbar* | **PARTIAL** | Bouton inactif explicite | Néant | Néant | Annoncé honnêtement comme indisponible | Préparer l'infrastructure de cache de blocs de cours |
| **i18n** | Multilingue Anglais / Français | *Fixé en dur en français* | **PARTIAL** | Textes hardcodés en français | Néant | Néant | L'anglais est requis pour les sections anglophones du Cameroun | Préparer les clés de traduction sans casser le contenu pédagogique |

---

## 2. Synthèse de l'Architecture Détectée

1. **Framework :** Flutter 3.12+ avec Dart.
2. **State Management :** `flutter_riverpod` (StateNotifier, Provider, FutureProvider, family providers).
3. **Backend :** Supabase Backend (PostgreSQL, Supabase Auth, Storage, Edge Functions Deno).
4. **Modèle de Données :** Plus de 70 migrations SQL avec RLS strict, séparation des comptes élèves (`accounts`) et parents (`parent_accounts`), arbre académique hiérarchique (`academic_nodes`), dissociation contenu/rendu (`content_json` -> `ContentBlock`).
5. **Absence de dette de faux mocks :** L'application est branchée sur des données réelles Supabase. Quand une fonction n'est pas encore opérationnelle (agrégateur Mobile Money, mode hors-ligne), elle l'indique honnêtement par une snackbar informative au lieu de simuler un faux succès. Cette rigueur doit être préservée.
