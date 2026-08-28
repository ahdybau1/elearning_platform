---
name: model-routing
description: Implémenter le routage déterministe/device/server et la sélection de modèles.
---

# model-routing

## Procédure
1. Essayer déterministe/cache avant LLM.
2. Essayer device/local avant compute distant quand pertinent.
3. Respecter entitlement/quota et max model tier.
4. Tracer raison de routage, fallback, latence et coût.

## Definition of Done
- Exigence du cahier identifiée.
- Implémentation compatible avec l'existant.
- Tests pertinents passants.
- Sécurité/permissions vérifiées si concernées.
- Documentation/progression mise à jour.
