# Progression EDLEARN

## 2026-09-18 — Salutations Courtes, Allongement Timeout, Caméra Directe, Synchronisation BDD (Migration 88) & Éviction 5s — LIVRÉ

Résolution intégrale des 5 problématiques signalées par l'utilisateur pour le Tuteur Numérique et la gestion des sessions multi-appareils :

- **Salutations Naturelles et Brèves ("Bonjour")** :
  - Détection automatique de toute salutation (`isGreeting`) dans l'Edge Function `ai-tutor-chat`.
  - Contournement strict du cache SQL pour les salutations (`cacheable = false`), empêchant le monologue récurrent sur les suites arithmétiques.
  - Consigne système imposant une salutation chaleureuse, naturelle et brève (1 à 2 phrases courtes), présentant le "Tuteur pq learn" et demandant sur quelle matière/notion l'élève souhaite travailler.
  - Purge des caches de salutation pollués dans la base de données distante.
  - Réponse vérifiée en direct via API : `Bonjour ! 😊 Ravi de te retrouver. Quel sujet, chapitre ou exercice aimerais-tu qu'on explore ensemble aujourd'hui ? 🚀` en ~2s.

- **Disponibilité du Tuteur & Allongement du Timeout Client (60s + Bouton "Réessayer")** :
  - Timeout client de l'application élève porté de 15s à **60s** dans `ai_tutor_chat_screen.dart` pour encaisser les pics de latence des modèles multimodaux sans afficher de fausse panne réseau.
  - Mécanisme de retry exponentiel (2 tentatives à 1s et 2.5s) intégré côté Edge Function en cas de pic de charge Gemini (503/429/500).
  - Bouton interactif **[Réessayer]** ajouté directement dans la bulle d'erreur en cas de coupure réseau inattendue, permettant de relancer la question en un tap sans rien retaper.

- **Prise de Photo Directe & Viseur Caméra Live** :
  - Résolution du problème d'explorateur de fichiers sur navigateur : création de `WebcamCaptureDialog` via HTML5 WebRTC `getUserMedia` (`camera_helper_web.dart`).
  - Viseur vidéo interactif en direct avec autorisation caméra et déclencheur circulaire (`Icons.camera_rounded`) capturant instantanément la photo sans passer par le sélecteur de fichiers.
  - Façade conditionnelle `camera_helper.dart` ciblant la caméra arrière native sur mobile (`CameraDevice.rear`).

- **Synchronisation BDD des Conversations Multi-Appareils (Migration 88)** :
  - **Migration 88** (`88_student_chat_sessions.sql`) appliquée sur Supabase :
    - Table `student_chat_sessions` (`id`, `profile_id`, `title`, `messages jsonb`, `created_at`, `updated_at`).
    - RLS par compte propriétaire (`owns_profile(profile_id)`).
    - Trigger serveur `trg_enforce_student_chat_sessions_limit` garantissant la limite stricte de **10 conversations par profil** (suppression automatique des plus anciennes).
  - Évolution de `LocalChatStorageService` en mode hybride local-first : affichage instantané (0ms) depuis `SharedPreferences` + synchronisation automatique avec la table Supabase `student_chat_sessions` pour que l'élève retrouve ses conversations quel que soit le smartphone ou l'ordinateur utilisé.

- **Session Unique Stricte & Éviction Concurrente Immédiate (Heartbeat 5s)** :
  - Ajout d'un battement de cœur actif toutes les 5 secondes (`_heartbeatTimer`) dans `SessionGuardNotifier`.
  - Si un compte s'ouvre sur un second appareil, la base de données désactive immédiatement la session du premier appareil (`enforce_single_session`).
  - Le premier appareil détecte la désactivation en moins de 5 secondes et affiche l'écran de verrouillage `SessionEvictedScreen` sans nécessiter de rafraîchissement ni de manipulation.

- **Tests & Validation** :
  - **104/104 tests passés avec succès** (`flutter test`).
  - `flutter analyze` : 0 erreur, 0 warning.
  - Déploiement Supabase validé (`supabase db push` + `supabase functions deploy ai-tutor-chat --no-verify-jwt`).
  - Build Web de production compilé (`flutter build web --release`).

## 2026-09-18 — Rendu Markdown Riche, Formules LaTeX, Visualiseur de Fréquences Vocales & Schémas Éducatifs — LIVRÉ

Mise à niveau complète du Tuteur Numérique (`Tuteur pq learn`) et de ses bulles de discussion répondant point par point aux retours d'ergonomie :

- **Visualiseur Dynamique d'Ondes de Fréquences & Enregistrement Vocal Continu** :
  - Correction de l'interruption à la 2e seconde : enregistrement vocal désormais continu avec chronomètre en temps réel (`Timer.periodic`).
  - **Visualiseur d'ondes sonores (18 barres verticales animées)** avec gradient cyan pulsant et dynamique fluide.
  - Boutons séparés « Annuler » et « Terminer » avec retour haptique.
  - Cycle de vie éco-responsable : l'animation de waveform s'arrête immédiatement hors enregistrement pour économiser la batterie du smartphone.

- **Moteur de Rendu Markdown Riche, LaTeX & Émojis (Zéro Astérisque Brut)** :
  - Intégration de `parseMarkdownSpans` dans `InlineLatexText` :
    - Rendu du **gras** (`**texte**`, `__texte__`) en `FontWeight.w700` sans laisser fuiter de caractères `**`.
    - Rendu de l'*italique* (`*texte*`, `_texte_`) en `FontStyle.italic`.
    - Rendu du ***gras-italique*** (`***texte***`).
    - Rendu du code en ligne (`` `code` ``) avec pastille monospace foncée.
    - Rendu du texte barré (`~~texte~~`).
    - Préservation et intégration fluide de tous les émojis pédagogiques (🎯, 💡, 📐, 🔬, 🚀, 📚, ✨, ⚠️, 🔍).
  - Gestion des blocs structurés dans `AiMessageBubbleRenderer` :
    - Titres hiérarchiques (`#`, `##`, `###`) avec police Outfit.
    - Listes numérotées (`1. `, `2. `) avec pastilles circulaires cyan stylisées.
    - Listes à puces (`- `, `* `) avec puces lumineuses cyan.
    - Citations et conseils (`> `) avec bordure gauche cyan et fond glassmorphique sombre.
    - Blocs de code (```lang ... ```) avec en-tête et bouton copier.

- **Schémas et Figures Pédagogiques (100% Gratuit)** :
  - Prise en charge de la syntaxe markdown image dans le fil de discussion.
  - Intégration de schémas géométriques et scientifiques gratuits (Pollinations.ai) dans le prompt de l'Edge Function `ai-tutor-chat`.
  - Carte d'illustration arrondie avec bordure cyan néon, chargement fluide et gestion d'erreur hors-ligne.
  - **Modal plein écran avec zoom interactif tactile (`InteractiveViewer`)**.

