import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../subscription/screens/paywall_modal.dart';

class OfficialExamsScreen extends ConsumerStatefulWidget {
  const OfficialExamsScreen({super.key});

  @override
  ConsumerState<OfficialExamsScreen> createState() =>
      _OfficialExamsScreenState();
}

class _OfficialExamsScreenState extends ConsumerState<OfficialExamsScreen> {
  int _selectedFilterIndex = 0; // 0: Tous, 1: Examens Nationaux, 2: Collèges d'Excellence

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final examsAsync = ref.watch(studentOfficialExamsProvider(profile?.classNodeId ?? ''));

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Annales & Épreuves (${profile?.className ?? ''})',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: StudentTheme.accentAmber,
            ),
            onPressed: () => Navigator.pushNamed(context, '/mock-arena'),
            icon: const Icon(Icons.emoji_events_rounded, size: 18),
            label: const Text('Examens Blancs', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(0, 'Toutes les épreuves'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Nationaux (BAC / BEPC)'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Lycées d\'Excellence'),
              ],
            ),
          ),

          // Exams List
          Expanded(
            child: examsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
              data: (exams) {
                final filtered = exams.where((e) {
                  if (_selectedFilterIndex == 1) return e.examType == 'officiel';
                  if (_selectedFilterIndex == 2) return e.examType == 'etablissement';
                  return true;
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final exam = filtered[index];
                    final isOfficial = exam.examType == 'officiel';

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: StudentTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StudentTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOfficial
                                      ? StudentTheme.accentIndigo.withOpacity(0.15)
                                      : StudentTheme.accentAmber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOfficial ? 'EXAMEN NATIONAL' : 'ÉPREUVE ÉTABLISSEMENT',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOfficial ? StudentTheme.accentIndigo : StudentTheme.accentAmber,
                                  ),
                                ),
                              ),
                              Text(
                                'Session ${exam.year}',
                                style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            exam.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (exam.schoolName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              exam.schoolName!,
                              style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: StudentTheme.borderDark),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ouverture du sujet avec filigrane de sécurité...')),
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined, size: 16),
                                  label: const Text('Consulter Sujet', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: StudentTheme.accentEmerald,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    if (profile?.hasActiveSubscription != true) {
                                      PaywallModal.show(context);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Affichage du corrigé détaillé pas-à-pas.')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                  label: const Text('Corrigé Détaillé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSel = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
      selectedColor: StudentTheme.accentPrimary.withOpacity(0.2),
      backgroundColor: StudentTheme.cardDark,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: isSel ? StudentTheme.accentPrimary : StudentTheme.textSecondary,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSel ? StudentTheme.accentPrimary : StudentTheme.borderDark),
      ),
    );
  }
}
