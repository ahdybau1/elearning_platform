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
| C2-01 | Distinguer chargement / vide / erreur+retry / droits | `lessons_manager_screen.dart`, `exercises_manager_screen.dart`, `academic_tree_screen.dart` | providers `chaptersWithLessons`, `exercises`, `academicTree` | 🟡 | audit `AsyncValue.when` de chaque écran ; « chargement présenté comme absence » signalé sur Leçons (ADMIN_TRANSVERSAL_AUDIT) ; réutiliser `elef_empty_state.dart` | — |
| C2-02 | Responsive tables/grilles 345/390/800/1400 px | idem + `pedagogical_catalog_screen.dart` | — | 🟡 | tables admin non auditées (mémoire `project_mobile_responsive_fix`) | — |
| C2-03 | Cohérence design (`ElefDesignSystem`) | tous les écrans du périmètre | — | 🟡 | plusieurs écrans mélangent `AppTheme` brut + `Theme.of(context)` non coloré + `ElefColors` (ex. `curriculum_autopilot_screen.dart`) | — |
| C2-04 | Recherche + filtres + tri + pagination | Leçons, Exercices, Catalogue | — | 🟡 | recherche présente (`_matchesSearch`) ; tri/pagination à vérifier/ajouter sur longues listes | — |
| C2-05 | Réorganisation (ordre) chapitres/leçons/exercices | `academic_tree` (chapitres via move), `lessons_manager` (leçons), `exercises_manager` | `display_order` | 🟡 | leçons : réordo up/down + persistance `display_order` ; **exercices : colonne d'ordre à créer** | — |
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

## Consigne #4 — Control-Plane IA centralisé (WP2)

| Réf | Attendu (CAHIER_TECHNIQUE_ADMIN_AI_CONTROL_PLANE ADM-077..093 ; CDC IA §9) | État | Reste à faire |
|---|---|---|---|
| C4-01 | Inventaire de **tous** les agents (26 catalogue + présents en code) intégrés à l'admin | 🟡 | 30 en registre ; 10 gateway_native injoignables, 7 draft — marquer « hors ligne » honnêtement |
| C4-02 | Par agent : rôle/description | 🔵 | `mission`/`non_mission` en DB |
| C4-03 | Activation / désactivation | ❌ | colonne `enabled` + toggle UI |
| C4-04 | Modèle & fournisseur administrables | 🟡 | dans `model_policy` jsonb, non éditable |
| C4-05 | Instructions & versions de prompts (+ diff, rollback) | ❌ | `prompt_template`/`prompt_version` + UI versions |
| C4-06 | Outils autorisés | 🟡 | `ai_tools` existe ; pas de lien agent→tools éditable |
| C4-07 | Sources utilisables | ❌ | `allowed_sources[]` |
| C4-08 | Formats d'entrée / sortie | 🟡 | `input_schema`/`output_schema` en DB, non éditables |
| C4-09 | Limites, délais, concurrence | 🟡 | `ai_policies` (concurrency_limit, allowance) ; pas par agent |
| C4-10 | Dépendances entre agents | ❌ | `depends_on[]` |
| C4-11 | Validation humaine éventuelle | ❌ | `requires_human_review` |
| C4-12 | Stratégie de reprise / remplacement | ❌ | `fallback_strategy` jsonb |
| C4-13 | Historique des exécutions | 🟡 | `ai_agent_calls` (sans payload I/O ni workflow) → `ai_agent_runs` |
| C4-14 | Résultats, erreurs, consommation par agent | 🟡 | agrégé dans dashboard ; pas de détail run |
| C4-15 | **Console de test** (entrée → sortie structurée → vérif schéma) | ❌ | Edge Function générique + UI |
| C4-16 | **Suivi de workflows multi-agents** (progression, étapes, erreurs, reprise) | ❌ | `ai_workflows` + `ai_workflow_steps` + UI |
| C4-17 | Ne pas exposer de raisonnement interne privé | 🟡 | à respecter dans la console |
| C4-18 | Rôles IA distincts (`AI_ADMIN`, `PEDAGOGICAL_AI_REVIEWER`, `RAG_MANAGER`…) | ❌ | `is_admin` seul aujourd'hui — best-effort ou documenté |

---

## Consigne #5 — Page Intégrations (WP4)

