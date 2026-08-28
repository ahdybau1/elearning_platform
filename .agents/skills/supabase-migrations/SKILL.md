---
name: supabase-migrations
description: Créer des migrations PostgreSQL/Supabase non destructives, versionnées et compatibles RLS.
---

# supabase-migrations

## Procédure
1. Lire toutes les migrations existantes pertinentes.
2. Préférer additive migration puis backfill puis contraintes.
3. Définir indexes, FK, RLS/policies et audit nécessaires.
4. Tester upgrade et scénario rollback raisonnable.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
