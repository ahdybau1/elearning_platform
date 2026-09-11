# Matrice de traçabilité — Achèvement de l'application ADMINISTRATION

> Artefact persistant exigé par la consigne #1/#11. Mis à jour à la fin de chaque work package (WP).
> Branche de travail : `admin-completion` (WIP Antigravity préservé sur `main` = commit `09d8d63`).
> Baseline WP0 (2026-09-10) : `flutter analyze` 0/0 · `flutter test` 36/36 · `flutter build web` OK
> (la syntaxe null-aware `initialParams: ?x` du WIP compile bien sur le compilateur web).

## Légende état

| Code | Sens |
|---|---|
| ❌ Absent | Rien dans le code/DB |
| 🟡 Partiel | Existe mais incomplet |
| 🟠 Simulé | Affiche un résultat non réel / faux succès |
| ✅ Opérationnel | Implémenté **et vérifié** bout en bout |
| 🔵 Vérifié-existant | Déjà là et confirmé fonctionnel cette session |

## Faits d'infrastructure établis (WP0)

- Supabase projet `kdprnavvgzhnygovfyuw` (« PIQ CAM »), Postgres 17.6, `ACTIVE_HEALTHY`.
  Accès Management API confirmé (PAT session).
- **Pas de `supabase_migrations.schema_migrations`** → l'historique d'application des 77 fichiers
  SQL est inconnu ; **toujours sonder le schéma live avant toute migration**. `pgvector` + `pg_cron`
  actifs. 76 tables publiques, 13 tables `ai_*`.
- **21 Edge Functions déployées** — `ai-curriculum-mapping` + `ai-pedagogical-validation` **déployées
  en WP1** (via `npx supabase functions deploy --use-api`, `SUPABASE_ACCESS_TOKEN`=PAT, depuis la
  racine du dépôt). `ai-curriculum-mapping` corrigée avant déploiement : la jointure PostgREST
  `academic_levels(name)` visait une table inexistante → remplacée par
  `academic_nodes:class_node_id(name)`. Les deux **vérifiées bout-en-bout** avec un JWT super_admin
  réel (compte de test éphémère `claude-wp1-test-admin@pqlearn.local`, à supprimer en WP8) :
  mapping renvoie de vrais chapitres, validation détecte `_mock` + leçon vide, 401 sans auth.
- **Registre `ai_agents` : 30 lignes.** 13 pointent une Edge Function réelle déployée ;
  **10 sont `gateway_native`** (AGT-006/007/008/009/010/015/017/018/019/024) = **injoignables**
  (Gateway FastAPI non déployé) ; 7 sont `draft` (AGT-002/003/011/012/013/023/026).
- Colonnes d'ordre : `chapters.display_order` ✅, `lessons.display_order` ✅, **`exercises` n'a PAS
  de colonne d'ordre** (migration additive requise en WP1).
- Table `ai_agents` = minimale (agent_id, name, mission, non_mission, catalogue_relation, status,
  owner) → **tous les champs control-plane manquent** (enabled, provider, model, tools, limites,
  dépendances, HITL, fallback, prompt) → WP2.
- `ai_rag_sources` / `ai_rag_ingestions` / `ai_rag_chunks` = schéma migration 56 seul (pas de
  crawl_rules / schedule / provenance / access_terms / job queue) → WP3.

---

## Consigne #2 — Interfaces chapitres / leçons / exercices / IA (WP1)