| Réf | Attendu | État | Reste à faire |
|---|---|---|---|
| C5-01 | Page d'admin des intégrations | ❌ | écran + nav |
| C5-02 | Inventaire (rôle, présence/version, compatibilité, config, licence/coût) | ❌ | table `integrations` + doc `INTEGRATIONS_INVENTORY.md` |
| C5-03 | Activation | ❌ | toggle `enabled` |
| C5-04 | Test de connexion | ❌ | Edge Function `integration-healthcheck` |
| C5-05 | État de santé, limites, erreurs, dernière vérification | ❌ | colonnes `last_check_at/last_status/last_error` |
| C5-06 | Secrets côté serveur uniquement | 🔵 | déjà function secrets Supabase (`GEMINI_API_KEY`, `SERVICE_ROLE_KEY`) — ne rien exposer client |
| C5-07 | Aucune API payante obligatoire ajoutée | 🔵 | contrainte respectée |

---

## Consigne #6 — Scraping & Ingestion (WP3)

| Réf | Attendu | État | Reste à faire |
|---|---|---|---|
| C6-01 | Centre de gestion des sources & collecte | ❌ | écran `ingestion_center_screen.dart` |
| C6-02 | Ajout/modif sources, URL/sites/fichiers/documents | 🟡 | table `ai_rag_sources` (schéma minimal) |
| C6-03 | Règles inclusion/exclusion, profondeur, limites | ❌ | `crawl_rules` jsonb |
| C6-04 | Fréquence & planification | ❌ | `schedule` + pg_cron worker |
| C6-05 | Lancement manuel | ❌ | bouton + insert job |
| C6-06 | Suivi, annulation, relance, temporisation, nouvelles tentatives | ❌ | `ai_ingestion_jobs` (statut/progress/attempts/next_retry) |
| C6-07 | Détection des doublons | ❌ | hash empreinte |
| C6-08 | Extraction texte + métadonnées | 🟡 | `ai-document-structuring` existe |
| C6-09 | OCR si nécessaire | 🟠 | pas de moteur vision auto-hébergé à coût zéro → **livré « indisponible »** honnête |
| C6-10 | Nettoyage & structuration | 🟡 | via `ai-document-structuring` |
| C6-11 | Classement pédagogique | 🟡 | via `ai-curriculum-mapping` (à déployer) |
| C6-12 | Prévisualisation avant intégration, validation/rejet | ❌ | `ai_extracted_documents` état `preview/validated/rejected` |
| C6-13 | Provenance + date de collecte, historique erreurs | ❌ | colonnes dédiées |
| C6-14 | Contenu collecté = non fiable (anti prompt-injection) | 🔵 | principe à appliquer dans le worker |
| C6-15 | Traitement en arrière-plan sans bloquer l'UI | ❌ | pg_cron + Edge worker |

---

## Consigne #7 — Réponses interactives administrables + packs hors-ligne (WP5)

| Réf | Attendu | État | Reste à faire |
|---|---|---|---|
| C7-01 | Config + preview : texte enrichi, formules, tableaux, cartes, indices, corrections par étapes, QCM, audio/prononciation, graphiques, schémas, simulations | 🟡 | Studio v2 couvre ~10 types ; manquent tableaux, cartes, corrections par étapes, QCM affiché, audio, graph/schéma dédiés |
| C7-02 | Formats structurés versionnés | ❌ | table `render_formats` (schema jsonb + version) |
| C7-03 | Validation des réponses d'agents avant usage | 🟡 | brancher `ai-pedagogical-validation` au chemin de publication |
| C7-04 | Composants de rendu réutilisables + preview fidèle | 🟡 | galerie de composants centrale absente |
| C7-05 | Pas d'exécution de code arbitraire produit par IA | 🔵 | à garantir |
| C7-06 | Préparation de packs hors-ligne (sélection, dépendances, versions, taille) | ❌ | table `offline_packs` + écran |

---

## Consigne #9 — Autres modules admin (WP6)

| Module | Écran(s) | État | Reste à faire |
|---|---|---|---|
| Utilisateurs / profils / rôles / permissions | `users_roles/*` | 🔵 | import/export CSV (§18) ; 2FA admin (« non-optionnelle », absente) — décision périmètre |
| Abonnements & droits d'accès | `subscriptions/*` | 🔵 | vérifier pilotage du cycle d'expiration (pg_cron migr. 30) |
| Examens & événements | `exams_events/*` | 🔵 | publication atomique `exam_paper_review` (WIP) à revérifier |
| Notifications & communications | `announcements_screen.dart` + templates | 🟡 | écran de pilotage des templates + historique d'envoi |
| Tableaux de bord & statistiques | `dashboard/*` | 🟡 | relier chaque KPI à des données réelles ; limites explicites si service manquant |
| Paramètres système | `system_settings_screen.dart` | 🔵 | vérifier |
| Documents & médias | `media_library_screen.dart`, `shop_management_screen.dart` | 🔵 | vérifier |
| Traçabilité des actions | `audit_log_screen.dart` | 🔵 | vérifier couverture des nouvelles tables (control-plane, ingestion, intégrations) |

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
