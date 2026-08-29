import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import 'home_dashboard_screen.dart';
import '../../profile/screens/student_profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
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
  const _NavPage({required this.title, required this.icon, required this.screen});
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
/// déployée avec lui) — construction à l'origine calquée sur `main_admin_layout.dart` (barre
/// latérale permanente), corrigée ensuite (2026-08-29, retour utilisateur réel sur téléphone : "le
/// responsive est très nulle" — vérifié visuellement, la barre latérale de 260px ne laissait qu'un
/// filet de ~40px de contenu sur un écran de 390px, texte réduit à une lettre par ligne). En dessous
/// de `_kMobileBreakpoint`, la barre latérale devient un `Drawer` (tiroir standard Material,
/// dissimulé par défaut, ouvert via une icône burger) au lieu d'être en permanence à l'écran — le
/// contenu de la barre (groupes/pages/icônes) reste identique, seul son mode d'affichage change.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedFlatIndex = 0;
  bool _isSidebarCollapsed = false;
  final Set<String> _expandedModules = {..._kModuleGroupTitles};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // En dessous de cette largeur, une barre latérale permanente ne tient plus (testé réellement sur
  // un viewport de 390px, la référence "petit téléphone" — voir le commentaire de la classe).
  static const double _kMobileBreakpoint = 700;

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

  /// Contenu de la barre latérale, partagé entre le mode permanent (desktop/tablette large, dans le
  /// `Row` du `body`) et le mode tiroir (`Drawer`, mobile — `isDrawer: true` force la barre à rester
  /// dépliée, "réduire la barre" n'aurait aucun sens dans un tiroir qui se referme déjà tout seul).
  Widget _buildSidebarContent(List<_NavModule> studentModules, List<_NavPage> pages, {required bool isDrawer}) {
    final collapsed = isDrawer ? false : _isSidebarCollapsed;
    return Column(
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
              if (!collapsed) ...[
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
              final isExpanded = collapsed ? false : _expandedModules.contains(module.title);
              final isModuleActive = module.pages.contains(pages.isEmpty ? null : pages[_selectedFlatIndex]);

              void selectPage(int flatIndex) {
                setState(() => _selectedFlatIndex = flatIndex);
                if (isDrawer) Navigator.of(context).pop();
              }

              if (collapsed) {
                // Barre réduite en rail d'icônes : accès direct, pas de groupes (le nom du groupe
                // est de toute façon invisible ici) — jamais en mode Drawer (voir isDrawer ci-dessus).
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: module.pages.map((page) {
                    final flatIndex = pages.indexOf(page);
                    return _buildNavTile(
                      page: page,
                      isSelected: flatIndex == _selectedFlatIndex,
                      onTap: () => selectPage(flatIndex),
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
                        onTap: () => selectPage(flatIndex),
                      );
                    }),
                  const SizedBox(height: 4),
                ],
              );
            }).toList(),
          ),
        ),
        // Réduire la barre — uniquement pertinent en mode permanent (desktop/tablette).
        if (!isDrawer)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    final studentModules = _buildModules(profile?.classNodeId);
    final pages = studentModules.expand((m) => m.pages).toList();
    if (_selectedFlatIndex >= pages.length) _selectedFlatIndex = 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _kMobileBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.colors.background,
      drawer: isMobile
          ? Drawer(
              backgroundColor: context.colors.surface,
              width: 280,
              child: SafeArea(child: _buildSidebarContent(studentModules, pages, isDrawer: true)),
            )
          : null,
      body: Row(
        children: [
          // Sidebar permanente — uniquement au-delà du seuil mobile (voir `drawer` ci-dessus pour
          // l'équivalent en dessous).
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 80 : 260,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(right: BorderSide(color: context.colors.border)),
              ),
              child: _buildSidebarContent(studentModules, pages, isDrawer: false),
            ),

          // Espace de travail principal : une seule barre du haut partagée (contexte + profil),
          // puis le contenu de la page sans AppBar individuelle.
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border(bottom: BorderSide(color: context.colors.border, width: 1)),
                  ),
                  child: Row(
                    children: [
                      if (isMobile) ...[
                        IconButton(
                          icon: Icon(Icons.menu_rounded, color: context.colors.textSecondary),
                          tooltip: 'Menu',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          isMobile ? (pages.isEmpty ? '' : pages[_selectedFlatIndex].title) : 'Espace Élève (${profile?.className ?? '...'})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                        ),
                      ),
                      const Spacer(),
                      // Un seul profil sur ce compte : StudentAuthGate (main.dart) saute déjà
                      // ProfileSwitcherScreen dans ce cas précis (voir `profiles.length == 1`,
                      // avant même de regarder hasConfirmedProfileThisBoot) — un bouton "Changer
                      // de Profil" cliquable ici n'aurait donc structurellement AUCUN effet
                      // visible, ce qui était exactement le bug rapporté (« rien ne se passe »).
                      // Masqué sur mobile (place limitée, action secondaire) — reste accessible
                      // depuis Mon Profil.
                      if (!isMobile && authState.profiles.length > 1) ...[
                        OutlinedButton.icon(
                          // Jamais de `pushReplacementNamed('/profiles')` ici : ça évincerait
                          // StudentAuthGate (main.dart) de la pile de navigation pour de bon, le
                          // remplaçant par un écran figé qui ne réagirait plus jamais aux
                          // changements d'état (cause du bug « renvoie vers un ancien écran »).
                          // resetProfileSelection() laisse la porte réactive faire la bascule.
                          onPressed: () => ref.read(studentAuthProvider.notifier).resetProfileSelection(),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          // « Classe », pas « Profil » : sur cet appareil, « profil » désigne déjà
                          // le compte/la personne (voir « Qui se connecte ? »,
                          // device_account_selector_screen.dart) — réutiliser le même mot ici pour
                          // choisir entre les classes du MÊME compte donnait l'impression de « profil
                          // dans un profil » (retour utilisateur direct).
                          label: const Text('Changer de Classe'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.textSecondary,
                            side: BorderSide(color: context.colors.border),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        tooltip: 'Verrouiller',
                        icon: Icon(Icons.lock_outline_rounded, color: context.colors.textSecondary, size: 20),
                        onPressed: () => ref.read(studentAuthProvider.notifier).signOut(),
                      ),
                      const SizedBox(width: 8),
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
                      // Nom/rôle à côté de l'avatar : seulement s'il reste de la place (desktop).
                      if (!isMobile) ...[
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
}
