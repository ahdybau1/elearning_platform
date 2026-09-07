# Audit transversal de l’administration — 7 septembre 2026

## Périmètre et méthode

Session administrateur existante, aperçu local : visite des destinations visibles des cinq hubs (Accueil, Pédagogie, Comptes, Offres, Plus), lecture des actions accessibles, inspection de code et des contrats Supabase. Six templates du Studio observés. Les formulaires de modification et actions sensibles ne sont pas tous exercés : ouverture de page ne vaut pas validation métier. Le Centre des moteurs est inspecté dans le code ; son entrée n’était pas visible dans la portion du hub consultée. Aucun compte, paiement, permission ou contenu publié modifié pendant l’audit.

## Écarts prioritaires et plan

| Écart confirmé | Preuve | Correction prévue | Risque |
|---|---|---|---|
| Médiathèque fictive et inutilisable à 345 px | 4 photos externes codées en dur ; copie/insertion = snackbar seule ; en-tête très étroit | Réutiliser mediaLibraryProvider et MediaAsset existants, upload existant, vraie copie et sélection dans les éditeurs, affichage responsive | Faible, aucune migration |
| Générateur image simulé | ImageGenerationEngine.generate attend 600 ms puis renvoie une URL prédéfinie | État indisponible explicite, aucun faux résultat généré | Compatibilité des types conservée |
| Autopilot certifie un exemple | _loadSampleCurriculum, délais, injection sans écriture | Garder l’exemple consultable comme exemple non validé, retirer faux succès et injection, guider vers arbre réel | Aucun contenu existant supprimé |
| Centre moteurs fabrique diagnostics et latence | Délais 300/600 ms puis opérationnel/12 ms/100% | Vérifications locales limitées à leurs preuves, état non vérifié pour intégrations distantes, interface responsive | Aucun changement de permissions |
| Tableau de bord trop long | Liste brute de tous les appels IA sur 30 jours | Regroupement/réduction à traiter après les annonces trompeuses | Lecture seule |
| Chargement présenté comme absence | Leçons annonce initialement aucune classe puis affiche les données | État de chargement à distinguer dans une passe dédiée | Lecture seule |

Exigences : MASTER administration §2.3/2.5/2.7, Content Factory §4/5/6/9, Agents IA §9, AGENTS.md (aucun faux succès), responsive. Pas de nouveau provider payant, migration, changement RLS ou publication dans ce lot.

## Inventaire du code des écrans

Les nombres ci-dessous sont des points d’entrée de callbacks repérés, pas des opérations validées.

| Écran | Callbacks UI repérés | Appels asynchrones repérés |
|---|---:|---:|
| admin_app/lib/features/academic_tree/screens/academic_tree_screen.dart | 43 | 14 |
| admin_app/lib/features/academic_tree/screens/curriculum_autopilot_screen.dart | 7 | 3 |
| admin_app/lib/features/academic_tree/screens/school_year_promotion_screen.dart | 31 | 14 |
| admin_app/lib/features/auth/screens/login_screen.dart | 1 | 1 |
| admin_app/lib/features/community_support/screens/forum_moderation_screen.dart | 4 | 2 |
| admin_app/lib/features/community_support/screens/support_tickets_screen.dart | 6 | 3 |
| admin_app/lib/features/community_support/screens/whatsapp_groups_screen.dart | 9 | 4 |
| admin_app/lib/features/content_management/screens/exercises_manager_screen.dart | 47 | 17 |
| admin_app/lib/features/content_management/screens/exercise_corrections_screen.dart | 3 | 2 |
| admin_app/lib/features/content_management/screens/lessons_manager_screen.dart | 59 | 18 |
| admin_app/lib/features/content_management/screens/lesson_builder_screen.dart | 19 | 11 |
| admin_app/lib/features/content_management/screens/media_library_screen.dart | 9 | 1 |
| admin_app/lib/features/content_management/screens/pedagogical_catalog_screen.dart | 24 | 17 |
| admin_app/lib/features/content_management/screens/validation_queue_screen.dart | 9 | 14 |
| admin_app/lib/features/dashboard/screens/dashboard_overview_screen.dart | 3 | 0 |
| admin_app/lib/features/exams_events/screens/exam_paper_review_screen.dart | 8 | 3 |
| admin_app/lib/features/exams_events/screens/official_exams_screen.dart | 31 | 8 |
| admin_app/lib/features/exams_events/screens/olympiads_mock_exams_screen.dart | 25 | 10 |
| admin_app/lib/features/exams_events/screens/school_papers_screen.dart | 27 | 7 |
| admin_app/lib/features/subscriptions/screens/access_matrix_screen.dart | 15 | 4 |
| admin_app/lib/features/subscriptions/screens/donations_screen.dart | 20 | 7 |
| admin_app/lib/features/subscriptions/screens/payments_reconciliation_screen.dart | 10 | 2 |
| admin_app/lib/features/subscriptions/screens/shop_management_screen.dart | 15 | 6 |
| admin_app/lib/features/subscriptions/screens/subscription_tiers_screen.dart | 8 | 3 |
| admin_app/lib/features/system_settings/screens/ai_agents_dashboard_screen.dart | 1 | 0 |
| admin_app/lib/features/system_settings/screens/ai_agent_registry_screen.dart | 1 | 0 |
| admin_app/lib/features/system_settings/screens/announcements_screen.dart | 12 | 5 |
| admin_app/lib/features/system_settings/screens/engine_center_screen.dart | 2 | 2 |
| admin_app/lib/features/system_settings/screens/system_settings_screen.dart | 7 | 2 |
| admin_app/lib/features/users_roles/screens/active_sessions_screen.dart | 4 | 1 |
| admin_app/lib/features/users_roles/screens/admin_users_screen.dart | 18 | 6 |
| admin_app/lib/features/users_roles/screens/audit_log_screen.dart | 9 | 0 |
| admin_app/lib/features/users_roles/screens/parent_accounts_screen.dart | 20 | 6 |
| admin_app/lib/features/users_roles/screens/student_accounts_screen.dart | 22 | 7 |
| admin_app/lib/features/users_roles/screens/teacher_management_screen.dart | 26 | 7 |

## Résultat du lot

Médiathèque persistante, copie/sélection réelles, affichage responsive, faux succès de génération/Autopilot/diagnostics corrigés. Exemple de curriculum conservé comme non validé. Tableau de bord regroupé par agent ; chargement/erreur des classes et matières distingués de l’absence. 36 tests admin passants et analyse ciblée sans problème. Bibliothèque réelle et filtre vérifiés dans le navigateur connecté. Les intégrations non raccordées restent explicitement signalées ; aucune validation métier exhaustive ou publication automatique n’est revendiquée.