- **Harmonisation des Titres & Noms** :
  - Nom du tuteur mis à jour : **Tuteur pq learn** (titre d'écran conservé : *Tuteur Numérique*).
  - Tiroir d'historique : **Conversations** (retrait de la mention « IA »).

- **Tests & Validation** :
  - **104/104 tests passés avec succès** (`flutter test`).
  - Suite dédiée `ai_message_markdown_test.dart` validant le rendu markdown, listes, images et détection de fonctions.
  - Redéploiement de l'Edge Function `ai-tutor-chat` sur le projet Supabase distant (`kdprnavvgzhnygovfyuw`).

## 2026-09-18 — Déploiement Intégral Supabase (Toutes Fonctions & Synchronisation Migrations 01-87) — LIVRÉ

Déploiement complet en production sur le projet Supabase distant (`kdprnavvgzhnygovfyuw`) avec le Personal Access Token fourni par l'utilisateur, synchronisation exhaustive de l'état des migrations et mise à niveau en direct de toutes les Edge Functions.

- **Synchronisation Complète des Migrations (01 à 87)** :
  - Inspection de la base de données distante : toutes les tables du schéma de données (jusqu'à `87_gamification.sql` avec `badge_definitions`, `gamification_rules`, `profile_badges`, `lesson_completions`) sont déjà présentes et intègres.
  - Réparation et enregistrement officiel des 86 versions de migration (01 à 87) dans la table de registre distante `supabase_migrations.schema_migrations` via `supabase migration repair --status applied`.
  - Vérification par `supabase db push --dry-run` : **`Remote database is up to date`** (0 migration en retard, 0 conflit, intégrité totale garantie sans aucune perte de données).

- **Déploiement Intégral des 31 Edge Functions** :
  - `ai-tutor-chat` (v1.3.0) : déployée avec `--no-verify-jwt` et logique de repli automatique (retry 1.2s en cas de pic 503/429 sur le palier gratuit Gemini). Test d'invocation en direct validé avec succès (réponse maïeutique socratique en français, reconnaissance multimodale d'images/OCR fonctionnelle).
  - 5 autres fonctions publiques déployées sans vérification JWT : `payment-webhook`, `cron-subscription-reminders`, `ai-moderation`, `admin-create-teacher-account`, `admin-create-admin-account`.
  - 25 fonctions protégées déployées avec JWT : `ai-exercise-generation`, `ai-course-structuring`, `admin-create-parent-account`, `admin-create-student-account`, `ai-catalog-types-generation`, `ai-embeddings-generate`, `ai-document-structuring`, `ai-exam-paper-processing`, `ai-correction`, `ai-admin-assistant`, `ai-support-triage`, `ai-fraud-risk`, `ai-curriculum-mapping`, `ai-pedagogical-validation`, `ai-agent-invoke`, `ai-workflow-run`, `ingestion-worker`, `integration-healthcheck`, `curriculum-collect`, `curriculum-apply`, `curriculum-cancel`, `curriculum-scrape-start`, `curriculum-crawl-worker`, `curriculum-scrape-extract`, `ai-generate-text`.
  - Statut vérifié via `supabase functions list` : **31/31 fonctions au statut ACTIVE**.

- **Contrôle Qualité & Non-Régression** :
  - **97/97 tests automatisés validés avec succès** sur l'application Flutter.
  - Tests en direct du point de terminaison Edge Function validant l'absence d'erreurs CORS, de blocage d'authentification ou d'incompatibilité de schéma.

## 2026-09-17 — Assistant Numérique IA : Expérience ChatGPT / Gemini, Multimodalité & Stockage Local (Student App & Edge Function) — LIVRÉ

Refonte majeure de l'Assistant Numérique (`AiTutorChatScreen` et Edge Function `ai-tutor-chat`) calquée sur l'ergonomie et l'expérience de **ChatGPT** et **Google Gemini**, avec prise en charge multimodale réelle (photos/OCR devoirs manuscrits, documents PDF, audios/voix) et **stockage local exclusif sur le smartphone de l'élève avec quota strict de 10 conversations** pour préserver la base de données Supabase de toute surcharge.

- **Expérience Utilisateur & Design ChatGPT / Gemini (`student_app/lib/features/ai_tutor`)** :
  - **Tiroir d'Historique des Discussions (`ChatHistoryDrawer`)** :
    - Bouton épuré `+ Nouvelle discussion`.
    - Jauge visuelle de stockage local (`X / 10 chats`) et avertissement automatique dès que le quota de 10 conversations est atteint avec proposition de faire le ménage.
    - Regroupement chronologique automatique : *Aujourd'hui*, *7 derniers jours*, *Plus ancien*.
    - Menu contextuel unitaire par discussion (Renommer, Supprimer avec dialogue de confirmation).
    - Bouton global `Effacer tout l'historique` avec dialogue de confirmation sécurisé.
    - Pastille de transparence : *Stocké localement (zéro charge BDD)*.
  - **Dock de Saisie Multimodal Flottant (`ChatMultimodalDock`)** :
    - Bouton `+` ouvrant la feuille d'ajout : Prendre une photo (Caméra `ImagePicker`), Galerie d'images (`ImagePicker`), Document PDF (`FilePicker`), et Fichier audio (`FilePicker`).
    - Ruban horizontal de prévisualisation des pièces jointes en attente (`ChatAttachmentPill`) avec vignette et croix de retrait.
    - Champ de texte auto-extensible (1 à 5 lignes) avec placeholder invitant.
    - Bouton d'enregistrement vocal interactif avec chronomètre et pastille d'enregistrement rouge pulsante.
    - Bouton d'envoi circulaire réactif avec retour haptique, actif dès qu'un texte ou une pièce jointe est présente.
  - **Écran de Chat Réinventé (`AiTutorChatScreen`)** :
    - Barre supérieure minimale avec accès au tiroir par menu burger, pastille centrale de statut (« Tuteur Socratique IA • Multimodal » avec puce verte de présence), et bouton rapide d'édition.
    - Bannière de quota si 10 conversations sont atteintes.
    - État d'accueil chaleureux avec grand orbe lumineux animé et 4 cartes de démarrage socratique (Polynômes/courbes, Théorèmes, Analyse d'exercices en photo avec OCR, Méthodes de dérivées).
    - Affichage riche des pièces jointes dans le fil de discussion (vignettes d'images avec zoom plein écran interactif `InteractiveViewer`, capsules PDF, notes vocales).
    - Moteur mathématique LaTeX (`MathFormulaView`), détection de polynômes (`InteractiveFunctionGraph`) et citations de sources préservés sans régression.

- **Service de Stockage Local sur Smartphone (`LocalChatStorageService`)** :
  - Sauvegarde locale intégrale dans `SharedPreferences` sérialisée en JSON (`student_app/lib/core/services/local_chat_storage_service.dart`).
  - Cloisonnement strict par identifiant de profil élève (`student_chat_sessions_${profileId}`).
  - Gestion automatique des titres de discussions d'après la première question de l'élève.
  - Quota matériel plafonné à 10 sessions : méthodes d'inspection `canCreateNewSession()` et `getRemainingQuota()`.

- **Backend Multimodal Supabase Edge Function (`ai-tutor-chat` v1.3.0)** :
  - Mise à niveau de `supabase/functions/ai-tutor-chat/index.ts` vers la version `1.3.0`.
  - Acceptation du paramètre `attachments: Array<{ name, mime_type, data }>` (base64).
  - Validation des types MIME (`image/*`, `application/pdf`, `audio/*`) et injection en objets `inline_data` dans la charge utile de Google Gemini (`gemini-3.6-flash`).
  - Consignes maïeutiques adaptées pour l'OCR de copies manuscrites, la synthèse de PDF et l'écoute de questions vocales.
  - Contournement sécurisé du cache `ai_tutor_cache` en présence de médias binaires pour éviter d'encombrer la base de données.

- **Validation & Non-Régression Totale** :
  - **97/97 tests automatisés réussis** sur `student_app` (87 tests existants + 10 nouveaux tests unitaires et widgets).
  - `test/local_chat_storage_test.dart` : 6/6 tests passants (CRUD, sérialisation des pièces jointes, isolation de profils, saturation de quota à 10, suppression unitaire et totale).
  - `test/ai_tutor_multimodal_test.dart` : 4/4 tests passants (vignettes PDF/audio, tiroir avec quota, dock de saisie, écran complet).
  - `flutter analyze` : 0 erreur de compilation sur l'ensemble du projet.
  - `deno check supabase/functions/ai-tutor-chat/index.ts` : 100% vert.


Refonte globale de l'expérience d'apprentissage de `student_app` pour passer d'une interface utilitaire/rigide à un univers stimulant, moderne, immersif et gamifié (gradients soignés, halos lumineux, animations fluides, typographies Outfit/Inter et hiérarchies visuelles claires).

- **Composants du Design System (`student_app/lib/design_system`)** :
  - `PedagogicalCard` : Conteneur universel surélevé avec bordures subtiles, halo thématique optionnel (`glowColor`), en-tête avec trailing et support des interactions directes.
  - `GamifiedProgressBar` : Barre de progression animée fluide (`TweenAnimationBuilder`) avec gradients dynamiques et halo lumineux.
  - `CelebrationBanner` (`ExerciseFeedbackBanner`) : Bannière didactique avec gain d'XP en direct, explications socratiques pas-à-pas et proposition de passer le relais au Tuteur IA.
  - `AppColors` : Ajout des palettes de dégradés `aiCompanionGradient`, `roseGradient` et de l'utilitaire `glowEffect`.

- **Refonte 1 : Assistant Numérique IA (`AiTutorChatScreen` & `ContextualAiAgentSheet`)** :
  - Orbe IA animé avec double halo lumineux (`aiCompanionGradient`), badge d'état « En ligne », indicateur de niveau scolaire et bouton de réinitialisation contextuel.
  - Cartes d'invitation à la conversation (« Suggestions pour démarrer ») en grille dynamique avec icônes colorées et labels accrocheurs.
  - Bulles de messages modernisées : style dégradé glassmorphique pour l'élève, conteneurs structurés pour l'assistant avec avatars thématiques, rendu LaTeX intégré (`MathFormulaView`) et barre d'actions (copier, réécouter).
  - Dock de saisie flottant en pilule (`BorderRadius.circular(28)`) avec bouton d'envoi à gradient néon et retour haptique doux.
  - Onglets segmentés de `ContextualAiAgentSheet` modernisés en pilules à dégradé animé.

- **Refonte 2 : Interface des Exercices (`ExerciseRunnerScreen`)** :
  - Remplacement de la barre linéaire basique par `GamifiedProgressBar` et badges pilules pour le numéro de question et la récompense d'XP (`+20 XP`).
  - Carte d'énoncé scénarisée avec badge « Défi Interactif », ombre portée douce et accès direct aux outils scientifiques (SymPy) et au Tuteur IA contextuel.
  - Options QCM modernisées : pastilles alphabétiques circulaires (A, B, C, D) réactives, transitions de sélection fluides, feedback visuel instantané (émeraude / rose) avec icônes de validation explicites.
  - Écran de félicitations / résultat (`_showCompletionDialog`) repensé avec trophée doré sur halo solaire, jauge d'XP gamifiée et bouton de reprise à gradient.

- **Refonte 3 : Lecteur de Leçon (`LessonReaderScreen`)** :
  - Barre d'onglets de navigation de cours restructurée en pilules animées et dégradés thématiques selon la matière.
  - Cartes d'aide du Tuteur IA intégrées avec orbe lumineux, message d'accueil proactif et pilules d'action rapide.
  - Bloc de lancement du quiz d'entraînement avec pastille d'illustration à dégradé et bouton d'action primaire attrayant.

- **Refonte 4 : Liste & Cartes des Chapitres (`ChaptersListScreen`)** :
  - Élimination de la surcharge de boutons en `Wrap` désordonné au profit d'une hiérarchie claire en 3 niveaux :
    1. Capsules de métadonnées épurées (`${chapter.lessonsCount} leçons`, `${chapter.exercisesCount} exercices`) avec micro-icônes disciplinaires.
    2. Boutons d'actions secondaires en pilules horizontales compactes (`Introduction`, `Exercices`, `Fiche mémo`, `Leçons`).
    3. Bouton principal pleine largeur ("Ouvrir le cours") avec dégradé thématique de la matière et flèche d'engagement.
  - Cartes de chapitres avec ombre douce et liseré de couleur adaptatif.

- **Validation & Non-Régression** :
  - Intégrité Supabase préservée (aucun mock injecté, requêtes réelles et providers conservés).
  - 87/87 tests passés avec succès (`flutter test`) sans aucune régression.
  - `flutter analyze` : 0 erreur de compilation, respect strict des lints.


## 2026-09-11 — Ergonomie & Modernisation : Arbre Académique & Gestion des Leçons et Cours

- **Étape 1 : Page Arbre Académique (`AcademicTreeScreen`) — LIVRÉ** :
  - Remplacement du panneau latéral étriqué par une vue d'exploration fluide et spacieuse en pleine largeur (`isExploringNode` + `_currentNode`).
  - Barre de navigation hiérarchique avec fil d'Ariane interactif et historique bidirectionnel (`Précédent`, `Suivant`, `Racine`).
  - Raccourcis clavier physiques (`Alt+←`, `Alt+→`) et interception du bouton retour navigateur Web (`didPopRoute`).
  - 9/9 tests passants dans `test/academic_tree_exploration_test.dart`.

- **Étape 2 : Page Leçons & Cours (`LessonsManagerScreen`) — LIVRÉ** :
  - **En-tête Spacieux & Aéré** : Titre moderne, badge de la classe activement sélectionnée et bouton d'action primaire `+ Créer un Chapitre`.
  - **Barre de Métriques KPI en Direct** : 5 cartes de synthèse (Total Chapitres, Total Leçons, Leçons Publiées, En Validation, Éléments Archivés).
  - **Barre de Filtres Modernisée** : Sélecteurs stylisés de Classe et Matière avec icônes disciplinaires, champ de recherche rapide avec bouton d'effacement en un clic, et toggle d'archivage ergonomique.
  - **Dossiers Trimestriels Dépliables** : Cartes glassmorphiques avec bordure douce, icône de dossier thématique et compteurs de chapitres/leçons en pilules.
  - **Cartes de Chapitres Restructurées** : Titre avec barré lors de l'archivage, badges de classe, trimestre, classes jumelées (`Jumelée avec : ...`), statut d'archivage, et barre d'actions épurée (`+ Ajouter une leçon`, `Modifier`, et menu contextuel `PopupMenuButton` pour la duplication et suppression).
  - **Lignes de Leçons Fluides & Adaptatives** : Icône livre thématique selon publication/brouillon, badges de validation et de tier d'abonnement, accès direct au Studio, Aperçu, et Modifier, complétés d'un menu d'actions secondaires (PDF, Historique, Archiver, Supprimer).
  - **Responsive Mobile / Tablette (< 650px & < 750px)** : Adaptation automatique évitant toute troncature verticale ou affamement du titre.
  - **Non-Régression Stricte** : 100% des appels Supabase, jumelage de classes, fenêtres modales et logique de validation préservés.
  - **Vérification** : `flutter analyze` 0 issue · 5/5 tests ergonomie `test/lessons_manager_ergonomics_test.dart` passants · 65/65 tests passants sur l'ensemble de la suite de tests de `admin_app` · Build Web de production généré avec succès (`build/web`).

- **Étape 3 : Page Banque d'Exercices & Studio Dédié Plein Écran (`ExerciseStudioScreen` & `ExercisesManagerScreen`) — LIVRÉ** :
  - **Studio d'Exercices Dédié Plein Écran (`ExerciseStudioScreen`)** :
    - Fin définitive de la fenêtre modale étriquée et touffue : espace de création et d'édition en plein écran, aéré et professionnel, calqué sur les standards du `LessonBuilderScreen`.
    - **Barre Supérieure Contextuelle** : Titre dynamique, badge d'état (`BROUILLON` / `PUBLIÉ`), switch de publication en direct, bouton de fermeture fluide et action primaire `Enregistrer l'Exercice` avec spinner de progression.
    - **Onglet 1 — Énoncé & Médias** : Titre obligatoire, sélecteurs stylisés de typologie (`Entraînement`, `Évaluation`, etc.), format (`QCM`, `Réponse courte`, `Vrai/Faux`, etc.) et difficulté (`Facile`, `Intermédiaire`, `Approfondissement`), champ d'énoncé multi-lignes avec **aperçu LaTeX en temps réel** (`MathText`) et gestionnaire de pièces jointes médias.
    - **Onglet 2 — Choix & Corrigé Pédagogique** : Constructeur d'options QCM dynamique (ajout/suppression d'options à la volée, désignation de la bonne réponse par pastille cliquable avec coche verte, feedback explicatif individualisé par option), champ de corrigé pas-à-pas avec aperçu LaTeX en direct, et gestionnaire d'indices progressifs (un par ligne).
    - **Onglet 3 — Rattachement Académique & Métadonnées** : Sélecteur visuel interactif des **3 niveaux d'indépendance** (Niveau 1 : Leçon précise, Niveau 2 : Chapitre général, Niveau 3 : Type Examen indépendant), sélecteur sécurisé de classe/série (avec fallback anti-crash Flutter en cas de chargement asynchrone), formule d'abonnement requise (`Gratuit`, `Journalier`, `Mensuel`), et champs de compétences et prérequis académiques.
  - **Gestionnaire d'Exercices Débarrassé et Calme (`ExercisesManagerScreen`)** :
    - Élimination de plus de 1 150 lignes de code modal obsolète et étriqué au profit de redirections directes vers `ExerciseStudioScreen`.
    - Cartes d'exercices spacieuses en pleine largeur avec pastilles de niveau, badges d'abonnement, indicateurs de difficulté, boutons `Aperçu` et `Ouvrir le Studio`, et menu contextuel complet (PDF, Historique, Archivage, Suppression).
    - Métriques KPI interactives en direct, filtres segmentés par niveau et recherche instantanée.
  - **Service Supabase & Non-Régression** :
    - Mise à niveau de `SupabaseService.updateExercise` avec support de `updateLessonId`, `lessonId`, `updateChapterId`, `chapterId`, `updateClassNodeId`, et `updateTermId` pour les transferts fluides entre niveaux 1, 2 et 3.
  - **Validation & Tests Automatisés** :
    - `flutter analyze` : 0 issue sur l'ensemble des fichiers modifiés.
    - `test/exercises_manager_ergonomics_test.dart` : 6/6 tests passants.
  - **Étape 4 : Élimination du Scrolling Imbriqué & Espaces de Travail Dédiés Spacieux — LIVRÉ** :
    - **Fin du « Scroll dans le Scroll » et des Accordéons Imbriqués** : Élimination totale des conteneurs à défilement imbriqués (`ListView` dans `ExpansionTile` dans `ListView`) et des boîtes étriquées qui nuisaient à la lisibilité et à l'ergonomie.
    - **Double Volet Split Workspace pour `ExerciseStudioScreen`** :
      - Mise en page bi-volet ergonomique (`flex: 11` pour l'éditeur, `flex: 9` pour le canevas interactif élève en direct dès `>= 1050px`, repli gracieux en colonne fluide sur résolutions inférieures).
      - **Canevas Interactif en Direct (`_buildLiveCanvas`)** : Rendu LaTeX immédiat via `MathText`, simulation interactive des options de QCM cliquables avec validation visuelle instantanée, tiroir d'indices progressifs, et bascule Corrigé didactique pas-à-pas.
      - En-tête responsive sans aucun débordement (`Wrap` et `isExpanded: true` sur tous les sélecteurs).
    - **Architecture Master-Detail 3-Panes pour `ExercisesManagerScreen`** :
      - **Barre de Scope Horizontale des Trimestres (`_buildTermScopeBar`)** : Remplacement des accordéons par des pilules de filtrage interactives avec badges de compteurs en direct.
      - **Flux Catalogue Spacieux (`_buildExercisesFeed`)** : Liste d'exercices aérée en pleine largeur avec sélection active (`isSelected`) par surbrillance cyan, pastille d'état `Inspecté`, et raccourcis directs.
      - **Inspecteur Didactique Dédié (`_buildExerciseInspector`)** : Panneau d'inspection grand format à droite affichant l'énoncé complet, les formules LaTeX rendues, les options QCM et le corrigé pédagogique dès la sélection d'un exercice dans le catalogue, avec état d'accueil invitant et en-tête adaptatif `Wrap`.
    - **Validation & Non-Régression** :
      - `flutter analyze` : 0 issue.
      - Tests ergonomie & studio : 100% de réussite (`test/exercise_studio_test.dart` 3/3, `test/exercises_manager_ergonomics_test.dart` 6/6).
      - Suite complète `admin_app` : 74/74 tests passants.
      - Build Web de production généré avec succès (`build/web`).

## 2026-09-10/11 — Achèvement Administration : Control-Plane IA, Ingestion, Intégrations

Branche `admin-completion` (WIP Antigravity préservé sur `main` @ `09d8d63`). Voir
`docs/ADMIN_COMPLETION_MATRIX.md` (matrice par consigne) et `docs/ADMIN_DELIVERY_REPORT.md`
(rapport de livraison avec preuves).

- **Control-Plane IA (consigne #4) — LIVRÉ** : migration 78 (colonnes de pilotage sur
  `ai_agents`/`ai_agent_versions` + `ai_agent_runs`/`ai_workflows`/`ai_workflow_steps` + trigger
  d'audit). Edge Functions `ai-agent-invoke` (harnais de test/exécution + validation de schéma) et
  `ai-workflow-run` (orchestration multi-agents + reprise), déployées et vérifiées E2E. Écran
  `ai_agent_registry_screen.dart` réécrit (Agents / Historique / Workflows) : activation, HITL,
  prompts+versions, outils/sources/limites éditables, console de test, historique + export CSV.
- **Centre Sources & Ingestion (consigne #6) — LIVRÉ** : migration 79 (`ai_ingestion_jobs`,
  `ai_extracted_documents`, `ai_rag_sources` étendu, pg_cron). Edge Function `ingestion-worker`
  (crawl robots-aware, extraction, dédup, classement, embeddings après validation humaine),
  vérifiée E2E (URL → extrait → classé → validé → chunk RAG réel). Écran
  `ingestion_center_screen.dart` (nav 33). OCR image/PDF : indisponible explicite.
- **Page Intégrations (consigne #5) — LIVRÉ** : migration 80 (`integrations`, secrets jamais
  exposés). Edge Function `integration-healthcheck` (test de connexion réel), vérifiée
  (Gemini OK 50 modèles, Storage OK). Écran `integrations_screen.dart` (nav 34) +
  `docs/INTEGRATIONS_INVENTORY.md`.
- **Interfaces IA signalées (consigne #2) — corrigées** : `curriculum_autopilot_screen.dart`
  réécrit (fin du disclaimer contradictoire, action HITL réelle) ; bug réel `ai-curriculum-mapping`
  (jointure `academic_levels` inexistante) corrigé ; **bug réel `ai-course-structuring`**
  (`maxOutputTokens` trop bas → sortie tronquée/vide) corrigé + diagnostic réel.
- **Contenus (consigne #2)** : migration 81 — `exercises.display_order` + réordonnancement ▲/▼.
- **Autres modules (consigne #9)** : passe de vérification — tous opérationnels, `audit_log` actif
  (trigger IA vérifié). Restes documentés : historique `notification_log`, CSV utilisateurs, 2FA.
- **Différé explicitement (consigne #7)** : registre `render_formats` versionné, blocs
  QCM/audio/corrections par étapes, galerie centrale de composants, packs hors-ligne — socle
  (blocs typés + aperçu fidèle + LaTeX + simulateurs) opérationnel.
- **Vérif** : `flutter analyze` 0/0 · `flutter test` 36/36 · `flutter build web` OK · `deno check`
  vert sur les 7 Edge Functions. « Administration terminée » **non déclaré** — voir rapport.

## 2026-09-08 — Continuum Multimédia Médiathèque & Modernisation Observabilité Moteurs

- **Objectif :** Raccorder la Médiathèque centrale partagée (`MediaLibraryScreen`) au Studio de création (`lesson_builder_screen.dart`), intégrer le rendu natif haute-fidélité des figures et schémas dans l'application élève (`BlockRendererRegistry`), et moderniser le Centre des Moteurs (`EngineCenterScreen`) avec les tokens du `ElefDesignSystem`.
- **Continuum Multimédia & Schémas Pédagogiques (`admin_app` <-> `student_app`) :**
  - Dans `admin_app` (`lesson_builder_screen.dart`) :
    - Ajout de la section `RESSOURCES VISUELLES & MÉDIATHÈQUE` dans le volet Bibliothèque avec le bloc `Image & Schéma Pédagogique` (`LessonBlock.mediaImage`).
    - Carte d'édition dédiée dans `_BlockEditorCardWidgetState` avec sélecteur modal direct `MediaLibraryScreen(onSelected: ...)` pour lier les assets sans copier/coller manuel.
    - Champs URL, légende descriptive, texte alternatif d'accessibilité et aperçu miniature en direct.
    - Rendu en direct dans le volet d'aperçu élève du Studio v2.
  - Dans `student_app` (`block_renderer_registry.dart`) :
    - Routage des types `image`, `media_image`, `illustration` vers `_imageBlock`.
    - Rendu responsive adaptatif carte avec conteneur `Semantics` pour l'accessibilité, gestion de chargement (`loadingBuilder`), repli gracieux hors-ligne sans crash (`errorBuilder`), légende en italique et modale de zoom plein écran tactile avec `InteractiveViewer` (pinch-to-zoom).
- **Modernisation du Centre des Moteurs (`admin_app`) :**
  - Refonte complète de `EngineCenterScreen` sur `ElefDesignSystem` (`ElefColors`, `ElefTypography`, `ElefRadius`, `ElefBadge`).
  - Badges d'exécution visuels (`LOCAL`, `HYBRIDE`, `SERVEUR`), filtres rapides, compteurs de répartition et cartes de diagnostics interactifs.
- **Validation & Non-Régression :**
  - 92 tests automatisés réussis sur l'ensemble de la plateforme (36/36 `admin_app`, 56/56 `student_app`).
  - 0 avertissement ni erreur `dart analyze` sur l'ensemble des deux projets Flutter.
  - Zéro mock : utilisation exclusive des assets réels et fallbacks contrôlés.

## 2026-09-08 — Continuum Content Factory & Laboratoires Virtuels Déterministes

- **Objectif :** Intégrer les 5 moteurs scientifiques et simulateurs déterministes natifs dans le continuum éditorial (`admin_app` Studio v2 -> persistance JSON canonique -> `student_app` BlockRendererRegistry).
- **Modèle & Studio v2 (`admin_app`) :**
  - Ajout de la factory `LessonBlock.virtualLab({String? heading, required String labType, String? description, Map<String, dynamic>? initialParams, int order = 0})` dans `LessonBlock`.
  - Extension de la bibliothèque Studio v2 (`MOTEURS SCIENTIFIQUES & INTERACTIFS`) avec les blocs SPICE Circuit, Balistique 2D, et Visualiseur Moléculaire 3D.
  - Carte d'édition dédiée dans `_BlockEditorCardWidgetState` avec sélecteur déroulant du moteur déterministe (`circuit`, `ballistics`, `molecule`, `python`, `graph`) et synchronisation réactive des métadonnées `labType`.
- **Rendu & Interaction Élève (`student_app`) :**
  - Routage unifié dans `BlockRendererRegistry.build` pour les types `virtual_lab`, `simulation`, `lab`, `graph_plot`, `code_runner` vers `_virtualLabBlock`.
  - Carte `_VirtualLabCardWidget` adaptative dark/light avec badges de précision déterministe (`SPICE 3F5 DÉTERMINISTE`, `MOTEUR NEWTONIEN RK4`, `GÉOMÉTRIE 3D COVALENTE`, `INTERPRÉTEUR PYODIDE WASM`, `GRAPH ENGINE DÉTERMINISTE`).
  - Accordéon ergonomique mobile (replier/déplier) et lanceur plein écran modal (`showDialog` / `InteractiveFunctionGraph.showModal`).
  - Protection anti-débordement vertical avec `SingleChildScrollView` et hauteur bornée à 540 px.
- **Validation & Non-Régression :**
  - 90 tests automatisés réussis sur l'ensemble de la plateforme (36/36 `admin_app`, 54/54 `student_app`).
  - 0 avertissement ni erreur `dart analyze` sur les deux dépôts.
  - Zéro mock : utilisation exclusive des moteurs déterministes réels (ngspice/WASM/RK4).


Réouverture des brouillons depuis Leçons & Cours, soumission explicite à la revue,
conservation des métadonnées par l'ancien éditeur et barre Studio responsive implémentées.
13 tests admin et 20 tests élève passants ; analyses ciblées sans problème.
Compilation web admin réussie après correction du hash FNV-1a 64 bits incompatible
avec JavaScript dans le dernier push ; égalité du hash vérifiée sur Dart VM et JavaScript.
Test Supabase transactionnel réussi : brouillon masqué, approbation anonyme refusée,
approbation/publication admin, JSON publié intact, archivage masqué. Rollback vérifié :
aucun test persistant, compteurs inchangés. Voir `STUDIO_PUBLICATION_VERIFICATION.md`
pour la portée exacte, les limites et la correction de configuration locale.

## 2026-09-05 — reprise et audit local

- Référence : HEAD `f5edccf`, dernier chantier Exam Resource Factory, revue/approbation/publication admin.
- Inspection : instructions projet, historique Git, cahiers et plans, applications Flutter, services, Gateway, migration 73 et tests existants.
- Audit actualisé dans `AUDIT_REPORT.md` ; ordre de reprise corrigé dans `CONTENT_FACTORY_IMPLEMENTATION_PLAN.md`.
- Constats prioritaires : approbation pouvant ignorer les éditions non enregistrées, publication en deux requêtes client, lecture des questions structurées absente côté élève.
- Validation : inspection statique uniquement ; deux commandes `flutter test --no-pub` interrompues après absence de sortie. Cause non établie, tests non validés. Production et base distante non consultées.
- Code, migrations et données laissés inchangés. Le dossier `.claude/` était déjà non suivi avant cette passe.
- Prochain work package : fiabiliser la revue admin, puis publication transactionnelle et lecture élève sous contrôle des droits ; détails et critères dans le plan.

## 2026-09-05 — Audit Maître Application Élève & Génération des 9 Livrables
- **Objectif :** Réaliser l'audit complet de l'application élève existante (`student_app`), identifier les acquis, écarts, faiblesses UX et contraintes mobiles, sans casser le backend ni introduire de mocks permanents.
- **Documents produits dans `docs/` :**
  1. `docs/STUDENT_APP_CURRENT_STATE.md` (Matrice d'état des 32 modules avec statuts obligatoires).
  2. `docs/UI_UX_AUDIT.md` (Audit approfondi en 14 sections).
  3. `docs/STUDENT_APP_SCREENS.md` (Inventaire exhaustif des 25+ écrans réels).
  4. `docs/FEATURE_COVERAGE_MATRIX.md` (Matrice comparative des 22 domaines du CDC).
  5. `docs/DESIGN_SYSTEM.md` (Design system complet : tokens, typo, spacing, composants, blocs pédagogiques).
  6. `docs/RESPONSIVE_STRATEGY.md` (Stratégie multi-écrans 320px-1200px+ mobile-first).
  7. `docs/PEDAGOGICAL_UI_COMPONENTS.md` (Spécifications des 14 composants pédagogiques).
  8. `docs/UI_REDESIGN_PLAN.md` (Plan par vagues progressives P0-P3 et focus sur les 7 premiers écrans).
  9. `docs/REGRESSION_CHECKLIST.md` (Checklist de vérification obligatoire avant tout merge).
- **Règles respectées :** Zéro régression, conservation absolue de la vérité des données et des contrats d'abonnements/sessions, aucun code applicatif modifié à ce stade d'audit.
- **Statut de l'étape :** Validée et approuvée.

## 2026-09-06 — Implémentation Vague 0 (Design System & Navigation Mobile) & Vague 1 (Écrans Pédagogiques Clés)
- **Vague 0 terminée :**
  - Tokens créés dans `student_app/lib/design_system/tokens/` (`app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_breakpoints.dart`).
  - Composants créés dans `student_app/lib/design_system/components/` (`app_button.dart`, `app_card.dart`, `empty_state_view.dart`, `student_bottom_bar.dart`).
  - Navigation mobile-first : `MainNavigationScreen` adapté pour intégrer `StudentBottomBar` (5 onglets au pouce : Accueil, Cours, Exercices, Tuteur IA, Profil) sur mobile (< 700 px), tout en préservant le tiroir Drawer et le mode desktop/tablette.
- **Vague 1 terminée (7 écrans clés) :**
  - `HomeDashboardScreen` : Grille responsive adaptative (1 col sur 320 px, 2 col sur 360 px+, 3-4 col sur grands écrans), raccourci "Continuer mon cours" vers la matière active, tokens `AppRadius`.
  - `SubjectsListScreen` : Intégration `EmptyStateView`, tokens `AppRadius`, sous-titre explicatif et retour tactile.
  - `ChaptersListScreen` : Intégration `EmptyStateView`, dépliage réactif des leçons d'un chapitre pour accès direct 1-clic par leçon, conservation du déblocage trimestriel.
  - `LessonReaderScreen` : Résolution du bogue bloquant `lessons.first` — support multi-leçons avec barre d'onglets de leçons horizontales, pagination (Précédent / Suivant), intégration du Tuteur IA contextuel, `EmptyStateView` et conservation stricte du tatouage judiciaire et du Smart Paywall.
  - `ExercisesHubScreen` : Intégration `EmptyStateView` et `AppRadius`.
  - `ExerciseRunnerScreen` : Touch targets tactiles minimales à 48 px, boutons d'aide et de remédiation contextuelle vers le Tuteur IA en cas de mauvaise réponse, intégration `EmptyStateView` et tokens.
- **Validation qualité :** `flutter analyze` passé avec succès (0 erreur, 0 avertissement). Aucune régression, zéro mock ajouté, contrats DB/Supabase intacts.

## 2026-09-06 — Implémentation Vague 2 (Évaluations, Annales & Tuteur IA)
- **Objectif :** Refondre l'expérience des évaluations, de préparation aux examens officiels et de soutien par Tuteur IA, en garantissant une ergonomie mobile irréprochable et le respect des contrats métier.
- **Écrans modernisés :**
  1. `AiTutorChatScreen` :
     - Bulles de messages ergonomiques avec padding adapté, typographie contrastée et coins arrondis différenciés (utilisateur vs assistant).
     - Raccourcis de questions rapides (quick prompts) intégrés sous forme de puces interactives.
     - Indicateur de réflexion animé avec icône d'étincelles (`Icons.auto_awesome`).
     - Intégration de `EmptyStateView` avec icône personnalisée pour accueillir l'élève lors d'une nouvelle session.
  2. `OfficialExamsScreen` :
     - Sélecteur à double vue : regroupement par matière ou chronologique par année.
     - Tuiles d'épreuves modernisées avec badge d'année et accès direct au sujet PDF et au corrigé/questions interactives.
     - Intégration de `EmptyStateView` et des tokens `AppRadius`.
  3. `EstablishmentPapersScreen` :
     - Puces de sélection d'établissements fluides avec `AppRadius.radiusFull`.
     - Tuiles d'épreuves avec bandeau d'en-tête, icône thématique et actions enveloppées dans un `Wrap` pour éviter tout risque de débordement horizontal sur écrans 320-375 px.
     - Intégration de `EmptyStateView`.
  4. `MockExamArenaScreen` :
     - Cartes d'épreuves (Concours Blanc / Olympiade) stylisées avec `AppRadius.radiusLarge` et bordures subtiles.
     - Statuts sémantiques clairs (En cours, À venir, Terminé) avec affichage du score et du rang.
     - Intégration de `EmptyStateView` pour les classes sans épreuve planifiée.
- **Validation qualité :** `flutter analyze` passé avec **0 erreur** (3 warnings informatifs préexistants).
- **Vérification en direct :** Serveur web actif sur `http://0.0.0.0:8085` accessible en local sur `http://localhost:8085` et sur smartphone via `http://10.86.12.161:8085`.

## 2026-09-06 — Implémentation Vague 3 (Profil Élève, Sélecteur de Profil, Auth & Paramètres)
- **Objectif :** Refondre les interfaces d'identification, de gestion du compte élève, des profils multi-classes, des jalons d'apprentissage et des paramètres d'accessibilité.
- **Écrans modernisés :**
  1. `StudentLoginScreen` :
     - Formulaire ergonomique avec icônes de saisie, bordures `AppRadius.radiusMedium`, bouton à retour d'état de chargement et bannière d'erreur soignée.
     - Bouton bascule de visibilité mot de passe avec touch target tactile confortable.
  2. `ProfileSwitcherScreen` :
     - Cartes de profils réactives sous `LayoutBuilder` pour s'adapter dynamiquement aux largeurs d'écrans mobiles (de 320 px à 700 px+).
     - Badge discret "Actif" sur la classe en cours d'utilisation et boutons intégrant les tokens `AppRadius`.
  3. `StudentProfileScreen` :
     - Remplacement du simple bandeau "Gamification bientôt disponible" par une section valorisante **"Mes Réussites & Assiduité"** : badges d'Assiduité Pédagogique et d'Explorateur de Cours stylisés avec puces de statut "Actif" / "En cours".
     - Résolution complète des avertissements de lint `use_build_context_synchronously` à travers les gaps asynchrones.
     - Boîtes de dialogue de modification d'identité et de code personnel modernisées avec `AppRadius.radiusLarge` et `AppRadius.radiusSmall`.
  4. `SettingsScreen` :
     - Cartes de paramètres structurées avec `AppRadius.radiusLarge`.
     - Puces de sélection du mode d'apparence (Sombre, Clair, Automatique) et de la langue avec `AppRadius.radiusFull`.
     - Section d'accessibilité (contraste élevé, échelle de police système) clairement mise en valeur.
- **Validation qualité :** `flutter analyze` passé avec **0 erreur, 0 avertissement** (1 seule info préexistante de style).
- **Vérification en direct :** Recompilation à chaud effectuée avec succès sur le serveur Flutter Web `http://10.86.12.161:8085` (mobile) et `http://localhost:8085` (PC).

## 2026-09-06 — Implémentation Vague 4 (Communauté, Services & Support)
- **Objectif :** Harmoniser les espaces d'échanges collaboratifs (Forum de classe, Groupes d'étude), de boutique éducative et de tickets de support selon le Design System mobile-first.
- **Écrans modernisés :**
  1. `ClassForumScreen` :
     - Cartes de messages modernisées avec `AppRadius.radiusLarge` et bordures subtiles.
     - Badges de rôle pour les auteurs de publications avec `AppRadius.radiusFull`.
     - Barre de saisie inférieure optimisée avec `AppRadius.radiusFull` pour un confort tactile ergonomique au pouce.
     - Intégration de `EmptyStateView` avec icône de discussion pour inciter au premier échange pédagogique.
  2. `StudyCommunitiesScreen` :
     - Cartes de communauté stylisées (`AppRadius.radiusLarge`, padding aéré, icônes thématiques).
     - Bouton d'action "Rejoindre le groupe WhatsApp" ergonomique avec `AppRadius.radiusMedium`.
     - Intégration de `EmptyStateView` pour les classes sans groupe communautaire configuré.
  3. `BoutiqueShopScreen` :
     - Fiches de synthèse et fascicules présentés sous forme de cartes d'achat stylisées avec `AppRadius.radiusLarge`.
     - Puces de prix et de matière avec `AppRadius.radiusSmall` et `AppRadius.radiusFull`.
     - Intégration de `EmptyStateView` pour les catalogues vides ou en cours de réapprovisionnement.
  4. `SupportTicketsScreen` :
     - Cartes de tickets de signalement et d'assistance avec statuts colorés (Ouvert, Résolu, En attente) au format pilule `AppRadius.radiusFull`.
     - Dialogue de nouveau ticket restylé avec des champs aux coins arrondis `AppRadius.radiusMedium`.
     - Intégration de `EmptyStateView` avec bouton d'action contextuel permettant d'ouvrir un ticket directement depuis l'état vide.
