# Inventaire des intégrations, frameworks, bibliothèques, moteurs, modèles et API

> WP4 (consigne #5). État vérifié le 2026-09-11 sur la branche `admin-completion`.
> Pilotage runtime : écran admin **Intégrations** (nav id 34) + table `integrations` (migration 80)
> + Edge Function `integration-healthcheck` (test de connexion réel).

## 1. Intégrations externes (pilotées depuis l'admin)

| Clé | Rôle | Présent / version | Config (non secrète) | Secret requis | État de connexion | Licence / coût |
|---|---|---|---|---|---|---|
| `gemini_generative` | Génération de texte (tuteur, structuration cours, exercices, assistant admin) | ✅ Edge Functions déployées | `model=gemini-3.6-flash` | `GEMINI_API_KEY` (function-secret) | **OK vérifié** (50 modèles, ~88 ms) | Google Gemini API **Free Tier — 0 $** |
| `gemini_embeddings` | Embeddings 768-dim pour le RAG (`ai_rag_chunks`) | ✅ `ai-embeddings-generate` | `model=gemini-embedding-001`, `dim=768` | `GEMINI_API_KEY` | testable (même clé que ci-dessus, OK) | Free Tier — 0 $ |
| `supabase_storage` | Médias (illustrations, PDF, avatars) | ✅ 2 buckets : `avatars`, `media` | `buckets=[avatars, media]` | — | **OK vérifié** (2 buckets, ~209 ms) | Inclus dans le plan Supabase |
| `payment_mobile_money` | Encaissement abonnements (MTN MoMo / Orange Money) | 🟠 `payment-webhook` déployé, **non branché** | `webhook_function=payment-webhook` | `PAYMENT_WEBHOOK_SECRET` | **non configuré** (aucun contrat agrégateur) — affiché honnêtement, aucun débit réel/simulé | À définir avec l'agrégateur |

**Secrets côté serveur uniquement** (function-secrets Supabase, jamais dans le client / le dépôt /
les logs / une table lisible) : `GEMINI_API_KEY`, `PAYMENT_WEBHOOK_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_DB_URL`, `SUPABASE_JWKS`, `AI_MOCK_MODE`, `SUPABASE_SECRET_KEYS`, `SUPABASE_PUBLISHABLE_KEYS`.

## 2. Frameworks & runtimes

| Élément | Rôle | Version | Compatibilité | Fonctionnalités dépendantes |
|---|---|---|---|---|
| Flutter / Dart | UI `admin_app` + `student_app` | Flutter 3.44.8 (Dart ~3.10) | ✅ analyze 0/0, build web OK | Toute l'interface admin |
| Supabase (PostgreSQL 17.6) | Base, Auth, RLS, Storage, Edge Functions, pg_cron | projet `kdprnavvgzhnygovfyuw` ACTIVE_HEALTHY | ✅ | Toute la persistance, RBAC/RLS, jobs planifiés |
| Deno (Edge Functions) | Logique serveur (24 fonctions déployées) | runtime Supabase | ✅ `deno check` vert sur les nouvelles | Agents IA, harnais de test, worker d'ingestion, healthcheck |
| FastAPI Gateway (`gateway/`) | Orchestrateur IA cible (LangGraph/vLLM) | présent, **NON déployé** | hors périmètre coût zéro | 8 agents `gateway_native` — marqués « hors ligne » dans l'admin, jamais simulés |

## 3. Bibliothèques Flutter `admin_app` (pubspec.yaml — toutes réellement utilisées)

| Paquet | Version | Usage | Doublon / inutile ? |
|---|---|---|---|
| `supabase_flutter` | ^2.8.0 | client Supabase | non |
| `flutter_riverpod` | ^2.6.1 | état / providers | non |
| `go_router` | ^14.8.0 | routage | non |
| `google_fonts` | ^6.2.1 | typographie (Outfit / Inter / Fira Code) | non |
| `data_table_2` | ^2.5.15 | tables denses admin | non |
| `intl` | ^0.20.2 | formats date/nombre | non |
| `flutter_math_fork` | ^0.7.4 | rendu LaTeX (`math_text.dart`) | non |
| `file_picker` | ^10.3.7 | upload médias | non |
| `flutter_svg` | ^2.0.17 | schémas SVG | non |
| `flutter_dotenv` | ^5.2.1 | config publique (`SUPABASE_URL`/anon) | non |
| `pdf` + `printing` | ^3.11 / ^5.13 | export PDF leçons/exercices, aperçu impression | non |
| `url_launcher` | ^6.3.1 | liens externes (doc intégrations) | non |

**Aucune dépendance ajoutée pour les WP1–WP4** : le control-plane IA, le centre d'ingestion et la
page Intégrations réutilisent l'existant. **Aucune API payante obligatoire introduite.**

## 4. Modèles IA

| Modèle | Fournisseur | Usage | Coût |
|---|---|---|---|
| `gemini-3.6-flash` | Google | génération (tuteur, cours, exercices, assistant, curriculum) | Free Tier — 0 $ |
| `gemini-embedding-001` | Google | embeddings RAG (768-dim) | Free Tier — 0 $ |
| Moteurs déterministes locaux (SimulationEngine, GraphEngine, math_tools) | — | labos virtuels, calculs, vérification | 0 $ (exécution locale) |

Claude / Anthropic : **retiré du projet** (jamais configuré comme secret ; cf. mémoire projet).
Ne pas réintroduire sans une clé réellement configurée et vérifiée.

## 5. Reste à faire / limites déclarées

- OCR d'images / PDF scannés : **indisponible** (aucun moteur vision auto-hébergé à coût zéro).
  Le worker d'ingestion refuse ces types avec un message clair — jamais de faux résultat.
- Gateway FastAPI : non déployé (contrainte coût zéro). 8 agents `gateway_native` restent
  catalogués mais « hors ligne » dans le Control-Plane IA.
- Mobile Money : en attente du contrat agrégateur. `payment-webhook` prêt côté code.
