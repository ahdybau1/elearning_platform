-- Model Router multi-fournisseurs (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §5, PROVIDER_LOCK_IN=false).
-- Enregistre les fournisseurs IA GRATUITS de la chaîne de bascule dans `integrations` (migration 80)
-- pour qu'ils soient visibles, activables et testables depuis l'écran Intégrations. Chaque
-- fournisseur n'est réellement utilisé que si son function-secret est présent (jamais la valeur
-- ici — seulement le nom). Aucune API payante obligatoire.

INSERT INTO integrations (key, name, category, provider, description, enabled, config, secret_ref, docs_url, known_limits, license_note, cost_note, last_status) VALUES
(
  'ai_provider_groq', 'Groq (Llama 3.3 70B / 8B)', 'ai', 'groq',
  'Fournisseur de secours n°1 du Model Router. Inférence très rapide, palier gratuit sans carte bancaire.',
  TRUE, '{"base_url": "https://api.groq.com/openai/v1", "model_strong": "llama-3.3-70b-versatile", "model_small": "llama-3.1-8b-instant", "order": 1}'::jsonb,
  'GROQ_API_KEY', 'https://console.groq.com/docs/rate-limits',
  '{"free_tier": true, "rpd": "élevé", "no_card": true}'::jsonb,
  'Modèles Llama (Meta) — licence Llama Community.', '0 $ (palier gratuit Groq, sans carte).',
  'not_configured'
),
(
  'ai_provider_cerebras', 'Cerebras (Llama 3.3 70B)', 'ai', 'cerebras',
  'Fournisseur de secours du Model Router. Inférence rapide, palier gratuit.',
  TRUE, '{"base_url": "https://api.cerebras.ai/v1", "model_strong": "llama-3.3-70b", "model_small": "llama-3.1-8b", "order": 2}'::jsonb,
  'CEREBRAS_API_KEY', 'https://inference-docs.cerebras.ai/',
  '{"free_tier": true, "no_card": true}'::jsonb,
  'Modèles Llama (Meta).', '0 $ (palier gratuit Cerebras).', 'not_configured'
),
(
  'ai_provider_openrouter', 'OpenRouter (modèles :free)', 'ai', 'openrouter',
  'Fournisseur de secours du Model Router via les modèles suffixés « :free » (Llama, Gemma, DeepSeek…).',
  TRUE, '{"base_url": "https://openrouter.ai/api/v1", "model_strong": "meta-llama/llama-3.3-70b-instruct:free", "model_small": "google/gemma-2-9b-it:free", "order": 4}'::jsonb,
  'OPENROUTER_API_KEY', 'https://openrouter.ai/docs/api-reference/limits',
  '{"free_tier": true, "note": "modèles :free uniquement"}'::jsonb,
  'Variable selon le modèle sélectionné.', '0 $ pour les modèles « :free ».', 'not_configured'
),
(
  'ai_provider_mistral', 'Mistral La Plateforme', 'ai', 'mistral',
  'Fournisseur de secours du Model Router. Palier gratuit « La Plateforme » (mistral-small).',
  TRUE, '{"base_url": "https://api.mistral.ai/v1", "model": "mistral-small-latest", "order": 5}'::jsonb,
  'MISTRAL_API_KEY', 'https://docs.mistral.ai/deployment/laplateforme/tier/',
  '{"free_tier": true}'::jsonb,
  'Modèles Mistral — conditions La Plateforme.', '0 $ (palier gratuit, dans les limites).', 'not_configured'
)
ON CONFLICT (key) DO NOTHING;

-- gemini_generative devient explicitement le fournisseur n°3 de la chaîne (déjà seedé migration 80).
UPDATE integrations
SET config = config || '{"order": 3, "role": "model_router_provider"}'::jsonb,
    description = 'Fournisseur principal du Model Router (structuration de cours, tuteur, génération). Palier gratuit Google AI Studio (~quotas journaliers).'
WHERE key = 'gemini_generative';
