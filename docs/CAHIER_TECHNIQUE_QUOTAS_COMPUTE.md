# CAHIER TECHNIQUE â AI ENTITLEMENTS, QUOTAS ET COMPUTE FABRIC

## 1. SÃ©paration
Subscription/plan, payeur, bÃ©nÃ©ficiaire et AI entitlement sont distincts. Un Ã©lÃ¨ve peut payer son abonnement ; un parent ou tiers autorisÃ© peut payer pour un bÃ©nÃ©ficiaire sans devenir propriÃ©taire du profil.

## 2. Quotas
Les quotas protÃ¨gent surtout le compute distant/gÃ©nÃ©ratif. Ne pas compter par simple nombre de questions : utiliser des unitÃ©s/credits pondÃ©rÃ©s par classe de coÃ»t. Les valeurs numÃ©riques sont configurables et dÃ©terminÃ©es aprÃ¨s benchmark.

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
FREE, DAY_PASS, WEEKLY optionnel, MONTHLY_STANDARD, MONTHLY_PREMIUM, SCHOOL_PLAN, PROMOTIONAL. Chaque policy peut dÃ©finir allowance, reset, rollover, max model tier, priority, concurrency, OCR/generation allowance et fair use.

## 4. Ledger
Usage append-only : request/job, beneficiary, policy, agent, model, compute class, units reserved/consumed/refunded, cache/device flags, timestamp, reason. Les corrections se font par Ã©critures compensatoires, pas par rÃ©Ã©criture silencieuse.

## 5. Compute Fabric
NÅuds autorisÃ©s : device, serveur propre, school node, universitÃ©/partenaire/sponsor approuvÃ©, capacitÃ© gratuite externe comme bonus. Scheduler tient compte de santÃ©, modÃ¨le chargÃ©, VRAM/RAM, queue, prioritÃ©, confidentialitÃ©, quota et coÃ»t.

## 6. DÃ©gradation
Quota distant Ã©puisÃ© : conserver selon droits cours, exercices existants, examens, jeux/musiques publiÃ©s, outils dÃ©terministes, cache, local RAG, offline et device AI possible. Ne jamais prÃ©senter un free tier externe comme garantie de production.
