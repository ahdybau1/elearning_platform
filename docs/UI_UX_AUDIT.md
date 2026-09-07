# Audit UI/UX Complet — Application Élève (UI_UX_AUDIT)

**Plateforme :** EDLEARN Student Application (Flutter)  
**Date :** 2026-09-05  
**Version évaluée :** Codebase à HEAD (`f5edccf`+)  
**Rôles d'évaluation :** Lead Product Designer, Senior UI/UX Designer, Senior Flutter Front-End Engineer, Spécialiste EdTech & Mobile-First.

---

## 1. Résumé Exécutif

L'application élève EDLEARN dispose d'une base technique remarquablement solide sur le plan des données et de l'architecture :
- **Vérité des données :** L'application est directement branchée sur Supabase avec un modèle relationnel robuste (arbre académique Cameroun, leçons structurées, exercices multi-formats, comptes parents séparés, politique RLS stricte).
- **Rigueur pédagogique :** Le découplage entre contenu canonique (`ContentBlock`) et présentation (`BlockRendererRegistry`) est déjà mis en place.
- **Transparence exemplaire :** Les fonctionnalités en attente de passerelles tierces (Mobile Money, téléchargement offline lourd) affichent un message honnête et ne prétendent pas fonctionner par des mocks trompeurs.

Cependant, sur le plan **UI/UX, ergonomie mobile et expérience d'apprentissage**, l'application souffre d'un défaut fondamental de conception d'origine :
- **L'illusion du desktop administratif :** L'interface a initialement été bâtie comme un clone de l'application d'administration (`main_admin_layout.dart`), avec une barre latérale permanente découpée en 6 modules d'entreprise ("Mon espace", "Apprentissage", "Évaluation", "Communauté", "Services", "Support").
- **Adaptation mobile réactive mais non pensée pour le pouce :** Pour pallier les débordements sur écran 390px, cette barre a été simplement reléguée dans un `Drawer` Material standard. Un élève sur smartphone se retrouve à devoir constamment ouvrir un menu latéral de 14 items pour naviguer.
- **Pages monolithiques et manque de hiérarchie visuelle :** Plusieurs fichiers dépassent 600 à 1000 lignes (`student_profile_screen.dart` : 1074 lignes, `home_dashboard_screen.dart` : 783 lignes, `exercise_runner_screen.dart` : 671 lignes). Tout est empilé verticalement sous forme de cartes denses avec peu d'aération rythmée.
- **Rupture de continuité pédagogique :** Dans `ChaptersListScreen`, cliquer sur un chapitre envoie directement sur `LessonReaderScreen` qui n'affiche que la toute première leçon du chapitre (`lessons.first`), occultant les leçons suivantes et déconnectant les exercices du parcours naturel.

---

## 2. Architecture Frontend Existante

### Organisation des dossiers
```
student_app/lib/
├── main.dart                      # Point d'entrée, AppRootGate, StudentAuthGate, MaterialApp, onGenerateRoute
├── core/
│   ├── auth/                      # StudentAuthProvider, ParentAuthProvider, DeviceAccountsService
│   ├── config/                    # SupabaseConfig, variables d'environnement
│   ├── models/                    # StudentModels, ContentBlock, PublishedExamQuestion
│   ├── providers/                 # StudentProviders, AppRootProviders
│   ├── rendering/                 # BlockRendererRegistry (rendu des blocs de leçons)
│   ├── services/                  # StudentSupabaseService, ForensicWatermarkService
│   ├── theme/                     # StudentTheme, StudentColors, SubjectVisuals
│   └── widgets/                   # MaintenanceGate, StudentPageContent, StudentScreenHeader
└── features/
    ├── ai_tutor/                  # AiTutorChatScreen
    ├── community/                 # ClassForumScreen, StudyCommunitiesScreen (WhatsApp)
    ├── courses/                   # SubjectsListScreen, ChaptersListScreen, LessonReaderScreen, ExerciseRunnerScreen, ExercisesHubScreen, ExerciseChapterFoldersScreen
    ├── exams/                     # OfficialExamsScreen, EstablishmentPapersScreen, MockExamArenaScreen, ExamQuestionsScreen
    ├── home/                      # HomeDashboardScreen, MainNavigationScreen
    ├── onboarding/                # RoleSelectionScreen, DeviceAccountSelectorScreen, LoginCodeEntryScreen, StudentLoginScreen, OnboardingWizardScreen, ProfileSwitcherScreen
    ├── parent_portal/             # ParentDashboardScreen, ParentEntryScreen
    ├── profile/                   # StudentProfileScreen
    ├── settings/                  # SettingsScreen
    ├── subscription/              # BoutiqueShopScreen, PaywallModal
    └── support/                   # SupportTicketsScreen, DonationsScreen
```

