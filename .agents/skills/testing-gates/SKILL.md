---
name: testing-gates
description: Écrire tests et gates avant de déclarer une phase terminée.
---

# testing-gates

## Procédure
1. Unit + integration + DB/policy + widget/E2E selon risque.
2. Inclure happy path, erreurs, permissions et régression.
3. Aucune fonctionnalité critique « done » sans preuve de test.
4. Documenter limites connues.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
