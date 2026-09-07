# Content Factory — Implementation Plan (2026-08-28)

## Tranche suivante après `be2c58e` — association des fiches

1. Corriger la résolution des références : accents et séparateurs normalisés, pas de
   correspondance sur une sous-chaîne arbitraire ou sur une matière générique, pas de fiche par défaut.
2. Utiliser la même résolution depuis le lecteur et les cartes de chapitres ; ne proposer
   l'ouverture que si une fiche correspond au chapitre.
3. Remplacer l'annonce fictive d'enregistrement hors ligne par un état explicite.
4. Tester les trois références, les absences et ambiguïtés, les accès UI et les petits écrans.

Réalisé localement : résolution sans fiche arbitraire, accès conditionnels, états hors ligne
et erreur image honnêtes, actions/onglets mobiles adaptatifs. La même passe corrige les
liens fictifs des introductions et du laboratoire vers le lecteur. Les introductions enregistrées
priment ; le modèle de dérivation reste disponible seulement pour les chapitres de mathématiques
correspondants. Tests élève : 44 passants, dont 24 nouveaux ; analyse ciblée : aucun problème.

Limites : les correspondances de fiches utilisent encore titres/tags/alias du registre local.
L'association administrable par identifiant de contenu, le vrai stockage hors ligne et les
évaluations d'observations de laboratoire restent à implémenter. Aucun succès simulé ne les remplace.

## Reprise 2026-09-07 — CF-002, persistance du Studio v2

Priorité issue de l'audit de `7996f20` : remplacer le faux succès de sauvegarde par
une création réelle en brouillon, réutiliser l'identifiant créé, charger les blocs
existants avant édition et conserver les métadonnées. Tester annulation, erreur et
sauvegardes répétées. La publication et les formats historiques restent traités par
le gestionnaire existant ; le jalon complet Admin → revue → élève reste à vérifier.

Implémentation locale validée : 5 tests Studio + 2 tests admin existants passants,
analyse ciblée sans problème. Suite : entrée de réouverture depuis Leçons & Cours,
validation avec Supabase de test, puis vérification du rendu élève contre les références.

Mise à jour du 7 septembre : réouverture et soumission implémentées, métadonnées
préservées dans l'ancien éditeur. 13 tests admin, 20 tests élève passants. Build web admin
réussi après correction du cache FNV-1a compatible JavaScript. Sonde SQL
sur Supabase réel réussie et intégralement annulée. Le contrat de rendu est testé sur
trois largeurs ; validation navigateur avec comptes et comparaison graphique exhaustive
restent distinctes. Preuves : `STUDIO_PUBLICATION_VERIFICATION.md`.

> Ordre conforme à U11 (`docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`) : modèle de contenu structuré →
> catalogues → Template/Renderer Registry → Block Editor Admin → rendu élève → import/jobs → agents
> d'import → Exercise Factory → génération de cours → PDF → validation/versioning/audit → (seulement
> ensuite) AI Gateway/Compute Fabric/Model Factory. Chaque tâche = petite implémentation testée avant la
> suivante, conformément à `.agents/AGENTS.md`.

## Constat qui fonde CF-001 (vérifié dans le code réel, pas supposé)

`lessons.content_json` (migration `02_schema_academic_content.sql`) est déjà une colonne JSONB — l'intention
d'un contenu structuré existait déjà — mais elle est consommée dans
`student_app/lib/features/courses/screens/lesson_reader_screen.dart:178-208` comme **un sac de clés fixes
codées en dur** (`body`, `theoreme`, `formule`, `piege`, `methode`, chacune avec son propre `if
(lesson.contentJson['x'] != null) _buildXCard(...)`), pas comme une liste de blocs typés avec un
`renderer_key` résolu par un registre. C'est exactement ce que `pedagogical-renderer/SKILL.md` interdit
(« Ne pas hardcoder une longue chaîne de if par type ») et ce que U2.3 exige de corriger. C'est donc le vrai
point de départ, pas une supposition.