### State Management
- Utilisation propre et cohérente de `flutter_riverpod` (v2.6.1).
- `StateNotifierProvider` pour l'authentification et les sessions (`studentAuthProvider`, `parentAuthProvider`).
- `FutureProvider.family` pour les requêtes dépendantes de la classe ou du chapitre (`studentSubjectsProvider`, `studentChaptersProvider`, `studentLessonsProvider`, etc.).
- Gestion réactive des portes d'accès (`AppRootGate`, `StudentAuthGate`, `MaintenanceGate`).

---

## 3. Navigation

### Navigation Actuelle
- Un `Scaffold` central dans `MainNavigationScreen`.
- Sur écran `>= 700px` : sidebar latérale rétractable (largeur 260px).
- Sur écran `< 700px` : barre cachée dans un `Drawer` Material déclenché par un bouton burger.
- En parallèle, un `Navigator` impératif standard avec `onGenerateRoute` dans `main.dart` pour les écrans de sous-détail (`/chapters`, `/lesson-reader`, `/exercises`, `/ai-tutor`, `/mock-arena`).

### Défauts Ergonomiques Majeurs
1. **Pas de BottomNavigationBar sur mobile :** Le pouce de l'élève ne peut pas basculer rapidement entre son cours, ses exercices et son tuteur sans lever la main vers l'icône burger en haut à gauche.
2. **Perte du contexte parent :** Quand on navigue vers `/lesson-reader` ou `/exercises`, la barre de navigation disparaît complètement dans un écran plein écran sans fil d'Ariane clair.
3. **Hiérarchie administrative :** 6 catégories et 14 sous-pages dans un tiroir. Un élève n'a que faire de voir "Services", "Support", "Évaluation" au même niveau d'importance visuelle que "Continuer mon cours".

---

## 4. Revue Détaillée des Écrans

### 4.1 Accueil (`HomeDashboardScreen`)
- **Forces :** Intègre les vraies données : message d'anniversaire personnalisé, compte à rebours de l'examen officiel national, trimestre en cours avec dates réelles, grille des matières de la classe, carte de communauté WhatsApp.
- **Faiblesses :** Empilement vertical de bannières massives (Bannière abonnement violette + Compte à rebours bleu + Carte trimestre + Grille + WhatsApp + Tuteur). L'élève doit faire défiler 3 écrans entiers avant d'atteindre ses matières. L'action essentielle "Reprendre où je m'étais arrêté" est absente.

### 4.2 Liste des Matières (`SubjectsListScreen`)
- **Forces :** Filtrage strict par classe du profil actif (`classNodeId`), dégradés et icônes dynamiques par matière via `SubjectVisuals`.
- **Faiblesses :** Liste linéaire de tuiles épaisses. Pas de pourcentage de progression par matière, pas de notion de chapitres maîtrisés, pas de tri par matière favorite ou urgente.

### 4.3 Liste des Chapitres (`ChaptersListScreen`)
- **Forces :** Bannière héroïque avec motif animé (`SubjectMotif`), gestion explicite des chapitres verrouillés par trimestre avec date de déblocage automatique.
- **Faiblesses :** Chaque carte de chapitre présente un seul bouton d'action "Ouvrir le cours". L'élève ne voit pas la liste des leçons contenues dans ce chapitre. Il ne peut pas choisir directement une leçon spécifique ni lancer directement les exercices de fin de chapitre.

### 4.4 Lecteur de Leçon (`LessonReaderScreen`)
- **Forces :** Rendu riche et modulaire grâce à `BlockRendererRegistry`, affichage du temps de lecture estimé, filigrane de sécurité discret, bouton direct vers les exercices.
- **Faiblesses critiques :**
  - **Ne lit que la première leçon (`lessons.first`) :** Si un chapitre compte 4 leçons, les leçons 2, 3 et 4 sont totalement inaccessibles depuis l'interface !
  - **Absence de table des matières intra-leçon :** Les cours longs demandent un défilement infini sans repère.
  - **Pas de reprise de position :** Quitter la page remet le défilement à zéro.

