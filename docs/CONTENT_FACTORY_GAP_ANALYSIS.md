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
| Exercise Factory (structure complète : hints/skills/prerequisites/grading/provenance) | | X | | `exercises_manager_screen.dart`, `ai-exercise-generation` | `exercises` (cahier historique §36.3) | Vérifier colonnes réelles vs schéma cible U2.4 avant extension | Moyen |
| Agents IA — DocumentStructuringAgent / ExerciseAgent / ModerationAgent (versions basiques) | X | | | `ai-course-structuring`, `ai-exercise-generation`, `ai-moderation` (edge functions) | `ai_agent_calls`, `ai_content_review` | Faire évoluer vers le contrat standard (§4 cahier Agents IA) plutôt que remplacer | Faible si additif |
| TutorAgent complet (RAG + Student Model + tools + enveloppe standard) | | X | | `ai-tutor-chat`, `ai_tutor_chat_screen.dart` | aucune table Student Model dédiée confirmée | Chantier RAG + contrat requis avant d'appeler ça un « agent » au sens du cahier | Moyen |
| RAG (pgvector, ingestion, citations) | | | X | aucun | aucune (`pgvector` absent) | Nécessite migration `CREATE EXTENSION vector` + tables sources/chunks — à ne faire qu'après besoin réel confirmé (RAG est étape 8-9 dans U11, pas immédiate) | Moyen — nouvelle dépendance DB |
| Agent Registry / Prompt Registry / Tool Registry (ADM-AI-001 à 004) | | | X | aucun côté `admin_app` | aucune table `ai_agents`/`ai_prompts`/`ai_tools` | Différer jusqu'à ce qu'il y ait plus d'un agent à administrer réellement | Faible — reporter |
| Quota Engine / Entitlements IA (§6, U7) | | | X | aucun | aucune table `ai_policies`/`ai_entitlements`/`ai_usage_ledger` | Différer — le cahier interdit de coder les valeurs en dur avant benchmark, donc pas urgent | Faible — reporter |
| Compute Fabric / Model Router / Sovereign AI Gateway (Partie 3, U3, U6) | | | X | aucun (pas de service Python) | aucune | Différer explicitement à la fin (U11 étape 14) — décision d'infrastructure à valider avec l'utilisateur avant de commencer (nouvel hébergement hors Vercel/Supabase) | Élevé si démarré prématurément — ne pas commencer sans confirmation explicite |
| Observabilité IA (traces, coûts, latence par run) (§15) | | X | | `ai_agent_calls` capture au moins un usage basique | `ai_agent_calls` | Étendre progressivement plutôt que construire tout `ai_runs`/`ai_tool_calls` d'un coup | Faible |

## Lecture

Le seul écart **structurel bloquant** avant de coder quoi que ce soit est **Structured Content /
Template-Renderer Registry** : c'est le socle sur lequel tout le reste de la Content Factory (Block Editor,
rendu élève, PDF, offline, génération IA) doit s'appuyer selon U2 et le cahier technique Content Factory.
C'est donc la première tâche réelle (CF-001), après confirmation du schéma actuel de `lessons`/`chapters`/
`exercises`.

Les couches Agent Registry, Quota Engine et Compute Fabric sont volontairement classées « à différer » : le
pack lui-même (U11) les place en dernier, et les construire maintenant reviendrait à administrer un système
pour un seul agent réel (le tutor), ce qui contredit la règle « pas de faux tableau de bord ».
