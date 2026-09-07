# Plan de Refonte UI/UX Progressive (UI_REDESIGN_PLAN)

**Date :** 2026-09-05  
**Cible :** Application Élève EDLEARN (`student_app`)  
**Règle absolue :** Pas de refonte "Big Bang" incontrôlable. Déploiement par vagues successives testées visuellement et fonctionnellement sur données réelles Supabase sans régression.

---

## 1. Vue d'Ensemble des Vagues de Déploiement

| Vague | Priorité | Périmètre Fonctionnel | Objectif Pédagogique & Produit |
| :--- | :---: | :--- | :--- |
| **Vague 0** | **P0** | **Fondations du Design System & Navigation Mobile-First** | Centraliser les tokens, créer les composants fondamentaux, remplacer le tiroir par la BottomBar. |
| **Vague 1** | **P0** | **Le Cœur Pédagogique Élève (Les 7 Premiers Écrans)** | Accueil -> Matières -> Chapitres -> Leçon (multi-leçons) -> Quiz/Exercice -> Corrigé enrichi. |
| **Vague 2** | **P1** | **Évaluations, Annales d'Examens & Tuteur IA Contextuel** | Sujets officiels BEPC/Bac, épreuves établissements, arène d'examens blancs, aide IA intra-cours. |
| **Vague 3** | **P2** | **Onboarding, Authentification, Sélecteur de Profil & Paramètres** | Fluidifier le wizard d'inscription, rehausser le sélecteur de profil, polir les paramètres et l'accessibilité. |
| **Vague 4** | **P3** | **Communautés, Boutique, Support & Services Complémentaires** | Forum modéré de classe, boutique de fiches, tickets support, dons et préparation de l'offline structuré. |

---

## 2. Vague 0 — Fondations & Navigation Mobile-First (P0)

### 2.1 Scope
- Mettre en place l'architecture du Design System dans `lib/design_system/` :
  - `tokens/app_colors.dart`
  - `tokens/app_typography.dart`
  - `tokens/app_spacing.dart`
  - `tokens/app_radius.dart`
- Développer les composants universels : `AppButton`, `AppCard`, `EmptyStateView`, `SectionHeader`.
- Remplacer l'ancien tiroir Material de 14 items dans `MainNavigationScreen` par :
  - **Sur smartphone (<700 px) :** `StudentBottomBar` avec 5 onglets clés (Accueil, Cours, Exercices, Tuteur IA, Profil).
  - **Sur tablette & desktop ($\ge 700$ px) :** `NavigationRail` / Sidebar compacte respectueuse du contenu.

### 2.2 Fichiers impactés
- `lib/core/theme/student_theme.dart` (intégration des nouveaux tokens en compatibilité ascendante).
- `lib/features/home/screens/main_navigation_screen.dart` (refonte de la structure de navigation).
- `lib/core/widgets/student_page_content.dart` (calibrage des marges adaptatives).

### 2.3 Risques & Mitigation
- *Risque :* Casser l'accès aux sous-pages qui étaient dans le tiroir (Dons, Boutique, Support).
- *Mitigation :* Les sous-pages secondaires sont regroupées élégamment dans un hub "Services & Plus" accessible depuis l'onglet Profil ou un bouton dédié sans encombrer la barre principale.

---

## 3. Vague 1 — Le Cœur Pédagogique Élève : Les 7 Premiers Écrans (P0)

C'est la séquence critique par laquelle l'élève apprend, pratique et progresse chaque jour :

```
[1. Accueil] ──> [2. Matières] ──> [3. Chapitres] ──> [4. Détail Chapitre]
                                                               │
┌──────────────────────────────────────────────────────────────┘
│
└──> [5. Lecteur de Leçon] ──> [6. Runner d'Exercices] ──> [7. Corrigé Pédagogique]
```

### Écran 1 : Accueil Élève (`HomeDashboardScreen`)
- **Problèmes actuels :** Empilement lourd de 4 bannières verticales, pas de bouton "Continuer ma leçon", matières reléguées en bas de page.
- **Proposition UX :**
  - En-tête dynamique et motivant (avatar élève, classe, série, streak de régularité).
  - Bloc héroïque "Continuer à apprendre" avec la dernière leçon consultée et barre de progression.
  - Grille des matières au programme ergonomique avec code couleur dynamique.
  - Accès direct au Tuteur IA et au compte à rebours officiel dans un bandeau compact.
- **Fichiers :** `lib/features/home/screens/home_dashboard_screen.dart`.
- **Validation :** Test responsive 320 px, 390 px, 412 px et tablette.

### Écran 2 : Liste des Matières (`SubjectsListScreen`)
- **Problèmes actuels :** Simple liste verticale répétitive, aucun statut de maîtrise visible.
- **Proposition UX :**
  - Tuiles de matières avec dégradé sémantique (`SubjectVisuals`), icône flottante, nombre de chapitres terminés vs totaux.
  - Indicateur de maîtrise par matière (ex : "6/10 chapitres complétés • Maîtrise 60%").
  - Bascule d'affichage Liste / Grille selon la largeur de l'écran.
- **Fichiers :** `lib/features/courses/screens/subjects_list_screen.dart`.

### Écran 3 & 4 : Chapitres & Entrée dans le Chapitre (`ChaptersListScreen`)
- **Problèmes actuels :** Le clic sur un chapitre lance directement `LessonReaderScreen` sans afficher la liste des leçons ni les objectifs.
- **Proposition UX :**
  - Bannière de chapitre avec accroche contextuelle ("À la fin de ce chapitre, tu sauras...").
  - Liste explicite des leçons du chapitre avec leur durée estimée et statut (terminée, en cours, à lire).
  - Distinction nette entre les leçons de cours et les exercices d'entraînement du chapitre.
  - Badge clair sur les chapitres des trimestres futurs avec date de déblocage automatique.
