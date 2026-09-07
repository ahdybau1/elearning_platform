# Studio → revue → publication → lecture : vérification du 7 septembre 2026

## Corrections

Le gestionnaire de leçons propose l'ouverture des brouillons structurés dans le Studio.
Le Studio enregistre avant de soumettre explicitement pour revue humaine ; un échec de
soumission conserve l'identifiant du brouillon pour éviter une seconde création lors du retry.
La publication reste l'action de la file de validation existante.

L'ancien éditeur conserve désormais les identifiants, métadonnées, champs de renderer et
blocs médias sans texte. Il accepte les types spécialisés sans erreur de sélection.
Les autres clés du document sont conservées lors de l'édition. La barre du Studio répartit
ses actions sur plusieurs lignes sur les petits écrans et propose le retour aux leçons.

## Preuves locales

- `admin_app`: `flutter test --no-pub` — **13 tests passants**.
- `student_app`: `flutter test --no-pub` — **20 tests passants**.
- Analyse ciblée des six fichiers admin concernés — **No issues found**.
- La fixture `test_fixtures/studio_course_v2.json` traverse le modèle de l'ancien éditeur,
  le modèle Studio et le modèle élève. Le renderer élève est testé à 390, 800 et 1400 pixels.
- Test mobile de la barre du Studio, annulation, erreur de création, conservation du contenu,
  refus d'éditer une leçon publiée, reprise d'une soumission échouée sans duplication.
- `flutter build web --release --no-pub` admin — **réussie**, après correction du hash
  FNV-1a du dernier push : utilisation de `BigInt` pour conserver les 64 bits sur JavaScript.
  Deux tests dédiés et une exécution du probe compilé en JavaScript confirment le résultat.
  Analyse du moteur/probe/tests : aucun problème. Le dry-run Wasm signale toujours l'import
  historique `dart:html` de l'écran d'audit ; cela ne bloque pas la compilation web JavaScript.

## Vérification Supabase réelle

Utilisation de l'API de gestion Supabase sur le projet configuré par l'URL locale.
Lectures de schéma et politiques via l'endpoint
[`database/query/read-only`](https://supabase.com/docs/reference/api/v1-read-only-query).
Les tables `lessons`, `lesson_versions`, `validation_queue` et `exam_paper_questions` existent.
Le registre `supabase_migrations.schema_migrations` est absent : ne pas en déduire que toutes
les migrations du dépôt ont été appliquées ou qu'aucune ne l'a été.

Le script `supabase/tests/studio_publication_rollback.sql` a été exécuté avec la même fixture,
dans une transaction intégralement annulée. Aucun trigger utilisateur sur `lessons` et
`validation_queue` n'a été trouvé lors de l'inspection préalable.

Assertions réussies :

1. Création d'un brouillon et soumission sous le rôle `authenticated` avec le contexte d'un admin actif.
2. Brouillon invisible sous le rôle `anon`.
3. Approbation par un anonyme refusée.
4. RPC `approve_and_publish_content` exécutée sous le contexte admin : file approuvée et leçon publiée.
5. Lecture publique de la leçon gratuite publiée ; JSON strictement identique à la fixture.
6. Leçon archivée invisible.
7. `ROLLBACK` ; contrôle indépendant : **0 leçon de test restante, 3 leçons totales, 2 publiées**, comme avant.

Le jeton de gestion n'est enregistré dans aucun fichier du projet. `SUPABASE_PROJECT_REF`
dans le `.env` local a été corrigé à partir de l'URL. Cette variable contenait une clé sensible,
renvoyée par une erreur API lors du premier appel : son renouvellement reste nécessaire.

## Limites

Ces preuves combinent des tests Flutter, un test transactionnel des politiques/RPC et le
parcours navigateur décrit ci-dessous. Ce n'est pas une session avec deux comptes connectés.
Les accès payants, rôles pédagogiques détaillés et fidélité graphique exhaustive aux images
ne sont pas certifiés. Aucune migration n'a été déployée.
Une réponse réseau perdue après création reste un cas d'idempotence serveur à traiter.

## Parcours navigateur réel et configuration publique

Après connexion manuelle de l'utilisateur, le Studio a enregistré une leçon de contrôle
de cinq blocs, puis affiché « Brouillon enregistré et soumis pour validation ». La file
contenait cette leçon en attente ; l'action manuelle « Approuver & Publier » l'a publiée.
La base a confirmé `is_published=true`, `is_active=true`, accès `gratuit`.

Le lecteur de production `LessonReaderScreen`, ouvert via l'entrée de développement
`student_app/tool/studio_preview.dart?chapter=<uuid>` compilée localement, a chargé ce même
chapitre avec le service Supabase réel et une session anonyme : titre et cinq blocs présents.
Aucun service simulé ni privilège administrateur n'est injecté dans ce mode. Le mode sans
paramètre reste une prévisualisation statique du template admin.

Contrôles visuels à 390 et 1400 pixels : colonnes de synthèse adaptatives, formules rendues,
image originale « Résumé : Suites réelles » présente dans la visionneuse. Le bandeau de fiche
élève débordait à 390 pixels : badges passés en `Wrap`, correction confirmée au navigateur.
L'en-tête admin de validation était comprimé sur mobile : compteur placé sous le titre.
L'égalité auteur/réviseur ne permet pas de conclure à une approbation automatique ; les
libellés indiquent désormais le fait observé, sans changer les permissions.

La leçon `c727419f-b4c1-4072-ac5e-cf3057798e72` et le chapitre
`1f4590da-91d8-4f4d-8a0e-47dad68c17a2`, créés uniquement pour ce test, ont été archivés
(`is_active=false`). L'historique de validation est conservé. Après rechargement, le lecteur
public affiche « Aucune leçon publiée pour ce chapitre ». Les trois leçons préexistantes
n'ont pas été modifiées. La réouverture dans le Studio est couverte par les tests widget,
pas par un parcours navigateur complet depuis les filtres du gestionnaire.

Les deux applications embarquent maintenant `.env.public` (URL + clé publishable) et plus
le `.env` privé. L'auto-connexion par identifiants de développement a été retirée de l'admin.
La session admin existante est restaurée normalement après recompilation et rechargement.
`node scripts/verify_public_config.cjs --built` réussit pour les deux builds web release.
Les suites donnent 13 tests admin et 20 tests élève passants. L'analyse admin globale signale
20 infos préexistantes (accolades et `dart:html`), sans erreur de compilation ; elles ne sont
pas déclarées résolues par ce chantier.

La migration des clients vers la clé publishable n'est **pas** une révocation des anciennes
clés. Les 19 Edge Functions déployées et le gateway utilisent encore le rôle serveur historique.
Migrer et tester ces consommateurs avant de désactiver les clés legacy reste nécessaire pour
traiter la clé exposée sans interrompre le service. Aucun secret de gestion n'est versionné.
L'utilisateur n'a pas indiqué de nouvel hébergement : aucun projet Vercel n'a été créé.

## Relancer le test SQL

Exécuter uniquement comme sonde contrôlée avec le propriétaire de la base. Remplacer le
littéral SQL **entier** `'__CONTENT_JSON__'` par la fixture JSON échappée comme chaîne SQL
(doubler les apostrophes), sans remplacer le texte du commentaire. Envoyer le script en un
seul appel ; conserver `BEGIN`, `statement_timeout` et `ROLLBACK`. Toute assertion échouée
interrompt la transaction. Ne pas exécuter les instructions séparément en autocommit.
