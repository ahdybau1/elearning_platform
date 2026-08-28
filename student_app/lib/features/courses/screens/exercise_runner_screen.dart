import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';

class ExerciseRunnerScreen extends ConsumerStatefulWidget {
  final String chapterId;
  final String chapterTitle;
  /// Quand fourni (ex. depuis le hub « Exercices » — voir exercises_hub_screen.dart), court-circuite
  /// la récupération par `chapterId` : nécessaire pour les exercices liés à une leçon ou indépendants,
  /// qui n'ont justement pas de `chapterId` unique à interroger.
  final List<Exercise>? preloadedExercises;

  const ExerciseRunnerScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
    this.preloadedExercises,
  });

  @override
  ConsumerState<ExerciseRunnerScreen> createState() =>
      _ExerciseRunnerScreenState();
}

/// §3.2 du CDC : le format réel d'un exercice ('format' en base, voir admin_app `ExerciseFormat`)
/// détermine son mode d'interaction — un ancien modèle ne gérait que le QCM et ignorait les 4 autres
/// formats que l'admin peut réellement créer (réponse courte, rédaction, manuscrit scanné,
/// flashcard), qui se seraient affichés vides (aucune option à choisir).
class _ExerciseRunnerScreenState extends ConsumerState<ExerciseRunnerScreen> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isRevealed = false;
  int _totalScore = 0;
  final TextEditingController _freeTextCtrl = TextEditingController();
  /// Nombre d'indices déjà révélés pour l'exercice courant (CF-003 enrichissement) — remis à zéro à
  /// chaque changement d'exercice, jamais partagé entre deux exercices différents.
  int _hintsShown = 0;

  @override
  void dispose() {
    _freeTextCtrl.dispose();
    super.dispose();
  }

  void _goToNext(List<Exercise> exercises) {
    if (_currentIndex < exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isRevealed = false;
        _hintsShown = 0;
        _freeTextCtrl.clear();
      });
    } else {
      _showCompletionDialog(context, exercises.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = widget.preloadedExercises != null
        ? AsyncValue<List<Exercise>>.data(widget.preloadedExercises!)
        : ref.watch(studentExercisesProvider(widget.chapterId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Quiz — ${widget.chapterTitle}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
      body: StudentPageContent(
        child: exercisesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text(
              'Erreur: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (exercises) {
            if (exercises.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 46,
                        color: context.colors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun exercice publié pour ce chapitre',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Revenez bientôt : l\'enseignant prépare encore ce quiz.',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: context.colors.accentAmber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${currentEx.points} XP',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.accentPrimary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildFormatBody(context, currentEx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(context, exercises, currentEx),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statementCard(BuildContext context, Exercise ex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        ex.questionText,
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: context.colors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  /// Indices progressifs (CF-003 enrichissement) : un bouton révèle l'indice suivant, jamais tous
  /// d'un coup — cohérent avec la maïeutique du Tuteur Numérique plutôt qu'une solution donnée
  /// directement. Masqué une fois la réponse validée (plus d'utilité à ce stade).
  Widget _hintsSection(BuildContext context, Exercise ex) {
    if (ex.hints.isEmpty || _isRevealed) return const SizedBox.shrink();
    final hasMore = _hintsShown < ex.hints.length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _hintsShown; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.accentAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: context.colors.accentAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ex.hints[i],
                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (hasMore)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: context.colors.accentAmber),
              onPressed: () => setState(() => _hintsShown++),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
              label: Text(_hintsShown == 0 ? 'Voir un indice' : 'Indice suivant'),
            ),
        ],
      ),
    );
  }

  Widget _correctionCard(BuildContext context, Exercise ex, {bool? isCorrect}) {
    final color = isCorrect == null
        ? context.colors.accentIndigo
        : (isCorrect ? context.colors.accentEmerald : context.colors.accentRose);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect == null
                    ? Icons.lightbulb_outline_rounded
                    : (isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded),
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect == null
                    ? 'Corrigé'
                    : (isCorrect ? 'Excellente Réponse !' : 'Réponse Incorrecte'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ex.explanation.isNotEmpty ? ex.explanation : 'Aucun corrigé fourni pour cet exercice.',
            style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBody(BuildContext context, Exercise ex) {
    switch (ex.format) {
      case 'flashcard':
        return _buildFlashcardBody(context, ex);
      case 'reponse_courte':
      case 'redaction':
        return _buildFreeTextBody(context, ex);
      case 'manuscrit_scan':
        return _buildManuscriptBody(context, ex);
      case 'qcm':
      default:
        return _buildQcmBody(context, ex);
    }
  }

  Widget _buildQcmBody(BuildContext context, Exercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statementCard(context, ex),
        _hintsSection(context, ex),
        const SizedBox(height: 20),
        ...List.generate(ex.options.length, (optIdx) {
          final option = ex.options[optIdx];
          final isSelected = _selectedOptionIndex == optIdx;

          Color borderColor = context.colors.border;
          Color bgColor = context.colors.card;

          if (_isRevealed) {
            if (optIdx == ex.correctIndex) {
              borderColor = context.colors.accentEmerald;
              bgColor = context.colors.accentEmerald.withValues(alpha: 0.15);
            } else if (isSelected) {
              borderColor = context.colors.accentRose;
              bgColor = context.colors.accentRose.withValues(alpha: 0.15);
            }
          } else if (isSelected) {
            borderColor = context.colors.accentPrimary;
            bgColor = context.colors.accentPrimary.withValues(alpha: 0.1);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _isRevealed ? null : () => setState(() => _selectedOptionIndex = optIdx),
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
                          String.fromCharCode(65 + optIdx),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(option, style: GoogleFonts.inter(fontSize: 15, color: context.colors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_isRevealed) _correctionCard(context, ex, isCorrect: _selectedOptionIndex == ex.correctIndex),
      ],
    );
  }

  Widget _buildFreeTextBody(BuildContext context, Exercise ex) {
    final isRedaction = ex.format == 'redaction';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statementCard(context, ex),
        _hintsSection(context, ex),
        const SizedBox(height: 20),
        Text(
          isRedaction ? 'Votre rédaction' : 'Votre réponse',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _freeTextCtrl,
          enabled: !_isRevealed,
          maxLines: isRedaction ? 10 : 3,
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: isRedaction ? 'Rédigez votre réponse ici...' : 'Répondez en quelques mots...',
            hintStyle: TextStyle(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_isRevealed) ...[
          _correctionCard(context, ex),
          const SizedBox(height: 8),
          Text(
            'Comparez votre réponse au corrigé ci-dessus — aucune notation automatique pour ce format.',
            style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildFlashcardBody(BuildContext context, Exercise ex) {
    return GestureDetector(
      onTap: () => setState(() => _isRevealed = !_isRevealed),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isRevealed ? context.colors.accentIndigo.withValues(alpha: 0.12) : context.colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _isRevealed ? context.colors.accentIndigo : context.colors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRevealed ? Icons.check_circle_outline_rounded : Icons.touch_app_outlined,
              color: context.colors.accentIndigo,
              size: 26,
            ),
            const SizedBox(height: 16),
            Text(
              _isRevealed ? ex.explanation : ex.questionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRevealed ? 'Réponse — touchez pour revenir' : 'Touchez la carte pour retourner',
              style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManuscriptBody(BuildContext context, Exercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statementCard(context, ex),
        _hintsSection(context, ex),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.accentAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.accentAmber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_document, color: context.colors.accentAmber, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cet exercice se rédige à la main, sur papier, puis se rend à votre enseignant — l\'application ne recueille pas de copie scannée pour l\'instant.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (_isRevealed) _correctionCard(context, ex),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, List<Exercise> exercises, Exercise currentEx) {
    final isLast = _currentIndex == exercises.length - 1;
    final bool canPrimaryAct = switch (currentEx.format) {
      'qcm' => _selectedOptionIndex != null,
      'reponse_courte' || 'redaction' => _freeTextCtrl.text.trim().isNotEmpty,
      _ => true,
    };

    String label;
    if (!_isRevealed) {
      label = switch (currentEx.format) {
        'flashcard' => 'Retourner la carte',
        'manuscrit_scan' => 'Voir un corrigé de référence',
        _ => 'Valider ma réponse',
      };
    } else {
      label = isLast ? 'Terminer le Quiz' : 'Question Suivante';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.accentPrimary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: !canPrimaryAct
            ? null
            : () {
                if (!_isRevealed) {
                  setState(() {
                    _isRevealed = true;
                    if (currentEx.format == 'qcm' && _selectedOptionIndex == currentEx.correctIndex) {
                      _totalScore += currentEx.points;
                    } else if (currentEx.format != 'qcm') {
                      _totalScore += currentEx.points;
                    }
                  });
                } else {
                  _goToNext(exercises);
                }
              },
        child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
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
                color: context.colors.accentEmerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: context.colors.accentEmerald,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Quiz Terminé avec Succès !',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez gagné +$_totalScore XP sur ce chapitre.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text(
                'Retour au cours',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
