import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';

class SubjectsListScreen extends ConsumerWidget {
  const SubjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Cours & Matières (${profile?.className ?? ''})',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : Consumer(builder: (context, ref, _) {
              final subjectsAsync = ref.watch(studentSubjectsProvider(profile.classNodeId));
              return subjectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 46, color: StudentTheme.textMuted),
                            const SizedBox(height: 16),
                            Text('Aucune matière programmée pour ${profile.className}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 6),
                            Text('L\'administration n\'a pas encore associé de matière à cette classe.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final s = subjects[index];
                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/chapters',
                            arguments: {'subjectId': s.id, 'subjectName': s.name, 'classNodeId': profile.classNodeId},
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: StudentTheme.cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: StudentTheme.borderDark),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: StudentTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.menu_book_rounded, color: StudentTheme.accentPrimary, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.chaptersCount > 0
                                          ? '${s.chaptersCount} chapitres au programme'
                                          : 'Chapitres en cours de publication',
                                      style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.arrow_forward_ios_rounded, color: StudentTheme.textSecondary, size: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }),
    );
  }
}
