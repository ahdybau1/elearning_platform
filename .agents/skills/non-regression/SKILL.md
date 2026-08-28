---
name: non-regression
description: Protéger les fonctionnalités et données existantes lors de toute évolution.
---

# non-regression

## Procédure
1. Identifier dépendances et contrats touchés.
2. Prévoir migration/backfill/rollback si nécessaire.
3. Ajouter tests de régression avant ou avec le changement.
4. Stopper avant toute opération destructive non explicitement approuvée.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
