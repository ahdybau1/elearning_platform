import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../../core/theme/subject_visuals.dart';

class SubjectsListScreen extends ConsumerWidget {
  const SubjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return profile == null
        ? const Center(child: CircularProgressIndicator())
        : StudentPageContent(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: StudentScreenHeader(
                    title: 'Cours & Matières (${profile.className})',
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(
                        studentSubjectsProvider(profile.classNodeId),
                      );
                      return subjectsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(
                          child: Text(
                            'Erreur: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        data: (subjects) {
                          if (subjects.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_outlined,
                                      size: 46,
                                      color: context.colors.textMuted,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucune matière programmée pour ${profile.className}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'L\'administration n\'a pas encore associé de matière à cette classe.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: subjects.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final s = subjects[index];
                              final visual = SubjectVisuals.forSubject(
                                code: s.code,
                                name: s.name,
                              );
                              return InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/chapters',
                                    arguments: {
                                      'subjectId': s.id,
                                      'subjectName': s.name,
                                      'subjectCode': s.code,
                                      'classNodeId': profile.classNodeId,
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: visual.gradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: visual.gradient.last
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              right: -8,
                                              bottom: -8,
                                              child: SubjectMotif(
                                                icon: visual.icon,
                                                size: 42,
                                                opacity: 0.22,
                                              ),
                                            ),
                                            Center(
                                              child: Icon(
                                                visual.icon,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.name,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    context.colors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              s.chaptersCount > 0
                                                  ? '${s.chaptersCount} chapitres au programme'
                                                  : 'Chapitres en cours de publication',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: context
                                                    .colors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: context.colors.surface,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: context.colors.textSecondary,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
