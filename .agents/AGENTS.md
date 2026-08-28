# EDLEARN — Instructions persistantes pour agents de développement

## Source de vérité
1. Inspecter le code et les migrations réels avant modification.
2. Lire `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md` et les cahiers techniques concernés.
3. Non-régression : ne supprimer/remplacer aucune fonctionnalité compatible sans analyse, migration et tests.
4. Ne jamais inventer l'état du repo, de la DB ou d'une intégration.

## Workflow
Audit -> gap analysis -> plan -> petite implémentation -> tests -> documentation -> commit/review. Toute migration destructive, perte de données, changement de sécurité ou suppression fonctionnelle exige STOP + rapport.

## Architecture
- Content != Presentation ; contenu canonique structuré + renderer/template.
- LLM orchestre/explique ; moteurs spécialisés calculent/simulent/rendent.
- Aucune API IA payante obligatoire ; providers interchangeables.
- Agents sans SQL générique ; tools typés/allowlistés.
- Quotas distants séparés des fonctions locales/déterministes/cache.
- Publication pédagogique humaine par défaut.

## Documentation
Maintenir `docs/DEVELOPMENT_PROGRESS.md`, ADRs, migrations et tests. Pas de faux boutons, mocks permanents ou statistiques inventées déclarés « terminés ».

## Skills
Les procédures détaillées vivent dans `.agents/skills/*/SKILL.md`. Activer le skill correspondant avant une tâche spécialisée.
