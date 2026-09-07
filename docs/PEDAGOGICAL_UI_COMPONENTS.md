# Spécification des Composants Pédagogiques Interactifs (PEDAGOGICAL_UI_COMPONENTS)

**Date :** 2026-09-05  
**Projet :** EDLEARN Student Application  
**Principe fondateur :** Content != Presentation. Les composants consomment des données canoniques structurées (`ContentBlock`, `Exercise`) et génèrent une interface pédagogique claire, motivante et sans artifice distractif.

---

## 1. Registre des Blocs de Cours

### 1.1 `DefinitionBlock` (Définition Fondamentale)
- **Rôle pédagogique :** Fixer le vocabulaire, les concepts de base et les notions institutionnelles.
- **Identifiant type :** `'definition'`
- **Composants visuels :**
  - Bordure latérale gauche de 4 px couleur `accentIndigo` (`#6366F1`).
  - En-tête avec icône `Icons.menu_book_rounded`, intitulé en gras ("Définition : [Titre du concept]").
  - Corps en `GoogleFonts.inter` (15 px, hauteur 1.6, couleur `textPrimary`).
  - Fond de carte `card` (`#1B243B` en sombre / blanc en clair).

### 1.2 `FormulaBlock` (Formule Mathématique & Scientifique)
- **Rôle pédagogique :** Mettre en évidence les équations, relations physiques, réactions chimiques et formules clés.
- **Identifiant type :** `'formule'` ou `'formula'`
- **Composants visuels :**
  - Conteneur à fond contrasté sombre (`#0E1726`), contour fin `accentPrimary`.
  - En-tête : badge de la matière ou titre de la formule (ex : "Discriminant d'une équation du second degré").
  - Zone centrale : formule mise en page avec police adaptée, centrée avec marge d'aération.
  - Défilement horizontal automatique et fluide si l'équation dépasse la largeur de l'écran mobile.

### 1.3 `TheoremBlock` (Théorème Majeur & Propriété)
- **Rôle pédagogique :** Mettre en avant un résultat mathématique ou une loi physique démontrée essentielle pour l'examen.
- **Identifiant type :** `'theoreme'` ou `'theorem'`
- **Composants visuels :**
  - Fond teinté bleu nuit soutenu (`#132338`), bordure gauche cyan lumineux (`#38BDF8`).
  - Icône `Icons.verified_rounded`.
  - Distinction nette entre l'énoncé du théorème et ses hypothèses d'application.

### 1.4 `MethodBlock` (Méthode & Savoir-Faire Pas-à-Pas)
- **Rôle pédagogique :** Expliquer à l'élève la démarche algorithmique ou méthodologique pour résoudre un problème type.
- **Identifiant type :** `'methode'` ou `'method'`
- **Composants visuels :**
  - Bordure latérale gauche ambre (`#F59E0B`).
  - Icône `Icons.lightbulb_outline_rounded`.
  - Découpage en étapes numérotées : 1. Analyser l'énoncé, 2. Poser la formule, 3. Vérifier les unités, 4. Conclure.

### 1.5 `ExampleBlock` (Exemple d'Application & Contre-Exemple)
- **Rôle pédagogique :** Illustrer immédiatement la théorie par une application concrète chiffrée ou rédigée.
- **Identifiant type :** `'exemple'` ou `'example'`
- **Composants visuels :**
  - Bordure violette douce (`#A855F7`), icône `Icons.auto_awesome_rounded`.
  - Deux sous-parties claires :
    - *Énoncé de l'exemple*
    - *Résolution détaillée pas-à-pas*.

### 1.6 `TrapBlock` (Piège Classique d'Examen)
- **Rôle pédagogique :** Prévenir les erreurs récurrentes sanctionnées par les correcteurs aux examens nationaux (BEPC, Probatoire, Bac).
- **Identifiant type :** `'piege'` ou `'trap'`
- **Composants visuels :**
  - Fond d'avertissement teinté rose foncé (`#2C161E`), bordure latérale rose vif (`#F43F5E`).
  - Icône d'alerte `Icons.warning_amber_rounded`.
  - Texte explicatif : "Erreur fréquente : oublier de changer le sens de l'inégalité lors de la division par un nombre négatif."

### 1.7 `TipBlock` (Conseil d'Examen & Rédaction)
- **Rôle pédagogique :** Donner des astuces d'efficacité, de gestion du temps et de clarté de copie.
- **Identifiant type :** `'conseil_examen'` ou `'exam_tip'`
- **Composants visuels :**
  - Bordure latérale cyan (`#06B6D4`), icône `Icons.tips_and_updates_rounded`.
  - Mise en forme aérée incitant à soigner la présentation et les encadrements.

