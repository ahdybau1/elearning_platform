# EDLEARN Sovereign AI Gateway — IA-002 (Gateway minimal)

Premier work package du chantier « Agents IA » selon l'ordre imposé par
`docs/CAHIER_DES_CHARGES_AGENTS_IA.md` §22 :

- IA-000 Audit — fait (`docs/AUDIT_REPORT.md`)
- IA-001 Contracts — fait (migration `55_ai_agent_registry_ia001.sql`, écran Admin « Registre des Agents IA »)
- **IA-002 Gateway minimal — ce dossier**
- IA-003 Tool Gateway, IA-004 RAG (schéma déjà fait, pipeline d'ingestion à venir), IA-005 Model Router... : pas encore faits.

## Ce que c'est réellement

Un service FastAPI qui :
1. Vérifie l'authentification Supabase du client (JWT réel, via `/auth/v1/user` — pas de
   réimplémentation de vérification de signature).
2. Consulte le registre réel des agents (IA-001, table `ai_agents`/`ai_agent_versions`) pour savoir
   quelle Edge Function exécute vraiment l'agent demandé.
3. Route la requête vers cette Edge Function Deno réelle (déjà en production), avec le payload
   spécifique à cet agent.
4. Journalise l'appel dans `ai_agent_calls` (même table que les Edge Functions, CF-004).
5. Renvoie l'enveloppe de sortie standard `§4.2` du cahier (`request_id`, `status`, `result`, `usage`,
   `agent_version`, `model_version`) au lieu de la réponse brute et hétérogène de chaque Edge Function.

**Ce que ce n'est PAS** : pas d'Agent Orchestrator (LangGraph), pas de modèle auto-hébergé
(vLLM/Ollama), pas de RAG branché, pas de Quota Engine réel. La Gateway est aujourd'hui un
**proxy authentifié et observable** devant les agents Deno existants — la prochaine étape logique
(IA-005 Model Router) ajoutera un vrai choix de modèle indépendant du provider.

## Lancer en local

Conforme à la stratégie « coût initial nul » du cahier (§33) : la machine de développement est un
nœud Compute Fabric légitime pour prototyper (§U6). Pas encore déployé sur un hébergement dédié —
décision à prendre séparément quand ce sera nécessaire.

```bash
cd gateway
pip install -r requirements.txt
cp .env.example .env   # puis remplir avec les vraies clés (voir student_app/.env pour les valeurs)
uvicorn app.main:app --reload --port 8000
```

Test rapide :
```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/v1/agents/AIA-AGT-001/invoke \
  -H "Authorization: Bearer <un vrai JWT Supabase>" \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"AIA-AGT-001","payload":{"message":"Bonjour"}}'
```
