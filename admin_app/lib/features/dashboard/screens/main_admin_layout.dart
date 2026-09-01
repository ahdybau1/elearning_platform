import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';
import 'dashboard_overview_screen.dart';
import '../../academic_tree/screens/academic_tree_screen.dart';
import '../../content_management/screens/lessons_manager_screen.dart';
import '../../content_management/screens/exercises_manager_screen.dart';
import '../../content_management/screens/validation_queue_screen.dart';
import '../../subscriptions/screens/subscription_tiers_screen.dart';
import '../../subscriptions/screens/access_matrix_screen.dart';
import '../../subscriptions/screens/payments_reconciliation_screen.dart';
import '../../users_roles/screens/student_accounts_screen.dart';
import '../../users_roles/screens/parent_accounts_screen.dart';
import '../../users_roles/screens/teacher_management_screen.dart';
import '../../users_roles/screens/admin_users_screen.dart';
import '../../users_roles/screens/audit_log_screen.dart';
import '../../exams_events/screens/official_exams_screen.dart';
import '../../exams_events/screens/school_papers_screen.dart';
import '../../exams_events/screens/olympiads_mock_exams_screen.dart';
import '../../community_support/screens/forum_moderation_screen.dart';
import '../../community_support/screens/whatsapp_groups_screen.dart';
import '../../community_support/screens/support_tickets_screen.dart';
import '../../system_settings/screens/ai_agents_dashboard_screen.dart';
import '../../system_settings/screens/ai_agent_registry_screen.dart';
import '../../system_settings/screens/announcements_screen.dart';
import '../../system_settings/screens/system_settings_screen.dart';
import '../../content_management/screens/pedagogical_catalog_screen.dart';
import '../../subscriptions/screens/shop_management_screen.dart';
import '../../subscriptions/screens/donations_screen.dart';
import '../../academic_tree/screens/school_year_promotion_screen.dart';
import '../../users_roles/screens/active_sessions_screen.dart';

class MainAdminLayout extends ConsumerStatefulWidget {
  const MainAdminLayout({super.key});

  @override
  ConsumerState<MainAdminLayout> createState() => _MainAdminLayoutState();
}

class _MainAdminLayoutState extends ConsumerState<MainAdminLayout> {
  bool _isSidebarCollapsed = false;
  final Set<String> _expandedGroups = {};
  bool _expansionInitialized = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Navigation mobile — état local séparé du provider desktop. Retour utilisateur explicite
  // (2026-08-31) : un Drawer qui reprend tel quel un menu desktop à 8 catégories/27 items n'est
  // pas une "interface mobile", juste une réorganisation de la même interface (comme WhatsApp Web
  // vs WhatsApp mobile : deux structures de navigation différentes, pas la même repliée). Sur
  // mobile, on passe donc à un vrai modèle d'app : barre de navigation en bas à quelques
  // destinations, chaque destination ouvrant un "hub" de grosses cartes tactiles, qui ouvrent à
  // leur tour l'écran demandé en plein écran avec un bouton retour — jamais 27 items visibles
  // à la fois. `_mobileDrilledItemId` est nul quand on est sur un hub, non-nul quand on a
  // "plongé" dans un écran précis depuis ce hub.
  int _mobileTabIndex = 0;
  int? _mobileDrilledItemId;

  // En dessous de cette largeur, une barre latérale permanente ne tient plus (retour utilisateur
  // réel sur téléphone, 2026-08-29 : "le responsive est très nulle" — vérifié visuellement, la barre
  // de 280px ne laissait qu'un filet de contenu sur un écran de 390px). Même seuil que
  // student_app/main_navigation_screen.dart, pour la même discipline de construction.
  static const double _kMobileBreakpoint = 700;

  static const _allRoles = AdminRole.values;