| Réf | Attendu | Écran / composant | Service + données | État | Reste à faire | Preuve |
|---|---|---|---|---|---|---|
| C2-01 | Distinguer chargement / vide / erreur+retry / droits | `lessons_manager_screen.dart`, `exercises_manager_screen.dart`, `academic_tree_screen.dart` | providers `chaptersWithLessons`, `exercises`, `academicTree` | 🔵 | **vérifié** : `lessons_manager` distingue déjà chargement (spinner + label) / erreur (`_loadError` + bouton Réessayer) / vide, à 2 niveaux (classes puis matières) — test dédié `lessons_loading_test.dart` (16 cas). `exercises_manager` + `academic_tree` : `.when` loading/error/empty présents ; erreur `exercises_manager` sans bouton retry (mineur) | 36 tests |
| C2-02 | Responsive tables/grilles 345/390/800/1400 px | idem + `pedagogical_catalog_screen.dart` | — | 🟡 | tables admin non auditées (mémoire `project_mobile_responsive_fix`) | — |
| C2-03 | Cohérence design (`ElefDesignSystem`) | tous les écrans du périmètre | — | 🟡 | plusieurs écrans mélangent `AppTheme` brut + `Theme.of(context)` non coloré + `ElefColors` (ex. `curriculum_autopilot_screen.dart`) | — |
| C2-04 | Recherche + filtres + tri + pagination | Leçons, Exercices, Catalogue | — | 🟡 | recherche présente (`_matchesSearch`) ; tri/pagination à vérifier/ajouter sur longues listes | — |
| C2-05 | Réorganisation (ordre) chapitres/leçons/exercices | `academic_tree` (nœuds via move), `lessons_manager` (leçons `display_order`), `exercises_manager` | `display_order` | 🟡 | **exercices : FAIT** — migration 81 (`exercises.display_order` + backfill par dossier chapitre/trimestre), `fetchExercises`/`fetchAllExercises` triés, `swapExerciseOrder`, boutons ▲/▼ par carte d'exercice dans son dossier. Nœuds arbre : `updateNodeOrder` existant. Reste : réordo explicite des leçons dans un chapitre (aujourd'hui `display_order` posé à la création/édition, pas de ▲/▼) | migration appliquée + analyze 0/0 + 36 tests |
| C2-06 | Duplication | chapitres ✅, exercices ✅, **leçons ?** | RPC dupli | 🟡 | vérifier/ajouter duplication de leçon | — |
| C2-07 | Import / export (CSV/JSON) chap.+leçons+exos | — | — | ❌ | à construire (aussi §18 CDC) | — |
| C2-08 | Prévisualisation fidèle (dont LaTeX récent) | `_showLessonPreviewModal`, `_showStudentPreviewModal`, `lesson_builder` aperçu | `math_text.dart` | 🟡 | vérifier rendu LaTeX + parité aperçu/élève | — |
| C2-09 | Publier / dépublier / archiver / restaurer / suppr. déf. | Leçons, Exercices, Arbre | RPC lifecycle | 🔵 | libellés à harmoniser ; vérifier présence sur chapitres | — |
| C2-10 | Opérations groupées (publier/archiver/palier sur sélection) | Leçons, Exercices | — | ❌ | à construire | — |
| C2-11 | Historique / suivi des traitements | versions leçons ✅, versions exos ✅, **chapitres ?** | `*_versions` | 🟡 | vérifier historique chapitre | — |
| C2-12 | Curriculum Autopilot : message cohérent + action réelle | `curriculum_autopilot_screen.dart` | `mapCurriculumWithAi` → `ai-curriculum-mapping` | ✅ | réécrit : disclaimer contradictoire supprimé, framing HITL exact, `ElefDesignSystem` cohérent, `_textController` réactif (listener), chaque chapitre candidat → bouton « Gérer dans Leçons & Cours » (nav id 2) + copier l'ID, transparence méthode déterministe | EF vérifiée bout-en-bout (JWT super_admin) → renvoie chapitre réel « Vérification Studio — Suites » ; `flutter analyze` 0/0 sur le fichier |
| C2-13 | File de validation : pré-contrôle IA fonctionnel | `validation_queue_screen.dart` `_runPedagogicalPrecheck` | `validateLessonWithAi` → `ai-pedagogical-validation` | 🟡 | backend ✅ (EF déployée + vérifiée : flag `_mock` bloquant sur leçon publiée, structure vide détectée). Contrat de champs identique au dialogue UI. Reste : vérif du rendu dialogue dans l'app en session + traçage `ai_agent_runs` (WP2) | EF testée sur 2 leçons réelles |
| C2-14 | Registre Agents IA lisible (schémas I/O, statut, EF liée, dernier appel) | `ai_agent_registry_screen.dart` | `aiAgentsProvider` | 🟡 | lecture seule OK pour l'affichage ; enrichir avec « en ligne / hors ligne (gateway_native) » + dernier appel ; l'édition = WP2 | — |
| C2-15 | Tableau de bord Agents IA & Coûts lisible | `ai_agents_dashboard_screen.dart` | `aiAgentCallsProvider` | 🔵 | regroupé par agent (déjà corrigé) ; lier « Derniers appels » à l'historique WP2 | — |

