# Audit Report — EDLEARN (2026-08-28)

> Produit selon le skill `project-audit` du pack de gouvernance reçu ce jour (voir `MANIFEST.md`,
> `.agents/AGENTS.md`). Portée : état réel du repo par rapport à la nouvelle couche « Agents IA / Content
> Factory / Vibe Coding » (`docs/CAHIER_DES_CHARGES_AGENTS_IA.md`, section U1-U12 de
> `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`, cahiers techniques). Le reste de l'application (académique,
> abonnements, examens, communauté, espace parent...) est déjà couvert par les addenda datés au fil de
> `docs/cahier_des_charges.md` et n'est pas ré-audité ligne à ligne ici — seuls les faits nécessaires au
> périmètre IA/Content Factory sont vérifiés.

## 1. Ce qui vient d'être fait (avant cet audit)

Le pack de gouvernance fourni par l'utilisateur (`AGENTS.md`, 5 cahiers, `CLAUDE.md`, `MANIFEST.md`,
`PROMPT_MAITRE_VIBE_CODING_ELEARNING.md`, `README_START_HERE.md`, 29 `SKILL.md`) a été installé tel quel
dans le repo :

- `.agents/AGENTS.md` + `.agents/skills/*/SKILL.md` (29 skills).
- `CLAUDE.md`, `MANIFEST.md`, `PROMPT_MAITRE_VIBE_CODING_ELEARNING.md`, `README_START_HERE.md` (racine).
- `docs/CAHIER_DES_CHARGES_AGENTS_IA.md`, `docs/CAHIER_TECHNIQUE_ADMIN_AI_CONTROL_PLANE.md`,
  `docs/CAHIER_TECHNIQUE_CONTENT_FACTORY.md`, `docs/CAHIER_TECHNIQUE_FRAMEWORKS_OUTILS_IA.md`,
  `docs/CAHIER_TECHNIQUE_QUOTAS_COMPUTE.md`.
- `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md` : copie fidèle de `docs/cahier_des_charges.md` (le journal
  vivant déjà utilisé par ce projet, avec ses addenda datés réels) + la section « MISE À JOUR 2026 » (U1-U12)
  apportée par le pack. `docs/cahier_des_charges.md` reste le fichier à modifier en premier ; le MASTER_MAJ
  doit être resynchronisé après toute modification substantielle (noté en tête de ce fichier).

Aucun code applicatif n'a été modifié à cette étape — uniquement de la documentation/gouvernance, conforme
à la règle « ne jamais modifier de code pendant l'audit ».

## 2. Stack réelle confirmée (pas supposée)

- **Flutter** : deux apps distinctes, `student_app/` et `admin_app/`, chacune `lib/{core,features}` +
  `main.dart`. Pas de FastAPI, pas de service Python, pas de LangGraph, pas de vLLM/Ollama/llama.cpp dans
  le repo à ce jour — la « Sovereign AI Gateway » du cahier IA (Partie 3) est un **objectif cible**, pas un
  état actuel.
- **Backend** : Supabase (Postgres + RLS + Auth) — **51 migrations** numérotées (`01_...` à `52_...`, avec un
  trou historique déjà documenté en mémoire projet). Logique serveur via **9 Supabase Edge Functions Deno**
  (`supabase/functions/`) : 4 de création de compte (`admin-create-*`), `payment-webhook`,
  `cron-subscription-reminders`, et **4 fonctions IA déjà réelles** : `ai-catalog-types-generation`,
  `ai-course-structuring`, `ai-exercise-generation`, `ai-moderation`, plus `ai-tutor-chat` (le « Tuteur
  Numérique » élève, Gemini `gemini-3.6-flash`, confirmé fonctionnel en production ce mois-ci — voir mémoire
  projet).
- **Aucune dépendance IA payante obligatoire actuellement** : les 3 fonctions `ai-catalog-types-generation`,
  `ai-course-structuring`, `ai-exercise-generation` déclarent un `AI_MOCK_MODE` explicite (`Deno.env.get(...)
  === "true"`), commenté « jamais un comportement silencieux » — cohérent avec la contrainte #10 du cahier
  Agents IA et la règle qualité (pas de faux succès). `ai-moderation` et `ai-tutor-chat` n'ont **pas** ce
  garde-fou `AI_MOCK_MODE` — à corriger si un mode dégradé sans clé API doit y être ajouté (actuellement ils
  échoueront simplement si `GEMINI_API_KEY` est absente, ce qui est honnête mais pas gracieux).
- **Toutes ces fonctions IA appellent directement Claude/Gemini depuis Deno**, sans Model Router, sans
  capability abstraite (`classification_small`, `pedagogy_small`...), sans contrat d'enveloppe JSON standard
  (§4 du cahier Agents IA), sans RAG, sans quota engine, sans ledger d'usage append-only. Elles ressemblent
  chacune à un agent unitaire codé en dur plutôt qu'à un système orchestré partagé.

## 3. Ce qui existe déjà et se rapproche du vocabulaire du nouveau pack

