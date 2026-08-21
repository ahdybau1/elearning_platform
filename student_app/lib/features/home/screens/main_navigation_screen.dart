import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import 'home_dashboard_screen.dart';
import '../../courses/screens/subjects_list_screen.dart';
import '../../exams/screens/official_exams_screen.dart';
import '../../exams/screens/mock_exam_arena_screen.dart';
import '../../ai_tutor/screens/ai_tutor_chat_screen.dart';
import '../../community/screens/class_forum_screen.dart';
import '../../subscription/screens/boutique_shop_screen.dart';

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

// Application élève à part entière (projet Flutter distinct de admin_app, jamais compilée ni
// déployée avec lui) — cette barre latérale reprend seulement le LANGAGE visuel de admin_app
// (modules dépliables → pages), pour une cohérence de famille de produit, pas un partage de code.
final List<_NavModule> _studentModules = [
  _NavModule(title: 'Général', pages: [
    _NavPage(title: 'Tableau de Bord', icon: Icons.dashboard_rounded, screen: const HomeDashboardScreen()),
  ]),
  _NavModule(title: 'Pédagogie', pages: [
    _NavPage(title: 'Mes Matières & Cours', icon: Icons.menu_book_rounded, screen: const SubjectsListScreen()),
  ]),
  _NavModule(title: 'Examens & Concours', pages: [
    _NavPage(title: 'Examens Officiels', icon: Icons.workspace_premium_rounded, screen: const OfficialExamsScreen()),
    _NavPage(title: 'Concours Blancs', icon: Icons.emoji_events_rounded, screen: const MockExamArenaScreen()),
  ]),
  _NavModule(title: 'Assistant IA', pages: [
    _NavPage(title: 'Tuteur IA', icon: Icons.auto_awesome_rounded, screen: const AiTutorChatScreen()),
  ]),
  _NavModule(title: 'Communauté', pages: [
    _NavPage(title: 'Forum de Classe', icon: Icons.forum_rounded, screen: const ClassForumScreen()),
  ]),
  _NavModule(title: 'Boutique', pages: [
    _NavPage(title: 'Documents à la Carte', icon: Icons.storefront_rounded, screen: const BoutiqueShopScreen()),
  ]),
];

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedFlatIndex = 0;
  final Set<String> _expandedModules = {
    for (final m in _studentModules) m.title,
  };

  List<_NavPage> get _flatPages => _studentModules.expand((m) => m.pages).toList();

  @override
  Widget build(BuildContext context) {
    final pages = _flatPages;
    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      body: Row(
          children: [
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: StudentTheme.surfaceDark,
                border: const Border(right: BorderSide(color: StudentTheme.borderDark)),
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
                            gradient: const LinearGradient(
                              colors: [StudentTheme.accentPrimary, StudentTheme.accentIndigo],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('E-Learning National',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: StudentTheme.borderDark),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: _studentModules.map((module) {
                        final isExpanded = _expandedModules.contains(module.title);
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
                                padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        module.title.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: StudentTheme.textMuted,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                                      size: 18,
                                      color: StudentTheme.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              ...module.pages.map((page) {
                                final flatIndex = pages.indexOf(page);
                                final isSelected = flatIndex == _selectedFlatIndex;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? StudentTheme.accentPrimary.withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      leading: Icon(page.icon, size: 20,
                                          color: isSelected ? StudentTheme.accentPrimary : StudentTheme.textSecondary),
                                      title: Text(
                                        page.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          color: isSelected ? Colors.white : StudentTheme.textSecondary,
                                        ),
                                      ),
                                      onTap: () => setState(() => _selectedFlatIndex = flatIndex),
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 4),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/profiles'),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Changer de Profil'),
                      style: OutlinedButton.styleFrom(foregroundColor: StudentTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedFlatIndex,
                children: pages.map((p) => p.screen).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
