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
  }) {
    return Container(
      margin: EdgeInsets.only(
        left: indented && !_isSidebarCollapsed ? 20 : 12,
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
          title: _isSidebarCollapsed
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
          onTap: () => ref.read(selectedNavIndexProvider.notifier).state = item.id,
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
    }

    // Une navigation déclenchée ailleurs (ex: raccourci du tableau de bord) doit aussi
    // dérouler automatiquement le groupe correspondant, même s'il était replié.
    ref.listen<int>(selectedNavIndexProvider, (previous, next) {
      final group = groupTitleFor(next);
      if (group != null && !_expandedGroups.contains(group)) {
        setState(() => _expandedGroups.add(group));
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Left Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarCollapsed ? 80 : 280,
            decoration: const BoxDecoration(
              color: AppTheme.primarySurface,
              border: Border(
                right: BorderSide(color: AppTheme.primaryBorder, width: 1),
              ),
            ),
            child: Column(
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
                            colors: [
                              AppTheme.accentBlue,
                              AppTheme.accentIndigo,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (!_isSidebarCollapsed) ...[
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
                      final isGroupExpanded = _expandedGroups.contains(group.title);
                      final isGroupActive = group.items.any((i) => i.id == selectedIndex);
                      final groupHasBadges = group.items.any((i) => i.badgeCount != null);

                      if (_isSidebarCollapsed) {
                        // Barre réduite en rail d'icônes : pas de groupes, accès direct à toutes
                        // les pages autorisées (le nom du groupe est de toute façon invisible ici).
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: group.items.map((item) => _buildNavTile(
                                context: context,
                                item: item,
                                isSelected: selectedIndex == item.id,
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
                                          color: isGroupActive
                                              ? AppTheme.accentBlue
                                              : AppTheme.textMuted,
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
                                      isGroupExpanded
                                          ? Icons.keyboard_arrow_down_rounded
                                          : Icons.keyboard_arrow_right_rounded,
                                      size: 18,
                                      color: isGroupActive
                                          ? AppTheme.accentBlue
                                          : AppTheme.textMuted,
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
                                )),
                        ],
                      );
                    },
                  ),
                ),

                // Sidebar Collapse Toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.primaryBorder),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: _isSidebarCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          _isSidebarCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: AppTheme.textMuted,
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Réduire la barre',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Right Workspace
          Expanded(
            child: Column(
              children: [
                // Top Global Header Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: AppTheme.primarySurface,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.primaryBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Active Context Indicator — Flexible pour ne jamais forcer un overflow du
                      // Row quand la fenêtre est étroite (RenderFlex overflow constaté).
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
                      ),
                      const Spacer(),

                      // Sélecteur de pays — multi-sélection réelle + "Tous les pays", remplace
                      // l'ancienne liste factice codée en dur jamais connectée à rien.
                      const _CountryScopeSelector(),
                      const SizedBox(width: 16),

                      // Financial Rights Badge Indicator
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

                      // Profile Avatar User Info
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
  const _CountryScopeSelector();

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
