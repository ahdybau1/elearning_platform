# CAHIER TECHNIQUE â ADMIN AI CONTROL PLANE

L'Admin contrÃ´le deux univers connectÃ©s : **Content Factory** (production pÃ©dagogique) et **AI Control Plane** (agents, modÃ¨les, RAG, compute, quotas, Ã©valuations).

## Mapping ADM-077 Ã  ADM-093
- ADM-077 Agents : registre, dÃ©tail, builder/config, statut, canary, fallback.
- ADM-078 Prompts/Tools/Permissions : versions, allowlists, scopes, rollback.
- ADM-079 Models : registry, licences, benchmarks, adapters, Model Factory.
- ADM-080 RAG : sources, ingestion, chunks, index, versions.
- ADM-081 RAG Quality : console de recherche, citations, recall/precision proxy, erreurs.
- ADM-082 Evaluations : datasets, gates, A/B, canary, promotion/rollback.
- ADM-083 Infrastructure : Compute Fabric, nodes, jobs, cache, coÃ»ts, alertes/incidents.
- ADM-084 Learning Orchestrator : politiques de routage, fallback, quota-aware routing.
- ADM-085 Mastery Engine : paramÃ¨tres pÃ©dagogiques versionnÃ©s, sÃ©parÃ©s des quotas IA.
- ADM-086 Analytics : usage, qualitÃ©, compute, Ã©conomies cache/device, coÃ»ts.
- ADM-087 Fraud : signaux de quota/paiement/Ã©valuation, jamais sanction automatique.
- ADM-088 Roles : AI_ADMIN, AI_ENGINEER, PEDAGOGICAL_AI_REVIEWER, RAG_MANAGER, COMPUTE_ADMIN, FINANCE_ADMIN, SUPPORT_ADMIN, AUDITOR.
- ADM-089 Audit : journal append-only des actions sensibles.
- ADM-090 Feature Flags : rollout 0/1/10/25/50/100%, kill switches.
- ADM-091 Languages/Accessibility : capacitÃ©s modÃ¨les, traduction, voix, adaptations.
- ADM-092 Integrations : providers optionnels, compute nodes, connecteurs.
- ADM-093 Health/Jobs/Backups : santÃ©, queues, sauvegarde/restauration modÃ¨les/RAG/config.

## RÃ¨gle
L'Admin doit pouvoir comprendre la chaÃ®ne OFFER -> ENTITLEMENT -> QUOTA -> USER -> AGENT -> ROUTER -> RAG/TOOLS -> MODEL -> COMPUTE -> RESPONSE -> EVALUATION -> COST -> IMPROVEMENT, sans exposer de secrets ni autoriser d'action destructive non auditÃ©e.