---

## Consigne #3 — Gestion pédagogique complète (WP1 + WP5)

| Réf | Attendu | Écran | État | Reste à faire |
|---|---|---|---|---|
| C3-01 | Arbre : systèmes/programmes, niveaux, classes, séries, matières, chapitres, leçons | `academic_tree_screen.dart` + `lessons_manager` | 🔵 | tronc commun (twin groups) OK ; vérifier séries |
| C3-02 | Compétences & prérequis | `exercises` `skills[]`/`prerequisites[]` (tags libres, migr. 54) ; pas de graphe | 🟡 | pas d'UI d'édition dédiée compétences au niveau chapitre/leçon ; graphe de compétences absent |
| C3-03 | Intro & histoire des notions | `chapters.introduction` + `intro_media_json` | 🔵 | — |
| C3-02b | Objectifs & compétences (bloc) | Studio v2 bloc `objectifs` | 🟡 | vérifier édition |
| C3-04 | Cours, explications, exemples | Studio v2 blocs | 🔵 | — |
| C3-05 | Formules & notations scientifiques | bloc `formule` + `math_text.dart` | 🟡 | rendu admin OK récent ; vérifier |
| C3-06 | Illustrations & documents | bloc `media_image` + Médiathèque | 🔵 | — |
| C3-07 | Exercices base / avancés / examen | `exercises.difficulty` | 🔵 | — |
| C3-08 | Indices | `instructions_json.hints` | 🔵 | édités admin, affichés élève |
| C3-09 | Corrigés détaillés | `solution_json` | 🔵 | — |
| C3-10 | Barèmes & critères d'évaluation | — | ❌ | à ajouter (bloc/champ exercice) |
| C3-11 | Ressources audio | — | ❌ | bloc audio + Storage → WP5 |
| C3-12 | Graphiques / simulations / labos virtuels | Studio v2 blocs `virtual_lab` (WIP) | 🟡 | insertion ajoutée (WIP) ; vérifier édition + rendu |
| C3-13 | Différenciation par type de matière (sci./litt./tech./indus./comm./techno.) | `subject_template_model.dart` | 🟡 | vérifier couverture des 6 familles |
| C3-14 | Provenance & versions préservées | `provenance` (exos) ; versions leçons/exos | 🟡 | surfacer provenance dans l'UI |

---

## Consigne #4 — Control-Plane IA centralisé (WP2) — **LIVRÉ**

Migration `78_ai_control_plane.sql` **appliquée** (Management API) : `ai_agents` +enabled/
requires_human_review/depends_on/runtime/description ; `ai_agent_versions` +prompt_template/
prompt_notes/allowed_tools/allowed_sources/limits/fallback_strategy ; nouvelles tables
`ai_agent_runs` (17 col), `ai_workflows`, `ai_workflow_steps` ; trigger d'audit `log_ai_config_change`
→ `audit_log`. `runtime` backfillé (15 edge_function, 8 gateway_native, 7 none). AGT-017/024
rattachés à leurs Edge Functions réelles. Edge Functions **déployées + vérifiées** :
`ai-agent-invoke` (harnais test/run), `ai-workflow-run` (orchestration séquentielle + reprise).
UI : `ai_agent_registry_screen.dart` réécrit en **Control-Plane** (3 vues : Agents / Historique /
Workflows). `flutter analyze` 0/0 · 36 tests · `build web` OK.