  final List<NavGroup> _rawNavGroups = [
    NavGroup(
      title: 'Aperçu Général',
      items: [
        NavItem(id: 0, title: 'Tableau de Bord', icon: Icons.dashboard_rounded, allowedRoles: _allRoles),
      ],
    ),
    NavGroup(
      title: 'Gestion Pédagogique',
      items: [
        NavItem(
          id: 1,
          title: 'Arbre Académique',
          icon: Icons.account_tree_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
        NavItem(
          id: 2,
          title: 'Leçons & Cours',
          icon: Icons.menu_book_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu, AdminRole.enseignant],
        ),
        NavItem(
          id: 3,
          title: 'Banque d\'Exercices',
          icon: Icons.quiz_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu, AdminRole.enseignant],
        ),
        NavItem(
          id: 4,
          title: 'File de Validation',
          icon: Icons.fact_check_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
        NavItem(
          id: 22,
          title: 'Catalogue Pédagogique (16.0)',
          icon: Icons.auto_stories_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
        NavItem(
          id: 25,
          title: 'Année & Campagne Passage',
          icon: Icons.calendar_month_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
      ],
    ),
    NavGroup(
      title: 'Offres & Tarification',
      items: [
        NavItem(
          id: 5,
          title: 'Paliers & Tarifs',
          icon: Icons.sell_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
        NavItem(
          id: 6,
          title: 'Matrice de Droits',
          icon: Icons.grid_view_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
        NavItem(
          id: 7,
          title: 'Paiements & Litiges',
          icon: Icons.receipt_long_rounded,
          isFinancial: true,
          allowedRoles: [AdminRole.superAdmin],
        ),
        NavItem(
          id: 23,
          title: 'Boutique (Documents)',
          icon: Icons.storefront_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
        NavItem(
          id: 24,
          title: 'Dons & Caritatif',
          icon: Icons.volunteer_activism_rounded,
          isFinancial: true,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
      ],
    ),
    NavGroup(
      title: 'Comptes & Sécurité',
      items: [
        NavItem(
          id: 8,
          title: 'Élèves & Profils',
          icon: Icons.school_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.support],
        ),
        NavItem(
          id: 9,
          title: 'Comptes Parents',
          icon: Icons.family_restroom_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.support],
        ),
        NavItem(
          id: 10,
          title: 'Enseignants & Écoles',
          icon: Icons.badge_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
        NavItem(
          id: 26,
          title: 'Sessions & Anti-Partage',
          icon: Icons.devices_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.support],
        ),
        NavItem(
          id: 11,
          title: 'Administrateurs & Rôles',
          icon: Icons.admin_panel_settings_rounded,
          allowedRoles: [AdminRole.superAdmin],
        ),
        NavItem(
          id: 12,
          title: 'Audit Log & Traçabilité',
          icon: Icons.history_rounded,
          allowedRoles: [AdminRole.superAdmin],
        ),
      ],
    ),
    NavGroup(
      title: 'Examens & Épreuves',
      items: [
        NavItem(
          id: 13,
          title: 'Examens Officiels',
          icon: Icons.workspace_premium_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
        NavItem(
          id: 14,
          title: 'Épreuves Établissements',
          icon: Icons.domain_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu, AdminRole.enseignant],
        ),
        NavItem(
          id: 15,
          title: 'Olympiades & Examens Blancs',
          icon: Icons.emoji_events_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.adminContenu],
        ),
      ],
    ),
    NavGroup(
      title: 'Modération & Support',
      items: [
        NavItem(
          id: 16,
          title: 'Modération Forum',
          icon: Icons.forum_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.moderateur],
        ),
        NavItem(
          id: 17,
          title: 'Groupes WhatsApp',
          icon: Icons.groups_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.moderateur, AdminRole.support],
        ),
        NavItem(
          id: 18,
          title: 'Support Client',
          icon: Icons.support_agent_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays, AdminRole.support, AdminRole.moderateur],
        ),
      ],
    ),
    NavGroup(
      title: 'Système & IA',
      items: [
        NavItem(
          id: 19,
          title: 'Agents IA & Coûts',
          icon: Icons.psychology_rounded,
          allowedRoles: [AdminRole.superAdmin],
        ),
        NavItem(
          id: 27,
          title: 'Registre des Agents IA (IA-001)',
          icon: Icons.hub_rounded,
          allowedRoles: [AdminRole.superAdmin],
        ),
        NavItem(
          id: 20,
          title: 'Bannières Annonces',
          icon: Icons.campaign_rounded,
          allowedRoles: [AdminRole.superAdmin, AdminRole.adminPays],
        ),
        NavItem(
          id: 21,
          title: 'Paramètres Système',
          icon: Icons.settings_rounded,
          allowedRoles: [AdminRole.superAdmin],
        ),
      ],
    ),
  ];