### 4.5 Moteur d'Exercices (`ExerciseRunnerScreen`)
- **Forces :** Supporte 5 formats réels (QCM, réponse courte, rédaction, flashcard, manuscrit scanné), progression par question, calcul de points XP réels, système d'indices progressifs (`_hintsSection`), persistance de la tentative via `recordExerciseAttempt`.
- **Faiblesses :**
  - Le feedback après réponse est abrupt (simple carte colorée verte ou rouge en dessous).
  - L'explication n'est pas décomposée en étapes méthodologiques.
  - La fin du quiz affiche une boîte de dialogue modale basique sans récapitulatif détaillé des compétences acquises ou des erreurs à réviser.

### 4.6 Tuteur Numérique IA (`AiTutorChatScreen`)
- **Forces :** Connexion réelle à l'Edge Function Deno `ai-tutor-chat` branchée sur Gemini Flash, suggestions rapides de questions ("Quick Prompts"), gratuit et illimité.
- **Faiblesses :** L'écran est déconnecté du cours. L'élève doit retaper lui-même la question ou la formule. Aucune prise en compte de la leçon active ou de l'exercice sur lequel il vient d'échouer.

### 4.7 Profil & Compte (`StudentProfileScreen`)
- **Forces :** Upload d'avatar réel vers Supabase Storage avec cache-busting, liaison avec compte parent par code bidirectionnel, liste des profils archivés, affichage de l'établissement et de la date de naissance.
- **Faiblesses :** Fichier monolithique de 1074 lignes mélangeant formulaire d'identité, code de déverrouillage, liaison parent, profils archivés et gestion d'abonnements.

---

## 5. Design System Existant

Le fichier `student_theme.dart` implémente :
- Une classe `StudentColors` (ThemeExtension) gérant 4 variantes : `dark`, `darkHighContrast`, `light`, `lightHighContrast`.
- Des couleurs sémantiques de base :
  - `backgroundDark = Color(0xFF0B0F19)`
  - `surfaceDark = Color(0xFF131B2E)`
  - `cardDark = Color(0xFF1B243B)`
  - `borderDark = Color(0xFF2B3754)`
  - Accents : Cyan (`0xFF38BDF8`), Emerald (`0xFF10B981`), Amber (`0xFFF59E0B`), Rose (`0xFFF43F5E`), Indigo (`0xFF6366F1`), Purple (`0xFFA855F7`).
- Des typographies avec Google Fonts : `Outfit` pour les titres, `Inter` pour le corps de texte.

### Limites constatées du Design System actuel
1. **Absence d'échelle de tokens normalisée :** Espacements (`padding`, `margin`) hardcodés de manière hétérogène (10, 14, 16, 18, 20, 22, 24, 28, 32) dans chaque widget.
2. **Rayons de courbure (BorderRadius) dispersés :** 6, 8, 10, 12, 14, 16, 18, 20, 24 selon les widgets.
3. **Absence de tokens d'ombres et d'élévation normalisés.**
4. **Pas de composant bouton standardisé :** Chaque écran redéfinit son propre `ElevatedButton.styleFrom(...)`.

---

## 6. Responsive

- **Breakpoint unique actuel :** `_kMobileBreakpoint = 700`.
- **Problème :** En dessous de 700px, tous les écrans mobiles (de 320px à 430px) reçoivent exactement la même mise en page avec des espacements fixes de 20px.
- **Sur petit smartphone (320px - 360px) :**
  - Risque d'overflows sur les lignes contenant titre + badge.
  - La grille `GridView.builder(crossAxisCount: 2)` de l'accueil écrase le contenu des tuiles de matières.
- **Sur tablette (768px - 1024px) :**
  - La mise en page s'étire sans tire-d'aile, rendant les lignes de lecture trop larges (>100 caractères par ligne), fatiguant la vue.

---

## 7. Accessibilité (A11y)

- **Points forts :**
  - Implémentation réelle de `TextScaler.linear(settings.fontScale)` dans le `MaterialApp.builder`.
  - Deux thèmes à fort contraste dédiés (`darkHighContrast`, `lightHighContrast`).
  - Filigrane DRM configuré avec opacité calibrée pour ne pas gêner la lecture.
- **Points faibles :**
  - Plusieurs boutons d'icônes n'ont pas de label sémantique pour TalkBack/VoiceOver.
  - Dans les quiz, les options sélectionnées se fient trop exclusivement à la couleur du contour pour signifier l'état avant validation.
  - Les formules mathématiques dans `BlockRendererRegistry` sont de simples textes ou containers sans description textuelle alternative pour les lecteurs d'écran.

---

## 8. Performance