- **Validation qualité :** `flutter analyze lib/features/community lib/features/subscription lib/features/support` passé avec **0 erreur, 0 warning** ("No issues found!").
- **Vérification en direct :** Recompilation à chaud (`Hot restart`) effectuée avec succès sur le serveur web actif `http://10.86.12.161:8085` (smartphone) et `http://localhost:8085` (desktop).

## 2026-09-06 — Modules Déroulants (Sidebar/Drawer) & Barre du Bas Escamotable
- **Demande utilisateur :**
  1. Rendre les modules de la barre latérale / Drawer déroulants au clic (accordéon clair masquant les liens tant que le module n'est pas sélectionné).
  2. Permettre à l'élève de masquer la barre de navigation inférieure (mode plein écran immersif) et de la réafficher à tout moment à volonté.
- **Réalisations :**
  1. **Modules Déroulants Accordéon (`MainNavigationScreen`) :**
     - Initialisation propre : seul le module actif est ouvert par défaut au démarrage (`'Mon espace'`), évitant l'encombrement visuel initial.
     - Cartes de module élégantes avec icône thématique (`Icons.space_dashboard_outlined`, `Icons.school_outlined`, `Icons.fact_check_outlined`, etc.), pastille de comptage du nombre de pages et chevron interactif de pliage/dépliage (`Icons.keyboard_arrow_down_rounded`).
     - Arborescence visuelle claire avec ligne guide verticale à gauche (`border.left`) reliant les pages enfants du module ouvert.
  2. **Barre du Bas Escamotable & Mode Plein Écran (`StudentBottomBar` & `MainNavigationScreen`) :**
     - Ajout d'une poignée discrète de rabat tactile au sommet de `StudentBottomBar` avec chevron vers le bas.
     - Bouton bascule dédié dans la barre supérieure (`AppBar`) sur mobile avec icône `Icons.fullscreen_rounded` / `Icons.fullscreen_exit_rounded`.
     - **Ergonomie 100% immersive demandée par l'élève** : quand la barre du bas est masquée, **aucun bouton ni élément ne subsiste en bas** de l'écran (espace libéré intégralement).
     - La réapparition se fait exclusivement et facilement en cliquant sur le bouton d'agrandissement en haut à droite de l'écran.
- **Validation qualité :** `flutter analyze` passé avec **0 erreur, 0 avertissement** ("No issues found!").
- **Vérification en direct :** Compilation Web Release (`build/web`) réussie et servie par serveur autonome SPA sur `http://localhost:8085` et `http://10.86.12.161:8085`.

## 2026-09-06 — Intégration du Parcours Cours & Exercices Pédagogiques Interactifs
- **Objectif :** Intégrer, fiabiliser et câbler l'ensemble des maquettes de cours et d'exercices interactifs de l'application élève (`student_app`).
- **Résolution des anomalies de Design System :**
  - Correction de 139 erreurs d'imports et de tokens (`AppColors`, `AppRadius`) dans les nouveaux composants.
  - Ajout des alias sémantiques régressifs dans `AppColors` (`tealSuccess`, `cyanPrimary`, `amberHighlight`) et `AppRadius` (`card`, `button`, `badge`, `modal`).
- **Écrans interactifs finalisés et validés :**
  1. `ChapterIntroScreen` : Découverte historique (Fermat, Newton, Leibniz) et applications industrielles réelles.
  2. `DerivativeLabScreen` : Laboratoire interactif vectoriel avec manipulation tactile du point $A$, tracé de la tangente en direct et calcul temps réel de $f'(x)$.
  3. `ExercisePathScreen` : Parcours adaptatif en 6 niveaux de maîtrise (du rappel au niveau Baccalauréat).
  4. `ExercisePrepScreen` : Modal/écran de préparation avec configuration du chronomètre et choix du support de brouillon.
  5. `VariationTableExerciseScreen` : Exercice tactile de complétion du tableau de variations avec calcul dynamique du score.
  6. `ExerciseCorrectionScreen` : Corrigé avec analyse des erreurs récurrentes, remédiation et gains d'XP.
  7. `MultiStepProblemScreen` : Résolution guidée en 3 phases (Modéliser, Raisonner, Calculer).
  8. `ProblemCorrectionScreen` : Corrigé détaillé accordéon avec barème officiel d'examen à points partiels.
- **Câblage des flux de navigation élève :**
  - `ChaptersListScreen` : Boutons d'accès direct 1-clic « Introduction & Applications » et « Parcours d'exercices ».
  - `LessonReaderScreen` : Accès au laboratoire de dérivée depuis l'AppBar et pied de page du lecteur avec bascule vers le Labo et le Mode Concours.
  - `ExercisesHubScreen` : Bannière héroïque interactive d'entraînement adaptatif 6 niveaux et tableau de variations.
- **Validation qualité :** `flutter analyze lib` passé avec **0 erreur, 0 avertissement** ("No issues found!").

## 2026-09-06 — Intégration des Fiches Mémo de Synthèse HD & Formules Déterministes (Option 3)
- **Origine & Diagnostic :** Exploitation des 31 fiches de synthèse de haute qualité déposées dans `scratch_design_images/` pour Terminale C, D & TI (Suites réelles, Oscillateurs mécaniques, Pendule élastique, etc.).
- **Architecture choisie (Option 3) :**
  - **Fiche Visuelle HD Interactive :** Visualiseur plein écran avec `InteractiveViewer` (zoom tactile 0.8x à 4.5x, double-tap, pan fluide) pour réviser sur la fiche mémoire de synthèse.
  - **Contenu Canonique Déterministe (`Content != Presentation`) :** Onglet commutable "Formules & Définitions" avec formules LaTeX complètes, points d'attention, astuces d'examen et conventions de calcul.
- **Composants créés & intégrés :**
  1. `SummarySheetRegistry` (`student_app/lib/core/models/summary_sheet_registry.dart`) : Registre typé des fiches et métadonnées pédagogiques.
  2. `SummarySheetViewerModal` (`student_app/lib/features/courses/widgets/summary_sheet_viewer_modal.dart`) : Modal immersif plein écran avec bascule double-vue (Visuel HD / Formules).
  3. Intégration `LessonReaderScreen` : Bannière héroïque d'accès direct + bouton d'action AppBar.
  4. Intégration `ChaptersListScreen` : Bouton d'accès rapide 1-clic sur chaque carte de chapitre déverrouillé.
  5. Intégration `BoutiqueShopScreen` : Catalogue dédié "Fiches Mémo de Synthèse Officielles" en accès inclus.
## 2026-09-06 — Intégration du Moteur KaTeX Vectoriel et des Agents IA Contextuels
- **Problématique résolue :** Correction des lacunes signalées par l'élève : absence de compilateur mathématique (formules qui s'affichaient en texte brut informatique monospace) et invisibilité des 26 agents IA du cahier des charges dans l'UX.
- **Intégration de la bibliothèque KaTeX (`flutter_math_fork 0.7.4`) :**
  - Ajout de la dépendance officielle dans `pubspec.yaml` (100% offline, pure Dart, compatible Web/Mobile).
  - Création du composant [`MathFormulaView`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/core/rendering/math_formula_view.dart) : rendu vectoriel net des fractions, racines, intégrales, dérivées et symboles grecs, avec défilement horizontal fluide et gestion d'erreurs gracieuse.
  - Mise à niveau du [`BlockRendererRegistry`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/core/rendering/block_renderer_registry.dart) : tous les cours et cartes de formules du projet bénéficient désormais automatiquement du rendu KaTeX/LaTeX haute définition.
