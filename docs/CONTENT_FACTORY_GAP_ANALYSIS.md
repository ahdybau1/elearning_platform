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
| TutorAgent complet (RAG + Student Model + tools + enveloppe standard) | | X | | `ai-tutor-chat`, `ai_tutor_chat_screen.dart` | aucune table Student Model dédiée confirmée | Chantier RAG + contrat requis avant d'appeler ça un « agent » au sens du cahier | Moyen |
| RAG — pipeline complet (ingestion + recherche par similarité) [IA-004, FAIT 2026-08-29] | X | | | `gateway/app/rag/`, `supabase/functions/ai-embeddings-generate` | `ai_rag_sources`, `ai_rag_ingestions`, `ai_rag_chunks`, `vector` (migration 56), RPC `match_rag_chunks` (migration 59), tool `rag_search` (migration 60) | Aucune — vérifié bout en bout : ingestion réelle de la leçon publiée (6 chunks, 768 dims), recherche sémantique correcte (similarité 0.78 sur la requête la plus pertinente), filtrage de périmètre confirmé | Faible — tout tourne dans la stack Supabase + Gateway locale déjà en place |
| Agent Registry / Tool Registry (ADM-AI-001/002) [IA-001, FAIT 2026-08-29] | X | | | `ai_agent_registry_screen.dart`, `fetchAiAgents` | `ai_agents`, `ai_agent_versions`, `ai_tools`, `ai_agent_tools` (migration 55) | Aucune — 5 agents réels enregistrés avec leur vrai contrat I/O | Faible |
| Tool Gateway — curriculum/contenu/math (§12) [IA-003, FAIT 2026-08-29] | X | | | `gateway/app/tools/` (`get_curriculum_context`, `search_validated_content`, `sympy_solve`) | `ai_tools` (migration 57) | Aucune — 3 tools réels testés avec de vraies données. `ai_agent_tools` reste vide : aucun agent réel n'appelle encore ces tools (branchement = IA-007) | Faible — voir note sécurité ci-dessous |
| Model Router — abstraction par capability (§5) [IA-005, FAIT 2026-08-29] | X | | | `gateway/app/model_router/`, `supabase/functions/ai-generate-text` | `ai_agents`/`ai_agent_versions` (migration 61) | Aucune — vérifié réellement (pedagogy_small : Gemini, réponse correcte) | Faible |
| **Claude retiré du projet [2026-08-29, décision explicite du porteur de projet].** `ANTHROPIC_API_KEY` n'avait jamais été configurée — Claude n'a donc jamais réellement fonctionné, malgré ce que le code et l'UI admin affichaient (« Structurer avec l'IA (Claude) »). Code mort supprimé dans les 4 fonctions concernées + Model Router ; libellés admin corrigés ; registre IA-001 mis à jour (migration 62). Gemini est désormais le seul fournisseur réel du projet, partout, honnêtement affiché comme tel. | | | | | | | |
| Quota Engine / Entitlements IA (§6, U7) [IA-006, FAIT 2026-08-29] | X | | | `gateway/app/quota.py` | `ai_policies`, `ai_entitlements`, `ai_usage_ledger` (migration 63) | Aucune — vérifié bout en bout : invocation réelle de AIA-AGT-001 (profil `b519ff5d-...`, tier `gratuit`) → vraie ligne `ai_usage_ledger` avec `policy_key='FREE'`, `units_consumed=1002` (tokens réels lus dans `ai_agent_calls`, pas estimés). Toujours pas d'application de plafond — `allowance_units` reste NULL partout, conforme à l'interdiction du cahier de fixer un chiffre avant benchmark | Faible — traçage seulement, aucun risque de blocage utilisateur prématuré |
| Sovereign AI Gateway minimal (auth/permissions/request IDs/observabilité) [IA-002, FAIT 2026-08-29] | X | | | `gateway/` (FastAPI, Python — premier service Python du projet, Python installé sur la machine développeur pour l'occasion) | `ai_agent_calls` (réutilisée, `provider='gateway'`) | Aucune — vérifié end-to-end en local avec un vrai appel proxié vers AIA-AGT-001 (Tuteur Numérique) | Faible — tourne en local, pas encore d'hébergement dédié |
| Agent Orchestrator (LangGraph) / modèles auto-hébergés (vLLM/Ollama) / Compute Scheduler | | | X | aucun | aucune | **C'est la partie qui exige réellement un nouvel hébergement durable** (service persistant, potentiellement GPU pour un modèle local) — distinct de la Gateway elle-même (IA-002, faite, tourne en local sans GPU). U6 du cahier autorise « machine développeur » comme premier nœud légitime, mais une exécution ad hoc via un process en arrière-plan n'est pas une dépendance de production garantie (le cahier le dit explicitement) | Élevé si présenté comme une solution de production sans decision d'hébergement durable explicite |
| Observabilité IA (traces, coûts, latence par run) (§15) | | X | | `ai_agent_calls` capture au moins un usage basique | `ai_agent_calls` | Étendre progressivement plutôt que construire tout `ai_runs`/`ai_tool_calls` d'un coup | Faible |

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

**Note sécurité (IA-003, 2026-08-29)** : la première implémentation de `sympy_solve` s'est révélée être
une vraie exécution de code arbitraire (testé et confirmé : une commande shell s'est réellement
exécutée sur la machine via l'expression `__import__("os").system(...)`). Corrigée avant tout commit
définitif — voir le commentaire de sécurité en tête de `gateway/app/tools/math_tools.py` pour le détail
technique complet. Retenue comme leçon générale : **tout futur tool acceptant une entrée texte libre et
la faisant passer dans un evaluateur (`eval`, `parse_expr`, template engine, etc.) doit être testé avec
un payload d'injection avant d'être considéré comme fait**, pas seulement avec des entrées légitimes.
