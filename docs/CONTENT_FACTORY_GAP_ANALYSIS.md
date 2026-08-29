# Content Factory — Gap Analysis (2026-08-28)

> Portée : couche Content Factory + Agents IA du nouveau pack de gouvernance, comparée à l'état réel
> confirmé dans `docs/AUDIT_REPORT.md`. Colonnes conformes à `PROMPT_MAITRE_VIBE_CODING_ELEARNING.md`.

| Fonctionnalité | Existe | Partiel | Absent | Fichiers réels | DB réelle | Action | Risque |
|---|---|---|---|---|---|---|---|
| Catalogue pédagogique par matière (U2.2, §16.0) | | X | | `admin_app/.../content_management/screens/pedagogical_catalog_screen.dart` | table catalogue (nom exact à confirmer en lisant les migrations `content_catalog`) | Vérifier versioning + duplication vers matière proche avant d'y toucher | Faible — additif |
| Workflow de validation (§2.5) | X | | | `.../content_management/screens/validation_queue_screen.dart` | `validation_queue` | Réutiliser tel quel pour Content Factory, ne pas recréer | Faible |
| Structured Content (blocs typés, `renderer_key`) (U2.1, U2.3) | | | X | aucun trouvé | à confirmer (probable colonne texte/JSON ad hoc dans `lessons`) | Lire le schéma réel `lessons`/`chapters` avant de concevoir CF-001 | Moyen — cœur du chantier |
| Template Registry / Renderer Registry (U2.3) | | | X | aucun | — | Créer un registre Flutter (`renderer_key -> Widget`) + schéma de blocs | Moyen |
| Block Editor Admin + preview | | | X | `lessons_manager_screen.dart` existe mais éditeur probablement texte simple, pas blocs typés | — | À concevoir après le modèle de contenu structuré | Moyen |
| Exercise Factory — cœur (génération → admin → élève) | X | | | `exercises_manager_screen.dart`, `ai-exercise-generation`, `Exercise.fromJson` (student_app) | `exercises` (`instructions_json`/`solution_json`) | Aucune — vérifié réellement câblé de bout en bout (CF-003, 2026-08-28), pas de bug comme sur les leçons | Faible |
| Exercise Factory — enrichissement U2.4 (hints/skills/prerequisites/provenance/duplicate detector) | | | X | — | — | Choix produit à trancher avec le porteur de projet avant migration (taxonomie compétences, seuil doublon) | Faible — reporter, pas de dette cachée |
| Agents IA — DocumentStructuringAgent / ExerciseAgent / ModerationAgent (versions basiques) | X | | | `ai-course-structuring`, `ai-exercise-generation`, `ai-moderation` (edge functions) | `ai_agent_calls`, `ai_content_review` | Faire évoluer vers le contrat standard (§4 cahier Agents IA) plutôt que remplacer | Faible si additif |
| TutorAgent complet (RAG + Student Model + tools + enveloppe standard) [IA-007, FAIT 2026-08-29] | X | | | `gateway/app/agents/tutor_agent.py`, `gateway/app/student_model/`, `ai-tutor-chat` v1.1.0 (étendu additivement) | `skills`, `skill_prerequisites`, `exercise_skills`, `exercise_attempts`, `ai_tutor_cache` (migration 64), seed du chapitre test (migration 65), registre v1.1.0 (migration 66) | Aucune — voir note IA-007 ci-dessous pour le détail de ce qui est réellement vérifié vs bloqué par un quota externe | Faible |
| RAG — pipeline complet (ingestion + recherche par similarité) [IA-004, FAIT 2026-08-29] | X | | | `gateway/app/rag/`, `supabase/functions/ai-embeddings-generate` | `ai_rag_sources`, `ai_rag_ingestions`, `ai_rag_chunks`, `vector` (migration 56), RPC `match_rag_chunks` (migration 59), tool `rag_search` (migration 60) | Aucune — vérifié bout en bout : ingestion réelle de la leçon publiée (6 chunks, 768 dims), recherche sémantique correcte (similarité 0.78 sur la requête la plus pertinente), filtrage de périmètre confirmé | Faible — tout tourne dans la stack Supabase + Gateway locale déjà en place |
| Agent Registry / Tool Registry (ADM-AI-001/002) [IA-001, FAIT 2026-08-29] | X | | | `ai_agent_registry_screen.dart`, `fetchAiAgents` | `ai_agents`, `ai_agent_versions`, `ai_tools`, `ai_agent_tools` (migration 55) | Aucune — 5 agents réels enregistrés avec leur vrai contrat I/O | Faible |
| Tool Gateway — curriculum/contenu/math (§12) [IA-003, FAIT 2026-08-29] | X | | | `gateway/app/tools/` (`get_curriculum_context`, `search_validated_content`, `sympy_solve`) | `ai_tools` (migration 57) | Aucune — 3 tools réels testés avec de vraies données. `ai_agent_tools` reste vide : aucun agent réel n'appelle encore ces tools (branchement = IA-007) | Faible — voir note sécurité ci-dessous |
| Model Router — abstraction par capability (§5) [IA-005, FAIT 2026-08-29] | X | | | `gateway/app/model_router/`, `supabase/functions/ai-generate-text` | `ai_agents`/`ai_agent_versions` (migration 61) | Aucune — vérifié réellement (pedagogy_small : Gemini, réponse correcte) | Faible |
| **Claude retiré du projet [2026-08-29, décision explicite du porteur de projet].** `ANTHROPIC_API_KEY` n'avait jamais été configurée — Claude n'a donc jamais réellement fonctionné, malgré ce que le code et l'UI admin affichaient (« Structurer avec l'IA (Claude) »). Code mort supprimé dans les 4 fonctions concernées + Model Router ; libellés admin corrigés ; registre IA-001 mis à jour (migration 62). Gemini est désormais le seul fournisseur réel du projet, partout, honnêtement affiché comme tel. | | | | | | | |
| Content Factory agents (§7) [IA-008, FAIT partiellement 2026-08-29] | | X | | `gateway/app/agents/{curriculum_mapping,pedagogical_validation}.py`, `ai-document-structuring` | `ai_agents` (AIA-AGT-014/015/016/017/024, migration 67) | Aucune pour les 3 construits (016/017/024) — vérifiés réellement. OCRAgent/FormulaRecognitionAgent (014/015) différés faute d'infra vision (`status='draft'`, honnête) | Faible pour ce qui est construit ; OCR reste un vrai pivot d'infra si activé un jour |
| Quota Engine / Entitlements IA (§6, U7) [IA-006, FAIT 2026-08-29] | X | | | `gateway/app/quota.py` | `ai_policies`, `ai_entitlements`, `ai_usage_ledger` (migration 63) | Aucune — vérifié bout en bout : invocation réelle de AIA-AGT-001 (profil `b519ff5d-...`, tier `gratuit`) → vraie ligne `ai_usage_ledger` avec `policy_key='FREE'`, `units_consumed=1002` (tokens réels lus dans `ai_agent_calls`, pas estimés). Toujours pas d'application de plafond — `allowance_units` reste NULL partout, conforme à l'interdiction du cahier de fixer un chiffre avant benchmark | Faible — traçage seulement, aucun risque de blocage utilisateur prématuré |
| Sovereign AI Gateway minimal (auth/permissions/request IDs/observabilité) [IA-002, FAIT 2026-08-29] | X | | | `gateway/` (FastAPI, Python — premier service Python du projet, Python installé sur la machine développeur pour l'occasion) | `ai_agent_calls` (réutilisée, `provider='gateway'`) | Aucune — vérifié end-to-end en local avec un vrai appel proxié vers AIA-AGT-001 (Tuteur Numérique) | Faible — tourne en local, pas encore d'hébergement dédié |
| Agent Orchestrator (LangGraph) / modèles auto-hébergés (vLLM/Ollama) / Compute Scheduler | | | X | aucun | aucune | **C'est la partie qui exige réellement un nouvel hébergement durable** (service persistant, potentiellement GPU pour un modèle local) — distinct de la Gateway elle-même (IA-002, faite, tourne en local sans GPU). U6 du cahier autorise « machine développeur » comme premier nœud légitime, mais une exécution ad hoc via un process en arrière-plan n'est pas une dépendance de production garantie (le cahier le dit explicitement) | Élevé si présenté comme une solution de production sans decision d'hébergement durable explicite |
| Observabilité IA (traces, coûts, latence par run) (§15) | | X | | `ai_agent_calls` capture au moins un usage basique | `ai_agent_calls` | Étendre progressivement plutôt que construire tout `ai_runs`/`ai_tool_calls` d'un coup | Faible |

**IA-008 (2026-08-29) — Content Factory agents.** Décision explicite du porteur de projet : différer
OCRAgent (AIA-AGT-014) et FormulaRecognitionAgent (AIA-AGT-015) — exigent un vrai moteur de vision
(OpenCV/PaddleOCR auto-hébergé, nommés par le cahier), aucune infra de ce type n'existe ; enregistrés en
`status='draft'` dans le registre (honnête : catalogués, pas construits) plutôt que silencieusement
absents. Construits et vérifiés réellement :

- **DocumentStructuringAgent (AIA-AGT-016)** — nouvelle Edge Function `ai-document-structuring`.
  Différence volontaire avec `course_structuring` (existant) : celui-ci SEGMENTE un texte source déjà
  écrit sans inventer de contenu (chaque bloc porte un `source_excerpt` littéral, vérifié mécaniquement
  contre le texte source — un bloc non traçable est rétrogradé en ambiguïté, pas silencieusement gardé).
  Testé avec un vrai texte SVT (relief terrestre) : 4 blocs corrects (paragraph/definition/
  theoreme/piege), tous traçables, confidence 0.98, 0 ambiguïté.
- **CurriculumMappingAgent (AIA-AGT-017)** — `gateway/app/agents/curriculum_mapping.py`, Gateway-native
  (pas d'appel LLM : recherche sémantique sur le corpus RAG déjà ingéré + matcher lexical sur
  chapters/skills, échelle réelle du projet). Bug trouvé et corrigé en testant : la comparaison lexicale
  ignorait les accents ("theoremes" ne matchait pas "théorèmes") — corrigé par normalisation Unicode
  (NFD + suppression des marques diacritiques) appliquée symétriquement à l'entrée et aux stopwords.
  Re-testé après correction : rattachement correct au chapitre réel avec confidence 1.0, compétences
  correctement identifiées.
- **PedagogicalValidationAgent (AIA-AGT-024)** — `gateway/app/agents/pedagogical_validation.py`,
  Gateway-native, déterministe (structure des blocs, rattachement curriculaire, détection de contenu
  factice/mock, vérification symbolique best-effort des formules). Testé sur la leçon test réelle : a
  correctement détecté `_mock: true` et l'a remonté en `blocking_issue` car la leçon est publiée —
  un vrai problème que rien ne signalait avant.
- Sécurité : les deux agents Gateway-native sont réservés admin (`user.is_admin`) — testé et confirmé
  (403 pour un compte élève).

Registre : migration 67, `ai_agent_tools` lié (`rag_search` pour AIA-AGT-017, `sympy_solve` pour
AIA-AGT-024).

**IA-009 (2026-08-29) — Exercise vertical slice.** ExerciseAgent (AIA-AGT-004) était déjà réel (CF-003).
Construit et vérifié : **CorrectionAgent (AIA-AGT-005)**, nouveau — `gateway/app/agents/
correction_agent.py`, Gateway-native (appelle `ai-generate-text` via le Model Router IA-005, pas de
nouvelle Edge Function). Ne traite que `reponse_courte`/`redaction` (le QCM a déjà une correction
déterministe exacte, testé : rejet propre avec message clair). Respecte la règle explicite du cahier
(« séparer machine_score/confidence/feedback et official_grade ») : écrit uniquement les colonnes
`ai_score`/`ai_confidence`/`ai_feedback`/`ai_misconceptions`/`needs_human_review` (migration 68),
**jamais** `official_correct`.

**Validation humaine réelle** : nouvel endpoint `POST /v1/exercise-attempts/{id}/review` (admin
uniquement, RLS + vérification applicative) qui pose `official_correct`/`reviewed_by`/`reviewed_at` —
c'est le SEUL chemin qui écrit une note officielle. `reviewed_by` résout le vrai `admin_users.id` de
l'appelant (a nécessité d'exposer `admin_user_id` sur `AuthenticatedUser`, absent avant).