| Concept du nouveau pack | Équivalent réel trouvé | État |
|---|---|---|
| `content_catalog` / Catalogues pédagogiques (U2.2, §16.0) | `admin_app/.../content_management/screens/pedagogical_catalog_screen.dart` + table(s) catalogue en DB | Existe côté Admin, à vérifier si versionné/duplicable comme l'exige U2.2 |
| Workflow de validation (§2.5, U2.1) | `admin_app/.../content_management/screens/validation_queue_screen.dart`, table `validation_queue` (cahier historique §36.3) | Existe, workflow réel déjà en place pour cours/exercices |
| `ai_agent_calls` / suivi coûts (§16.5, ancien §36.9) | `supabase/migrations/03_schema_community_admin_ai.sql` → `CREATE TABLE ai_agent_calls`, `ai_content_review` | Existe mais correspond au **modèle de données de l'ancien cahier** (2 tables), pas aux 24 tables `ai_*` ciblées par la section 17 du nouveau cahier Agents IA (`ai_agents`, `ai_runs`, `ai_rag_chunks`, `ai_policies`, `ai_usage_ledger`...) |
| TutorAgent (AIA-AGT-001) | `ai-tutor-chat` (edge function) + `ai_tutor_chat_screen.dart` (élève, « Tuteur Numérique ») | Version rudimentaire seulement : appel direct Gemini, pas de RAG, pas de Student Model, pas de tools (`sympy_solve` etc.), pas d'enveloppe I/O standard, pas de citations obligatoires, pas de quota |
| ExerciseAgent (AIA-AGT-004) | `ai-exercise-generation` (edge function) + `exercises_manager_screen.dart` | Génère des exercices bruts vers la queue de validation ; pas de duplicate detector, pas de solveur indépendant de vérification (SymPy), pas de classification de difficulté automatique documentée |
| DocumentStructuringAgent (AIA-AGT-016) | `ai-course-structuring` (edge function) + `lessons_manager_screen.dart` | Structure un cours depuis un texte source ; pas de pipeline OCR/FormulaRecognition en amont détecté dans le repo (à confirmer : aucune dépendance OpenCV/PaddleOCR trouvée) |
| ModerationAgent (AIA-AGT-020) | `ai-moderation` (edge function) | Existe, branché sur Gemini ; scope exact (forum uniquement ? champ libre ?) non vérifié dans cet audit |
| RAG (pgvector, section 10) | Aucun | `pgvector` introuvable dans les migrations (`grep vector` → 0 résultat). Pas de table `*_chunks`/`*_embeddings`. **Absent intégralement.** |
| Agent Registry / Model Router / Quota Engine / Compute Fabric (§9, U3, U6, U8) | Aucun | Absent intégralement — aucune table, aucun service, aucune UI Admin correspondante. |
| Structured Content / Template-Renderer Registry (U2.3) | Aucun système générique détecté ; cours/exercices probablement stockés en colonnes texte/JSON ad hoc (à confirmer via lecture des migrations `lessons`/`exercises` avant CF-001) | Probablement absent sous la forme `renderer_key` générique exigée |

## 4. Écart structurel principal

Le nouveau pack décrit une architecture cible à deux étages (Local Task Router Flutter + Sovereign AI
Gateway FastAPI/LangGraph/vLLM) alors que le projet réel est aujourd'hui **Flutter + Supabase Edge Functions
uniquement**, sans service Python, sans hébergement de modèles open-weight, sans Compute Fabric. Construire
la Gateway complète serait un chantier d'infrastructure majeur et distinct (nouveau runtime, nouvel
hébergement — non couvert par la stack Vercel + Supabase actuelle).

Le pack lui-même anticipe cet écart : U11 place explicitement le Model Router/Compute Fabric/Model Factory
**en dernier** (étape 14), après le modèle de contenu structuré, les catalogues, le Template/Renderer
Registry, l'import, l'Exercise Factory et la génération de cours (étapes 5 à 13, toutes réalisables dans la
stack actuelle Flutter + Supabase). C'est donc l'ordre à suivre — pas de pivot d'infrastructure prématuré.

## 5. Risques identifiés

- **Doublon de modèle de données IA** : le nouveau cahier propose 24 tables `ai_*` alors que 2 existent déjà
  (`ai_agent_calls`, `ai_content_review`). Toute migration future doit **étendre**, pas dupliquer — vérifier
  nommage avant `CREATE TABLE`.
- **Numérotation des migrations** : déjà un précédent de collision cette session (`49_...` dupliqué, corrigé
  en `51_`/`52_`). Toujours vérifier `ls supabase/migrations | sort` avant de nommer une nouvelle migration.
- **Référence documentaire morte** : les 4 fonctions IA existantes citent un fichier `docs/06_ai_pipeline.md`
  en commentaire (« voir 06_ai_pipeline.md ») qui n'existe pas dans le repo actuel — soit perdu lors d'un
  nettoyage antérieur, soit jamais créé. À recréer ou à corriger la référence lors du prochain travail sur
  ces fonctions, pour ne pas laisser une note trompeuse dans le code.
- **`ai-moderation` et `ai-tutor-chat` sans `AI_MOCK_MODE`** : contrairement aux 3 autres fonctions IA, pas
  de mode dégradé explicite documenté — à examiner si un vrai mode offline/dégradé est requis pour elles
  (le tutor a un usage élève direct, donc plus sensible à une panne Gemini que la génération admin).

## 6. Non couvert par cet audit (à faire avant d'aller plus loin si besoin)

- Lecture ligne à ligne des schémas exacts des tables `lessons`/`exercises`/`chapters` (nécessaire avant
  CF-001, voir plan d'implémentation).
- Audit du reste de l'application (académique, abonnements, examens officiels, forum, boutique...) : déjà
  couvert par les sessions précédentes et les addenda de `docs/cahier_des_charges.md` — non repris ici pour
  rester dans le périmètre du nouveau pack.
- Tests automatisés existants (aucun répertoire `test/` inspecté dans cette passe).
