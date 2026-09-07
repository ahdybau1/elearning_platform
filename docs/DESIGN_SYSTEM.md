# Design System EDLEARN — Application Élève (DESIGN_SYSTEM)

**Version :** 1.0.0  
**Date :** 2026-09-05  
**Cible :** Flutter Mobile-First (Android, iOS, Tablette, Web/Desktop)  
**Philosophie :** Clarté pédagogique, ergonomie au pouce, sobriété moderne, adaptabilité aux smartphones modestes (Cameroun/Afrique subsaharienne).

---

## 1. Principes Directeurs de Design

1. **Mobile-First & Pouce en Priorité :** Les commandes critiques se situent dans la zone basse de l'écran (Bottom Bar, Bottom Sheets, FAB d'aide).
2. **Pédagogie Active :** Chaque écran doit susciter l'envie d'apprendre. Éviter le style "tableau de bord administratif" ou "Google Drive scolaire".
3. **Zéro Artifice Décoratif Inutile :** Pas de glassmorphism systématique qui ralentit les GPU bas de gamme, pas d'ombres diffuses disproportionnées, pas de 4 bannières empilées sans action concrète.
4. **Hiérarchie Visuelle Implacable :** Une seule action primaire par écran. Les informations secondaires s'effacent au profit de la lisibilité du cours et de la question.
5. **Couleurs Sémantiques Univoques :** Le vert n'est utilisé que pour le succès pédagogique, le rouge pour l'erreur corrigée, l'ambre pour l'attention/indice, le cyan pour le Tuteur IA.

---

## 2. Palette Chromatique & Tokens

### Couleurs de Structure & Surfaces

| Token | Dark Mode (Standard) | Dark High-Contrast | Light Mode | Light High-Contrast | Rôle |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `background` | `#0B0F19` | `#000000` | `#F8FAFC` | `#FFFFFF` | Fond général de l'application |
| `surface` | `#131B2E` | `#0A0A0A` | `#FFFFFF` | `#FFFFFF` | Barres d'action, en-têtes, feuilles modales |
| `card` | `#1B243B` | `#141414` | `#FFFFFF` | `#FFFFFF` | Cartes de contenu, conteneurs de leçons |
| `cardHover` | `#222D47` | `#1F1F1F` | `#F1F5F9` | `#F3F4F6` | État pressé ou survolé des cartes |
| `border` | `#2B3754` | `#E5E7EB` | `#E2E8F0` | `#000000` | Lignes de séparation, contours de cartes |
| `borderFocus` | `#38BDF8` | `#FFFFFF` | `#0284C7` | `#000000` | Contour de champ ou élément actif |

### Couleurs Typographiques

| Token | Dark Mode | Dark High-Contrast | Light Mode | Light High-Contrast | Rôle |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `textPrimary` | `#FFFFFF` | `#FFFFFF` | `#0F172A` | `#000000` | Titres, texte de lecture principal |
| `textSecondary`| `#94A3B8` | `#E5E7EB` | `#475569` | `#1F2937` | Sous-titres, explications, métadonnées |
| `textMuted` | `#64748B` | `#CBD5E1` | `#94A3B8` | `#374151` | Mentions secondaires, placeholders, badges discrets |

### Accents Sémantiques & Pédagogiques

| Token | Code Hex | Dark HC | Light | Rôle Pédagogique |
| :--- | :--- | :--- | :--- | :--- |
| `accentPrimary` | `#38BDF8` | `#7DD3FC` | `#0284C7` | Action primaire, validation, bouton actif |
| `accentCyan` | `#06B6D4` | `#22D3EE` | `#0E7490` | **Tuteur Numérique IA**, astuces maïeutiques |
| `accentIndigo` | `#6366F1` | `#818CF8` | `#4F46E5` | Définitions formelles, notions académiques |
| `accentEmerald` | `#10B981` | `#34D399` | `#059669` | Succès, réponse correcte, validation, débloqué |
| `accentAmber` | `#F59E0B` | `#FBBF24` | `#D97706` | Indice d'exercice, avertissement, chapitre à venir |
| `accentRose` | `#F43F5E` | `#FB7185` | `#E11D48` | Erreur, piège d'examen, notion à revoir |
| `accentPurple` | `#A855F7` | `#C084FC` | `#9333EA` | Exemples concrets, démonstrations, cas pratiques |
| `premiumGold` | `#F59E0B` | `#FCD34D` | `#D97706` | Badge formule excellence, contenu abonné |
| `lockedGray` | `#475569` | `#9CA3AF` | `#94A3B8` | Contenu hors trimestre ou verrouillé |