### 1.8 `ObjectiveBlock` & `CompetencyBlock`
- **Rôle pédagogique :** En tête de chaque chapitre, annoncer clairement ce que l'élève sera capable de faire.
- **Composants visuels :**
  - Cartouche de compétences avec puces cochables au fur et à mesure que les exercices sont validés.
  - "À la fin de ce chapitre, tu sauras : ..." formulé en compétences concrètes et motivantes.

### 1.9 `SummaryBlock` (Fiche Récapitulative / L'Essentiel)
- **Rôle pédagogique :** Synthèse mémorisable pour les révisions rapides la veille d'un devoir.
- **Composants visuels :**
  - Encadré complet avec puce de résumé, temps de relecture (ex: "3 min de révision"), bouton "Télécharger la fiche de synthèse".

---

## 2. Composants d'Entraînement & d'Exercices

### 2.1 `QuizOptionTile` (Option QCM Interactive)
- **Rôle :** Permettre le choix d'une réponse parmi 4 options.
- **États d'affichage :**
  - *Repos :* Contour gris neutre `border`, fond `card`.
  - *Sélectionné (avant validation) :* Contour cyan `accentPrimary` (2 px), fond légèrement bleuté.
  - *Validé Juste :* Contour vert émeraude (`#10B981`), fond vert à 15% d'opacité, icône coche verte.
  - *Validé Faux :* Contour rouge rose (`#F43F5E`), fond rouge à 15% d'opacité, icône croix rouge.
  - *Bonne réponse révélée :* Contour vert pour montrer à l'élève où se trouvait la réponse attendue.

### 2.2 `ExerciseHintCard` (Indices Pédagogiques Progressifs)
- **Rôle :** Maïeutique : débloquer l'élève qui hésite sans lui donner la réponse brute.
- **Fonctionnement :**
  - Bouton discret "Voir un indice" (couleur ambre).
  - Au clic, affichage de l'indice 1.
  - Si l'élève hésite encore, bouton "Indice suivant" jusqu'à épuisement des indices prévus.
  - Masquage automatique des indices une fois la question validée.

### 2.3 `CorrectionCard` (Feedback & Pédagogie de l'Erreur)
- **Rôle :** Transformer chaque erreur en opportunité d'apprentissage.
- **Structure en 4 parties :**
  1. **Verdict bienveillant :** "Pas tout à fait !" au lieu d'un "Faux !" agressif.
  2. **Analyse de l'erreur :** Pourquoi ce raisonnement ne fonctionne pas dans ce cas.
  3. **Démarche attendue :** La méthode correcte explicitée pas-à-pas.
  4. **Action de remédiation :**
     - Bouton "Refaire un exercice similaire".
     - Bouton "Demander au Tuteur IA de m'expliquer autrement".

### 2.4 `FlashcardWidget` (Mémorisation Active)
- **Rôle :** Mémoriser définitions, formules, dates historiques ou vocabulaire de langues.
- **Composants :**
  - Recto : Question ou mot clé.
  - Tap pour retourner : animation de retournement (Flip 3D à 180° en 250 ms).
  - Verso : Définition, formule ou traduction.
  - Auto-évaluation : boutons "Je savais" / "À revoir".

---

## 3. Composants d'Assistance IA Contextuelle

### 3.1 `AiHelpFloatingButton` (Bouton d'Aide Contextuelle)
- **Emplacement :** Bouton flottant discret en bas à droite du lecteur de cours et des exercices.
- **Fonctionnement :** Ouvre une Bottom Sheet de discussion avec le Tuteur Numérique **déjà pré-chargée** avec le contexte de la leçon courante (ex : "Je lis le cours sur le Théorème de Pythagore, peux-tu m'expliquer autrement l'étape 2 ?").

---

## 4. Composants de Simulations Scientifiques (Cadre Cible)

### 4.1 `SimulationPlaceholderView`
- **Rôle :** Espace dédié pour les simulateurs de physique (circuits électriques, vecteurs de forces), chimie (équations de réaction) ou géométrie interactive.
- **Structure :**
  - Zone interactive plein écran ou 16:9 sans débordement.
  - Bandeau de paramètres réglables en bas (curseurs de tension, résistance, température).
  - Explications guidées par le Tuteur IA sur les observations faites par l'élève.