**Persistance élève réelle** : `exercise_attempts.submitted_answer` (JSONB, déjà utilisé par
`recordExerciseAttempt` côté `student_app`, IA-007) est la source lue par CorrectionAgent — aucune
nouvelle table élève nécessaire.

Vérifié réellement, pas relu :
- Insertion d'une vraie tentative `reponse_courte` (RLS élève réelle) avec une réponse substantielle →
  CorrectionAgent appelé → score/confiance/feedback pédagogique cohérents renvoyés par Gemini, écrits en
  base, `official_correct` resté `null`.
- Validation humaine : admin pose `official_correct=true` → `reviewed_by`/`reviewed_at` réels écrits ;
  un élève tentant la même requête reçoit 403.
- Garde-fou format : une tentative QCM envoyée à CorrectionAgent est rejetée avec un message clair
  (« a déjà une correction déterministe »), pas silencieusement acceptée.

**Différé consciemment** (pas construit dans cette passe, pour rester dans le périmètre d'un vertical
slice) : déduplication d'exercices par embeddings (mentionnée dans le workflow ExerciseAgent du cahier)
— à construire si un vrai volume d'exercices apparaît (6 exercices fixtures aujourd'hui, prématuré).

## Lecture

Le seul écart **structurel bloquant** avant de coder quoi que ce soit est **Structured Content /
Template-Renderer Registry** : c'est le socle sur lequel tout le reste de la Content Factory (Block Editor,
rendu élève, PDF, offline, génération IA) doit s'appuyer selon U2 et le cahier technique Content Factory.
C'est donc la première tâche réelle (CF-001), après confirmation du schéma actuel de `lessons`/`chapters`/
`exercises`.