---

## 3. Typographie Normalisée

L'application s'appuie sur deux polices complémentaires de Google Fonts :
- **Outfit** : pour les titres, chiffres, badges et scores (chaleureuse, géométrique et lisible).
- **Inter** : pour la lecture continue de cours, les explications et les formulaires (excellente lisibilité sur petits écrans).

| Style Token | Famille | Taille | Poids | Hauteur de ligne | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | Outfit | 28 px | Bold (700) | 1.2 | Titre héroïque d'accueil, score d'arène |
| `displayMedium`| Outfit | 22 px | Bold (700) | 1.25 | Titres d'écrans majeurs, nom de matière |
| `titleLarge` | Outfit | 18 px | SemiBold (600) | 1.3 | Titre de chapitre, intitulé de question |
| `titleMedium` | Outfit | 16 px | SemiBold (600) | 1.35 | Titre de bloc pédagogique, sous-titres |
| `bodyLarge` | Inter | 16 px | Regular (400) | 1.6 | Corps de texte des leçons, lecture confortable |
| `bodyMedium` | Inter | 14 px | Regular (400) | 1.5 | Options de QCM, cartes secondaires |
| `bodySmall` | Inter | 12 px | Regular (400) | 1.4 | Métadonnées, date, temps de lecture |
| `label` | Inter | 12 px | SemiBold (600) | 1.2 | Badges d'état, boutons, puces de filtres |
| `code` | JetBrains Mono | 13 px | Regular (400) | 1.45 | Code informatique, formules brutes |

> **Règle d'accessibilité :** Tous les textes s'adaptent automatiquement à l'échelle choisie dans les Paramètres via `TextScaler.linear(settings.fontScale)` (allant de 0.85 à 1.30) sans tronquer les boutons grâce à un dimensionnement `minHeight` plutôt que fixe.

---

## 4. Échelle d'Espacement Normalisée (Spacing Tokens)

Finis les paddings arbitraires de 14, 18 ou 22 px dispersés. L'application respecte strictement une grille de 4 / 8 px :

| Token | Valeur | Usage recommandé |
| :--- | :--- | :--- |
| `space2` | 2 px | Micro-décalages, traits de bordure |
| `space4` | 4 px | Espacement icône-texte compact, marges de badges |
| `space8` | 8 px | Espacement entre boutons d'un groupe, espacement intra-badge |
| `space12` | 12 px | Marge interne de cartes compactes, interligne de champs |
| `space16` | 16 px | Padding standard de conteneur, séparation de sections légères |
| `space20` | 20 px | Padding horizontal standard des écrans mobiles (Safe margin) |
| `space24` | 24 px | Espacement entre blocs majeurs, padding de modals |
| `space32` | 32 px | Espacement inter-sections du tableau de bord |
| `space40` | 40 px | Aération haute des écrans héroïques |
| `space48` | 48 px | Hauteur tactile minimale recommandée (Touch target WCAG) |

---

## 5. Rayons de Courbure (Radius Tokens)

| Token | Rayon | Usage |
| :--- | :--- | :--- |
| `radiusSmall` | 6 px | Badges discrets, puces de filtres |
| `radiusMedium` | 12 px | Boutons d'action, champs de texte, cartes d'options QCM |
| `radiusLarge` | 16 px | Cartes de chapitres, blocs pédagogiques de leçons |
| `radiusXLarge` | 24 px | Feuilles modales basses (Bottom Sheets), cartes héroïques |
| `radiusFull` | 999 px | Avatars ronds, badges XP en pastille, boutons flottants |

---

## 6. Ombres & Élévation (Shadows)

Les ombres doivent être extrêmement subtiles pour préserver le framerate à 60 FPS sur les processeurs d'entrée de gamme :

- **Élévation 0 (Flat) :** Fond et bordure `border` (style par défaut pour 90% des cartes).
- **Élévation 1 (Card Hover / Accent) :** `BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))`.
- **Élévation 2 (Modal / Bottom Sheet) :** `BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, -4))`.
- **Lueur Accent (Subtle Glow) :** Réservée exclusivement aux bannières clés : `BoxShadow(color: accentPrimary.withOpacity(0.2), blurRadius: 16, offset: Offset(0, 4))`.

---

## 7. Système d'Iconographie

Un pack unique et cohérent : **Material Icons Rounded** (forme adoucie, moderne et conviviale pour élèves).

- **Navigation & Actions :** 24 px (touch target minimum 48x48 px).
- **En-têtes & Matières :** 28 px.
- **Badges & Statuts :** 14 à 16 px.
- **Motif d'arrière-plan thématique :** 96 à 130 px avec opacité $\le 0.14$.