- **Points forts :**
  - Utilisation de `ListView.separated` avec recyclage des cellules.
  - Pas d'assets lourds ou d'images 4K non optimisées : motifs légers animés par `AnimatedBuilder` et `Transform`.
  - Cache-busting léger sur les avatars.
- **Points faibles :**
  - `HomeDashboardScreen` utilise un `SingleChildScrollView` géant contenant un `GridView` avec `shrinkWrap: true` et `NeverScrollableScrollPhysics()`, ce qui force la création en mémoire de tous les éléments à l'avance.

---

## 9. Problèmes de Cohérence Identifiés

1. **Intitulés d'écrans :** "Tableau de Bord" vs "Accueil", "Mes Matières & Cours" vs "Cours & Matières".
2. **Boutons d'action :** Parfois cyan, parfois indigo, parfois vert émeraude pour des actions de même niveau d'importance (CTA primaire).
3. **Cartes d'état vide (Empty States) :** Textes et icônes créés ad hoc dans chaque fichier avec des paddings différents au lieu d'un composant réutilisable `EmptyStateView`.

---

## 10. Composants Dupliqués à Factoriser

1. **En-têtes d'écrans :** `StudentScreenHeader` existe mais n'est pas utilisé partout (certains écrans utilisent un `AppBar` standard, d'autres empilent un titre dans le body).
2. **Cartes d'indices et d'avertissements :** Présentes dans `ExerciseRunnerScreen` et `BlockRendererRegistry` avec des styles similaires mais recodées indépendamment.
3. **Badges de badges/XP/Timer :** Mini-containers répétés dans 5 écrans différents.

---

## 11. Fonctionnalités Déjà Bonnes (À Conserver Absolument)

1. **Découplage `ContentBlock` & `BlockRendererRegistry` :** Modèle extensible et propre.
2. **Déblocage temporel par trimestre :** Masquage automatique selon la date et calendrier scolaire national.
3. **Filtrage académique strict :** L'élève ne voit que les matières et examens de sa classe.
4. **Gestion de session et comptes connus :** Service `DeviceAccountsService` et déverrouillage PIN.
5. **Enregistrement des tentatives d'exercices :** Fonction `recordExerciseAttempt` qui alimente la mémoire d'apprentissage.
6. **Isolation de l'Espace Parent :** Comptes `parent_accounts` séparés sans mélange avec l'élève.

---

## 12. Fonctionnalités Fragiles

1. **Lecteur de cours bloqué sur `lessons.first` :** Masque 75% du contenu des chapitres multi-leçons.
2. **Navigation mobile via Drawer :** Incommode pour les élèves sur téléphone.
3. **Sélecteur de profil :** Ne montre pas l'avancement global, incitant peu à reprendre une session.
4. **Chat Tuteur IA :** Pas d'ancrage contextuel à la leçon consultée.

---

## 13. Risques de Régression Majeurs

1. **Casser les IDs et arguments de navigation :** `subjectId`, `classNodeId`, `chapterId` doivent impérativement transiter entre les écrans.
2. **Casser les polices RLS Supabase :** Toute modification de requête doit respecter `auth.uid()` et les liaisons `subject_class_links`.
3. **Régression sur l'Espace Parent :** Ne jamais mélanger le provider parent (`parentAuthProvider`) avec celui de l'élève.
4. **Perte de l'honnêteté des statuts :** Ne jamais introduire de faux succès sur les paiements ou le mode offline.

---

## 14. Recommandations Stratégiques

1. **Adopter une navigation mobile-first :** Remplacer le Drawer par une `StudentBottomNavigation` avec 5 points d'ancrage essentiels :
   - 🏠 **Accueil** (Continuer, progression du jour, matières récentes)
   - 📚 **Apprendre** (Matières, chapitres, leçons complètes)
   - ✏️ **Pratiquer** (Exercices de cours, annales, quiz)
   - 💡 **Tuteur IA** (Aide contextuelle, explications)
   - 👤 **Profil** (Progression, récompenses, paramètres)
2. **Corriger immédiatement le lecteur de leçons :** Ajouter une barre de progression inter-leçons, un sommaire déroulant et une navigation Suivant/Précédent.
3. **Normaliser le Design System :** Figer les tokens dans `lib/design_system/` (spacing, radius, typography, colors, buttons, inputs).
4. **Enrichir l'expérience pédagogique :** Introduire la notion de maîtrise progressive, les célébrations de fin d'exercice et l'explication d'erreurs guidée.
