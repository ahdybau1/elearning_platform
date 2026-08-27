import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/auth/parent_auth_provider.dart';
import '../../../core/auth/parent_space_navigation.dart';
import '../../../core/providers/student_providers.dart';
import 'home_dashboard_screen.dart';
import '../../profile/screens/student_profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../parent_portal/screens/parent_dashboard_screen.dart';
import '../../courses/screens/subjects_list_screen.dart';
import '../../courses/screens/exercises_hub_screen.dart';
import '../../exams/screens/official_exams_screen.dart';
import '../../exams/screens/establishment_papers_screen.dart';
import '../../exams/screens/mock_exam_arena_screen.dart';
import '../../ai_tutor/screens/ai_tutor_chat_screen.dart';
import '../../community/screens/class_forum_screen.dart';
import '../../community/screens/study_communities_screen.dart';
import '../../subscription/screens/boutique_shop_screen.dart';
import '../../support/screens/donations_screen.dart';
import '../../support/screens/support_tickets_screen.dart';

class _NavPage {
  final String title;
  final IconData icon;
  final Widget screen;
  final bool requiresParentPin;
  const _NavPage({required this.title, required this.icon, required this.screen, this.requiresParentPin = false});
}

class _NavModule {
  final String title;
  final List<_NavPage> pages;
  const _NavModule({required this.title, required this.pages});
}

// Noms de groupe fixes (utilisés pour retenir l'état déplié/replié), indépendants des pages qui
// peuvent apparaître ou disparaître selon le profil actif (ex : Examens Officiels, §4 du CDC).
const List<String> _kModuleGroupTitles = [
  'Mon espace', 'Apprentissage', 'Évaluation', 'Communauté', 'Services', 'Support',
];

