import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/providers/student_providers.dart';

class ChaptersListScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const ChaptersListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(studentChaptersProvider(subjectId));

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          subjectName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
        data: (chapters) {
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: chapter.isUnlocked ? StudentTheme.cardDark : StudentTheme.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: chapter.isUnlocked ? StudentTheme.borderDark : StudentTheme.borderDark.withOpacity(0.4),
                  ),
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
                            color: chapter.isUnlocked
                                ? StudentTheme.accentPrimary.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Chapitre ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: chapter.isUnlocked ? StudentTheme.accentPrimary : Colors.grey,
                            ),
                          ),
                        ),
                        if (!chapter.isUnlocked)
                          Row(
                            children: [
                              const Icon(Icons.lock_clock_rounded, size: 14, color: StudentTheme.accentAmber),
                              const SizedBox(width: 4),
                              Text(
                                'Trimestre 2',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: StudentTheme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 14, color: StudentTheme.accentEmerald),
                              const SizedBox(width: 4),
                              Text(
                                'Disponible',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: StudentTheme.accentEmerald,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      chapter.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: chapter.isUnlocked ? Colors.white : StudentTheme.textSecondary,
                      ),
                    ),
                    if (chapter.introduction != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        chapter.introduction!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: StudentTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${chapter.lessonsCount} leçons • ${chapter.exercisesCount} exercices',
                          style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textMuted),
                        ),
                        if (chapter.isUnlocked)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StudentTheme.accentPrimary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/lesson-reader',
                                arguments: {'chapterId': chapter.id, 'chapterTitle': chapter.title},
                              );
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text('Ouvrir le cours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: StudentTheme.textSecondary,
                              side: const BorderSide(color: StudentTheme.borderDark),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ce chapitre sera débloqué automatiquement au Trimestre 2.')),
                              );
                            },
                            icon: const Icon(Icons.lock_outline_rounded, size: 14),
                            label: const Text('Bientôt débloqué', style: TextStyle(fontSize: 11)),
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
    );
  }
}