---

## CF-001 — Modèle de contenu structuré (blocs typés) + migration additive [FAIT — 2026-08-28, commit `072f05f`]

**Objectif.** Faire évoluer `content_json` vers une structure `{ "blocks": [ {id, type, order, data,
renderer_key, version}, ... ] }` sans casser les leçons existantes.

**Fichiers.**
- `student_app/lib/core/models/content_block.dart` (nouveau) : modèle `ContentBlock` (`id`, `type`,
  `rendererKey`, `order`, `data: Map<String, dynamic>`).
- `student_app/lib/core/models/student_models.dart` : `Lesson.contentJson` reste tel quel en transition ;
  ajouter `Lesson.blocks` (parsing `contentJson['blocks']` si présent, sinon liste vide).
- `student_app/lib/core/rendering/block_renderer_registry.dart` (nouveau) : `Map<String, Widget Function(
  BuildContext, ContentBlock)>`, avec un fallback `UnknownBlockPlaceholder` sûr (jamais un crash).
- Premiers renderers, migrés depuis les `_buildXCard` existants de `lesson_reader_screen.dart` (réutiliser
  leur JSX/style tel quel, juste déplacé derrière le registre) : `paragraph`, `theorem`, `formula`, `trap`
  (« piège »), `method`.
- `admin_app/lib/features/content_management/screens/lessons_manager_screen.dart` : lire/écrire via la même
  structure `blocks` pour les nouvelles leçons (les anciennes restent lisibles par les deux formats en
  parallèle — voir migration).

**DB.** Aucune migration de schéma nécessaire (`content_json` est déjà JSONB, donc additive par nature) —
uniquement un script de **backfill optionnel** (pas obligatoire, réversible) qui peut mapper les anciennes
clés (`body/theoreme/formule/piege/methode`) vers `blocks[]` pour les leçons déjà publiées, à lancer
seulement après validation manuelle sur un échantillon. Tant que ce backfill n'est pas fait, le renderer
élève doit lire **les deux formats** (`blocks` si présent, sinon fallback sur les anciennes clés) — non-
régression stricte, aucune leçon existante ne doit s'afficher vide.

**Tests.** Widget test du registre (type connu → bon widget, type inconnu → placeholder, pas de crash) ;
test de non-régression manuelle sur au moins 3 leçons existantes réelles (ancien format) + 1 leçon test au
nouveau format.

**Critères d'acceptation.** Une leçon existante s'affiche à l'identique après le changement. Une nouvelle
leçon écrite au format `blocks` s'affiche correctement. Aucun `if/else` par type ajouté hors du registre.

**Réalisé.** `content_block.dart` + `block_renderer_registry.dart` (student_app), `Lesson.blocks` dans
`student_models.dart`, branchement dans `lesson_reader_screen.dart`. Constat confirmé en cours de route :
ce n'était pas qu'un problème de style — `contentJson['theoreme'/'formule'/'piege'/'methode']` n'étaient
écrites par **aucun** chemin réel (ni l'éditeur manuel admin, ni la génération IA, qui stocke plutôt sous
`contentJson['ai_structured']`) ; ces blocs ne s'affichaient donc jamais avant ce correctif. `Lesson.blocks`
lit maintenant réellement `ai_structured.sections/common_traps/exam_tips`. `quiz_questions` (également
généré par `ai-course-structuring` mais jamais exploité) reste explicitement hors périmètre — voir CF-003.
`flutter analyze` propre + `flutter build web --release` réussi + build vérifié servi en HTTP 200.

---

## CF-002 — Étendre le registre au Block Editor Admin + preview [FAIT — 2026-08-28, commits `4b9f8b9` + `c69654a`]