| Réf | Attendu | État | Preuve |
|---|---|---|---|
| C4-01 | Inventaire de **tous** les agents intégrés à l'admin | ✅ | 30 agents listés, filtres (en ligne/hors ligne/brouillon), badge EN LIGNE/HORS LIGNE + `offlineReason` explicite |
| C4-02 | Par agent : rôle/description | ✅ | mission/non-mission/catalogue + champ `description` éditable |
| C4-03 | Activation / désactivation | ✅ | `Switch` par carte → `updateAiAgentConfig(enabled:)` ; trigger audit |
| C4-04 | Modèle & fournisseur | 🟡 | `model_policy`/`runtime` affichés ; édition du modèle = via prompt/version, pas de sélecteur dédié |
| C4-05 | Prompts & versions (+ rollback) | ✅ | dialogue prompt_template + note de version ; `versionStatusDropdown` (draft/candidate/production/retired) = mécanisme de rollback |
| C4-06 | Outils autorisés | ✅ | éditeur de chips `allowed_tools` → `updateAiAgentVersion` |
| C4-07 | Sources utilisables | ✅ | éditeur de chips `allowed_sources` |
| C4-08 | Formats d'entrée / sortie | ✅ | schémas I/O affichés (JSON dépliable) ; l'aperçu d'entrée alimente la console de test |
| C4-09 | Limites, délais, concurrence | ✅ | champs `max_tokens`/`timeout_ms`/`max_concurrency` → `limits` jsonb |
| C4-10 | Dépendances entre agents | 🟡 | colonne `depends_on[]` + persistance service ; affichage UI à compléter |
| C4-11 | Validation humaine éventuelle | ✅ | `SwitchListTile` → `requires_human_review` |
| C4-12 | Stratégie de reprise / remplacement | 🟡 | colonne `fallback_strategy` jsonb + service ; éditeur UI dédié à finir (retry/backoff/fallback_agent) |
| C4-13 | Historique des exécutions | ✅ | onglet Historique : `ai_agent_runs` (entrée+sortie+statut+durée+schéma), filtre par agent, export CSV |
| C4-14 | Résultats, erreurs, consommation par agent | ✅ | run détaillé dépliable ; lien « historique de cet agent » depuis la carte |
| C4-15 | **Console de test** | ✅ | zone entrée JSON → `ai-agent-invoke` → sortie structurée + statut + durée + `output_valid` + issues de schéma ; désactivée si hors ligne. **Vérifié E2E** : AGT-024 → sortie valide (659 ms), AGT-006 gateway_native → échec « hors ligne » honnête, tous 2 tracés dans `ai_agent_runs` |
| C4-16 | **Workflows multi-agents** | ✅ | onglet Workflows : progression, étapes, erreurs, bouton **Reprendre**. **Vérifié E2E** : pipeline 2 étapes, étape 2 échoue (`lesson_id manquant`) → workflow `failed` 50 % → contexte corrigé → reprise → `completed` 100 % |
| C4-17 | Pas de raisonnement interne privé exposé | ✅ | console montre entrée/sortie structurée/diagnostics seulement |
| C4-18 | Rôles IA distincts | ❌ | `is_admin_user()` + `super_admin` seuls (aligné migr. 55) — rôles fins IA différés, documenté ici |

---

## Consigne #5 — Page Intégrations (WP4) — **LIVRÉ**

Migration `80_integrations.sql` **appliquée** : table `integrations` (config non secrète + `secret_ref`
= nom du function-secret + état de santé). 4 intégrations seedées (Gemini génération, Gemini
embeddings, Supabase Storage, Mobile Money). Edge Function **`integration-healthcheck` déployée +
vérifiée E2E**. UI `integrations_screen.dart` (nav id 34). Doc `docs/INTEGRATIONS_INVENTORY.md`.
`analyze` 0/0 · `test` 36/36 · `build web` OK.