**Mise à jour 2026-08-29** (le porteur de projet a demandé de reprendre ce chantier en suivant
strictement l'ordre IA-000...IA-014 du cahier, §22) : Agent Registry (IA-001), Gateway minimale
(IA-002), Tool Gateway (IA-003), RAG complet (IA-004), Model Router (IA-005) et Quota Engine (IA-006)
sont faits — aucun n'exigeait de nouvelle infrastructure durable au-delà de Python installé localement,
contrairement à l'hypothèse initiale de ce document. Seuls l'Agent Orchestrator (LangGraph), les
modèles auto-hébergés et le Compute Scheduler restent un vrai pivot d'hébergement, et restent différés
en attendant une décision explicite. Claude a été entièrement retiré le même jour (voir ligne dédiée
ci-dessus) — Gemini est l'unique fournisseur réel.

**IA-006 (2026-08-29)** : le Quota Engine trace désormais l'usage réel dans `ai_usage_ledger` à chaque
appel `/v1/agents/{agent_id}/invoke`, avec l'entitlement réel du profil (résolu depuis
`subscription_tier`) et les tokens réellement consommés (relus dans `ai_agent_calls`, jamais estimés).
Aucun plafond n'est encore appliqué — `allowance_units` reste NULL sur les 7 policies tant qu'aucun
benchmark réel n'a fixé de chiffre, conformément à l'interdiction explicite du cahier (§2 règle 10).
Prochaine étape naturelle du §22 : IA-007 (premier vertical slice, TutorAgent complet avec RAG + tool
math + lecture Student Model + cache + quota + observabilité — les briques existent déjà séparément).

