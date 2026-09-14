import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';

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
                    subtitle: 'Sélectionnez une discipline pour explorer ses chapitres et cours.',
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
                            return EmptyStateView(
                              icon: Icons.menu_book_outlined,
                              title: 'Aucune matière programmée pour ${profile.className}',
                              description:
                                  'L\'administration n\'a pas encore associé de matière à cette classe pour l\'année scolaire en cours.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            itemCount: subjects.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
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
                                borderRadius: AppRadius.radiusLarge,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: AppRadius.radiusLarge,
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
                                          borderRadius: AppRadius.radiusMedium,
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