/// Application élève à part entière (projet Flutter distinct de admin_app, jamais compilée ni
/// déployée avec lui) — construction VOLONTAIREMENT calquée sur `main_admin_layout.dart` (même
/// structure : coquille avec barre latérale + une seule barre du haut partagée, réduction de la
/// barre, surbrillance du groupe actif, survol des items) pour que les deux applications
/// « soient faites de la même façon », comme demandé — pas un partage de code, juste la même
/// discipline de construction. Groupes et pages calqués sur l'architecture de navigation du
/// cahier des charges (§20) : Mon espace / Apprentissage / Évaluation / Communauté / Services /
/// Support.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedFlatIndex = 0;
  bool _isSidebarCollapsed = false;
  final Set<String> _expandedModules = {..._kModuleGroupTitles};

  /// §4 du cahier des charges : « Un niveau sans examen officiel n'affiche simplement pas cette
  /// fonctionnalité. » — un profil dont la classe n'a aucune ligne dans `official_exams` (ex : une
  /// classe de 2nde, qui ne compose ni BEPC ni Probatoire ni Bac) ne voit tout simplement pas
  /// l'entrée « Examens Officiels ». Quand l'examen existe, le libellé reprend son nom exact (ex :
  /// « Anciens Sujets BEPC ») au lieu d'un intitulé générique qui laissait croire à un catalogue
  /// commun à tous les niveaux.
  List<_NavModule> _buildModules(String? classNodeId) {
    final examAsync = classNodeId == null
        ? null
        : ref.watch(officialExamForClassProvider(classNodeId));
    final exam = examAsync?.valueOrNull;

    return [
      _NavModule(title: 'Mon espace', pages: [
        _NavPage(title: 'Tableau de Bord', icon: Icons.dashboard_rounded, screen: const HomeDashboardScreen()),
        _NavPage(title: 'Mon Profil', icon: Icons.person_outline_rounded, screen: const StudentProfileScreen()),
        _NavPage(title: 'Paramètres', icon: Icons.settings_outlined, screen: const SettingsScreen()),
        _NavPage(
          title: 'Espace Parent',
          icon: Icons.family_restroom_rounded,
          screen: const ParentDashboardScreen(),
          requiresParentPin: true,
        ),
      ]),
      _NavModule(title: 'Apprentissage', pages: [
        _NavPage(title: 'Mes Matières & Cours', icon: Icons.menu_book_rounded, screen: const SubjectsListScreen()),
        _NavPage(title: 'Exercices', icon: Icons.edit_note_rounded, screen: const ExercisesHubScreen()),
        _NavPage(title: 'Tuteur Numérique', icon: Icons.auto_awesome_rounded, screen: const AiTutorChatScreen()),
      ]),
      _NavModule(title: 'Évaluation', pages: [
        if (exam != null)
          _NavPage(
            title: 'Anciens Sujets ${exam.name}',
            icon: Icons.workspace_premium_rounded,
            screen: const OfficialExamsScreen(),
          ),
        _NavPage(title: 'Épreuves par Établissement', icon: Icons.apartment_rounded, screen: const EstablishmentPapersScreen()),
        _NavPage(title: 'Examens Blancs & Olympiades', icon: Icons.emoji_events_rounded, screen: const MockExamArenaScreen()),
      ]),
      _NavModule(title: 'Communauté', pages: [
        _NavPage(title: 'Forum de Classe', icon: Icons.forum_rounded, screen: const ClassForumScreen()),
        _NavPage(title: 'Communautés d\'Étude', icon: Icons.groups_rounded, screen: const StudyCommunitiesScreen()),
      ]),
      _NavModule(title: 'Services', pages: [
        _NavPage(title: 'Documents à la Carte', icon: Icons.storefront_rounded, screen: const BoutiqueShopScreen()),
        _NavPage(title: 'Soutien / Dons', icon: Icons.favorite_outline_rounded, screen: const DonationsScreen()),
      ]),
      _NavModule(title: 'Support', pages: [
        _NavPage(title: 'Messagerie & Tickets', icon: Icons.support_agent_rounded, screen: const SupportTicketsScreen()),
      ]),
    ];
  }

  // Même logique que `_buildNavTile` de admin_app : fond de sélection porté par un Container
  // (pas ListTile.selectedTileColor, invisible sous le DecoratedBox de la barre latérale), survol
  // discret, icône/texte mis en avant quand sélectionné.
  Widget _buildNavTile({required _NavPage page, required bool isSelected, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? context.colors.accentPrimary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          leading: Icon(page.icon, size: 20,
              color: isSelected ? context.colors.accentPrimary : context.colors.textSecondary),
          title: Text(
            page.title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    // Amorce la restauration de session parent dès l'affichage de la coquille principale (voir
    // ParentAuthNotifier._init) — sans ça, le premier clic sur « Espace Parent » de la session
    // pourrait redemander une connexion alors qu'une session valide était en cours de restauration.
    ref.watch(parentAuthProvider);
    final profile = authState.activeProfile;
    final studentModules = _buildModules(profile?.classNodeId);
    final pages = studentModules.expand((m) => m.pages).toList();
    if (_selectedFlatIndex >= pages.length) _selectedFlatIndex = 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Row(
          children: [
            // Sidebar Left Navigation — mêmes dimensions/transition que main_admin_layout.dart
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 80 : 260,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(right: BorderSide(color: context.colors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [context.colors.accentPrimary, context.colors.accentIndigo],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('E-Learning National',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.colors.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: studentModules.map((module) {
                        final isExpanded = _expandedModules.contains(module.title);
                        final isModuleActive = module.pages.contains(pages.isEmpty ? null : pages[_selectedFlatIndex]);

                        if (_isSidebarCollapsed) {
                          // Barre réduite en rail d'icônes : accès direct, pas de groupes (le nom
                          // du groupe est de toute façon invisible ici) — même comportement que
                          // main_admin_layout.dart.
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: module.pages.map((page) {
                              final flatIndex = pages.indexOf(page);
                              return _buildNavTile(
                                page: page,
                                isSelected: flatIndex == _selectedFlatIndex,
                                onTap: () => page.requiresParentPin
                                    ? _openParentPage(flatIndex)
                                    : setState(() => _selectedFlatIndex = flatIndex),
                              );
                            }).toList(),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedModules.remove(module.title);
                                } else {
                                  _expandedModules.add(module.title);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        module.title.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isModuleActive ? context.colors.accentPrimary : context.colors.textMuted,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                                      size: 18,
                                      color: isModuleActive ? context.colors.accentPrimary : context.colors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              ...module.pages.map((page) {
                                final flatIndex = pages.indexOf(page);
                                return _buildNavTile(
                                  page: page,
                                  isSelected: flatIndex == _selectedFlatIndex,
                                  onTap: () => page.requiresParentPin
                                      ? _openParentPage(flatIndex)
                                      : setState(() => _selectedFlatIndex = flatIndex),
                                );
                              }),
                            const SizedBox(height: 4),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  // Réduire la barre — même emplacement/style que main_admin_layout.dart.
                  InkWell(
                    onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.border))),
                      child: Row(
                        mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Icon(
                            _isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                            color: context.colors.textMuted,
                          ),
                          if (!_isSidebarCollapsed) ...[
                            const SizedBox(width: 12),
                            Text('Réduire la barre', style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Espace de travail principal : une seule barre du haut partagée (contexte + profil),
            // puis le contenu de la page sans AppBar individuelle — même structure que
            // main_admin_layout.dart.
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border(bottom: BorderSide(color: context.colors.border, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Espace Élève (${profile?.className ?? '...'})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/profiles'),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: const Text('Changer de Profil'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.textSecondary,
                            side: BorderSide(color: context.colors.border),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Se déconnecter',
                          icon: Icon(Icons.logout_rounded, color: context.colors.textSecondary, size: 20),
                          onPressed: () => ref.read(studentAuthProvider.notifier).signOut(),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: context.colors.accentPrimary,
                          child: Text(
                            (authState.account?.firstName.isNotEmpty == true)
                                ? authState.account!.firstName[0].toUpperCase()
                                : 'É',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${authState.account?.firstName ?? ''} ${authState.account?.lastName ?? ''}'.trim(),
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                            ),
                            Text('Élève', style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: context.colors.background,
                      child: IndexedStack(
                        index: _selectedFlatIndex,
                        children: pages.map((p) => p.screen).toList(),
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

  /// §17 du cahier des charges : vraie session parent (parent_accounts, distincte du compte élève)
  /// — si déjà connecté (session restaurée automatiquement au démarrage), on bascule directement
  /// sans redemander quoi que ce soit ; sinon un vrai formulaire email + mot de passe.
  Future<void> _openParentPage(int targetIndex) async {
    if (ref.read(parentAuthProvider).isAuthenticated) {
      setState(() => _selectedFlatIndex = targetIndex);
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => ParentAuthDialog(
        onSuccess: () {
          Navigator.pop(ctx);
          setState(() => _selectedFlatIndex = targetIndex);
        },
      ),
    );
  }
}
