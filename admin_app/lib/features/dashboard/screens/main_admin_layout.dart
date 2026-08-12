import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
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

class MainAdminLayout extends ConsumerStatefulWidget {
  const MainAdminLayout({super.key});

  @override
  ConsumerState<MainAdminLayout> createState() => _MainAdminLayoutState();
}

class _MainAdminLayoutState extends ConsumerState<MainAdminLayout> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<NavGroup> _navGroups = [
    NavGroup(
      title: 'Aperçu Général',
      items: [
        NavItem(id: 0, title: 'Tableau de Bord', icon: Icons.dashboard_rounded),
      ],
    ),
    NavGroup(
      title: 'Gestion Pédagogique',
      items: [
        NavItem(
          id: 1,
          title: 'Arbre Académique',
          icon: Icons.account_tree_rounded,
        ),
        NavItem(id: 2, title: 'Leçons & Cours', icon: Icons.menu_book_rounded),
        NavItem(id: 3, title: 'Banque d\'Exercices', icon: Icons.quiz_rounded),
        NavItem(
          id: 4,
          title: 'File de Validation',
          icon: Icons.fact_check_rounded,
          badgeCount: 3,
        ),
      ],
    ),
    NavGroup(
      title: 'Offres & Tarification',
      items: [
        NavItem(id: 5, title: 'Paliers & Tarifs', icon: Icons.sell_rounded),
        NavItem(
          id: 6,
          title: 'Matrice de Droits',
          icon: Icons.grid_view_rounded,
        ),
        NavItem(
          id: 7,
          title: 'Paiements & Litiges',
          icon: Icons.receipt_long_rounded,
          isFinancial: true,
        ),
      ],
    ),
    NavGroup(
      title: 'Comptes & Sécurité',
      items: [
        NavItem(id: 8, title: 'Élèves & Profils', icon: Icons.school_rounded),
        NavItem(
          id: 9,
          title: 'Comptes Parents',
          icon: Icons.family_restroom_rounded,
        ),
        NavItem(
          id: 10,
          title: 'Enseignants & Écoles',
          icon: Icons.badge_rounded,
        ),
        NavItem(
          id: 11,
          title: 'Administrateurs & Rôles',
          icon: Icons.admin_panel_settings_rounded,
        ),
        NavItem(
          id: 12,
          title: 'Audit Log & Traçabilité',
          icon: Icons.history_rounded,
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
        ),
        NavItem(
          id: 14,
          title: 'Épreuves Établissements',
          icon: Icons.domain_rounded,
        ),
        NavItem(
          id: 15,
          title: 'Olympiades & Examens Blancs',
          icon: Icons.emoji_events_rounded,
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
          badgeCount: 2,
        ),
        NavItem(id: 17, title: 'Groupes WhatsApp', icon: Icons.groups_rounded),
        NavItem(
          id: 18,
          title: 'Support Client',
          icon: Icons.support_agent_rounded,
          badgeCount: 5,
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
        ),
        NavItem(
          id: 20,
          title: 'Bannières Annonces',
          icon: Icons.campaign_rounded,
        ),
        NavItem(
          id: 21,
          title: 'Paramètres Système',
          icon: Icons.settings_rounded,
        ),
      ],
    ),
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
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
      default:
        return const DashboardOverviewScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final authState = authAsync.valueOrNull;

    if (authAsync.isLoading || authState == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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

                // Navigation Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _navGroups.length,
                    itemBuilder: (context, groupIdx) {
                      final group = _navGroups[groupIdx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isSidebarCollapsed)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                group.title.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ...group.items.map((item) {
                            final isSelected = _selectedIndex == item.id;
                            final isRestrictedFinancial =
                                item.isFinancial &&
                                !authState.canViewFinancials;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                selected: isSelected,
                                selectedTileColor: AppTheme.accentBlue
                                    .withValues(alpha: 0.15),
                                hoverColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                leading: Icon(
                                  item.icon,
                                  size: 20,
                                  color: isSelected
                                      ? AppTheme.accentBlue
                                      : isRestrictedFinancial
                                      ? AppTheme.accentRose.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.white70,
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
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isRestrictedFinancial
                                                    ? Colors.white38
                                                    : Colors.white70,
                                              ),
                                            ),
                                          ),
                                          if (isRestrictedFinancial)
                                            const Icon(
                                              Icons.lock_rounded,
                                              size: 14,
                                              color: AppTheme.accentRose,
                                            )
                                          else if (item.badgeCount != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentRose,
                                                borderRadius:
                                                    BorderRadius.circular(10),
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
                                  if (isRestrictedFinancial) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Accès restreint : Seul le Super-Administrateur peut consulter les données financières.',
                                        ),
                                        backgroundColor: AppTheme.accentRose,
                                      ),
                                    );
                                  } else {
                                    setState(() {
                                      _selectedIndex = item.id;
                                    });
                                  }
                                },
                              ),
                            );
                          }),
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
                          color: Colors.white60,
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Réduire le menu',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white60,
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

          // Main Content Right Panel
          Expanded(
            child: Column(
              children: [
                // Top Global Header Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppTheme.primarySurface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.primaryBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Global Search Input
                      Expanded(
                        child: Container(
                          height: 42,
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: TextField(
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Rechercher un élève, un cours, un établissement...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppTheme.textMuted,
                              ),
                              filled: true,
                              fillColor: AppTheme.primaryDark,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Country Selector Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Row(
                          children: [
                            const Text('🇨🇲', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              authState.selectedCountry,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Live Role Switcher (For testing permissions enforcement)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: authState.isSuperAdmin
                              ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                              : AppTheme.accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: authState.isSuperAdmin
                                ? AppTheme.accentEmerald
                                : AppTheme.accentBlue,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AdminRole>(
                            value: authState.role,
                            dropdownColor: AppTheme.primarySurface,
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            items: AdminRole.values.map((role) {
                              return DropdownMenuItem<AdminRole>(
                                value: role,
                                child: Row(
                                  children: [
                                    Icon(
                                      role == AdminRole.superAdmin
                                          ? Icons.shield_rounded
                                          : Icons.person_rounded,
                                      size: 16,
                                      color: role == AdminRole.superAdmin
                                          ? AppTheme.accentEmerald
                                          : AppTheme.accentBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      role.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newRole) {
                              if (newRole != null) {
                                ref
                                    .read(authProvider.notifier)
                                    .switchRole(newRole);
                              }
                            },
                          ),
                        ),
                      ),
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

                      // User Avatar & Name
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.accentBlue,
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 20,
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
                    child: _getSelectedScreen(),
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

  NavItem({
    required this.id,
    required this.title,
    required this.icon,
    this.badgeCount,
    this.isFinancial = false,
  });
}
