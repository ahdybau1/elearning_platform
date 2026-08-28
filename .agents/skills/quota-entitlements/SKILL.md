---
name: quota-entitlements
description: Implémenter les politiques AI entitlement, credits pondérés et ledger append-only.
---

# quota-entitlements

## Procédure
1. Lire docs/CAHIER_TECHNIQUE_QUOTAS_COMPUTE.md.
2. Séparer subscription, payeur, bénéficiaire, policy.
3. Ne pas hardcoder les quotas finaux avant benchmark.
4. Réconciliation par écritures compensatoires.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