  List<NavGroup> _getFilteredNavGroups(
    AdminRole role, {
    required bool canViewFinancials,
    int? pendingValidationCount,
    int? flaggedPostsCount,
    int? openTicketsCount,
  }) {
    // Les badges reflètent le vrai décompte de chaque provider, jamais une valeur factice codée en dur.
    final liveBadgeCounts = <int, int?>{
      4: pendingValidationCount,
      16: flaggedPostsCount,
      18: openTicketsCount,
    };
    final List<NavGroup> filtered = [];
    for (final group in _rawNavGroups) {
      final allowedItems = group.items
          .where((item) => item.isAllowedFor(role))
          // Un item financier sans la permission réelle (admin_permissions) ne doit même pas être
          // visible — pas de "teaser" verrouillé qui trahit l'existence d'une fonctionnalité que
          // cet admin n'a pas le droit de voir.
          .where((item) => !item.isFinancial || canViewFinancials)
          .map((item) {
            if (liveBadgeCounts.containsKey(item.id) && liveBadgeCounts[item.id] != null) {
              final count = liveBadgeCounts[item.id]!;
              return NavItem(
                id: item.id,
                title: item.title,
                icon: item.icon,
                badgeCount: count > 0 ? count : null,
                isFinancial: item.isFinancial,
                allowedRoles: item.allowedRoles,
              );
            }
            return item;
          })
          .toList();
      if (allowedItems.isNotEmpty) {
        filtered.add(NavGroup(title: group.title, items: allowedItems));
      }
    }
    return filtered;
  }

