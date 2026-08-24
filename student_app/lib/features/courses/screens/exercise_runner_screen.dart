import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';

class ExerciseRunnerScreen extends ConsumerStatefulWidget {
  final String chapterId;
  final String chapterTitle;

  const ExerciseRunnerScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
  });

  @override
  ConsumerState<ExerciseRunnerScreen> createState() =>
      _ExerciseRunnerScreenState();
}

class _ExerciseRunnerScreenState extends ConsumerState<ExerciseRunnerScreen> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerValidated = false;
  int _totalScore = 0;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(studentExercisesProvider(widget.chapterId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Quiz — ${widget.chapterTitle}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 16),
        ),
      ),
      body: StudentPageContent(child: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
        data: (exercises) {
          if (exercises.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 46, color: context.colors.textMuted),
                    const SizedBox(height: 16),
                    Text('Aucun exercice publié pour ce chapitre',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Revenez bientôt : l\'enseignant prépare encore ce quiz.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          final currentEx = exercises[_currentIndex];
          final progress = (_currentIndex + 1) / exercises.length;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Bar & Question Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentIndex + 1} sur ${exercises.length}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.colors.accentPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.stars_rounded, color: context.colors.accentAmber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '+${currentEx.points} XP',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.colors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(context.colors.accentPrimary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 24),

                // Question Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    currentEx.questionText,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Options List
                Expanded(
                  child: ListView.separated(
                    itemCount: currentEx.options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, optIdx) {
                      final option = currentEx.options[optIdx];
                      final isSelected = _selectedOptionIndex == optIdx;

                      Color borderColor = context.colors.border;
                      Color bgColor = context.colors.card;

                      if (_isAnswerValidated) {
                        if (optIdx == currentEx.correctIndex) {
                          borderColor = context.colors.accentEmerald;
                          bgColor = context.colors.accentEmerald.withOpacity(0.15);
                        } else if (isSelected) {
                          borderColor = context.colors.accentRose;
                          bgColor = context.colors.accentRose.withOpacity(0.15);
                        }
                      } else if (isSelected) {
                        borderColor = context.colors.accentPrimary;
                        bgColor = context.colors.accentPrimary.withOpacity(0.1);
                      }

                      return InkWell(
                        onTap: _isAnswerValidated
                            ? null
                            : () => setState(() => _selectedOptionIndex = optIdx),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? context.colors.accentPrimary : context.colors.surface,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + optIdx), // A, B, C, D
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.black : context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Explanation Block if validated
                if (_isAnswerValidated) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedOptionIndex == currentEx.correctIndex
                          ? const Color(0xFF0E2E20)
                          : const Color(0xFF2E121A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedOptionIndex == currentEx.correctIndex
                            ? context.colors.accentEmerald
                            : context.colors.accentRose,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedOptionIndex == currentEx.correctIndex
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: _selectedOptionIndex == currentEx.correctIndex
                                  ? context.colors.accentEmerald
                                  : context.colors.accentRose,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedOptionIndex == currentEx.correctIndex
                                  ? 'Excellente Réponse !'
                                  : 'Réponse Incorrecte',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentEx.explanation,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _selectedOptionIndex == null
                        ? null
                        : () {
                            if (!_isAnswerValidated) {
                              setState(() {
                                _isAnswerValidated = true;
                                if (_selectedOptionIndex == currentEx.correctIndex) {
                                  _totalScore += currentEx.points;
                                }
                              });
                            } else {
                              if (_currentIndex < exercises.length - 1) {
                                setState(() {
                                  _currentIndex++;
                                  _selectedOptionIndex = null;
                                  _isAnswerValidated = false;
                                });
                              } else {
                                _showCompletionDialog(context, exercises.length);
                              }
                            }
                          },
                    child: Text(
                      !_isAnswerValidated
                          ? 'Valider ma réponse'
                          : (_currentIndex < exercises.length - 1 ? 'Question Suivante' : 'Terminer le Quiz'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      )),
    );
  }

  void _showCompletionDialog(BuildContext context, int totalQuestions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.accentEmerald.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded, color: context.colors.accentEmerald, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              'Quiz Terminé avec Succès !',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez gagné +$_totalScore XP sur ce chapitre.',
              style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Retour au cours', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
