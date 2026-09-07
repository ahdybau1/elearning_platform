# ELEF Design System v2 — Spécifications et Tokens

## 1. Vision et Principes Directeurs
L'EDLEARN / ELEF Design System a été conçu pour en finir définitivement avec les interfaces génériques Material par défaut, les boîtes encombrantes (« touffu avec des box qui ne servent à rien ») et les incohérences stylistiques entre l'espace d'administration et l'application élève.

### Principes :
1. **Typographie d'Élite (Éditoriale & Scientifique)** : Utilisation de **GoogleFonts Outfit** pour les titres majeurs et display, **GoogleFonts Inter** pour la lecture au kilomètre et **GoogleFonts Fira Code** pour les formules, variables et blocs de code.
2. **Couleurs Sémantiques & Accents Disciplinaires** :
   - Mathématiques : Cyan 500 (`#06B6D4`)
   - Sciences Physiques : Ambre (`#F59E0B`)
   - Chimie : Émeraude (`#10B981`)
   - SVT / Biologie : Lime (`#84CC16`)
   - Informatique & NSI : Bleu (`#3B82F6`)
   - Français & Littérature : Violet (`#A855F7`)
   - Philosophie : Rose (`#EC4899`)
   - Sciences de l'Ingénieur / Technique : Orange (`#F97316`)
   - Commercial & Gestion : Teal (`#14B8A6`)
   - Génie Industriel : Slate (`#64748B`)
3. **Surfaces Hiérarchisées** : Dark mode profond (`#0A0F1D`, `#111827`, `#1E293B`, `#27354A`) évitant les fonds blancs agressifs et isolant naturellement les éléments sans bordures redondantes.
4. **Zéro Code Brut Côté Élève** : Rendu LaTeX mathématique vectoriel natif via `MathFormulaView` et `flutter_math_fork` (avec KaTeX et MathJax interchangeables).

---

## 2. Tokens Fondamentaux
- `ElefColors` (`admin_app/lib/core/design_system/tokens/elef_colors.dart`)
- `ElefTypography` (`admin_app/lib/core/design_system/tokens/elef_typography.dart`)
- `ElefSpacing` (`admin_app/lib/core/design_system/tokens/elef_spacing.dart`)
- `ElefRadius` (`admin_app/lib/core/design_system/tokens/elef_radius.dart`)
- `ElefElevation` (`admin_app/lib/core/design_system/tokens/elef_elevation.dart`)
- `ElefMotion` (`admin_app/lib/core/design_system/tokens/elef_motion.dart`)
- `ElefBreakpoints` (`admin_app/lib/core/design_system/tokens/elef_breakpoints.dart`)

---

## 3. Composants UI Universels
- `ElefButton` : Variantes `primary`, `secondary`, `outline`, `ghost`, `danger` avec tailles `sm`, `md`, `lg` et état de chargement natif.
- `ElefInput` & `ElefSearchField` : Champs formulaires avec validation visuelle et états de focus avec lueur.
- `ElefCard` : Conteneur avec 3 variantes (`elevated`, `outlined`, `filled`).
- `ElefBadge` & `ElefChip` : Badges disciplinaires subtils et interactifs.
- `ElefTabs` : Segments de navigation sans rechargement.
- `ElefEmptyState` : Affichage chaleureux et guidant en cas d'absence de contenu.

---

## 4. Composants Pédagogiques Haute Fidélité
- `ElefCallout` (`admin_app/lib/core/design_system/pedagogical/elef_callout.dart`) : Encadrés allégés pour définitions, théorèmes, formules, pièges d'examen, méthodes et conseils du professeur.
- `ElefSummarySheetCard` (`admin_app/lib/core/design_system/pedagogical/elef_summary_sheet_card.dart`) : Composant de reproduction **traits pour traits** des fiches mémos (ex: *Suites Numériques*), intégrant colonnes comparatives, formule générale centrale, puces méthodologiques et alerte piège du Bac.