- **Fichiers :** `lib/features/courses/screens/chapters_list_screen.dart`.

### Écran 5 : Lecteur de Leçon Multi-Leçons (`LessonReaderScreen`)
- **Problèmes actuels critiques :** Ne lit que `lessons.first` ! Occulte toutes les leçons suivantes. Pas de table des matières, pas de navigation Suivant/Précédent.
- **Proposition UX :**
  - Sélecteur ou onglets horizontaux de leçons en haut d'écran (Leçon 1, Leçon 2, Leçon 3...).
  - Barre de progression de lecture et estimation du temps restant.
  - Rendu sublime des blocs (`ContentBlock`) via `BlockRendererRegistry`.
  - Bouton flottant d'aide IA contextuelle ("Demander une explication sur ce paragraphe").
  - Pied de page avec bouton vers la leçon suivante et bouton "Démarrer le quiz d'entraînement".
- **Fichiers :** `lib/features/courses/screens/lesson_reader_screen.dart`.

### Écran 6 : Runner d'Exercices Interactif (`ExerciseRunnerScreen`)
- **Problèmes actuels :** Options QCM austères, validation sans étape de réflexion, interface de texte libre brute.
- **Proposition UX :**
  - Carte d'énoncé aérée avec formules mathématiques parfaitement rendues.
  - Options de QCM tactiles à retour haptique léger et distinction claire de la sélection.
  - Tiroir d'indices progressifs (CF-003) pour guider l'élève sans pénalisation brutale.
  - Barre de progression de la série et gain d'XP en direct.
- **Fichiers :** `lib/features/courses/screens/exercise_runner_screen.dart`.

### Écran 7 : Corrigé & Pédagogie de l'Erreur (`CorrectionCard` / `CompletionSummary`)
- **Problèmes actuels :** Simple boîte de dialogue modale de fin de quiz, pas d'explication méthodologique détaillée en cas d'erreur.
- **Proposition UX :**
  - Décomposition bienveillante en cas d'erreur : ce qui a été répondu, pourquoi c'est erroné, la méthode de résolution type, la formule à retenir.
  - Bouton direct : "Demander au Tuteur IA de m'expliquer mon erreur".
  - Écran de bilan de fin de session valorisant le score, les points XP gagnés, les compétences validées et les erreurs à revoir.
- **Fichiers :** `lib/features/courses/screens/exercise_runner_screen.dart`.

---

## 4. Vague 2 — Évaluations, Annales & Tuteur IA (P1)

### 4.1 Scope
- Refonte visuelle de l'accès aux anciens sujets officiels nationaux (`OfficialExamsScreen`) : filtres par année et matière fluides, fiches de corrigés d'examen.
- Épreuves d'établissements (`EstablishmentPapersScreen`) : mise en avant des lycées d'excellence et compositions de référence.
- Arène des examens blancs et olympiades (`MockExamArenaScreen`) : chronomètre élégant non anxiogène, tableau des scores anonymisé.
- Tuteur Numérique IA (`AiTutorChatScreen`) : mode plein écran et mode feuille contextuelle (BottomSheet) partageant la même conversation.

---

## 5. Vague 3 — Onboarding, Auth, Profil & Paramètres (P2)

### 5.1 Scope
- Assistant d'inscription (`OnboardingWizardScreen`) : aération des 7 étapes sur mobile, sélecteur de classe interactif et fluide.
- Écran de connexion (`StudentLoginScreen`) : microcopy bienveillante, retour visuel des erreurs réseau.
- Sélecteur de profil (`ProfileSwitcherScreen`) : affichage de la classe, avatar, streak et dernier cours suivi pour chaque profil.
- Profil élève (`StudentProfileScreen`) : découpage du fichier de 1074 lignes en sous-widgets maintenables, mise en valeur des badges et de la progression.
- Paramètres (`SettingsScreen`) : organisation soignée par onglets thématiques (Compte, Accessibilité, Notifications, Sécurité).

---

## 6. Vague 4 — Communauté, Services & Offline (P3)

### 6.1 Scope
- Forum de classe (`ClassForumScreen`) : filtres par matière, signalement propre pour sécurité des mineurs.
- Boutique de fiches (`BoutiqueShopScreen`) : présentation valorisante des documents tout en maintenant le statut honnête de passerelle en attente.
- Support utilisateur (`SupportTicketsScreen`) : suivi clair des conversations avec l'administration.
- Préparation de l'architecture de cache hors-ligne de blocs de leçons structurés.

---

## 7. Critères d'Acceptation de Chaque Vague

Chaque modification d'écran doit satisfaire 10 critères stricts avant d'être validée :
1. **Compilation sans avertissement ni régression Dart.**
2. **Fonctionnement confirmé sur données réelles Supabase (aucun mock injecté).**
3. **Zéro RenderFlex overflow sur les viewports 320 px, 360 px, 390 px, 412 px et tablette.**
4. **Action primaire immédiatement identifiable par l'élève en moins de 3 secondes.**
5. **Respect strict de la matrice de droits et des abonnements (paywall non contourné).**
6. **Contraste de lecture conforme aux normes WCAG AA.**
7. **Adaptabilité au grossissement de police système (`fontScale`).**
8. **Aucune rupture des routes de navigation existantes.**
9. **Code fractionné en composants de moins de 350 lignes.**
10. **Test visuel réel exécuté et validé.**