**IA-007 (2026-08-29) — TutorAgent, vertical slice complet.** Choix explicite du porteur de projet :
construire le Student Model **complet** (U9 : Competency Graph + Student Model + Learning Orchestrator +
Mastery Engine), pas une version minimale ni un report. Constat honnête avant de coder : AUCUNE table de
tentative d'exercice n'existait (`exercise_runner_screen.dart` ne persistait rien), et les 6 seuls
exercices + la seule leçon déjà en base sont des fixtures de développement CF-003/CF-001 (« Énoncé généré
factice », `content_json._mock = true`) — le Mastery Engine est donc réel et fonctionnel, mais sans corpus
pédagogique réel pour l'instant (même situation que le RAG en IA-004).

Construit : `skills`/`skill_prerequisites` (Competency Graph), `exercise_attempts` (preuve d'apprentissage
— comblait un vrai trou), `get_student_skill_mastery` (Mastery Engine, RPC recalculée à la demande,
jamais stockée), `gateway/app/student_model/orchestrator.py` (Learning Orchestrator, règle déterministe :
prochaine compétence non maîtrisée dont les prérequis le sont), `gateway/app/agents/tutor_agent.py`
(orchestration RAG + math tool heuristique + Student Model + cache `ai_tutor_cache`, branchée dans
`POST /v1/agents/AIA-AGT-001/invoke`), `ai-tutor-chat` étendu de façon additive (rétrocompatible avec
l'écran élève existant) pour accepter le contexte construit par la Gateway.

**Corrections de sécurité faites au passage** (pas différées) : `verify_profile_access` (nouveau, dans
`gateway/app/auth.py`) — avant IA-007, rien ne vérifiait qu'un `profile_id` fourni dans une requête
appartenait réellement au compte authentifié (touchait déjà IA-006 silencieusement) ; testé et confirmé
bloquant (403) pour un profil d'un autre compte, sur `/invoke` et sur les nouveaux endpoints Student
Model. `math_tools.py` a aussi été corrigé pour accepter la multiplication implicite (« 5x », écriture
naturelle d'un élève) via `implicit_multiplication_application` de SymPy — re-testé avec le payload
d'injection original après ce changement, toujours rejeté (voir [[feedback_test_eval_tools_for_injection]]).

**Vérifié réellement, pas supposé :**
- Tool math déclenché par heuristique dans un vrai message ("Comment resoudre 5x-4=16...") → `sympy_solve`
  appelé, résultat exact (x=4) injecté dans `tool_trace_summary` de l'enveloppe.
- Cache : 2ᵉ appel identique → `usage.route="cache"`, aucun nouvel appel Gemini, `hit_count`
  incrémenté en base.
- Student Model + Learning Orchestrator : 2 vraies tentatives insérées (RLS élève réelle, pas
  service_role) → `mastery_level=0.5` correctement recalculé ; 3 tentatives supplémentaires →
  `mastery_level=0.8`, et la recommandation de compétence suivante bascule automatiquement de
  DEFINITIONS vers THEOREMES (son prérequis) — la chaîne Competency Graph → Student Model → Learning
  Orchestrator fonctionne de bout en bout avec de vraies données.
- RAG scopé matière/classe : `rag_search` direct confirmé (3 citations réelles, similarité 0.57-0.57 sur
  la leçon test).
- **Round-trip RAG-augmenté → réponse Gemini, re-testé avec succès après régénération du quota** (même
  session, plus tard) : citations réelles (3, similarité 0.57-0.59) + réponse Gemini qui utilise
  effectivement le contexte RAG injecté (a remarqué que le contenu ingéré porte en réalité sur les
  équations du second degré malgré l'étiquette SVT — preuve qu'il lit vraiment le contexte fourni, pas
  un artefact). Les 6 briques d'IA-007 sont donc toutes prouvées, y compris leur combinaison complète.

**Note sécurité (IA-003, 2026-08-29)** : la première implémentation de `sympy_solve` s'est révélée être
une vraie exécution de code arbitraire (testé et confirmé : une commande shell s'est réellement
exécutée sur la machine via l'expression `__import__("os").system(...)`). Corrigée avant tout commit
définitif — voir le commentaire de sécurité en tête de `gateway/app/tools/math_tools.py` pour le détail
technique complet. Retenue comme leçon générale : **tout futur tool acceptant une entrée texte libre et
la faisant passer dans un evaluateur (`eval`, `parse_expr`, template engine, etc.) doit être testé avec
un payload d'injection avant d'être considéré comme fait**, pas seulement avec des entrées légitimes.
