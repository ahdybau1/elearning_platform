# CAHIER TECHNIQUE — ADMIN AI CONTROL PLANE

L'Admin contrôle deux univers connectés : **Content Factory** (production pédagogique) et **AI Control Plane** (agents, modèles, RAG, compute, quotas, évaluations).

## Mapping ADM-077 à ADM-093
- ADM-077 Agents : registre, détail, builder/config, statut, canary, fallback.
- ADM-078 Prompts/Tools/Permissions : versions, allowlists, scopes, rollback.
- ADM-079 Models : registry, licences, benchmarks, adapters, Model Factory.
- ADM-080 RAG : sources, ingestion, chunks, index, versions.
- ADM-081 RAG Quality : console de recherche, citations, recall/precision proxy, erreurs.
- ADM-082 Evaluations : datasets, gates, A/B, canary, promotion/rollback.
- ADM-083 Infrastructure : Compute Fabric, nodes, jobs, cache, coûts, alertes/incidents.
- ADM-084 Learning Orchestrator : politiques de routage, fallback, quota-aware routing.
- ADM-085 Mastery Engine : paramètres pédagogiques versionnés, séparés des quotas IA.
- ADM-086 Analytics : usage, qualité, compute, économies cache/device, coûts.
- ADM-087 Fraud : signaux de quota/paiement/évaluation, jamais sanction automatique.
- ADM-088 Roles : AI_ADMIN, AI_ENGINEER, PEDAGOGICAL_AI_REVIEWER, RAG_MANAGER, COMPUTE_ADMIN, FINANCE_ADMIN, SUPPORT_ADMIN, AUDITOR.
- ADM-089 Audit : journal append-only des actions sensibles.
- ADM-090 Feature Flags : rollout 0/1/10/25/50/100%, kill switches.
- ADM-091 Languages/Accessibility : capacités modèles, traduction, voix, adaptations.
- ADM-092 Integrations : providers optionnels, compute nodes, connecteurs.
- ADM-093 Health/Jobs/Backups : santé, queues, sauvegarde/restauration modèles/RAG/config.

## Règle
L'Admin doit pouvoir comprendre la chaîne OFFER -> ENTITLEMENT -> QUOTA -> USER -> AGENT -> ROUTER -> RAG/TOOLS -> MODEL -> COMPUTE -> RESPONSE -> EVALUATION -> COST -> IMPROVEMENT, sans exposer de secrets ni autoriser d'action destructive non auditée.