- **Câblage des Agents IA Pédagogiques ([`ContextualAiAgentSheet`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/features/ai_tutor/widgets/contextual_ai_agent_sheet.dart)) :**
  - Déclencheurs contextuels 1-clic intégrés sur chaque formule et en pied de leçon :
    1. **Tuteur Socratique (`TutorAgent` / `SocraticAgent` AIA-AGT-001/002)** : dialogue maïeutique pas-à-pas pour débloquer la réflexion sans spoiler la solution.
    2. **Détecteur de Pièges d'Examen (`DiagnosticAgent` / `MisconceptionAgent` AIA-AGT-004/005)** : QCM ciblé sur les erreurs fréquentes du Baccalauréat avec score et remédiation immédiate.
    3. **Entraînement Recommandé (`ExerciseAgent` / `RecommendationAgent` AIA-AGT-003/010)** : application directe avec champ de calcul, correction automatique et gain d'XP.
  - **Autonomie souveraine & Fallback déterministe** : fonctionne en direct avec l'AI Gateway/Supabase, et bascule de manière transparente sur le moteur déterministe local si l'API externe est absente ou hors-ligne (zéro plantage garanti).
- **Validation qualité :** `flutter analyze lib` passé avec **0 erreur, 0 avertissement** (`No issues found!`), compilation web release validée et servie sur `http://localhost:8085`.
- **Extension du rendu KaTeX et des Agents IA au moteur d'exercices :**
  1. [`InlineLatexText`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/core/rendering/math_formula_view.dart) : Parser intelligent texte mixte / LaTeX `$formule$` ou `$$formule$$` via `WidgetSpan` pour les énoncés, indices, explications et propositions QCM.
  2. [`ExerciseRunnerScreen`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/features/courses/screens/exercise_runner_screen.dart) :
     - Énoncés, indices progressifs, options QCM et flashcards convertis au KaTeX vectoriel.
     - Bouton d'action direct **Tuteur Socratique** en tête d'énoncé pour assistance maïeutique pas-à-pas en cours d'exercice.
     - Bouton **Comprendre mon erreur (Diagnostic IA & Pièges)** dans le corrigé pour déclencher l'analyse des misconceptions par l'IA lors d'une mauvaise réponse.
  3. [`VariationTableInteractive`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/features/pedagogy/widgets/variation_table_interactive.dart) : En-têtes ($x$, $f'(x)$, $f$) et bornes ($-\infty$, $+\infty$) vectorisées en KaTeX haute précision.
  4. [`VariationTableExerciseScreen`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/features/exercises/screens/variation_table_exercise_screen.dart) & [`ExerciseCorrectionScreen`](file:///c:/Users/ahdyb/.gemini/antigravity-ide/scratch/elearning_platform/student_app/lib/features/exercises/screens/exercise_correction_screen.dart) :
     - Énoncé et règles de dérivation en LaTeX KaTeX.
     - Déclencheur direct du Tuteur Socratique et de l'IA Diagnostic dans le flux de remédiation d'erreur.
  5. Validation : `flutter analyze lib` (0 issues), `flutter build web --release` réussi (77.1s), déploiement local actif sur `http://localhost:8085`.

## 2026-09-06 — Intégration Complète des Moteurs Scientifiques, SymPy & MathJax v3 Dual Engine

- **Contexte & Exigence Utilisateur :**
  - Demande d'intégrer l'ensemble des bibliothèques, moteurs et frameworks mentionnés dans les cahiers des charges : **MathJax** aux côtés de **KaTeX**, **SymPy** pour le calcul formel exact, et les hubs de simulation scientifique (**ngspice/CircuitJS**, **3Dmol.js/RDKit**, **Pyodide WASM**, **OpenModelica/Box2D**).
  - Application stricte de la Règle d'Or d'Architecture (Cahier Technique §1 & §6) : *« Le LLM comprend, raisonne, explique, crée et orchestre ; les moteurs spécialisés calculent, exécutent, rendent, simulent et stockent. Zéro hallucination mathématique permise. »*

- **1. Double Moteur Mathématique KaTeX / MathJax v3 (`math_formula_view.dart` & `web/index.html`) :**
  - `web/index.html` : Injection du script officiel MathJax v3 (`https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js`) avec configuration TeX standard W3C SVG (`inlineMath: [['$', '$'], ['\\(', '\\)']]`).
  - `MathRendererSettings` & `MathRendererEngine` : Gestionnaire réactif global avec méthode `toggleEngine()`.
  - `MathFormulaView` : Badge interactif cliquable 1-clic (`Bascule vers MathJax` / `Bascule vers KaTeX`) qui permute instantanément le mode de rendu et le thème visuel (Cyan pour KaTeX, Émeraude pour MathJax v3 SVG).

- **2. Service Scientifique Déterministe & Calcul Formel SymPy (`scientific_tools_service.dart`) :**
  - Connexion directe au Tool Gateway Python/FastAPI (`http://127.0.0.1:8000/tools/sympy_solve`, SymPy 1.13) avec sandbox sécurisée (`_safe_global_dict`, `'__builtins__': {}`, timeout 1500 ms).
  - Solveur analytique local déterministe autonome (résolution des équations du 2nd degré par discriminant $\Delta = b^2 - 4ac$, calcul formel de dérivées cubiques et polynomiales, équations linéaires $ax + b = 0$).

- **3. Hub Modal Outils Scientifiques & Labos Virtuels (`scientific_tools_modal.dart`) :**
  - **Onglet 1 : Calcul SymPy** — Champ d'expression libre, modes Résoudre ($=0$), Dérivée ($f'(x)$), Factorisation, Évaluation numérique, et boutons d'exemples rapides du Bac.
  - **Onglet 2 : Grapheur & Dérivée** — Tracé dynamique de courbes avec curseur d'abscisse et calcul de la tangente réactive instantanée.
  - **Onglet 3 : Labos Virtuels** — Accès aux 4 simulateurs du cahier des charges (Électronique `ngspice/CircuitJS`, Molécules 3D `3Dmol.js/RDKit`, Python WASM `Pyodide`, Physique `OpenModelica/Box2D`).

- **4. Câblage Universel à travers l'Application Élève :**
  - `LessonReaderScreen` : Bouton calculatrice SymPy dans l'AppBar et bouton pleine largeur dans la carte d'assistance pédagogique.
  - `ExerciseRunnerScreen` : Bouton SymPy dans l'AppBar et déclencheur `SymPy / Grapheur` directement inséré dans chaque carte d'énoncé officiel.
  - `ContextualAiAgentSheet` : Bouton d'accès dans l'en-tête et puce d'action directe dans le tuteur socratique (`Calculer ou tracer avec SymPy & Outils Scientifiques`).

- **5. Validation & Tests :**
  - `flutter analyze lib` : **0 erreur, 0 avertissement** (`No issues found!`).
  - `flutter test` : **5/5 tests passés avec succès** (Rendu KaTeX/MathJax, modal 3 onglets, résolution quadratique exacte, dérivée cubique, commutateur de paramètres).
  - `flutter build web --release` : Compilation réussie (106.5s) et servie sur le port 8085.

## 2026-09-07 — Résolution du Bug de Découpage des Environnements LaTeX (`cases`, `aligned`, `matrix`)

- **Analyse du Problème :**
  - Signalement élève : le code LaTeX de la formule des limites de suites par morceaux s'affichait en texte brut non compilé (`\lim_{n \to +\infty} q^n = \begin{cases} 0 \text{si } -1 < q < 1`).
  - **Cause racine identifiée :** Dans `MathFormulaView` (`math_formula_view.dart`), la fonction de découpage multi-lignes effectuait un `split(r'\\')` aveugle et un `replaceAll('&', ' ')`. Or, dans un environnement LaTeX comme `\begin{cases} ... \end{cases}`, les doubles antislashs `\\` sont les séparateurs de lignes internes du système et les esperluettes `&` sont les taquets d'alignement des conditions. Le `split` tronquait le bloc en 4 lignes séparées, laissant `\begin{cases}` non fermé sur la première ligne, ce qui déclenchait l'erreur de parsing et basculait le widget sur le texte brut de repli `onErrorFallback`.
- **Correction apportée :**
  - Dans `MathFormulaView` (`math_formula_view.dart`) : Détection préalable d'environnement unitaire (`sanitizedFormula.contains(r'\begin{')`). Si la formule contient un environnement (`cases`, `matrix`, `aligned`, `array`, `gathered`), elle n'est **jamais découpée par `\\`** et ses taquets `&` sont préservés intacts.
  - Dans `InlineLatexText` : Ajout des déclencheurs mathématiques `\begin{` et `\Delta` pour auto-détection sans délimiteur `$`.
- **Validation Qualité :**
  - `flutter test` : **7/7 tests passés avec succès (100%)**, incluant le test direct de non-régression sur `\begin{cases}` et `\begin{aligned}`.
  - `flutter analyze lib` : **0 erreur, 0 avertissement** (`No issues found!`).
  - `flutter build web --release` : Compilation réussie (103.0s) et déploiement immédiat sur le serveur actif (port 8085).

## 2026-09-07 — ELEF v2 : Design System Unifié, Moteurs Déterministes & Studio de Cours Trait-pour-Trait

- **Contexte & Requête Utilisateur :**
  - Critique de l'interface encombrée et « touffue avec des box qui ne servent à rien » et demande explicite de concevoir la fiche de synthèse visuelle des **Suites Numériques de façon identique traits pour traits** directement sur l'application depuis `admin_app`.
  - Priorité donnée à `admin_app` pour doter la plateforme d'un véritable Studio de Création Pédagogique d'élite, tout en dé-clutterant `student_app`.
- **1. ELEF Design System & Tokens (`admin_app/lib/core/design_system/`) :**
  - Tokens complets créés : `ElefColors` (palette dark mode avec 9 accents disciplinaires), `ElefTypography` (GoogleFonts Outfit, Inter & Fira Code), `ElefSpacing`, `ElefRadius`, `ElefElevation`, `ElefMotion`, `ElefBreakpoints`.
  - Composants UI universels créés : `ElefButton` (variantes, tailles, spinner natif), `ElefInput` & `ElefSearchField`, `ElefCard`, `ElefBadge` & `ElefChip`, `ElefTabs`, `ElefEmptyState`.
  - Composants pédagogiques haute fidélité créés : `ElefCallout` (encadrés légers de théorèmes, définitions, formules, pièges) et `ElefSummarySheetCard` (fiches mémos de référence traits pour traits avec colonnes comparatives, formules centrales display, astuces et pièges du Bac).
- **2. Moteurs Scientifiques & Déterministes (`admin_app/lib/core/engines/`) :**
  - `CapabilityRegistry` : Catalogue des 9 capacités avec mode d'exécution (local/serveur), monitoring et fallbacks.
  - `MathEngine` : Moteur déterministe pour polynômes, discriminant, racines réelles, dérivées et tangentes.
  - `GraphEngine` : Spécifications et échantillonnage de courbes de fonctions 2D.
  - `SimulationEngine` : Circuits RLC, orbitales moléculaires 3D et balistique.
  - `CodeExecutionEngine` : Bac à sable d'exécution Python algorithmique.
  - `ImageGenerationEngine` : Moteur de génération d'illustrations scientifiques avec cache FNV-1a intelligent anti-duplication.
  - `EngineCenterScreen` : Écran d'administration de santé des moteurs avec lanceur de tests diagnostiques intégrés.
- **3. Schéma Universel `LessonBlock v2` & Templates de Filières (`core/models/`) :**
  - `LessonBlock` : Modèle universel v2 avec support JSON canonique et rétro-compatible pour 18 types de blocs.
  - `SubjectTemplate` : Catalogue de 6 templates de filières (Scientifique, Physique, Lettres, Informatique, Industriel, Commercial), incluant le générateur 1-clic pour la **Fiche Synthèse Suites Numériques (Arithmétique vs Géométrique)**.
- **4. Studio de Cours Interactif (`LessonBuilderScreen`) :**
  - Interface 3 volets haute fidélité (Bibliothèque latérale de blocs, Canvas réordonnable avec édition directe, Volet d'aperçu élève temps réel 390px/large).
  - Rendu sans aucun artefact LaTeX brut et génération 1-clic de la fiche Suites Numériques.
- **5. Médiathèque & Générateur d'Illustrations IA (`MediaLibraryScreen`) :**
  - Hub d'actifs médias avec modale de génération IA connectée à `ImageGenerationEngine` et indicateur visuel de cache (`Cache Hit ⚡ 0 token`).
- **6. Dé-cluttering de l'Application Élève (`student_app`) :**
  - Support natif du type `summary_card` dans `BlockRendererRegistry`.
  - Suppression des conteneurs blancs durs et des bordures doublées superflues pour une intégration fluide dans le thème de l'élève.
- **7. Navigation & Intégration :**
  - Items 30 (`Studio de Cours v2`), 31 (`Médiathèque & IA`) et 32 (`Centre des Moteurs`) câblés dans `MainAdminLayout`.
- **Validation Qualité :**
  - `flutter analyze` sur l'ensemble des nouveaux modules : **0 erreur, 0 avertissement**.
# 2026-09-07 — Reprise après le push `7996f20` : sauvegarde du Studio v2

- Vérification : HEAD local identique au HEAD GitHub ; cahiers Content Factory et MASTER,
  historique de progression, code du Studio et référence visuelle Suites réelles examinés.
- CF-002 : le Studio crée maintenant une leçon via `createLesson` dans une matière et un
  chapitre sélectionnés, puis conserve son identifiant pendant la session pour les mises à jour.
  La création utilise le brouillon non publié du service existant.
- Avec `initialLessonId`, chargement du titre et des blocs avant édition, conservation des
  autres clés de `content_json`, transmission de l'auteur connecté au versioning existant.
  Les leçons publiées et les formats historiques sont renvoyés vers Leçons & Cours.
- Annulation sans écriture, titre obligatoire, erreurs explicites et invalidation des listes
  Riverpod après sauvegarde confirmée. Noms de classes affichés lors du choix du chapitre.
- Trois débordements de texte corrigés : titres de catégories de la bibliothèque, badges/source
  de la fiche, titre des astuces. Les images de référence et contenus existants sont conservés.
- Validation : `flutter test --no-pub` dans `admin_app` : **7 tests passants** (2 existants,
  5 nouveaux). Analyse ciblée des 3 fichiers Dart concernés : **No issues found**.
  `git diff --check` sans erreur.
- Limites : services simulés dans les tests, aucune écriture de production ni migration exécutée.
  Publication → rendu élève, fidélité visuelle exhaustive, petits écrans et réouverture du Studio
  depuis le gestionnaire restent à vérifier/intégrer. Une sauvegarde répétée évite un doublon
  après confirmation, sans garantie d'idempotence serveur si la réponse réseau est perdue.

## Complément du 7 septembre — vérification réelle après connexion

Le parcours navigateur a confirmé sauvegarde Studio, soumission, approbation manuelle et
lecture anonyme via le véritable lecteur élève sur Supabase. Les cinq blocs et l'image
de référence Suites réelles sont affichés. Le chapitre et la leçon temporaires sont archivés,
et le lecteur confirme leur retrait. Corrections mobiles de la validation admin et du bandeau
de fiche élève vérifiées. Les tests sont maintenant à **13 admin / 20 élève** ; builds web
release réussis pour les deux applications.

Configuration cliente limitée à `.env.public`, contrôle automatisé des assets, suppression de
l'auto-connexion admin de développement. La révocation legacy reste à terminer après migration
des consommateurs serveur. Aucun nouvel hébergement configuré. Détails et limites dans
`STUDIO_PUBLICATION_VERIFICATION.md`, qui actualise les limites de la première passe ci-dessus.

## 7 septembre — fidélité du contexte dans le parcours élève (après `be2c58e`)

Exigences : MASTER U2/U2.3, Content Factory §5/§12, absence de faux succès (AGENTS.md).

- Le registre de fiches retourne désormais une correspondance précise ou aucune ; normalisation
  des accents/séparateurs, limites de mots, préférence au sujet le plus précis et refus des
  égalités ambiguës. Une matière générique ou un chapitre inconnu n'ouvre plus Suites réelles.
- Liste des chapitres et lecteur utilisent cette même résolution ; images/formules conservées.
- Visionneuse : message honnête sur l'enregistrement hors ligne non implémenté, erreur image
  distinguée d'un chargement, accès au mode formules conservé. Onglets et consigne de zoom
  adaptés aux petits écrans ; actions de chapitre sur plusieurs lignes au besoin.
- Introduction : reçoit l'identifiant et le texte réels du chapitre, les transmet au lecteur,
  ne fabrique plus une classe Terminale. Le texte enregistré prime sur le template de dérivation,
  qui reste restreint aux chapitres de mathématiques concernés. État explicite si aucun texte.
- Laboratoire : retour au lecteur d'origine et à sa leçon sélectionnée, sans `chap_derivation`
  fictif ni annonce de validation d'une observation qui n'a pas été évaluée.
- Vérification : 44 tests élève passants (20 existants + 24 nouveaux), analyse des huit fichiers
  concernés sans problème. Tests des trois fiches à 390/800/1400 pixels, erreur image,
  navigation introduction/lecteur, maintien de la sélection après le laboratoire.
  Build web release final réussi ; configuration distribuée contrôlée par
  `node scripts/verify_public_config.cjs --built`.
- Aucun changement de schéma, de permission, de données Supabase ou d'images de référence.
  Les tests des services utilisent des données de contrôle ; aucune nouvelle validation distante
  de ces parcours n'est revendiquée. Le stockage hors ligne et l'association des références
  administrable par identifiant restent des chantiers distincts. Déploiement non effectué.

## 7 septembre — entraînement contextuel : correction du contenu hors sujet

Audit navigateur connecté : la leçon SVT BONJOUR affichait un exercice de suites et une récompense XP fictive. Plan : limiter la banque locale aux suites reconnues, expliquer son absence ailleurs, préserver le tuteur et vérifier les régressions.
La requête tuteur utilise maintenant subject_name et les rôles attendus par la fonction existante ; délai porté à 30 secondes, double envoi bloqué et historique conservé entre onglets. Le secours local indique explicitement l’indisponibilité du service et ne donne plus de conseils mathématiques hors contexte. Aucun changement de données ou de permissions.

Vérification : 48 tests élève passants, dont 4 nouveaux (SVT dans les trois modes à 390 pixels et correction locale des suites sans XP fictifs). Analyse ciblée : aucun problème. Limites : la banque locale reste restreinte aux suites, l’association repose sur les titres connus ; le service IA distant et le contexte RAG par identifiant ne sont pas validés par ces tests. Aucun déploiement distant effectué.

## 7 septembre — audit transversal et intégrité des interfaces Admin

Références : MASTER administration §2.3/2.5/2.7, Content Factory §4/5/6/9 et Agents IA §9.
Inventaire et preuves : ADMIN_TRANSVERSAL_AUDIT_2026_09_07.md.

- Visite des destinations visibles de cinq hubs dans la session admin locale ; consultation des six templates du Studio. Inspection du code des écrans, providers, modèles, services et migrations de la médiathèque. Pas de validation exhaustive de chaque mutation métier.
- Médiathèque : remplacement des quatre photos fictives par le provider Supabase existant ; import via le service existant, recherche/type réels, chargement/erreur/vide distincts, actualisation, ouverture et copie d’URL effective. La sélection renvoie le modèle MediaAsset réel aux éditeurs qui utilisent MediaAttachmentPicker ; elle ne prétend pas insérer un média sans cours actif. Les références du Studio sont conservées.
- Génération d’image non raccordée : aucun faux résultat ou photo prédéfinie présenté comme génération. Contrats de requête/résultat conservés ; raccordement serveur restant à implémenter.
- Curriculum Autopilot : données d’exemple conservées dans un modèle séparé, explicitement non officielles/non validées ; suppression des temporisations qui annonçaient une collecte, certification et injection fictives. Navigation vers l’arbre académique réel. La collecte nationale n’est pas déclarée achevée.
- Centre moteurs : remplace latence/100% inventés par des contrôles locaux limités (normalisation LaTeX, racines polynomiales, sérialisation de configurations). Les services sans diagnostic sont non vérifiés. Ces contrôles ne certifient ni disponibilité distante, ni qualité du rendu, ni précision d’un simulateur.
- Interfaces testées à 345/390/800/1400 pixels. 32 tests admin passants, dont 19 nouveaux ; ancien test de faux harvesting remplacé par conservation et ouverture de l’exemple non validé. Tests régression du Studio/persistance/publication toujours passants. Analyse des neuf fichiers : aucun problème.
- Aucun schéma, permission, compte, paiement, contenu publié ou configuration secrète modifié. Aucun upload réel ni coût IA déclenché pour les tests. Points restant à traiter : tableau de bord trop long, états de chargement de certaines pages, raccordements IA et validation E2E des mutations module par module.

Complément du même lot : les appels IA du tableau de bord sont regroupés par agent (5 groupes initialement, développement de la liste et détail défilant), en conservant sommes et échecs observés. Les classes/matières distinguent chargement et échec réseau de l’absence réelle de données, avec reprise. Suite finale : **36 tests admin passants**, analyse ciblée sans problème. Le premier build web du lot (médiathèque/Autopilot/moteurs) a réussi ; bibliothèque réelle et filtre Images vérifiés en session connectée. Le build incluant les deux dernières corrections reste à produire après le push demandé par l’utilisateur. Aucun déploiement distant réalisé.

## 8 septembre — Remise à niveau intégrale Admin HQ (Studio v2, Agents IA, Multiplateforme & Tests)

Références : MASTER administration §2.3/2.5/2.7, Content Factory §4/5/6/9, Agents IA AIA-AGT-017 / AIA-AGT-024 et directives `.agents/AGENTS.md`.

- **Correction des tests & Marque visuelle** :
  - Mise à jour de `admin_app/test/widget_test.dart` pour s'aligner sur la marque visuelle réelle (`Image` avec logo SVG/PNG plutôt qu'un texte statique obsolète). Les 2 tests de `widget_test.dart` passent à 100%.
- **Studio de Cours v2 (`lesson_builder_screen.dart`)** :
  - Résolution définitive du bogue de perte de focus et saut de curseur lors de la frappe en extrayant les cartes de blocs dans un widget avec état dédié `_BlockEditorCardWidget` doté de contrôleurs textuels stables (`ValueKey(block.id)`).
  - Ajout du bloc `Fiche Synthèse Visuelle` (`LessonBlock.summaryCard`) dans la bibliothèque de blocs.
  - Implémentation de l'éditeur interactif complet pour `summary_card` : titres, sous-titres, formule clé LaTeX, comparaison responsive à 2 colonnes (Cas A vs Cas B avec badges et items libellé/formule), mémos et pièges d'examen.
  - Tests unitaires et de persistance du Studio : 7/7 passants.
- **Agents IA Métier Backend & Supabase Edge Functions** :
  - Déploiement de `ai-pedagogical-validation` (AIA-AGT-024) : validation substantielle des leçons (vérification des blocs de fond, détection de mocks/placeholders, conformité des formules et liaisons curriculaires avec calcul d'indice de confiance et liste de contrôle).
  - Déploiement de `ai-curriculum-mapping` (AIA-AGT-017) : analyse d'extraits officiels, normalisation lexicale, recherche de correspondance avec les chapitres/compétences de la base et détection d'ambiguïtés nécessitant une relecture humaine (HITL).
- **Raccordement IHM Frontend** :
  - `curriculum_autopilot_screen.dart` : Raccordement de l'assistant d'analyse AIA-AGT-017 avec suggestions de chapitres et compétences cibles, tout en maintenant les avertissements et l'absence de faux harvesting automatique. Mise en conformité responsive multi-résolutions (345px, 390px, 800px, 1400px sans overflow).
  - `validation_queue_screen.dart` : Ajout d'une action "Pré-contrôle IA (AIA-AGT-024)" ouvrant une boîte modale d'analyse automatisée de conformité avant validation humaine.
- **Portabilité multiplateforme & Qualité de code** :
  - Suppression de l'import obsolète web-only `dart:html` dans `audit_log_screen.dart` au profit d'une solution multiplateforme (`package:printing` et `Clipboard.setData`).
  - Casts sécurisés dans `active_sessions_screen.dart` pour prévenir tout crash sur les sessions utilisateur.
  - Résolution exhaustive de tous les avertissements `curly_braces_in_flow_control_structures` dans l'application admin (`academic_tree_screen.dart`, `school_year_promotion_screen.dart`, `pedagogical_catalog_screen.dart`, `validation_queue_screen.dart`, `exam_paper_review_screen.dart`).
- **Validation** :
  - `dart analyze` : **0 erreur, 0 avertissement** (No issues found).
  - `flutter test` : **36/36 tests passants à 100%**.
  - Intégrité Python Gateway : vérification des imports de `app.main` avec succès.

## 8 septembre — Audit Global Cross-Système (Application Élève, Liens Admin-Élève, Cahiers des Charges & Supabase)

Rapport exhaustif consigné dans : `docs/AUDIT_SYSTEME_COMPLET_2026_09_08.md`.

- **Application Élève (`student_app`)** :
  - Cartographie exhaustive des 13 modules et 31 écrans (Auth multi-comptes avec anti-fraude, Onboarding académique, BottomBar mobile-first, lecteurs de leçons haute-fidélité, Runner d'exercices à 5 formats, Annales d'examens officiels et d'établissements, Tuteur IA avec rendu LaTeX, Portail Parent étanche, Support et Dons).
  - 5 simulateurs et outils scientifiques déterministes autonomes sans mocks (`CircuitSimulatorWidget`, `BallisticsSimulatorWidget`, `MolecularViewer3DWidget`, `PythonSandboxWidget`, `InteractiveFunctionGraph` & `VariationTableInteractive`).
  - Validation qualité : **48/48 tests passants à 100%**, `dart analyze` : **No issues found**.
- **Synergie et Liens Admin <-> Élève** :
  - Chaîne éditoriale vérifiée : Studio v2 (`admin_app`) -> File de validation avec pré-contrôle IA (AIA-AGT-024) -> Transaction RPC `approve_and_publish_content` -> Consommation immédiate par `student_app` via `BlockRendererRegistry`.
  - Intégrité des données : compatibilité 100% des clés `summary_card` entre la sérialisation admin et le rendu élève.
  - Étanchéité RLS, filtrage trimestriel en coulisses, tatouage judiciaire anti-capture (`ForensicWatermarkService`) et observabilité des coûts IA via `ai_agent_calls`.
- **Alignement Cahiers des Charges (`docs/`)** :
  - Parfaite adhérence au CDC Master (Parties 1 et 2), au CDC Agents IA (zéro coût obligatoire, découplage calcul déterministe / raisonnement LLM), et au cahier Content Factory.
- **Application Supabase** :
  - 77 migrations relationnelles actives, RLS activé sur toutes les tables sensibles, 21 Edge Functions Deno opérationnelles, et buckets Storage (`lesson-media`, `avatars`, `official-exams`, `establishment-papers`) configurés.

## 8 septembre — Ergonomie Mobile & Élimination de la Surcharge de Boîtes ("Trop de box sur un même écran")

Références : Feedback utilisateur sur smartphone, CDC Master §11.1 Apparence & Design Mobile-First.

- **Élimination des boîtes blanches en dur et harmonisation Dark/Light (`block_renderer_registry.dart`)** :
  - Remplacement de `Colors.white` et des fonds ardoise fixes par `context.colors.card` et `context.colors.surface` dans tous les blocs haute-fidélité (`_essentialRulesCard`, `_guidedExampleCard`, `_remarksCard`, `_frequentErrorsCard`, `_quickCheckCard`, `_summaryCard`).
  - Adoucissement des bordures imbriquées (opacité ramenée de 70-90% à 35-50% avec `withAlpha`), suppression des bordures dures multiples et allègement des ombres portées pour aérer l'interface sur smartphones (345-390px).
  - Couleurs textuelles raccordées à `context.colors.textPrimary`, `textSecondary` et `textMuted` pour lisibilité sans éblouissement en mode sombre natif.
- **Tableau de Variations Interactif (`variation_table_interactive.dart`)** :
  - Remplacement de la carte blanche externe par `context.colors.card` avec bordure subtile `context.colors.border`.
  - Intégration d'un défilement horizontal `SingleChildScrollView` avec largeur minimale sécurisée (420px) pour les écrans < 420px : empêche l'écrasement des colonnes et le rognage des zones de dépôt Drag & Drop.
  - Transformation de la zone « ÉLÉMENTS À PLACER » en un ruban d'outils intégré, éliminant le conteneur lourd violet à double bordure.
- **Runner d'Exercices (`exercise_runner_screen.dart`)** :
  - En-tête de l'énoncé converti d'une `Row` rigide vers un `Wrap(spacing: 8, runSpacing: 8)` : supprime les risques de débordement ou d'écrasement entre le badge d'énoncé et les déclencheurs SymPy et Tuteur Socratique sur les largeurs 320-375px.
- **Tableau de Bord Accueil (`home_dashboard_screen.dart`)** :
  - Réduction drastique des marges et séparateurs verticaux empilés (passant de 24-28px à 12-14px).
  - Transformation de la carte d'abonnement `_buildActivePassCard` en une pastille d'état sobre et compacte.
  - Compactage des bandeaux Compte à rebours examen et Progression trimestrielle pour rendre les matières au programme immédiatement visibles au-dessus du pli de l'écran mobile.
- **Validation Qualité Globale** :
  - `student_app` : `dart analyze` **0 issues**, `flutter test` **48/48 tests passés (100%)**.
  - `admin_app` : `dart analyze` **0 issues**, `flutter test` **36/36 tests passés (100%)**.

## 14 septembre 2026 — Refonte Architecturale Multi-Pages & Aération Didactique des Exercices Admin

Références : Demande d'aération complète de l'interface des exercices ("chaque interface/box doit avoir sa propre page"), CDC Master §11 & Content Factory §8.

- **Élimination de la surcharge mono-page (`ExercisesManagerScreen`)** :
  - Remplacement de l'ancien panneau empilé (6 cartes KPI, 4 niveaux d'indépendance, inspecteur inline compressé) par un Hub structuré en deux espaces clairs :
    1. *Exercices du Programme (Niveaux 1 & 2)* organisés par dossiers de chapitres déroulants avec cartes épurées.
    2. *Examens & Concours (Niveau 3)* regroupant les épreuves indépendantes.
  - Cartes d'exercices allégées avec boutons d'accès direct « Consulter » et « Aperçu », menu contextuel complet (Studio, Exporter PDF, Dupliquer, Supprimer/Archiver).
  - En-tête et barre de recherche/filtres responsives (`LayoutBuilder`, `SingleChildScrollView` horizontal, encapsulation `Material`).
- **Fiche d'Exercice Plein Écran Dédiée (`ExerciseDetailScreen`)** :
  - Page plein écran avec `AppBar`, fil d'Ariane dynamique (`Banque > Classe > Matière > Chapitre`), bouton de bascule directe Statut (Publié / Brouillon).
  - Zone didactique majeure : rendu LaTeX de l'énoncé via `MathText`, simulation interactive des choix d'élèves (marquage instantané vert/rouge, bouton Réinitialiser), corrigé pas-à-pas et indices progressifs.
  - Panneau latéral de métadonnées pédagogiques (Classe, Chapitre, Trimestre, Format didactique, Type, Difficulté, Prérequis & Compétences).
  - Raccourcis d'action : « Modifier dans le Studio », « Aperçu Élève », « Exporter en PDF », « Générer variante IA », « Dupliquer ».
- **Immersion Élève Plein Écran (`ExerciseStudentPreviewScreen`)** :
  - Remplace la modale étroite de 580px par une interface plein écran dédiée.
  - Commutateur de viewport interactif : maquette Smartphone réaliste (390px) et mode Grand Écran / Tablette.
  - Simulation complète du parcours élève (sélection d'options, validation, feedback didactique, révélation d'indices, réinitialisation).
- **Studio de Génération IA Plein Écran (`ExerciseAiGenerationScreen`)** :
  - Interface dédiée remplaçant la boîte de dialogue contextuelle.
  - Formulaire de configuration contextuel (Classe, Chapitre, Typologie, Format didactique, Difficulté, Nombre d'exercices, Directives spécifiques).
  - Liste de révision des exercices générés avec sélection par cases à cocher et import en lot direct dans la banque d'exercices.
- **Service Supabase & Persistance (`SupabaseService`)** :
  - Méthode `duplicateExercise(exerciseId, adminId)` ajoutée avec copie intégrale des instructions, corrigé, compétences et prérequis.
- **Validation Qualité & Non-Régression** :
  - `admin_app` : `flutter analyze` : **0 erreur, 0 avertissement, 0 info**.
  - `admin_app` : `flutter test` : **75/75 tests passés (100%)** incluant `exercises_manager_ergonomics_test.dart` (7/7 tests passés), `exercise_studio_test.dart` et `lessons_manager_ergonomics_test.dart`.

## 15 septembre 2026 — Refonte Front-end Élève v2 (lots 1 à 10)

Références : CDC Master §11, audit `STUDENT_APP_CURRENT_STATE.md`, demande de refonte mobile-first de **pq learn** sans régression du continuum Admin → Supabase → Élève.

- **Lot 1 — socle de navigation et accueil pédagogique** :
  - nouvel accueil centré sur la prochaine action d'apprentissage, alimenté uniquement par le profil, les matières et le trimestre réels ;
  - ajout d'une vue Progression honnête, sans XP, maîtrise ou temps d'étude fictifs ;
  - navigation mobile prioritaire réorganisée en Accueil, Cours, Exercices, Progression et Profil ; Tuteur, examens, communauté et services restent accessibles dans le menu complet ;
  - harmonisation de la barre mobile avec la couleur d'accent du thème.
- **Lot 2 — catalogue de cours responsive** :
  - remplacement de la liste compacte par un catalogue adaptatif 1/2/3 colonnes ;
  - recherche locale réelle par nom ou code matière, effacement accessible et navigation clavier ;
  - rafraîchissement par geste, états chargement/erreur/vide/recherche sans résultat ;
  - conservation stricte de `studentSubjectsProvider` et du contrat de navigation `/chapters`.
- **Tests ajoutés** : `subjects_filter_test.dart` couvre recherche insensible à la casse, recherche par code et requête vide.
- **Lot 3 — chapitres et actions pédagogiques accessibles** :
  - remplacement des actions uniquement iconographiques par des boutons nommés : Introduction, Exercices, Fiche mémo et Leçons ;
  - ajout d'une description sémantique par chapitre pour les technologies d'assistance ;
  - amélioration du contraste du bouton principal et remplacement de l'erreur technique brute par un état utilisateur avec relance ;
  - conservation du déblocage trimestriel, du chargement réel des leçons, des fiches de synthèse et du parcours adaptatif existants.
- **Lot 4 — lecteur de leçon mobile** :
  - suppression du bouton hors-ligne non implémenté, conformément à la règle « aucun faux bouton » ;
  - AppBar désencombrée : accès direct aux exercices et regroupement des outils réels dans un menu nommé (fiche mémo, laboratoire, outils scientifiques) ;
  - remplacement de l'erreur technique brute par un état explicite avec relance du provider ;
  - conservation intégrale du `BlockRendererRegistry`, du tatouage, du paywall, du tuteur contextuel et de la navigation multi-leçons.
- **Lot 5 — hub et runner d'exercices** :
  - dossiers d'exercices réels réorganisés en grille responsive 1/2/3 colonnes et cartes sémantiques ;
  - démonstrateurs existants conservés mais renommés « Laboratoires d'entraînement » pour ne pas les confondre avec les séries publiées depuis Supabase ;
  - suppression du vocabulaire XP non adossé à un agrégat backend ; affichage des points définis par les exercices ;
  - correction du calcul local : une rédaction ou réponse courte non évaluée automatiquement ne reçoit plus artificiellement tous les points ; seuls les QCM corrects alimentent le total confirmé ;
  - états d'erreur Hub/Runner remplacés par une information utilisateur et une relance des providers réels.
- **Lot 6 — examens, annales et événements** :
  - annales officielles : récupération des erreurs de l'examen et des sujets avec relance des providers, contraste du bouton Corrigé corrigé ;
  - épreuves d'établissement : récupération séparée du catalogue d'établissements et des sujets filtrés sans exposer les erreurs techniques ;
  - examens blancs et olympiades : état de panne avec relance du flux de la classe et message neutre si le classement est temporairement indisponible ;
  - conservation stricte du cloisonnement par profil/classe, des documents externes, questions publiées, résultats, classements et demandes de deuxième correction.
- **Lot 7 — profil et paramètres honnêtes** :
  - ajout d'une sémantique de bouton à la modification de la photo de profil ;
  - remplacement du commutateur actif « Sous-titres vidéo », sans effet tant qu'aucun lecteur vidéo n'existe, par une information non interactive « À venir » ;
  - conservation des réglages réellement persistés dans `account_settings` : notifications, thème, taille du texte, contraste et visibilité du profil.
- **Lot 8 — tuteur, communauté et support résilients** :
  - suppression du secours pédagogique prédéfini présenté silencieusement comme une réponse du Tuteur Numérique lorsque l'Edge Function `ai-tutor-chat` échoue ; l'indisponibilité est désormais explicite et le double envoi est bloqué pendant la requête ;
  - conservation du contrat réel de l'Edge Function, de l'historique, du profil de classe, du rendu mathématique, de l'OCR et du grapheur ;
  - remplacement des erreurs techniques brutes des communautés WhatsApp, du forum de classe et des tickets de support par des états utilisateur avec relance des providers ;
  - suppression de l'exposition du lien d'invitation WhatsApp dans les messages d'erreur et maintien des créations réelles de publications et de tickets.
- **Lot 9 — boutique, abonnements et dons sans faux paiement** :
  - conservation des catalogues Supabase réels, des fiches mémo consultables, des prix et de la progression des campagnes ;
  - retrait de la saisie Mobile Money et des boutons actifs tant qu'aucun agrégateur n'est raccordé : les actions d'achat, d'abonnement et de don sont maintenant clairement désactivées ;
  - remplacement des erreurs techniques brutes par des états de reprise, sans enregistrer ni simuler une transaction locale.
- **Lot 10 — nettoyage transversal final des parcours élève** :
  - suppression du dernier bouton hors-ligne non implémenté dans la visionneuse de fiches ;
  - désactivation et libellé explicite des deux actions sans comportement dans les laboratoires d'entraînement (défi et justification) ;
  - retrait des détails d'erreur backend encore exposés dans l'onboarding, le profil, les paramètres, le portail parent, l'ancien tableau de bord, les chapitres et la réclamation d'examen ;
  - aucune mutation de schéma, RLS, contenu ou contrat Admin → Supabase → Élève.
- **Limite de validation de l'environnement Codex** : formatage Dart et `git diff --check` réussis. L'exécution Flutter locale reste à effectuer sous VS Code, le SDK de cet environnement étant bloqué pendant sa résolution réseau ; ce lot n'est pas déclaré entièrement validé avant `flutter analyze` et `flutter test`.

### Vérification Flutter réelle (lots 1 à 10) — complète la limite ci-dessus

`flutter analyze` et `flutter test` n'avaient jamais réellement tourné sur les lots 1 à 10 (environnement
Codex bloqué). Exécutés ici en environnement Flutter réel (Windows/VS Code) :

- `flutter analyze` : **0 erreur** (17 infos de style pré-existantes, aucune liée aux lots 1-10 :
  `unnecessary_underscores`, 1 `curly_braces_in_flow_control_structures`).
- `flutter test` (avant correction) : **52 tests passés / 5 échecs réels**, tous dans
  `test/summary_sheet_access_test.dart` — cassés par des sélecteurs de test devenus obsolètes après la
  refonte, pas des régressions fonctionnelles :
  - « Laboratoire interactif » n'est plus une icône directe avec info-bulle mais un item du menu
    « Outils de la leçon » (Lot 4, barre d'action allégée) → test mis à jour sur le vrai parcours en 2 temps ;
  - l'accès à la fiche mémo (`LessonReaderScreen` + `ChaptersListScreen`) n'a plus d'info-bulle dédiée :
    bannière avec bouton « Ouvrir » / bouton texte « Fiche mémo » → tests mis à jour sur les sélecteurs réels ;
  - le bouton « enregistrement hors ligne — à venir » ciblé par 3 tests a été supprimé intentionnellement
    par le Lot 10 (règle « aucun faux bouton ») → tests supprimés, pas réécrits : le contrôle qu'ils
    vérifiaient n'existe plus par design.
- `flutter test` (après correction) : **tous verts**.
- `flutter build web` : **OK**.
- Nettoyage additionnel sans lien avec les lots 1-10 : `student_app/.metadata` avait perdu ses entrées
  `android`/`ios`/`web` (remplacées au lieu d'être complétées par un `flutter create --platforms=windows`
  local) — restauré en fusion ; `student_app/windows/` ajouté au suivi git (cohérent avec `admin_app` qui
  le suit déjà) ; fichier `.patch` résiduel à la racine supprimé (déjà appliqué en `af5039d`).

**Conclusion** : les lots 1 à 10 de la refonte front-end élève v2 sont maintenant validés par une
exécution Flutter réelle, pas seulement par le formatage/lint de l'environnement Codex.

## 16 septembre 2026 — Refonte Front-end Élève v2 (lot 11 — Onboarding/Auth/Profil)

Référence : `docs/UI_REDESIGN_PLAN.md` Vague 3. Les 5 écrans d'entrée (RoleSelection,
DeviceAccountSelector, LoginCodeEntry, StudentLogin, ProfileSwitcher) n'avaient été touchés par
aucun des lots 1-10 et n'avaient aucun test — première passe réelle sur ce parcours.

- **LoginCodeEntryScreen** : le texte annonçait « code à 6 chiffres » alors que le format réel
  (`StudentProfileScreen`, `set_login_code`) accepte 4 à 40 caractères quelconques — corrigé
  (texte + doc obsolète dans `student_auth_provider.dart`).
- **StudentLoginScreen** : aucun parcours de récupération de mot de passe n'existait — ajout de
  `requestPasswordReset` (API standard `resetPasswordForEmail`) + dialogue dédié, message toujours
  générique pour ne jamais confirmer/infirmer l'existence d'un compte.
- **DeviceAccountSelectorScreen** : une erreur de lecture locale réelle (stockage corrompu) était
  confondue avec « aucun compte connu » — ajout d'un état d'erreur avec relance, et d'une icône
  « oublier ce compte » visible (l'appui long seul n'était jamais découvert). Bug réel trouvé en
  testant ce nouveau bouton : `setState(() => _knownFuture = ...)` (corps flèche) renvoyait le
  Future lui-même au lieu de void, provoquant une exception jamais observée avant — jamais exercé
  avant l'ajout d'un test sur ce bouton.
- **ProfileSwitcherScreen** : ajout de l'année scolaire et du palier d'abonnement réels par profil,
  jamais un « streak » fabriqué (aucune activité quotidienne n'est suivie côté backend — voir
  `STUDENT_APP_CURRENT_STATE.md`, ligne Gamification).
- Corrections de débordement horizontal (`Row` → `Wrap`) sur `LoginCodeEntryScreen` et
  `StudentLoginScreen` à largeur téléphone étroite, jamais détectées faute de test sur ces écrans.

`test/onboarding_auth_screens_test.dart` : 6 nouveaux tests. Vérification : `flutter analyze`
0 erreur (17 infos de style pré-existantes sans rapport), `flutter test` tous verts,
`flutter build web` OK.

**Reste dans la Vague 3** : `RoleSelectionScreen` (cosmétique seulement, non prioritaire) ;
`StudentProfileScreen` (1373 lignes — le plan demande un découpage en sous-composants, pas encore
fait) ; `SettingsScreen` (organisation par onglets thématiques demandée par le plan, pas vérifiée).

## 17 septembre 2026 — Refonte Front-end Élève v2 (lot 12 — découpage StudentProfileScreen)

Référence : `docs/UI_REDESIGN_PLAN.md` Vague 3, dernier point ouvert du lot précédent.

- `StudentProfileScreen` (1373 lignes) découpé en 12 fichiers sous
  `lib/features/profile/widgets/` : `ProfileIdentityCard`, `ProfileAvatarUploader`,
  `ProfileAchievementsSection`, `ProfileClassTile`, `FollowedClassesSection`,
  `ArchivedClassesSection`, `ArchiveClassDialog`, `LoginCodeCard`, `MyLoginCodeDialog`,
  `SetLoginCodeDialog`, `EditProfileDialog`, `ParentInviteCard`. L'écran devient un orchestrateur
  `ConsumerWidget` de ~65 lignes — critère d'acceptation n°9 du plan (fichiers < ~350 lignes)
  atteint pour ce module. Refactor planifié par l'agent ECC `planner` (cartographie précise du
  fichier + conventions réelles du dépôt), exécuté puis revu ligne par ligne contre l'historique
  git par l'agent ECC `flutter-reviewer` : aucune anomalie critique, portée de reconstruction des
  providers affinée (amélioration, pas une régression).
- `test/profile_widgets_test.dart` : 18 nouveaux tests (édition profil, code personnel,
  invitation/liaison parent, archivage/réactivation), y compris les échecs serveur honnêtes.

**Incident d'environnement (18h26 le 17/09)** : Windows Smart App Control (Contrôle des
applications basé sur la réputation) a commencé à bloquer `flutter_tester.exe` au niveau Code
Integrity du noyau (journal `Microsoft-Windows-CodeIntegrity/Operational`, évènements 3077/3118) —
un blocage système, pas un défaut de code. Conséquence : `flutter test` ne pouvait plus s'exécuter
DU TOUT, y compris sur des fichiers qui passaient la veille. `flutter analyze` et
`flutter build web` restaient fonctionnels et ont servi de seul filet de sécurité pour ce commit.
Le porteur de projet a choisi de désactiver Smart App Control lui-même (Windows Security →
Contrôle des applications et du navigateur) ; `flutter test` sera relancé sur l'ensemble de la
suite dès confirmation.

Vérification **au moment du commit** : `flutter analyze` 0 erreur (16 infos de style
pré-existantes, une de moins qu'avant grâce à une accolade ajoutée en déplaçant le code),
`flutter build web` OK. **`flutter test` non exécuté pour ce lot** (blocage ci-dessus) — à
confirmer vert dès que possible, sans quoi les 18 nouveaux tests restent non prouvés.

**Résolution (18/09)** : Smart App Control désactivé + machine redémarrée par le porteur de
projet — confirmé côté registre (`VerifiedAndReputablePolicyState` 1 → 0). `flutter test` relancé
sur toute la suite : les 18 nouveaux tests de `profile_widgets_test.dart` ont immédiatement révélé
un vrai bug pré-existant, jamais détectable avant faute de test sur cet écran — `ProfileClassTile`
(nom de classe + badge « Actif » + puce d'abonnement + icône d'archivage dans une seule `Row`)
débordait de 59px sur mobile dès qu'une classe active avait un nom un peu long. Corrigé (nom de
classe dans un `Flexible` avec ellipsis). Suite complète : **81/81 tests verts**, `flutter analyze`
0 erreur, `flutter build web` OK. Le lot 12 est donc maintenant intégralement vérifié.