Une fois CF-001 stable : éditeur admin capable d'ajouter/réordonner/supprimer des blocs typés (pas de saisie
JSON brute), preview live réutilisant le même registre que l'app élève (même rendu, une seule source de
vérité). Nécessite d'abord de lister les types de blocs réellement utiles avec l'équipe pédagogique
(catalogue §16.0 — déjà partiellement outillé via `pedagogical_catalog_screen.dart`, à vérifier/étendre).

**Réalisé (partie 1 — honnêteté de l'aperçu + persistance native, pas encore l'éditeur visuel).**
`admin_app` et `student_app` sont deux projets Flutter sans package Dart partagé (vérifié : aucune
dépendance `path:` entre les deux `pubspec.yaml`) — « réutiliser le même registre » au sens littéral
demande d'extraire un package commun, non fait ici. À la place : le rendu de l'aperçu admin
(`_buildPreviewSection`/`_buildPreviewCallout` dans `lessons_manager_screen.dart`) a été réécrit pour
reproduire fidèlement le même mapping type→icône/couleur que `BlockRendererRegistry`, et pour afficher
pièges/conseils/formules qu'il ignorait avant (l'aperçu mentait sur ce que l'élève voit réellement).
`_blocksFromAiStructured` persiste désormais `content_json['blocks']` au format natif dès l'enregistrement,
avec le même mapping exact que `Lesson.blocks` côté élève.

