# CAHIER TECHNIQUE — AI ENTITLEMENTS, QUOTAS ET COMPUTE FABRIC

## 1. Séparation
Subscription/plan, payeur, bénéficiaire et AI entitlement sont distincts. Un élève peut payer son abonnement ; un parent ou tiers autorisé peut payer pour un bénéficiaire sans devenir propriétaire du profil.

## 2. Quotas
Les quotas protègent surtout le compute distant/génératif. Ne pas compter par simple nombre de questions : utiliser des unités/credits pondérés par classe de coût. Les valeurs numériques sont configurables et déterminées après benchmark.

Configuration cible :
```env
AI_ZERO_COST_MODE=true
AI_QUOTA_ENGINE=true
LOCAL_AI_COUNTS_AGAINST_QUOTA=false
DETERMINISTIC_TOOLS_COUNTS_AGAINST_QUOTA=false
CACHED_AI_COUNTS_AGAINST_QUOTA=false
REMOTE_COMPUTE_QUOTA=true
PROVIDER_LOCK_IN=false
```

## 3. Politiques
FREE, DAY_PASS, WEEKLY optionnel, MONTHLY_STANDARD, MONTHLY_PREMIUM, SCHOOL_PLAN, PROMOTIONAL. Chaque policy peut définir allowance, reset, rollover, max model tier, priority, concurrency, OCR/generation allowance et fair use.

## 4. Ledger
Usage append-only : request/job, beneficiary, policy, agent, model, compute class, units reserved/consumed/refunded, cache/device flags, timestamp, reason. Les corrections se font par écritures compensatoires, pas par réécriture silencieuse.

## 5. Compute Fabric
Nœuds autorisés : device, serveur propre, school node, université/partenaire/sponsor approuvé, capacité gratuite externe comme bonus. Scheduler tient compte de santé, modèle chargé, VRAM/RAM, queue, priorité, confidentialité, quota et coût.

## 6. Dégradation
Quota distant épuisé : conserver selon droits cours, exercices existants, examens, jeux/musiques publiés, outils déterministes, cache, local RAG, offline et device AI possible. Ne jamais présenter un free tier externe comme garantie de production.
