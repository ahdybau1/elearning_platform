import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
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

// Application élève à part entière (projet Flutter distinct de admin_app, jamais compilée ni
// déployée avec lui) — cette barre latérale reprend seulement le LANGAGE visuel de admin_app
// (modules dépliables → pages), pour une cohérence de famille de produit, pas un partage de code.
// Groupes et pages calqués exactement sur l'architecture de navigation du cahier des charges
// (§20 — docs/cahier_des_charges.md) : Mon espace / Apprentissage / Évaluation / Communauté /
// Services / Support.
final List<_NavModule> _studentModules = [
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
    _NavPage(title: 'Tuteur IA', icon: Icons.auto_awesome_rounded, screen: const AiTutorChatScreen()),
  ]),
  _NavModule(title: 'Évaluation', pages: [
    _NavPage(title: 'Examens Officiels', icon: Icons.workspace_premium_rounded, screen: const OfficialExamsScreen()),
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
                                      onTap: () => page.requiresParentPin
                                          ? _showParentPinDialog(flatIndex)
                                          : setState(() => _selectedFlatIndex = flatIndex),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/profiles'),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Changer de Profil'),
                            style: OutlinedButton.styleFrom(foregroundColor: StudentTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Consumer(
                          builder: (context, ref, _) => IconButton(
                            tooltip: 'Se déconnecter',
                            icon: const Icon(Icons.logout_rounded, color: StudentTheme.textSecondary, size: 20),
                            onPressed: () => ref.read(studentAuthProvider.notifier).signOut(),
                          ),
                        ),
                      ],
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

  // TODO(Espace Parent réel) : même limite que dans profile_switcher_screen.dart — PIN codé en dur
  // en attendant le vrai rattachement via `parent_accounts` (§17 du cahier des charges).
  void _showParentPinDialog(int targetIndex) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudentTheme.cardDark,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: StudentTheme.accentAmber),
            const SizedBox(width: 10),
            Text('Code PIN Parent', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez votre code confidentiel à 4 chiffres (défaut : 1234) :',
              style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.firaCode(fontSize: 22, color: Colors.white, letterSpacing: 8),
              decoration: InputDecoration(
                filled: true,
                fillColor: StudentTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: StudentTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentTheme.accentAmber),
            onPressed: () {
              if (pinCtrl.text == '1234') {
                Navigator.pop(ctx);
                setState(() => _selectedFlatIndex = targetIndex);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code PIN incorrect (Code par défaut : 1234)')),
                );
              }
            },
            child: const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