---

## 8. Composants d'Interface Partagés

### 8.1 Boutons Standardisés (`AppButton`)
- **Primaire (`AppButton.primary`) :** Fond `accentPrimary` (Cyan/Bleu), texte noir (contraste maximal), bord arrondi 12 px, hauteur 48 px.
- **Secondaire (`AppButton.secondary`) :** Fond `surface`, bordure `border`, texte `textPrimary`.
- **Succès (`AppButton.success`) :** Fond `accentEmerald`, pour valider une réponse ou terminer un exercice.
- **Action Légère / Ghost (`AppButton.ghost`) :** Pas de fond, texte `accentPrimary`, pour les actions de retour ou passer une étape.

### 8.2 Champs de Saisie (`AppInput`)
- Fond `card`, bordure `border` (1 px) passant à `accentPrimary` (2 px) en focus.
- Hauteur de champ confortable (minimum 48 px).
- Affichage clair des erreurs en rouge sous le champ, sans décaler la mise en page.

### 8.3 Composant d'État Vide (`EmptyStateView`)
- Remplace les textes bruts "Aucune donnée".
- Affiche une grande icône douce (48 px), un titre clair, une explication rassurante et un bouton d'action explicite (ex : "Choisir une matière pour commencer").

### 8.4 Barre d'Action Inférieure Mobile-First (`StudentBottomBar`)
- 5 onglets fixes :
  1. 🏠 **Accueil**
  2. 📖 **Cours**
  3. ✏️ **Exercices**
  4. 🤖 **Tuteur IA**
  5. 👤 **Profil**
- Hauteur 64 px avec `SafeArea`. Icône active avec indicateur lumineux coloré.

---

## 9. Blocs Pédagogiques de Cours (`PedagogicalBlocks`)

Le modèle `ContentBlock` est rendu à travers des cartes sémantiques distinctives :

1. **Théorème Majeur (`theoreme`) :** Bordure gauche émeraude/cyan 4 px, icône `verified_rounded`, titre distinct, formules centrées.
2. **Définition Formelle (`definition`) :** Bordure indigo 4 px, icône `menu_book_rounded`, texte rigoureux.
3. **Formule Mathématique / Scientifique (`formule`) :** Conteneur dédié avec défilement horizontal fluide si formule longue, fond contrasté.
4. **Méthode & Savoir-Faire (`methode`) :** Bordure ambre 4 px, icône `lightbulb_outline_rounded`, étapes numérotées.
5. **Exemple Concret (`exemple`) :** Bordure violette 4 px, icône `auto_awesome_rounded`, cas pratique d'application.
6. **Piège d'Examen (`piege`) :** Fond rosé foncé, bordure rouge 4 px, icône `warning_amber_rounded`, alerte sur l'erreur fréquente des correcteurs.
7. **Conseil d'Examen (`conseil_examen`) :** Bordure cyan 4 px, icône `tips_and_updates_rounded`, astuce de gestion du temps ou de rédaction.

---

## 10. Blocs d'Exercices & Feedback de Correction

1. **Énoncé (`ExerciseStatement`) :** Typographie 17 px SemiBold, aérée et lisible.
2. **Indices Progressifs (`ExerciseHintCard`) :** Révélation d'un indice à la fois avec bouton "Indice suivant" sans pénalité excessive.
3. **Options QCM (`QuizOptionTile`) :** Carte avec lettre d'option (A, B, C, D) dans une pastille circulaire, contour s'illuminant au toucher.
4. **Feedback de Correction (`CorrectionCard`) :**
   - Si juste : célébration verte avec explication confirmative.
   - Si faux : décomposition bienveillante en 3 temps :
     - *Ce que tu as répondu*
     - *La bonne démarche*
     - *Le concept clé à revoir*
   - Bouton contextuel : **"Demander au Tuteur IA de m'expliquer autrement"**.

---

## 11. Principes de Mouvement & Micro-Animations

- **Durée courte (Micro-interactions) :** 150 ms à 200 ms (`Curves.easeOutCubic`) pour le tap sur un bouton ou le choix d'une option.
- **Durée moyenne (Transitions de pages / Modals) :** 250 ms à 300 ms (`Curves.easeOutQuad`).
- **Motif d'arrière-plan continu :** Flottement lent et reposant (durée 5 secondes, balancement de 6 px max) sans consommation CPU excessive.
- **Reduced Motion :** Désactivation automatique des animations continues si l'accessibilité système l'exige.
