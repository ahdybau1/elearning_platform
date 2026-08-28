---
name: project-audit
description: Auditer le repo, la stack, les migrations et produire une gap analysis avant changement majeur.
---

# project-audit

## Procédure
1. Inspecter arborescence, pubspec, config, routes, state management, services, tests et migrations.
2. Cartographier existant/cible/gap/risque.
3. Ne modifier aucun code pendant l'audit.
4. Écrire ou mettre à jour docs/AUDIT_REPORT.md et le plan de migration.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