| Réf | Attendu | État | Preuve |
|---|---|---|---|
| C5-01 | Page d'admin des intégrations | ✅ | écran + nav id 34 (super_admin) |
| C5-02 | Inventaire (rôle, présence/version, compat, config, licence/coût) | ✅ | carte par intégration + `docs/INTEGRATIONS_INVENTORY.md` (frameworks, libs, moteurs, modèles, API) |
| C5-03 | Activation | ✅ | `Switch` → `setIntegrationEnabled` |
| C5-04 | Test de connexion | ✅ | bouton « Tester la connexion » → `integration-healthcheck`. **Vérifié** : Gemini → OK (50 modèles, 88 ms) ; Storage → OK (2 buckets, 209 ms) ; Mobile Money → `not_configured` (honnête) |
| C5-05 | État de santé, limites, erreurs, dernière vérification | ✅ | `connected` / `last_status` / `last_error` / `last_latency_ms` / `last_check_at` affichés ; `known_limits` |
| C5-06 | Secrets côté serveur uniquement | ✅ | seul le *nom* du function-secret est affiché ; aucune clé côté client/dépôt/log |
| C5-07 | Aucune API payante obligatoire ajoutée | ✅ | contrainte respectée ; inventaire de deps = 0 ajout |

---

## Consigne #6 — Scraping & Ingestion (WP3) — **LIVRÉ**

Migration `79_ingestion_center.sql` **appliquée** : `ai_rag_sources` +source_url/raw_text/crawl_rules/
schedule/access_terms_ack/provenance/collected_at/status ; types élargis (`url`, `document`) ;
`ai_ingestion_jobs` (file générique : statut/progress/attempts/next_retry/error_history/cancel) ;
`ai_extracted_documents` (extrait + métadonnées + hash + dédup + classification + review_status) ;
`advance_ingestion_queue()` + pg_cron `process-ingestion-queue` (*/2 min, chemin texte déterministe).
Edge Function **`ingestion-worker` déployée + vérifiée E2E** : crawl `https://example.com`
(robots.txt respecté, texte extrait, job → done 100 %) ; classify (→ `ai-curriculum-mapping`) ;
validation humaine → embed (→ `ai-embeddings-generate`, **1 `ai_rag_chunk` réel** 768-dim écrit,
`ai_rag_ingestions` → completed). UI `ingestion_center_screen.dart` (nav id 33, groupe Gestion
Pédagogique) : Sources / Jobs / Extraits à relire. `analyze` 0/0 · `test` 36/36 · `build web` OK.

| Réf | Attendu | État | Preuve |
|---|---|---|---|
| C6-01 | Centre de gestion des sources & collecte | ✅ | écran + nav id 33 |
| C6-02 | Ajout/modif sources URL / texte / document | ✅ | dialogue « Nouvelle source » (URL + texte collé) ; archive/réactive |
| C6-03 | Règles inclusion/exclusion, profondeur, limites | 🟡 | `crawl_rules` jsonb persisté ; UI = champ profondeur (0 = page unique, > 0 honnêtement « non disponible cette itération ») ; include/exclude patterns pas encore édités |
| C6-04 | Fréquence & planification | 🟡 | colonne `schedule` (cron) + pg_cron worker actif ; éditeur de planning par source à finir |
| C6-05 | Lancement manuel | ✅ | bouton « Collecter / Extraire » + « Traiter la file » |
| C6-06 | Suivi, annulation, relance, tentatives | ✅ | onglet Jobs : barre de progression, « Annuler » (`cancel_requested`), « Relancer », `attempts/max`, historique d'erreurs |
| C6-07 | Détection des doublons | ✅ | empreinte SHA-256 du texte ; `is_duplicate` + `duplicate_of` ; badge DOUBLON dans l'UI |
| C6-08 | Extraction texte + métadonnées | ✅ | worker : fetch + strip HTML → texte, `metadata` {url, http_status, word_count, fetched_at, robots, depth} |
| C6-09 | OCR si nécessaire | 🟠 | **« indisponible » explicite** (aucun moteur vision auto-hébergé à coût zéro) — le worker refuse les content-types image/pdf avec un message clair, jamais de faux résultat |
| C6-10 | Nettoyage & structuration | ✅ | compaction espaces/lignes ; `ai-document-structuring` disponible pour la structuration fine |
| C6-11 | Classement pédagogique | ✅ | job `classify` → `ai-curriculum-mapping` → `classification` + `proposed_chapter/subject/class_node` sur l'extrait |
| C6-12 | Prévisualisation, validation/rejet | ✅ | onglet Extraits : aperçu texte + métadonnées + classement proposé → « Valider → indexer RAG » / « Rejeter » (motif obligatoire) |
| C6-13 | Provenance + date de collecte, historique erreurs | ✅ | `provenance`, `collected_at`, `error_history[]` jsonb affiché |
| C6-14 | Contenu collecté = non fiable (anti prompt-injection) | ✅ | le texte n'est jamais concaténé dans un prompt d'agent ; seul `ai-curriculum-mapping` le lit (rapprochement lexical déterministe, sans LLM) |
| C6-15 | Traitement arrière-plan non bloquant + reprise | ✅ | file `ai_ingestion_jobs` + worker Edge (UI kick + polling) + pg_cron ; reprise = `retryIngestionJob` / worker rejoue les `failed` sous `max_attempts` |

