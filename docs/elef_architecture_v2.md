# ELEF Architecture v2 — Moteurs Spécialisés & Studio Pédagogique

## 1. Principes d'Architecture (Conformes au Cahier des Charges Master)
1. **Séparation Déterministe vs LLM** : L'IA générative orchestre et reformule ; les calculs mathématiques, études de fonctions, simulations physiques et exécutions de code sont délégués à des moteurs déterministes spécialisés (`MathEngine`, `GraphEngine`, `SimulationEngine`, `CodeExecutionEngine`).
2. **Économie de Quota Distant & Zéro Dépendance Bloquante** : Cache intelligent SHA-256 / FNV-1a pour la génération d'images pédagogiques (`ImageGenerationEngine`), évitant toute requête dupliquée vers les fournisseurs d'IA.
3. **Modèle de Données Universel (`LessonBlock v2`)** :
   - Schéma standardisé supportant 18 types de blocs (académiques, interactifs, code, graphiques, fiches mémos).
   - Format canonique stocké dans `content_json['blocks']` dans la table `lessons` de PostgreSQL/Supabase, lu en temps réel par `student_app` via `BlockRendererRegistry`.

---

## 2. Inventaire des Moteurs Spécialisés
| Moteur | Fichier | Rôle Principal |
| :--- | :--- | :--- |
| `CapabilityRegistry` | `core/engines/capability_registry.dart` | Registre unifié des 9 capacités avec supervision, mode d'exécution (local/serveur) et fallbacks. |
| `MathEngine` | `core/engines/math_engine.dart` | Moteur déterministe pour polynômes, discriminant, racines, sommet, dérivées et équations de tangentes. |
| `GraphEngine` | `core/engines/graph_engine.dart` | Générateur de spécifications de courbes 2D avec calcul d'échantillons et asymptotes. |
| `SimulationEngine` | `core/engines/simulation_engine.dart` | Simulateur physique & chimique (Circuits RLC, orbitales moléculaires 3D, balistique). |
| `CodeExecutionEngine` | `core/engines/code_execution_engine.dart` | Bac à sable de programmation algorithmique (Python/Dart). |
| `ImageGenerationEngine` | `core/engines/image_generation_engine.dart` | Moteur de génération d'illustrations scientifiques avec cache FNV-1a anti-duplication. |

---

## 3. Nouveaux Écrans d'Administration (`admin_app`)
- **Studio de Cours v2 (`LessonBuilderScreen`)** :
  - Volet gauche : Bibliothèque de blocs hiérarchisée avec moteur de recherche.
  - Volet central : Canvas réordonnable avec édition directe et support des formules LaTeX.
  - Volet droit : Aperçu élève en temps réel (mobile 390px ou plein écran) affichant le cours **trait pour trait**.
  - Action rapide 1-clic : Génération immédiate de la **Fiche Synthèse Suites Numériques** (Arithmétique vs Géométrique).
- **Médiathèque & Générateur IA (`MediaLibraryScreen`)** :
  - Gestion des actifs médias disciplinaires.
  - Modale interactive de génération d'illustrations par IA avec affichage du cache hit (`⚡ 0 token consommés`).
- **Centre des Moteurs (`EngineCenterScreen`)** :
  - Tableau de bord de santé des moteurs scientifiques et du Capability Registry.
  - Lanceur de diagnostics intégrés avec vérification unitaire temps réel.

---

## 4. Modernisation de l'Application Élève (`student_app`)
- **`BlockRendererRegistry`** :
  - Support natif du type `summary_card` : affichage des fiches de synthèse sous forme de tableau comparatif haute définition sans boîte superflue.
  - Dé-cluttering des blocs existants : suppression des fonds blancs durs (`Colors.white`) et des doubles bordures, adaptation automatique aux tokens `context.colors.card` et `context.colors.textPrimary`.
  - Intégration transparente avec `MathFormulaView` pour le KaTeX et MathJax vectoriel.
