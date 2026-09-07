# Matrice de Couverture des Fonctionnalités (FEATURE_COVERAGE_MATRIX)

**Date :** 2026-09-05  
**Document de référence :** `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`  
**Périmètre :** Application Élève EDLEARN

---

## Matrice Comparative Spécification vs Réalité du Codebase

| Domaine | Fonctionnalité | Existe | Partiel | Manquant | Backend | UI | Priorité | Commentaire |
| :--- | :--- | :---: | :---: | :---: | :--- | :--- | :---: | :--- |
| **Auth** | Inscription multi-étapes (Wizard 7 étapes) | ✅ | | | `accounts`, `profiles`, RLS | `OnboardingWizardScreen` | P1 | Conforme au CDC §7.1. Navigation avant/arrière et descente de l'arbre académique réelles. |
| **Auth** | Authentification Email / Mot de passe | ✅ | | | Supabase Auth (`auth.users`) | `StudentLoginScreen` | P1 | Fonctionne sur session réelle. |
| **Auth** | Déverrouillage rapide par code personnel (PIN) | ✅ | | | RPC `verify_personal_login_code` | `LoginCodeEntryScreen` | P2 | Conforme au CDC §7.3. Déverrouille la session sans ressaisie du mot de passe. |
| **Auth** | Session unique stricte (anti-partage de compte) | ✅ | | | Migration 31 (`enforce_single_session`) | Déconnexion automatique gérée | P2 | Conforme au CDC §7.4. Déconnexion automatique de l'ancienne session. |
| **Auth** | Multi-profils sur un même compte | ✅ | | | Table `profiles` jointe à `accounts` | `ProfileSwitcherScreen` | P1 | Conforme au CDC §2.3. 1 profil = 1 classe = 1 abonnement. |
| **Academic Tree** | Arborescence Pays -> Section -> Enseignement -> Classe -> Série | ✅ | | | Table `academic_nodes` | Sélecteur dans le wizard | P1 | Descente hiérarchique dynamique conforme aux spécifications. |
| **Academic Tree** | Cloisonnement strict du contenu par classe du profil | ✅ | | | `subject_class_links`, RLS | Automatique via `activeProfile.classNodeId` | P0 | Conforme au CDC §2.4. L'élève ne voit que ce qui est associé à sa classe. |
| **Academic Tree** | Découpage par trimestre invisible (déblocage automatique) | ✅ | | | `terms_calendar`, dates officielles | `ChaptersListScreen` badges verrou | P0 | Conforme au CDC §1.8/§3.3. Déblocage temporel calculé selon la date du jour. |
| **Home** | Salutation, classe et profil actif | ✅ | | | `activeProfile`, `accounts` | En-tête `HomeDashboardScreen` | P0 | Conforme au CDC. |
| **Home** | Compte à rebours vers l'examen officiel national | ✅ | | | `official_exams`, `official_exam_classes` | Bannière countdown sur l'accueil | P0 | Conforme au CDC §2.7. Masqué si la classe n'a pas d'examen officiel. |
| **Home** | Reprise d'activité / "Continuer ma leçon" | | | ❌ | Champ `last_lesson_id` absent | Absente de l'accueil | P0 | **Manquant critique** : l'accueil doit répondre immédiatement à "Que dois-je faire maintenant ?". |
| **Subjects** | Liste des matières filtrée par profil | ✅ | | | `fetchSubjects(classNodeId)` | `SubjectsListScreen` | P0 | Couleurs et icônes dynamiques via `SubjectVisuals`. |
| **Subjects** | Indicateurs de progression et de maîtrise par matière | | ⚠️ | | Calculs possibles via `exercise_attempts` | Non affichés sur les tuiles | P0 | À enrichir pour visualiser la maîtrise (débutant, intermédiaire, acquis). |
| **Chapters** | Liste ordonnée des chapitres avec statut | ✅ | | | Table `chapters` | `ChaptersListScreen` | P0 | Détection automatique des chapitres du trimestre en cours. |
| **Chapters** | Introduction de chapitre (sens avant théorie) | ✅ | | | Colonne `introduction` | Affichée dans la carte chapitre | P0 | Conforme au CDC §26. Texte introductif d'accroche présent. |
| **Lessons** | Rendu de blocs pédagogiques riches (`ContentBlock`) | ✅ | | | JSON structuré `content_json` | `BlockRendererRegistry` | P0 | Théorème, définition, formule, méthode, exemple, piège, conseil d'examen. |
| **Lessons** | Navigation complète inter-leçons dans un chapitre | | | ❌ | `fetchLessons` renvoie bien la liste | `LessonReaderScreen` ne lit que `lessons.first` | P0 | **Bogue structurel UI majeur** : empêche d'accéder aux leçons 2, 3, etc. |
| **Lessons** | Sommaire intra-leçon et reprise de lecture | | | ❌ | Néant | Néant | P1 | Manque pour les longs cours pour éviter la fatigue visuelle. |
| **Activities** | Activités d'observation, manipulation, réflexion | | ⚠️ | | Stockable dans `content_json` | Rendu comme paragraphe ou bloc méthode | P1 | Pas encore de renderer d'activité interactive dédiée. |
| **Exercises** | Formats multiples (QCM, texte court, rédaction, flashcard, manuscrit) | ✅ | | | Table `exercises`, colonne `format` | `ExerciseRunnerScreen` | P0 | Supporte les 5 formats réels du backend. |
| **Exercises** | Enregistrement réel des tentatives élève | ✅ | | | Table `exercise_attempts` (IA-007) | `recordExerciseAttempt` | P0 | Enregistre score, réponse soumise, succès/échec. |
| **Exercises** | Indices progressifs guidés | ✅ | | | Tableau `hints` dans `exercises` | `_hintsSection` dans le runner | P0 | Révélation maïeutique un par un. |
| **Corrections** | Corrigé détaillé et pédagogie de l'erreur | | ⚠️ | | Colonne `explanation` dans `exercises` | `_correctionCard` basique | P0 | Manque la décomposition étape par étape et le rappel de la notion clé. |
| **Exams** | Annales officielles nationales (BEPC, Probatoire, Bac) | ✅ | | | Tables `official_exams`, `exam_papers` | `OfficialExamsScreen` | P1 | Cloisonné par classe. Sujets et années disponibles. |
| **Exams** | Épreuves d'établissements partenaires | ✅ | | | Tables `establishments`, `establishment_papers` | `EstablishmentPapersScreen` | P1 | Catalogue ouvert avec classe déduite du profil actif. |
| **Exams** | Examens blancs et Olympiades en ligne | ✅ | | | Table `mock_events`, `event_registrations` | `MockExamArenaScreen` | P1 | Événements, chronomètre, leaderboards anonymisés. |
| **Revision** | Révision intelligente espacée (SRS) | | | ❌ | Table d'historique de tentatives présente | Absence d'algorithme SM-2/FSRS et d'UI | P2 | Prévu CDC §15. À brancher sur les erreurs enregistrées. |
| **AI** | Tuteur Numérique sans coût obligatoire (Maïeutique) | ✅ | | | Edge Function `ai-tutor-chat` | `AiTutorChatScreen` | P1 | Conforme à la règle zéro-coût (Gemini Flash/Deno, fallback mock). |
| **AI** | Tuteur contextuel lié au cours ou à l'exercice actif | | ⚠️ | | Paramètres de contexte acceptés par l'API | Bouton flottant intra-leçon manquant | P0 | À intégrer directement dans le lecteur de leçon et la correction d'exercice. |
| **Gamification** | Points d'expérience (XP) | ✅ | | | Champ `points` par exercice | Calcul dynamique et affichage dans le quiz | P1 | Présent dans l'exercice runner. |
| **Gamification** | Streak (jours consécutifs) | | ⚠️ | | Horodatage des sessions disponible | Carte UI absente de l'accueil | P1 | À rendre visible sur l'accueil pour encourager la régularité sans culpabiliser. |
| **Rewards** | Badges, trophées, célébrations d'anniversaire | | ⚠️ | | Détection d'anniversaire active (`isBirthdayToday`) | Bannière anniversaire présente, pas d'écran badges | P2 | Manque un onglet/galerie de badges obtenus. |
| **Notifications** | Préférences de notifications in-app/push | ✅ | | | Table `account_settings` | `SettingsScreen` | P1 | Toggles réels pour abonnement, forum, révision. |
| **Notifications** | Centre de notifications in-app | | | ❌ | Table de notifications système | Pas d'écran dédié de notifications | P2 | Les notifications arrivent via bannières ou snackbars. |
| **Subscription** | Paliers tarifaires et contrôle d'accès (Matrice de droits) | ✅ | | | `account_subscriptions`, tables de droits | `PaywallModal`, bannières d'accès | P0 | Distingue Gratuit, Mensuel, Annuel. |
| **Payments** | Mobile Money (Orange Money, MTN MoMo) | | ⚠️ | | Webhook `payment-webhook` prêt | UI affiche un état d'attente honnête | P1 | Prêt pour branchement passerelle réelle (Campay/NotchPay). Pas de faux mock. |
| **Referral** | Parrainage (code élève, bonus jours) | | | ❌ | Spécifié au CDC §6.7 | Non implémenté en UI élève | P3 | Fonctionnalité de croissance future. |
| **Offline** | Cache de leçons et synchronisation locale | | ⚠️ | | Téléchargement PDF forensique | Bouton désactivé avec mention explicite | P2 | Doit évoluer vers un cache local de blocs structurés. |
| **Simulations** | Simulateurs scientifiques et labos virtuels | | | ❌ | Spécifié au CDC §55-56 | Absent du frontend élève | P3 | À prévoir pour sciences physiques et mathématiques. |
| **Profile** | Informations personnelles, avatar, liaison parent | ✅ | | | Table `accounts`, storage `avatars` | `StudentProfileScreen` | P1 | Upload photo réel avec cache-busting, liaison parent bidirectionnelle. |
| **Settings** | Apparence, contraste élevé, échelle de police, sécurité | ✅ | | | Table `account_settings` | `SettingsScreen` | P1 | Fonctionne avec `StudentTheme.resolve` et `TextScaler`. |