---

## Consigne #7 — Réponses interactives administrables + packs hors-ligne (WP5) — **partiel, en partie différé**

| Réf | Attendu | État | Constat / reste |
|---|---|---|---|
| C7-01 | Config + preview des types de contenu interactif | 🟡 | Studio v2 (`lesson_builder_screen.dart` + `lessons_manager` `kEditableBlockTypes`) couvre : paragraph, definition, theoreme, **formule (rendu LaTeX `math_text.dart`)**, methode, exemple, piege, conseil_examen, **summary_card (tableau comparatif + mémos)**, media_image, **virtual_lab (5 simulateurs déterministes)**. Aperçu élève fidèle via `_buildPreviewSection`. **Manquent** : bloc QCM affiché (généré mais pas rendu élève), bloc audio/prononciation, corrections par étapes dédiées, graph/schéma comme blocs autonomes |
| C7-02 | Formats structurés versionnés | ❌ **différé** | table `render_formats` (schema jsonb + version) non créée — le Studio v2 fige la liste des types en constante Dart ; migration vers un registre versionné = chantier suivant |
| C7-03 | Validation des réponses d'agents avant usage | 🟡 | `ai-pedagogical-validation` **déployé + vérifié** et branché dans la File de Validation (bouton pré-contrôle) ; pas encore obligatoire dans la RPC de publication atomique |
| C7-04 | Composants de rendu réutilisables + galerie de preview | 🟡 **différé** | composants pédagogiques réutilisables existent (`core/design_system/pedagogical/*`) ; **galerie centrale de prévisualisation** non construite |
| C7-05 | Pas d'exécution de code arbitraire produit par IA | 🔵 | garanti : aucune sortie IA n'est `eval`/exécutée ; les simulateurs sont des moteurs déterministes codés en dur |
| C7-06 | Préparation de packs hors-ligne | ❌ **différé** | table `offline_packs` + écran non construits ; le cahier MVP-Optimisé impose déjà un téléchargement par leçon explicite côté élève (hors périmètre admin du jour) |

**Raison du report** : WP5 est le plus gros reste et le moins prioritaire par rapport à l'insistance
explicite du porteur (« chapitres, leçons, exercices et fonctions IA »). Le socle (blocs typés +
aperçu fidèle + LaTeX + simulateurs) est opérationnel ; galerie centrale, registre versionné et
packs hors-ligne sont un chantier distinct chiffrable.

---

## Consigne #9 — Autres modules admin (WP6) — **vérifié**

Passe de vérification (2026-09-11) : `flutter analyze` 0/0 sur les 36 écrans, `flutter test` 36/36,
toutes les tables de domaine interrogées avec succès contre le Supabase réel, `audit_log` actif
(140 lignes). Détail par module vs `AUDIT_SYSTEME_COMPLET_2026_09_08.md` (qui documente déjà ces
modules comme opérationnels des sessions précédentes) :