**Réalisé (partie 2 — éditeur visuel).** `_EditableBlock` + `kEditableBlockTypes` (les 8 types déjà
supportés en lecture : paragraph/definition/theoreme/formule/methode/exemple/piege/conseil_examen — décidé
sans confirmation supplémentaire puisqu'ils étaient déjà la liste réellement rendue par
`BlockRendererRegistry`, aucune raison de la faire diverger) + `_buildEditableBlockCard` dans
`lessons_manager_screen.dart` : ajout/réordonnancement/modification/suppression de blocs à la main. La
génération IA remplit désormais directement ces blocs (au lieu d'aplatir en texte markdown non rendu,
l'ancien bug de fond de CF-001) et reste éditable ensuite. Aperçu élève + export PDF lisent maintenant les
blocs réellement en cours d'édition (live), plus la structuration IA figée — évite toute dérive entre ce
qui est corrigé à la main et ce qui est prévisualisé/exporté. `_formatAiStructuredAsText` (le mécanisme
d'aplatissement markdown, devenu mort) a été supprimé.

## CF-003 — Exercise Factory : aligner `exercises` sur le schéma cible U2.4 [AUDITÉ — 2026-08-28]

**Constat, contrairement à l'hypothèse initiale de l'audit.** Vérification faite (schéma réel de
`exercises` dans `02_schema_academic_content.sql`, pipeline `ai-exercise-generation` → 
`exercises_manager_screen.dart` → `Exercise.fromJson` côté élève) : **la chaîne génération → admin →
élève est déjà correctement câblée de bout en bout**, contrairement au bug réel trouvé sur les leçons
(CF-001). `statement`/`options` dans `instructions_json`, `correction`/`correct_index` dans
`solution_json`, tout est écrit et lu avec les mêmes clés partout — aucune donnée générée n'est perdue.

Ce qui manque réellement par rapport à la cible U2.4 (`hints`, `skills`, `prerequisites`, `provenance`,
détecteur de doublons, classification automatique de difficulté) n'est donc **pas un bug à corriger** mais
une **fonctionnalité à ajouter**.

**Enrichissement `hints`/`skills`/`prerequisites`/`provenance` [FAIT — 2026-08-29, commit `859ff54`].**
Plutôt que d'attendre une taxonomie de compétences figée (choix produit non tranché), migration 54 :
`skills`/`prerequisites` en tags texte libre (`TEXT[]`), migrables vers une vraie taxonomie/Competency
Graph plus tard sans perte de données — voir le commentaire de la migration pour la justification complète.
`hints` dans `instructions_json` (contenu élève, pas une colonne). `ai-exercise-generation` génère
maintenant indices + compétences en plus de l'énoncé/corrigé (déployé). Formulaire admin étendu (3 champs
« Pédagogie »), flux de génération par lot les reprend automatiquement. Côté élève,
`exercise_runner_screen.dart` révèle les indices progressivement (bouton « Voir un indice », jamais tous
d'un coup). Détecteur de doublons et classification automatique de difficulté restent non démarrés —
plus proches d'un vrai chantier RAG/similarité que d'un ajout de colonne, pas de raison de les prioriser
maintenant.

## CF-004 — Agents IA existants → contrat standard §4 [FAIT ET DÉPLOYÉ — 2026-08-28, commit `9522227`]

Faire évoluer `ai-course-structuring`, `ai-exercise-generation`, `ai-catalog-types-generation` pour émettre
l'enveloppe de sortie standard (`request_id`, `status`, `result`, `usage.route`, `agent_version`) sans
changer leur logique métier actuelle — traçabilité et observabilité d'abord, avant tout Agent Registry.

**Réalisé, additif uniquement (pas d'enveloppe imbriquée `result` — aurait cassé les clients existants sans
les mettre à jour en même temps ; choisi des champs `_request_id`/`_agent_version`/`_model`/`_duration_ms`
en plus, même convention que `_mock` déjà présent et jamais lu par aucun client).** Migration `53_...` :
`ai_agent_calls` gagne `request_id`/`model`/`duration_ms`/`status`/`error_message` — les échecs n'étaient
jusqu'ici jamais journalisés du tout. Les 5 fonctions IA journalisent maintenant systématiquement (succès
ET échec) avec le vrai modèle utilisé. Vérifié via `deno check` (vraie vérification de types) sur les 5.

**Déployé et vérifié en conditions réelles (2026-08-28)** : migration 53 appliquée (colonnes confirmées via
`information_schema.columns`), 5 fonctions redéployées via `npx supabase functions deploy`. Appel réel de
`ai-tutor-chat` (pas un mock) : réponse contient bien `_request_id`/`_agent_version`/`_model`/
`_duration_ms`, et la ligne correspondante existe dans `ai_agent_calls` avec `model=gemini-3.6-flash`,
`status=success`, `duration_ms` cohérent — la chaîne fonction → DB est confirmée bout en bout, pas
seulement déployée à l'aveugle.

## Explicitement différé (ne pas commencer sans confirmation explicite de l'utilisateur)

RAG/pgvector, Agent/Prompt/Tool Registry Admin, Quota Engine, Compute Fabric, Sovereign AI Gateway
FastAPI/LangGraph. Raisons : nouvel hébergement hors stack actuelle (Vercel + Supabase), coût
d'administration pour un seul agent réel aujourd'hui, et le pack lui-même (U11) les place en dernier. Voir
`docs/CONTENT_FACTORY_GAP_ANALYSIS.md`.

---

## Prochaine étape immédiate — actualisation du 2026-09-05

CF-001 et CF-002 sont déjà implémentés. Les reports IA ci-dessus sont historiques : plusieurs de ces
modules existent désormais dans `gateway/app/` (voir l'audit actualisé).

Le dernier chantier du dépôt (`f5edccf`) est Exam Resource Factory, tranche 1 : extraction et revue admin.
Ordre de reprise proposé, lié à U2.1/U2.4 et à l'annexe D.8-D.9 de CAHIER_IA_ZERO_COUT_MASTER :

1. Fiabiliser la revue admin : approbation du texte réellement édité, gestion des sauvegardes et tests ciblés.
2. Préparer la publication atomique côté serveur avec validation des questions ; examiner les droits avant toute modification de sécurité.
3. Ajouter la lecture élève des questions publiées, avec accès limité au périmètre autorisé et maintien des liens documentaires existants. Migration RLS additive à concevoir sur le schéma réel.
4. Vérifier les parcours admin → publication → élève, y compris brouillon inaccessible, refus de publication incomplète et accès selon abonnement.

Aucune migration ni modification applicative effectuée pendant la passe d'audit du 5 septembre.
