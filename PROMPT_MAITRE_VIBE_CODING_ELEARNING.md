# PROMPT MAÎTRE — DÉMARRAGE VIBE CODING

## Mission
Tu développes la Plateforme E-learning Cameroun dans Claude Code sur Google Antigravity. Une application existe déjà : **audit obligatoire avant modification**.

## Projet
`C:\Users\ahdyb\.gemini\antigravity-ide\scratch\elearning_platform`

## Sources de vérité
1. Le cahier des charges Markdown mis à jour du projet.
2. Le code et les migrations réellement présents.
3. Les décisions d'architecture documentées dans `docs/`.

## Règle de non-régression
Avant tout changement : ANALYSER → DÉPENDANCES → ÉCART → MIGRATION → IMPLÉMENTER → TESTER → VALIDER. Ne supprime rien de compatible silencieusement. Ne remplace pas une technologie uniquement par préférence.

## Première mission
1. Inspecte `lib/`, `assets/`, `supabase/`, migrations, `pubspec.yaml`, routes, modèles, services, repositories, state management, widgets, thèmes et tests.
2. Produis `docs/AUDIT_REPORT.md`.
3. Produis `docs/CONTENT_FACTORY_GAP_ANALYSIS.md` avec colonnes Fonctionnalité / Existe / Partiel / Absent / Fichiers / DB / Action / Risque.
4. Produis `docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md`, tâches `CF-001...`, chacune avec objectif, fichiers, DB, dépendances, implémentation, tests, critères d'acceptation.
5. Commence ensuite la première tâche non destructive.

## Priorité fonctionnelle
Construire EDLEARN Content Factory : Structured Content → Catalogues pédagogiques → Template Registry → Renderer Registry → Block Editor Admin → Preview → Workflow → rendu élève → upload/import → agents de structuration → Exercise Factory → génération IA → PDF depuis la même source.

## Content != Presentation
Les cours/exercices sont stockés sous forme structurée. Le design est appliqué par les renderers/templates. Un PDF uploadé est une source à transformer, pas simplement le cours final.

## IA
Aucune API commerciale payante obligatoire. Préparer local-first + FastAPI AI Gateway + Agent Orchestrator + RAG + tools + Model Router + Device AI + Compute Fabric. Les fournisseurs externes sont optionnels. Les agents n'ont jamais accès génériquement à toute la DB.

## Publication
L'IA analyse/propose/génère ; la publication pédagogique passe par validation humaine, versioning et audit.

## Qualité
Pas de faux boutons, TODO considérés terminés, statistiques inventées ou succès hardcodés. Chaque phase exige tests unitaires/intégration/widget/e2e pertinents.

## Skills
Avant une tâche, charge/applique tout skill du dépôt pertinent, même spécialisé : audit, Flutter, Supabase migrations, Content Factory, renderer, import, exercices, agent contracts, RAG, routing, quotas, sécurité mineurs, RBAC/RLS, offline, tests, accessibilité/i18n, observabilité, documentation. Si plusieurs skills s'appliquent, combine-les et signale brièvement lesquels gouvernent la tâche.

## Premier jalon E2E
Admin → créer cours → choisir contexte académique → ajouter blocs → preview → draft → review → approve → publish → app élève → ouvrir la leçon → rendu correct via template configuré.

Commence maintenant par l'audit réel. N'invente jamais l'état du projet.
