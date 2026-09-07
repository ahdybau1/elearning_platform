import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/rendering/block_renderer_registry.dart';
import '../../../core/services/forensic_watermark_service.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../subscription/screens/paywall_modal.dart';
import 'derivative_lab_screen.dart';
import '../../exercises/screens/exercise_prep_screen.dart';
import '../../../core/models/summary_sheet_registry.dart';
import '../widgets/summary_sheet_viewer_modal.dart';
import '../../ai_tutor/widgets/contextual_ai_agent_sheet.dart';
import '../../pedagogy/widgets/scientific_tools_modal.dart';

/// Lecteur pédagogique multi-leçons avec structuration de contenu en blocs typés (CF-001)
/// et navigation séquentielle entre les leçons d'un même chapitre.
class LessonReaderScreen extends ConsumerStatefulWidget {
  final String chapterId;
  final String chapterTitle;
  final String? initialLessonId;

  const LessonReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
    this.initialLessonId,
  });

  @override
  ConsumerState<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends ConsumerState<LessonReaderScreen> {
  int _selectedLessonIndex = 0;
  bool _hasInitializedIndex = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _switchLesson(int newIndex) {
    if (newIndex != _selectedLessonIndex) {
      setState(() => _selectedLessonIndex = newIndex);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    final lessonsAsync = ref.watch(studentLessonsProvider(widget.chapterId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          widget.chapterTitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.download_for_offline_rounded,
              color: context.colors.textMuted,
            ),
            tooltip: 'Mode Hors-Ligne — pas encore disponible',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: context.colors.accentAmber,
                  content: const Text(
                    'Mode Hors-Ligne pas encore disponible — fonctionnalité à venir.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryCyan),
            tooltip: 'Fiche Mémo Synthèse HD (Zoom & Formules)',
            onPressed: () {
              final sheet = SummarySheetRegistry.findSheetFor(widget.chapterTitle) ??
                  SummarySheetRegistry.sheets.first;
              SummarySheetViewerModal.show(context, sheet);
            },
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, color: Color(0xFF38BDF8)),
            tooltip: 'Laboratoire interactif de la dérivée',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DerivativeLabScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981)),
            tooltip: 'Calculateur SymPy & Outils Scientifiques',
            onPressed: () {
              ScientificToolsModal.show(
                context,
                initialQuery: widget.chapterTitle,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.quiz_rounded, color: context.colors.accentPrimary),
            tooltip: 'Passer aux exercices',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/exercises',
                arguments: {
                  'chapterId': widget.chapterId,
                  'chapterTitle': widget.chapterTitle,
                },
              );
            },
          ),
        ],
      ),
      body: StudentPageContent(
        child: lessonsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text(
              'Erreur: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (lessons) {
            if (lessons.isEmpty) {
              return EmptyStateView(
                icon: Icons.menu_book_outlined,
                title: 'Aucune leçon publiée pour ce chapitre',
                description:
                    'Revenez bientôt : l\'enseignant est en train de préparer ce cours pour votre programme.',
              );
            }

            // Sélection de la leçon initiale si spécifiée
            if (!_hasInitializedIndex && widget.initialLessonId != null) {
              final foundIndex = lessons.indexWhere((l) => l.id == widget.initialLessonId);
              if (foundIndex != -1) {
                _selectedLessonIndex = foundIndex;
              }
              _hasInitializedIndex = true;
            }

            if (_selectedLessonIndex >= lessons.length) {
              _selectedLessonIndex = 0;
            }

            final lesson = lessons[_selectedLessonIndex];
            final isLocked = !lesson.isFree && (profile?.hasActiveSubscription != true);

            final readerContent = SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur horizontal de leçons si le chapitre en compte plusieurs
                  if (lessons.length > 1) ...[
                    _buildLessonTabs(lessons, profile?.hasActiveSubscription == true),
                    const SizedBox(height: 20),
                  ],

                  // En-tête de la leçon active : Titre, numéro et durée estimée
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leçon ${_selectedLessonIndex + 1} sur ${lessons.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.colors.accentPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lesson.title,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: AppRadius.radiusSmall,
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: context.colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson.readingTimeMinutes} min',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Fiche Mémo Synthèse Officielle (HD Zoom & Formules LaTeX)
                  _buildSummarySheetBanner(context),
                  const SizedBox(height: 20),

                  // Contenu structuré en blocs typés (CF-001)
                  for (final block in lesson.blocks) ...[
                    BlockRendererRegistry.build(context, block),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 12),

                  // Barre de navigation pagination (Leçon précédente / Leçon suivante)
                  if (lessons.length > 1) ...[
                    _buildLessonPagination(lessons),
                    const SizedBox(height: 20),
                  ],

                  // Accompagnement IA : Bouton contextuel Tuteur IA
                  _buildAiTutorHelpCard(context, lesson),

                  const SizedBox(height: 20),

                  // Action de validation : Lancement du quiz du chapitre
                  _buildLaunchQuizCard(context),
                ],
              ),
            );

            // Filtre Smart Paywall si contenu verrouillé
            if (isLocked) {
              return Stack(
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.black45,
                      BlendMode.darken,
                    ),
                    child: readerContent,
                  ),
                  _buildPaywallModal(context),
                ],
              );
            }

            // Protection avec tatouage judiciaire
            return profile != null
                ? ForensicWatermarkService.buildWatermarkedContainer(
                    profile: profile,
                    phoneNumber:
                        authState.account?.phone ?? '+237 699 00 00 00',
                    child: readerContent,
                  )
                : readerContent;
          },
        ),
      ),
    );
  }

  /// Sélecteur horizontal pour naviguer entre les différentes leçons du chapitre
  Widget _buildLessonTabs(List<Lesson> lessons, bool isSubscriber) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lessons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final l = lessons[index];
          final isSelected = index == _selectedLessonIndex;
          final isLocked = !l.isFree && !isSubscriber;

          return InkWell(
            onTap: () => _switchLesson(index),
            borderRadius: AppRadius.radiusSmall,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.accentPrimary.withValues(alpha: 0.18)
                    : context.colors.surface,
                borderRadius: AppRadius.radiusSmall,
                border: Border.all(
                  color: isSelected
                      ? context.colors.accentPrimary
                      : context.colors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLocked) ...[
                    Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: isSelected
                          ? context.colors.accentPrimary
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '${index + 1}. ${l.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? context.colors.accentPrimary
                          : context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pagination inférieure : bouton leçon précédente et leçon suivante
  Widget _buildLessonPagination(List<Lesson> lessons) {
    final hasPrev = _selectedLessonIndex > 0;
    final hasNext = _selectedLessonIndex < lessons.length - 1;

    return Row(
      children: [
        if (hasPrev)
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textSecondary,
                side: BorderSide(color: context.colors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMedium,
                ),
              ),
              onPressed: () => _switchLesson(_selectedLessonIndex - 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                'Leçon précédente',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        if (hasNext)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.surface,
                foregroundColor: context.colors.textPrimary,
                elevation: 0,
                side: BorderSide(color: context.colors.accentPrimary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMedium,
                ),
              ),
              onPressed: () => _switchLesson(_selectedLessonIndex + 1),
              icon: const Text(''),
              label: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Leçon suivante',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: context.colors.accentPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: context.colors.accentPrimary,
                  ),
                ],
              ),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  /// Carte d'aide contextuelle par le Tuteur IA
  Widget _buildAiTutorHelpCard(BuildContext context, Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(
          color: AppColors.cyanAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusMedium,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.cyanAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agents Pédagogiques IA EDLEARN',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Dialogue socratique, détection de pièges et exercices ciblés.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    side: const BorderSide(color: AppColors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: () {
                    ContextualAiAgentSheet.show(
                      context,
                      topicTitle: lesson.title,
                      subject: widget.chapterTitle,
                      initialMode: 'tutor',
                    );
                  },
                  icon: const Icon(Icons.psychology_rounded, size: 15),
                  label: const Text(
                    'Tuteur Socratique',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amberHighlight,
                    side: const BorderSide(color: AppColors.amberHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: () {
                    ContextualAiAgentSheet.show(
                      context,
                      topicTitle: lesson.title,
                      subject: widget.chapterTitle,
                      initialMode: 'diagnostic',
                    );
                  },
                  icon: const Icon(Icons.rule_rounded, size: 15),
                  label: const Text(
                    'Pièges du Bac',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealSuccess,
                    foregroundColor: const Color(0xFF0A0E1A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: () {
                    ContextualAiAgentSheet.show(
                      context,
                      topicTitle: lesson.title,
                      subject: widget.chapterTitle,
                      initialMode: 'exercise',
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text(
                    'S\'entraîner',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () {
                ScientificToolsModal.show(
                  context,
                  initialQuery: lesson.title,
                );
              },
              icon: const Icon(Icons.calculate_rounded, size: 16),
              label: const Text(
                'Calculateur SymPy, Grapheur & Labos Virtuels',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte de lancement des exercices interactifs
  Widget _buildLaunchQuizCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(
            'Validez vos connaissances',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Testez votre compréhension avec le quiz interactif de ce chapitre.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accentPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMedium,
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/exercises',
                    arguments: {
                      'chapterId': widget.chapterId,
                      'chapterTitle': widget.chapterTitle,
                    },
                  );
                },
                icon: const Icon(Icons.quiz_rounded, size: 18),
                label: const Text(
                  'Démarrer les Exercices',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMedium,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DerivativeLabScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text(
                  'Labo Tangente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMedium,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExercisePrepScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text(
                  'Mode Concours & Chrono',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bannière interactive d'accès direct à la Fiche Mémo Synthèse HD du chapitre
  Widget _buildSummarySheetBanner(BuildContext context) {
    final sheet = SummarySheetRegistry.findSheetFor(widget.chapterTitle) ??
        SummarySheetRegistry.sheets.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1B2E), Color(0xFF162544)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.primaryCyan.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryCyan.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withAlpha(35),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.primaryCyan,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withAlpha(40),
                        borderRadius: AppRadius.radiusSmall,
                        border: Border.all(color: AppColors.accentAmber.withAlpha(100)),
                      ),
                      child: const Text(
                        'FICHE DE SYNTHÈSE HD',
                        style: TextStyle(
                          color: AppColors.accentAmber,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pinch-to-zoom HD',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sheet.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: const Color(0xFF0A0E1A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: () => SummarySheetViewerModal.show(context, sheet),
            icon: const Icon(Icons.zoom_in_rounded, size: 16),
            label: const Text(
              'Ouvrir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywallModal(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.radiusXLarge,
              border: Border.all(
                color: context.colors.accentPrimary.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.accentPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: context.colors.accentPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Contenu Premium Réservé',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette leçon complète, ses formules détaillées et ses corrigés d\'examens nécessitent un Pass Mensuel ou Annuel.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accentPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMedium,
                    ),
                  ),
                  onPressed: () => PaywallModal.show(context),
                  child: const Text(
                    'Débloquer avec Mobile Money',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