| Module | Écran(s) | État | Constat / reste |
|---|---|---|---|
| Utilisateurs / profils / rôles / permissions | `users_roles/*` (6 écrans) | 🔵 opérationnel | sessions, anti-partage, permissions nommées (`_showPermissionsModal`), audit sur suppressions. **Reste** : import/export CSV en masse (§18) ; **2FA admin** (« non-optionnelle » au cahier) absente — hors périmètre du jour, à trancher |
| Abonnements & droits d'accès | `subscriptions/*` (5 écrans) | 🔵 opérationnel | paliers (`subscription_tiers`), matrice (`matrix_features`/`access_matrix`), paiements/litiges, boutique, dons — CRUD réel. Cycle d'expiration piloté par pg_cron `subscription-lifecycle-daily` (migr. 30, actif) |
| Examens & événements | `exams_events/*` (4 écrans) | 🔵 opérationnel | officiels, établissements, olympiades — CRUD réel + revue/publication OCR (WIP Antigravity préservé) |
| Notifications & communications | `announcements_screen.dart` + `system_settings_screen.dart` (`_showEditTemplateModal`) | 🟡 partiel | 11 `notification_templates` **éditables** ; `scheduled_reminders`/`notification_log` écrits par le cron. **Reste** : vue d'historique des envois (`notification_log`) dans l'admin |
| Tableaux de bord & statistiques | `dashboard/*` | 🔵 opérationnel | tous les KPI branchés sur des providers réels (`activeProfilesCountProvider`, `publishedLessonsCountProvider`, `exercisesCountProvider`, `openTicketsCountProvider`, `validationQueueProvider`, `aiAgentCallsProvider`, `adminAssistantSummaryProvider`) + refresh |
| Paramètres système | `system_settings_screen.dart` | 🔵 opérationnel | `app_settings` (migr. 38) + templates de notification |
| Documents & médias | `media_library_screen.dart`, `shop_management_screen.dart` | 🔵 opérationnel | Médiathèque raccordée au Studio (commit `34ecc9f`), boutique CRUD réel |
| Traçabilité des actions | `audit_log_screen.dart` | 🔵 opérationnel | 140 lignes ; **le trigger `log_ai_config_change` (WP2) écrit bien `ai_config_update` dans `audit_log`** (vérifié : UPDATE `ai_agents` → ligne d'audit avec `after_json.agent_id`) |

---

## Consignes transverses

| Réf | Attendu | Suivi |
|---|---|---|
| C8 | Données de bout en bout (interface→autorisation→service→persistance→retour) | vérifié au fil des WP + WP7 |
| C10 | Vérifier les parcours réels (10 scénarios) | WP8 |
| C12 | Livrer avec preuves (`docs/ADMIN_DELIVERY_REPORT.md`) | WP8 |

---

## Documents cités et disponibles

Tous présents dans `docs/` : `CAHIER_DES_CHARGES_MASTER_MAJ_2026.md`, `cahier_des_charges.md`,
`CAHIER_DES_CHARGES_AGENTS_IA.md`, `CAHIER_IA_ZERO_COUT_MASTER.md`,
`CAHIER_TECHNIQUE_{ADMIN_AI_CONTROL_PLANE,CONTENT_FACTORY,FRAMEWORKS_OUTILS_IA,QUOTAS_COMPUTE}.md`,
`CONTENT_FACTORY_GAP_ANALYSIS.md`, `AUDIT_SYSTEME_COMPLET_2026_09_08.md`. Aucun document normatif
manquant identifié à ce stade. (Les 2 PDF originaux du cahier ne sont pas sur disque mais le
`.md` `cahier_des_charges.md` en est la transcription vivante — cf. mémoire projet.)

---

## Retour porteur 2026-09-12 (2ème vague de tests réels) — suivi des 6 points

| # | Demande | État | Détail / preuve |
|---|---|---|---|
| 1 | Agent de collecte de programmes : recherche→collecte→extraction→structuration réelles, priorité sources ministérielles, jamais d'invention, gaps signalés | 🔵 **livré** | `curriculum-scrape-start`/`curriculum-crawl-worker`/`curriculum-scrape-extract` — découverte CommonCrawl+Gemini grounding+Wikipédia, crawl BFS robots.txt, extraction Model Router. Prouvé E2E multi-pays (47 URL/5 domaines découverts, 51 pages crawlées, 19 items extraits, gaps honnêtes signalés). Commits `84b2aca`/`bd3ee3a`. |
| 2 | Écriture directe dans l'arbre académique : rattachement, dédup, statut « À vérifier », non-écrasement des éditions manuelles, undo | 🔵 **livré** | `curriculum-apply`/`curriculum-cancel` — `verification_status`/`manually_edited`/`curriculum_import_id` (migr. 83). Prouvé E2E Cameroun : 115 items proposés, 18 appliqués, re-collecte sans doublon, annulation totalement réversible. Commit `21f63ab`. |
| 3 | Agent de conception cours/leçons : contexte curriculaire complet + séparation stricte plan / rédaction / exemples / exercices, régénération partielle sans perte | 🟡 **implémenté, E2E réel bloqué par quota** | `ai-course-structuring` (3 modes `plan`/`full`/`examples_only` + `resolveCurricularContext`) et `ai-exercise-generation` (même contexte + Model Router) déployés, `deno check` propre. `lessons_manager_screen.dart` : 3 boutons séparés, fusion stricte en mode exemples (ne touche jamais aux blocs déjà rédigés). `flutter analyze` 0, `flutter test` 51/51, `flutter build web` OK. **Bloqué** : quota Gemini gratuit épuisé (429 stable, quota journalier) et aucun autre fournisseur (`GROQ_API_KEY`/`CEREBRAS_API_KEY`/`OPENROUTER_API_KEY`/`MISTRAL_API_KEY`) configuré comme secret Supabase → le Model Router n'a aucun repli disponible aujourd'hui. Signalé au porteur (a choisi de continuer sans vérification E2E immédiate). **Reste** : rejouer les 3 modes dès qu'une clé est fournie ou que le quota se réinitialise. |
| 4 | Ergonomie : pages dédiées séparées (arbre / détail / conception / aperçu / suivi), vraie navigation retour avec fil d'Ariane, zones de travail agrandies | 🟡 **démarré** | Éditeur de leçon (`_showLessonEditorModal`) converti d'une `AlertDialog` de taille fixe (max 1080px) en vraie page poussée (`Navigator.push`/`MaterialPageRoute`) avec `AppBar` + fil d'Ariane réel (Matière › Chapitre) + bouton retour natif préservant la position de la liste sous-jacente + zone de travail pleine largeur. Pilotage de collecte (`curriculum_autopilot_screen.dart`) déjà sur page dédiée (`_ImportDetailScreen`, commit `4350c6c`). **Reste** : même traitement pour l'éditeur d'exercices (`exercises_manager_screen.dart`), l'inspecteur inline de l'Arbre Académique, et le Studio de cours (`lesson_builder_screen.dart`). |
| 5 | LaTeX/texte scientifique : chaîne complète, délimiteurs, jamais de code brut, tous types de notations | 🔵 **livré** | `core/widgets/math_text.dart` réécrit (délimiteurs `$…$`/`$$…$$`/`\(…\)`/`\[…\]`, repli mhchem, erreur non brute) + 5 fichiers corrigés (`elef_callout.dart`, `elef_summary_sheet_card.dart`, `lesson_builder_screen.dart`, `lessons_manager_screen.dart`). 15 tests dédiés (`math_text_rendering_test.dart`) : fractions, racines, puissances/indices, vecteurs, systèmes, matrices, limites/dérivées/intégrales, unités physiques, chimie×2, délimiteurs alternatifs, `$` isolé, formule invalide, isolation display. |
| 6 | Preuve par parcours réel avec captures, simulé vs réel distingué | 🟡 **partiel** | Étapes 1-2 (collecte→arbre→persistance→re-collecte sans doublon) prouvées en API directe (voir #1/#2). Étape 3 (génération leçon scientifique→modification→aperçu) bloquée sur le même quota IA que #3. **Reste** : parcours UI complet avec captures d'écran une fois le repli IA opérationnel. |

**Prochaine étape recommandée** : (a) obtenir au moins une clé gratuite supplémentaire (Groq
recommandé — https://console.groq.com/keys, gratuit, sans CB) pour débloquer #3/#6 ; (b) poursuivre
#4 sur `exercises_manager_screen.dart` et l'Arbre Académique.