  Widget _getSelectedScreen(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return const DashboardOverviewScreen();
      case 1:
        return const AcademicTreeScreen();
      case 2:
        return const LessonsManagerScreen();
      case 3:
        return const ExercisesManagerScreen();
      case 4:
        return const ValidationQueueScreen();
      case 5:
        return const SubscriptionTiersScreen();
      case 6:
        return const AccessMatrixScreen();
      case 7:
        return const PaymentsReconciliationScreen();
      case 8:
        return const StudentAccountsScreen();
      case 9:
        return const ParentAccountsScreen();
      case 10:
        return const TeacherManagementScreen();
      case 11:
        return const AdminUsersScreen();
      case 12:
        return const AuditLogScreen();
      case 13:
        return const OfficialExamsScreen();
      case 14:
        return const SchoolPapersScreen();
      case 15:
        return const OlympiadsMockExamsScreen();
      case 16:
        return const ForumModerationScreen();
      case 17:
        return const WhatsappGroupsScreen();
      case 18:
        return const SupportTicketsScreen();
      case 19:
        return const AiAgentsDashboardScreen();
      case 20:
        return const AnnouncementsScreen();
      case 21:
        return const SystemSettingsScreen();
      case 22:
        return const PedagogicalCatalogScreen();
      case 23:
        return const ShopManagementScreen();
      case 24:
        return const DonationsScreen();
      case 25:
        return const SchoolYearPromotionScreen();
      case 26:
        return const ActiveSessionsScreen();
      case 27:
        return const AiAgentRegistryScreen();
      default:
        return const DashboardOverviewScreen();
    }
  }

  // La couleur de fond de l'état sélectionné est portée par ce Container (pas par
  // ListTile.selectedTileColor) : ListTile peint son fond sur le Material ancestor le plus
  // proche, et le DecoratedBox de la barre latérale au-dessus masquait cet effet (voir
  // l'assertion Flutter "ListTile background color or ink splashes may be invisible").
  Widget _buildNavTile({
    required BuildContext context,
    required NavItem item,
    required bool isSelected,
    bool indented = false,
    bool? collapsedOverride,
    bool closeDrawerOnTap = false,
  }) {
    final collapsed = collapsedOverride ?? _isSidebarCollapsed;
    return Container(
      margin: EdgeInsets.only(
        left: indented && !collapsed ? 20 : 12,
        right: 12,
        top: 2,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accentBlue.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          leading: Icon(
            item.icon,
            size: 20,
            color: isSelected ? AppTheme.accentBlue : Colors.white70,
          ),
          title: collapsed
              ? null
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                    if (item.badgeCount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRose,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
          onTap: () {
            ref.read(selectedNavIndexProvider.notifier).state = item.id;
            if (closeDrawerOnTap) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Contenu de la barre latérale, partagé entre le mode permanent (desktop/tablette large, dans le
  /// `Row` du `body`) et le mode tiroir (`Drawer`, mobile — `isDrawer: true` force la barre à rester
  /// dépliée : "réduire la barre" n'a pas de sens dans un tiroir qui se referme déjà tout seul, et
  /// chaque tap sur un item ferme le tiroir, voir `_buildNavTile`'s `closeDrawerOnTap`).
  Widget _buildSidebarColumn(List<NavGroup> filteredGroups, int selectedIndex, {required bool isDrawer}) {
    final collapsed = isDrawer ? false : _isSidebarCollapsed;
    return Column(
      children: [
        // App Brand Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentBlue, AppTheme.accentIndigo],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-LEARNING',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Administration HQ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Navigation Items List (STRICTLY FILTERED BY ROLE)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: filteredGroups.length,
            itemBuilder: (context, groupIdx) {
              final group = filteredGroups[groupIdx];
              final isGroupExpanded = collapsed ? false : _expandedGroups.contains(group.title);
              final isGroupActive = group.items.any((i) => i.id == selectedIndex);
              final groupHasBadges = group.items.any((i) => i.badgeCount != null);

              if (collapsed) {
                // Barre réduite en rail d'icônes : pas de groupes, accès direct à toutes les
                // pages autorisées (le nom du groupe est de toute façon invisible ici). Jamais en
                // mode Drawer (voir `collapsed` ci-dessus).
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: group.items.map((item) => _buildNavTile(
                        context: context,
                        item: item,
                        isSelected: selectedIndex == item.id,
                        collapsedOverride: collapsed,
                        closeDrawerOnTap: isDrawer,
                      )).toList(),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() {
                        if (isGroupExpanded) {
                          _expandedGroups.remove(group.title);
                        } else {
                          _expandedGroups.add(group.title);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.title.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isGroupActive ? AppTheme.accentBlue : AppTheme.textMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            if (groupHasBadges && !isGroupExpanded)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentRose,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Icon(
                              isGroupExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                              size: 18,
                              color: isGroupActive ? AppTheme.accentBlue : AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isGroupExpanded)
                    ...group.items.map((item) => _buildNavTile(
                          context: context,
                          item: item,
                          isSelected: selectedIndex == item.id,
                          indented: true,
                          collapsedOverride: collapsed,
                          closeDrawerOnTap: isDrawer,
                        )),
                ],
              );
            },
          ),
        ),

        // Sidebar Collapse Toggle — uniquement pertinent en mode permanent (desktop/tablette).
        if (!isDrawer)
          InkWell(
            onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.primaryBorder)),
              ),
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    _isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    color: AppTheme.textMuted,
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 12),
                    Text('Réduire la barre', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Regroupe les catégories du menu desktop en au plus 5 destinations de barre de navigation
  /// mobile (Accueil + jusqu'à 4 autres). "Aperçu Général" (1 seul item : Tableau de Bord) mène
  /// directement à l'écran, sans hub intermédiaire à un seul choix — inutile.
  List<_MobileTab> _buildMobileTabs(List<NavGroup> filteredGroups) {
    NavGroup? find(String title) =>
        filteredGroups.where((g) => g.title == title).firstOrNull;
    const knownTitles = {
      'Aperçu Général',
      'Gestion Pédagogique',
      'Comptes & Sécurité',
      'Offres & Tarification',
    };
    final tabs = <_MobileTab>[];
    final apercu = find('Aperçu Général');
    if (apercu != null) {
      tabs.add(_MobileTab(label: 'Accueil', icon: Icons.dashboard_rounded, groups: [apercu]));
    }
    final pedago = find('Gestion Pédagogique');
    if (pedago != null) {
      tabs.add(_MobileTab(label: 'Pédagogie', icon: Icons.menu_book_rounded, groups: [pedago]));
    }
    final comptes = find('Comptes & Sécurité');
    if (comptes != null) {
      tabs.add(_MobileTab(label: 'Comptes', icon: Icons.people_alt_rounded, groups: [comptes]));
    }
    final offres = find('Offres & Tarification');
    if (offres != null) {
      tabs.add(_MobileTab(label: 'Offres', icon: Icons.sell_rounded, groups: [offres]));
    }
    final plusGroups =
        filteredGroups.where((g) => !knownTitles.contains(g.title)).toList();
    if (plusGroups.isNotEmpty) {
      tabs.add(_MobileTab(label: 'Plus', icon: Icons.more_horiz_rounded, groups: plusGroups));
    }
    return tabs;
  }

  Widget _buildMobileTopBar({
    required String title,
    required bool showBack,
    required VoidCallback onBack,
    required VoidCallback onMenu,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.primarySurface,
        border: Border(bottom: BorderSide(color: AppTheme.primaryBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Sur un écran plongé, seule la flèche retour était visible ici — aucun moyen visible
          // de rouvrir le tiroir pour sauter directement vers une autre section sans d'abord
          // revenir au hub (constaté réellement : un tap au même endroit pour "changer d'onglet"
          // déclenchait un retour, pas l'ouverture du menu, 2026-08-31). Le bouton menu reste donc
          // toujours accessible, la flèche retour s'ajoute devant lui quand on est plongé.
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              tooltip: 'Retour',
              onPressed: onBack,
            ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white70),
            tooltip: 'Menu',
            onPressed: onMenu,
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const _CountryScopeSelector(compact: true),
        ],
      ),
    );
  }

  Widget _buildMobileHubTile(NavItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            _mobileDrilledItemId = item.id;
            ref.read(selectedNavIndexProvider.notifier).state = item.id;
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: AppTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                if (item.badgeCount != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHubBody(_MobileTab tab) {
    final showSectionHeaders = tab.groups.length > 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in tab.groups) ...[
          if (showSectionHeaders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Text(
                group.title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ),
          ...group.items.map(_buildMobileHubTile),
          if (showSectionHeaders) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildMobileBody(_MobileTab tab) {
    final single = tab.singleItem;
    final itemId = single?.id ?? _mobileDrilledItemId;
    if (itemId != null &&
        (single != null || tab.groups.any((g) => g.items.any((i) => i.id == itemId)))) {
      return _KeyboardScrollBridge(
        key: ValueKey('kb-scroll-mobile-$itemId'),
        child: _getSelectedScreen(itemId),
      );
    }
    return _buildMobileHubBody(tab);
  }

  /// Tiroir mobile — remplace la barre de navigation en bas (retour utilisateur réel, 2026-08-31 :
  /// une barre à 5 onglets restait mal exploitable sur son téléphone). Toujours 5 destinations au
  /// maximum (au lieu des 27 items à plat de l'ancien Drawer desktop-reflué), chacune assez grande
  /// pour le doigt — juste ouverte via un bouton burger au lieu d'être fixée en bas de l'écran.
  Widget _buildMobileDrawer(List<_MobileTab> tabs, int currentIndex) {
    return Drawer(
      backgroundColor: AppTheme.primarySurface,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentBlue, AppTheme.accentIndigo],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'E-LEARNING',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Administration HQ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _buildMobileDrawerTile(tabs[i], isSelected: i == currentIndex, onTap: () {
                      setState(() {
                        _mobileTabIndex = i;
                        _mobileDrilledItemId = null;
                        final single = tabs[i].singleItem;
                        if (single != null) {
                          ref.read(selectedNavIndexProvider.notifier).state = single.id;
                        }
                      });
                      Navigator.of(context).pop();
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawerTile(_MobileTab tab, {required bool isSelected, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentBlue.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(tab.icon, color: isSelected ? AppTheme.accentBlue : Colors.white70),
          title: Text(
            tab.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
          trailing: tab.hasBadge
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.accentRose, shape: BoxShape.circle),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMobileScaffold(List<NavGroup> filteredGroups) {
    final tabs = _buildMobileTabs(filteredGroups);
    final safeTabIndex = _mobileTabIndex < tabs.length ? _mobileTabIndex : 0;
    final activeTab = tabs[safeTabIndex];
    final single = activeTab.singleItem;
    final showBack = single == null && _mobileDrilledItemId != null;
    String title = activeTab.label;
    if (single != null) {
      title = single.title;
    } else if (_mobileDrilledItemId != null) {
      final drilled = activeTab.groups
          .expand((g) => g.items)
          .where((i) => i.id == _mobileDrilledItemId)
          .firstOrNull;
      if (drilled != null) title = drilled.title;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.primaryDark,
      drawer: _buildMobileDrawer(tabs, safeTabIndex),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileTopBar(
              title: title,
              showBack: showBack,
              onBack: () => setState(() => _mobileDrilledItemId = null),
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(child: _buildMobileBody(activeTab)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final authState = authAsync.valueOrNull;
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    if (authAsync.isLoading || authState == null) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pendingValidationCount = ref.watch(pendingValidationCountProvider).valueOrNull;
    final flaggedPostsCount = ref.watch(flaggedPostsProvider).valueOrNull?.length;
    final openTicketsCount = ref.watch(openTicketsCountProvider).valueOrNull;
    final filteredGroups = _getFilteredNavGroups(
      authState.role,
      canViewFinancials: authState.canViewFinancials,
      pendingValidationCount: pendingValidationCount,
      flaggedPostsCount: flaggedPostsCount,
      openTicketsCount: openTicketsCount,
    );

    // If active screen is not allowed for current role, default back to index 0
    final isCurrentAllowed = filteredGroups.any(
      (g) => g.items.any((item) => item.id == selectedIndex),
    );
    if (!isCurrentAllowed && selectedIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(selectedNavIndexProvider.notifier).state = 0;
      });
    }

    String? groupTitleFor(int navId) {
      for (final g in filteredGroups) {
        if (g.items.any((item) => item.id == navId)) return g.title;
      }
      return null;
    }

    // Le groupe contenant l'écran actif s'ouvre automatiquement à l'entrée dans l'app.
    if (!_expansionInitialized) {
      _expansionInitialized = true;
      final activeGroup = groupTitleFor(selectedIndex);
      if (activeGroup != null) _expandedGroups.add(activeGroup);
      // Équivalent mobile : place l'onglet + l'écran plongé initiaux sur ceux qui correspondent
      // à selectedIndex (ex: après un retour au premier plan sur un écran précis).
      final initialTabs = _buildMobileTabs(filteredGroups);
      for (var i = 0; i < initialTabs.length; i++) {
        final t = initialTabs[i];
        final matches = t.singleItem?.id == selectedIndex ||
            t.groups.any((g) => g.items.any((it) => it.id == selectedIndex));
        if (matches) {
          _mobileTabIndex = i;
          _mobileDrilledItemId = t.singleItem != null ? null : selectedIndex;
          break;
        }
      }
    }

    // Une navigation déclenchée ailleurs (ex: raccourci du tableau de bord) doit aussi
    // dérouler automatiquement le groupe correspondant, même s'il était replié, et faire
    // "plonger" la vue mobile sur le bon onglet/écran.
    ref.listen<int>(selectedNavIndexProvider, (previous, next) {
      final group = groupTitleFor(next);
      if (group != null && !_expandedGroups.contains(group)) {
        setState(() => _expandedGroups.add(group));
      }
      final tabsNow = _buildMobileTabs(filteredGroups);
      for (var i = 0; i < tabsNow.length; i++) {
        final t = tabsNow[i];
        final matches = t.singleItem?.id == next ||
            t.groups.any((g) => g.items.any((it) => it.id == next));
        if (matches) {
          setState(() {
            _mobileTabIndex = i;
            _mobileDrilledItemId = t.singleItem != null ? null : next;
          });
          break;
        }
      }
    });

    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

    if (isMobile) {
      return _buildMobileScaffold(filteredGroups);
    }

    // Ce point n'est plus atteint que pour l'affichage desktop/tablette (voir le retour anticipé
    // `_buildMobileScaffold` ci-dessus) — le Drawer et le bouton burger mobiles ont donc disparu
    // d'ici, remplacés par la navigation mobile dédiée.
    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarCollapsed ? 80 : 280,
            decoration: const BoxDecoration(
              color: AppTheme.primarySurface,
              border: Border(
                right: BorderSide(color: AppTheme.primaryBorder, width: 1),
              ),
            ),
            child: _buildSidebarColumn(filteredGroups, selectedIndex, isDrawer: false),
          ),

          // Main Screen Right Workspace
          Expanded(
            child: Column(
              children: [
                // Top Global Header Bar
                Container(
                  height: 70,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28),
                  decoration: const BoxDecoration(
                    color: AppTheme.primarySurface,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.primaryBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Menu burger — uniquement sous le seuil mobile (voir `drawer` du Scaffold).
                      if (isMobile) ...[
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white70),
                          tooltip: 'Menu',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      // Active Context Indicator — Flexible pour ne jamais forcer un overflow du
                      // Row quand la fenêtre est étroite (RenderFlex overflow constaté). Sur mobile,
                      // le titre de la page active remplace le contexte pays (plus utile, moins
                      // encombrant — le contexte pays reste accessible via le sélecteur compact).
                      if (!isMobile)
                        Consumer(
                          builder: (context, ref, _) {
                            final selectedIds = ref.watch(selectedCountryIdsProvider);
                            final countriesAsync = ref.watch(nodesByTypeProvider('country'));
                            final countries = countriesAsync.valueOrNull ?? [];
                            final label = selectedIds == null
                                ? 'Tous les pays'
                                : selectedIds.length == 1
                                    ? (countries.where((c) => c.id == selectedIds.first).firstOrNull?.name ??
                                        '1 pays')
                                    : '${selectedIds.length} pays';
                            return Flexible(
                              child: Text(
                                'Espace Administration ($label)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Expanded(
                          child: Text(
                            groupTitleFor(selectedIndex) ?? 'Administration',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                        ),
                      if (!isMobile) const Spacer(),

                      // Sélecteur de pays — multi-sélection réelle + "Tous les pays", remplace
                      // l'ancienne liste factice codée en dur jamais connectée à rien. Version
                      // compacte (icône seule) sur mobile — la place manque pour le libellé complet.
                      _CountryScopeSelector(compact: isMobile),
                      SizedBox(width: isMobile ? 8 : 16),

                      // Financial Rights Badge Indicator — masqué sur mobile (information
                      // secondaire, place limitée ; reste visible dans Paramètres/Profil admin).
                      if (!isMobile) ...[
                        Tooltip(
                          message: authState.canViewFinancials
                              ? 'Accès Financier : Autorisé (Super-Admin)'
                              : 'Accès Financier : Restreint (Masquage de sécurité)',
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: authState.canViewFinancials
                                ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                                : AppTheme.accentRose.withValues(alpha: 0.2),
                            child: Icon(
                              authState.canViewFinancials
                                  ? Icons.attach_money_rounded
                                  : Icons.lock_rounded,
                              size: 18,
                              color: authState.canViewFinancials
                                  ? AppTheme.accentEmerald
                                  : AppTheme.accentRose,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],

                      // Profile Avatar User Info — nom/rôle masqués sur mobile, seul l'avatar reste
                      // (identité complète toujours visible dans Mon Profil).
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.accentBlue,
                            child: Text(
                              authState.firstName.isNotEmpty
                                  ? authState.firstName[0].toUpperCase()
                                  : 'A',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${authState.firstName} ${authState.lastName}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  authState.role.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Page Screen Container Body
                Expanded(
                  child: Container(
                    color: AppTheme.primaryDark,
                    // `ListView`/`SingleChildScrollView` ne réclament jamais le focus au clic sur
                    // leur contenu (texte, cartes) : sans widget dédié, les flèches du clavier
                    // n'ont donc aucune Scrollable ciblée et ne font jamais rien, sur aucune page.
                    // Reclé sur `selectedIndex` pour redonner le focus (et donc le défilement au
                    // clavier) à chaque changement de page.
                    child: _KeyboardScrollBridge(
                      key: ValueKey('kb-scroll-$selectedIndex'),
                      child: _getSelectedScreen(selectedIndex),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de pays de la navbar : "Tous les pays" ou une sélection spécifique, qui filtre
/// réellement ce qui est affiché/créé dans toute l'application (via selectedCountryIdsProvider,
/// lu en interne par nodesByTypeProvider/termsProvider/subjectsProvider) — remplace l'ancienne
/// liste factice codée en dur (Cameroun/Côte d'Ivoire/Sénégal) jamais connectée à rien.
class _CountryScopeSelector extends ConsumerWidget {
  // `compact` (mobile) : icône seule, sans le libellé texte — la barre du haut n'a plus la place
  // pour "Tous les pays"/le nom du pays à côté du menu burger et de l'avatar (retour utilisateur
  // réel sur téléphone, 2026-08-29). Le picker complet reste identique, juste son déclencheur change.
  final bool compact;
  const _CountryScopeSelector({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedCountryIdsProvider);
    final countriesAsync = ref.watch(nodesByTypeProvider('country'));
    final countries = countriesAsync.valueOrNull ?? [];
    final label = selectedIds == null
        ? 'Tous les pays'
        : selectedIds.length == 1
            ? (countries.where((c) => c.id == selectedIds.first).firstOrNull?.name ?? '1 pays')
            : '${selectedIds.length} pays';

    if (compact) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: IconButton(
          tooltip: label,
          icon: const Icon(Icons.flag_rounded, color: AppTheme.accentEmerald, size: 18),
          onPressed: countries.isEmpty ? null : () => _showPicker(context, ref, countries, selectedIds),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onPressed: countries.isEmpty ? null : () => _showPicker(context, ref, countries, selectedIds),
        icon: const Icon(Icons.flag_rounded, color: AppTheme.accentEmerald, size: 18),
        label: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<AcademicNode> countries,
    Set<String>? current,
  ) {
    bool allSelected = current == null;
    final specific = Set<String>.from(current ?? countries.map((c) => c.id));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.flag_rounded,
            iconColor: AppTheme.accentEmerald,
            text: 'Pays actifs',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtre ce qui est affiché et créé dans toute l\'application.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  // ignore: deprecated_member_use
                  RadioListTile<bool>(
                    // ignore: deprecated_member_use
                    value: true,
                    // ignore: deprecated_member_use
                    groupValue: allSelected,
                    activeColor: AppTheme.accentEmerald,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Tous les pays', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    // ignore: deprecated_member_use
                    onChanged: (_) => setModalState(() => allSelected = true),
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<bool>(
                    // ignore: deprecated_member_use
                    value: false,
                    // ignore: deprecated_member_use
                    groupValue: allSelected,
                    activeColor: AppTheme.accentEmerald,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pays spécifiques', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    // ignore: deprecated_member_use
                    onChanged: (_) => setModalState(() => allSelected = false),
                  ),
                  if (!allSelected)
                    ...countries.map((c) => CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 24),
                          value: specific.contains(c.id),
                          activeColor: AppTheme.accentEmerald,
                          title: Text(c.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                          onChanged: (checked) => setModalState(() {
                            if (checked == true) {
                              specific.add(c.id);
                            } else {
                              specific.remove(c.id);
                            }
                          }),
                        )),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: () {
                if (allSelected || specific.isEmpty) {
                  // Rien de coché en mode "spécifique" : on retombe sur "Tous" plutôt que de
                  // filtrer silencieusement sur un ensemble vide qui masquerait tout.
                  ref.read(selectedCountryIdsProvider.notifier).state = null;
                } else {
                  ref.read(selectedCountryIdsProvider.notifier).state = Set.from(specific);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une destination de la barre de navigation mobile — regroupe une ou plusieurs [NavGroup] du
/// menu desktop. Si elle ne contient au total qu'un seul [NavItem] (ex: Accueil), l'appui ouvre
/// directement l'écran plutôt qu'un hub à un seul choix.
class _MobileTab {
  final String label;
  final IconData icon;
  final List<NavGroup> groups;
  _MobileTab({required this.label, required this.icon, required this.groups});

  NavItem? get singleItem {
    final allItems = groups.expand((g) => g.items).toList();
    return allItems.length == 1 ? allItems.first : null;
  }

  bool get hasBadge => groups.any((g) => g.items.any((i) => i.badgeCount != null));
}

class NavGroup {
  final String title;
  final List<NavItem> items;
  NavGroup({required this.title, required this.items});
}

class NavItem {
  final int id;
  final String title;
  final IconData icon;
  final int? badgeCount;
  final bool isFinancial;
  final List<AdminRole>? allowedRoles;

  NavItem({
    required this.id,
    required this.title,
    required this.icon,
    this.badgeCount,
    this.isFinancial = false,
    this.allowedRoles,
  });

  bool isAllowedFor(AdminRole role) {
    if (role == AdminRole.superAdmin) return true;
    if (allowedRoles == null || allowedRoles!.isEmpty) return true;
    return allowedRoles!.contains(role);
  }
}

/// Fait fonctionner les flèches Haut/Bas/PageUp/PageDown sur la page affichée.
///
/// Aucune des `ListView`/`SingleChildScrollView` de l'app ne réclame le focus clavier au clic sur
/// son contenu (texte, cartes) — seuls les boutons/champs le font. Sans ce pont, une pression sur
/// une flèche n'a donc aucune Scrollable ciblée et ne fait jamais rien, quelle que soit la page. On
/// simule plutôt un vrai `PointerScrollEvent` (identique à celui de la molette, qui lui fonctionne
/// déjà) au centre de la zone de contenu : ça déclenche le même chemin de défilement natif sans
/// dépendre du système de focus. `autofocus: true` + la ValueKey posée par l'appelant (recréée à
/// chaque changement de page) redonnent ce comportement à chaque nouvelle page, même après qu'un
/// champ/bouton ait pris le focus sur une page précédente.
class _KeyboardScrollBridge extends StatefulWidget {
  const _KeyboardScrollBridge({super.key, required this.child});

  final Widget child;

  @override
  State<_KeyboardScrollBridge> createState() => _KeyboardScrollBridgeState();
}

class _KeyboardScrollBridgeState extends State<_KeyboardScrollBridge> {
  final GlobalKey _contentKey = GlobalKey();

  static final Map<LogicalKeyboardKey, double> _scrollDeltas = {
    LogicalKeyboardKey.arrowDown: 70,
    LogicalKeyboardKey.arrowUp: -70,
    LogicalKeyboardKey.pageDown: 500,
    LogicalKeyboardKey.pageUp: -500,
  };

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = _scrollDeltas[event.logicalKey];
    if (delta == null) return KeyEventResult.ignored;

    final renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return KeyEventResult.ignored;
    }
    final center = renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(position: center, scrollDelta: Offset(0, delta)),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: KeyedSubtree(key: _contentKey, child: widget.child),
    );
  }
}
