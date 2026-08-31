import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';
import '../utils/lesson_pdf_generator.dart';
import '../utils/exercise_pdf_generator.dart';

class ValidationQueueScreen extends ConsumerStatefulWidget {
  const ValidationQueueScreen({super.key});

  @override
  ConsumerState<ValidationQueueScreen> createState() =>
      _ValidationQueueScreenState();
}

class _ValidationQueueScreenState extends ConsumerState<ValidationQueueScreen> {
  String _filterStatus = 'en_attente';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final reviewerId = authAsync.valueOrNull?.id ?? '';

    final queueAsync = ref.watch(validationQueueStreamProvider);
    final adminUsersAsync = ref.watch(adminUsersProvider);
    final adminUsers = adminUsersAsync.valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded : titre 26pt + longue phrase de sous-titre, sans contrainte de largeur,
              // débordait hors de l'écran sur mobile à côté du badge de compteur (retour
              // utilisateur réel, 2026-08-30).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File de Validation des Contenus',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Workflow : Brouillon → En attente → Approuvé/Rejeté/À corriger '
                      '(le contenu du super admin saute directement à Approuvé)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              queueAsync.when(
                data: (items) {
                  // Le compteur d'en-tête doit refléter ce qui attend RÉELLEMENT une décision, pas
                  // le nombre total de lignes de la queue — depuis l'auto-approbation super admin,
                  // une bonne partie des lignes n'a jamais été "en attente" et n'a besoin d'aucune
                  // attention (voir submitOrAutoApprove).
                  final pendingCount = items
                      .where(
                        (i) =>
                            i.statusString == 'en_attente' ||
                            i.status == ValidationStatus.enAttente,
                      )
                      .length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentAmber),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: AppTheme.accentAmber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pendingCount contenu(s) à réviser',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filter Tabs
          _buildFilterRow(),
          const SizedBox(height: 20),

          // Content List
          Expanded(
            child: queueAsync.when(
              data: (items) {
                final filtered = _filterStatus == 'en_attente'
                    ? items
                          .where(
                            (i) =>
                                i.statusString == 'en_attente' ||
                                i.status == ValidationStatus.enAttente,
                          )
                          .toList()
                    : items
                          .where((i) => i.statusString == _filterStatus)
                          .toList();

                if (filtered.isEmpty) {
                  final emptyLabel = switch (_filterStatus) {
                    'en_attente' => 'Aucun contenu en attente de validation.',
                    'approuve' => 'Aucun contenu approuvé pour le moment.',
                    'rejete' => 'Aucun contenu rejeté pour le moment.',
                    'a_corriger' =>
                      'Aucun contenu renvoyé en correction pour le moment.',
                    _ => 'Aucun contenu dans cet onglet.',
                  };
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 64,
                          color: AppTheme.accentEmerald.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyLabel,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return _buildQueueItem(item, reviewerId, adminUsers);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.accentRose,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement : $err',
                      style: GoogleFonts.inter(color: AppTheme.accentRose),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(validationQueueStreamProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      ('en_attente', 'En attente', AppTheme.accentAmber),
      ('approuve', 'Approuvés', AppTheme.accentEmerald),
      ('rejete', 'Rejetés', AppTheme.accentRose),
      ('a_corriger', 'À corriger', AppTheme.accentIndigo),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _filterStatus == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _filterStatus = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? f.$3.withValues(alpha: 0.2)
                      : AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? f.$3 : AppTheme.primaryBorder,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? f.$3 : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQueueItem(
    ValidationQueueItem item,
    String reviewerId,
    List<AdminUser> adminUsers,
  ) {
    final statusColor = _statusColor(item.status);
    final authorMatches = adminUsers.where((a) => a.id == item.authorId);
    final authorName = authorMatches.isNotEmpty
        ? '${authorMatches.first.firstName} ${authorMatches.first.lastName}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.statusString == 'en_attente'
              ? AppTheme.accentAmber.withValues(alpha: 0.4)
              : AppTheme.primaryBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — Wrap plutôt que Row : 2 badges + horodatage ne tenaient pas côte à côte
          // sur mobile (retour utilisateur réel, 2026-08-30), passent à la ligne au besoin.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _contentTypeLabel(item.contentType),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(item.status),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                item.createdAt.toLocal().toString().split('.').first,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FutureBuilder<String>(
            future: _resolveContentTitle(item),
            builder: (context, snapshot) => Text(
              snapshot.data ?? '…',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Auteur : ${authorName ?? "Inconnu (${item.authorId})"}',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (item.reviewerId != null) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final isSelfApproved = item.reviewerId == item.authorId;
                final reviewerMatches = adminUsers.where(
                  (a) => a.id == item.reviewerId,
                );
                final reviewerName = reviewerMatches.isNotEmpty
                    ? '${reviewerMatches.first.firstName} ${reviewerMatches.first.lastName}'
                    : 'Inconnu (${item.reviewerId})';
                final reviewedAtLabel = item.reviewedAt != null
                    ? item.reviewedAt!.toLocal().toString().split('.').first
                    : '';
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        isSelfApproved
                            ? 'Auto-approuvé par $reviewerName le $reviewedAtLabel'
                            : 'Revu par $reviewerName le $reviewedAtLabel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (isSelfApproved) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AUTO-APPROUVÉ',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentIndigo,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],

          if (item.reviewNotes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.accentAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.comment_rounded,
                    size: 16,
                    color: AppTheme.accentAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.reviewNotes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan),
                ),
                onPressed: () => _previewContent(item),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Prévisualiser le contenu'),
              ),
            ],
          ),

          // Actions (only for pending) — Wrap plutôt que Row(mainAxisAlignment.end) : les 3
          // boutons côte à côte ("Rejeter"/"À corriger"/"Approuver & Publier") débordaient hors
          // de l'écran sur mobile, le dernier coupé (retour utilisateur réel, 2026-08-30).
          if (item.statusString == 'en_attente') ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRose,
                    side: const BorderSide(color: AppTheme.accentRose),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _showDecisionDialog(
                          context,
                          item,
                          reviewerId,
                          'rejete',
                        ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Rejeter'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentIndigo,
                    side: const BorderSide(color: AppTheme.accentIndigo),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _showDecisionDialog(
                          context,
                          item,
                          reviewerId,
                          'a_corriger',
                        ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('À corriger'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _approveContent(item, reviewerId),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Approuver & Publier'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _contentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.exercise:
        return 'EXERCICE';
      case ContentType.lesson:
        return 'LEÇON';
    }
  }

  /// Titre réel du contenu soumis, résolu à la volée — le modèle ValidationQueueItem ne reçoit
  /// jamais de titre joint depuis validation_queue (qui ne stocke que content_id), donc afficher
  /// item.title tel quel revenait à afficher l'UUID brut.
  Future<String> _resolveContentTitle(ValidationQueueItem item) async {
    final service = ref.read(supabaseServiceProvider);
    if (item.contentType == ContentType.exercise) {
      final exercise = await service.getExercise(item.contentId);
      return exercise != null ? exercise.title : 'Exercice introuvable';
    }
    final lesson = await service.getLesson(item.contentId);
    return lesson != null ? lesson.title : 'Leçon introuvable';
  }

  /// Ouvre un aperçu imprimable du contenu soumis (PDF), pour que le réviseur puisse réellement
  /// lire ce qu'il valide avant de cliquer Approuver/Rejeter — jusqu'ici la file de validation
  /// n'offrait aucun moyen de voir le contenu lui-même.
  Future<void> _previewContent(ValidationQueueItem item) async {
    final service = ref.read(supabaseServiceProvider);
    try {
      if (item.contentType == ContentType.exercise) {
        final exercise = await service.getExercise(item.contentId);
        if (exercise == null) throw Exception('Exercice introuvable');
        String subjectName = 'Matière';
        String? chapterTitle;
        if (exercise.chapterId != null) {
          final chapter = await service.getChapter(exercise.chapterId!);
          if (chapter != null) {
            chapterTitle = chapter.title;
            final subject = await service.getSubject(chapter.subjectId);
            if (subject != null) subjectName = subject.name;
          }
        }
        await ExercisePdfGenerator.printOrSave(
          exercise: exercise,
          subjectName: subjectName,
          chapterTitle: chapterTitle,
        );
      } else {
        final lesson = await service.getLesson(item.contentId);
        if (lesson == null) throw Exception('Leçon introuvable');
        final chapter = await service.getChapter(lesson.chapterId);
        String subjectName = 'Matière';
        if (chapter != null) {
          final subject = await service.getSubject(chapter.subjectId);
          if (subject != null) subjectName = subject.name;
        }
        await LessonPdfGenerator.printOrSave(
          lesson: lesson,
          subjectName: subjectName,
          chapterTitle: chapter?.title ?? 'Chapitre inconnu',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text(
              'Impossible de prévisualiser : $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _approveContent(
    ValidationQueueItem item,
    String reviewerId,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.approveContent(item.id, reviewerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentEmerald,
            content: Text(
              'Contenu approuvé et publié avec succès !',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text(
              'Erreur: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDecisionDialog(
    BuildContext context,
    ValidationQueueItem item,
    String reviewerId,
    String decision,
  ) async {
    // Le modèle ne reçoit jamais de titre joint depuis validation_queue (voir
    // _resolveContentTitle) — sans cette résolution, le titre du dialogue affichait l'UUID brut du
    // contenu, illisible pour le réviseur au moment de confirmer un rejet.
    final resolvedTitle = await _resolveContentTitle(item);
    if (!context.mounted) return;

    final notesController = TextEditingController();
    final isReject = decision == 'rejete';
    final decisionLabel = isReject ? 'Rejeter' : 'À corriger';
    final decisionColor = isReject
        ? AppTheme.accentRose
        : AppTheme.accentIndigo;
    String? fieldError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: isReject ? Icons.cancel_outlined : Icons.edit_rounded,
            iconColor: decisionColor,
            text: '$decisionLabel : "$resolvedTitle"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReject
                      ? 'Précisez le motif du rejet. L\'auteur sera notifié automatiquement.'
                      : 'Indiquez les corrections requises avant republication.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isReject
                        ? 'Ex: Exemples manquants, fautes dans la question 3...'
                        : 'Ex: Veuillez ajouter une introduction et corriger les formules p.3',
                    errorText: fieldError,
                    filled: true,
                    fillColor: AppTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: decisionColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: decisionColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (fieldError != null)
                      setModalState(() => fieldError = null);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: decisionColor),
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) {
                  setModalState(
                    () => fieldError = isReject
                        ? 'Le motif du rejet est obligatoire.'
                        : 'Les corrections requises sont obligatoires.',
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isProcessing = true);
                try {
                  final service = ref.read(supabaseServiceProvider);
                  if (isReject) {
                    await service.rejectContent(
                      item.id,
                      reviewerId,
                      notes: notes,
                    );
                  } else {
                    await service.sendBackContent(
                      item.id,
                      reviewerId,
                      notes: notes,
                    );
                  }
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: decisionColor,
                        content: Text(
                          isReject
                              ? 'Contenu rejeté. L\'auteur sera notifié.'
                              : 'Renvoyé en correction à l\'auteur.',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.accentRose,
                        content: Text(
                          'Erreur: $e',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: Text('Confirmer : $decisionLabel'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.approuve:
        return AppTheme.accentEmerald;
      case ValidationStatus.rejete:
        return AppTheme.accentRose;
      case ValidationStatus.aCorriger:
        return AppTheme.accentIndigo;
      default:
        return AppTheme.accentAmber;
    }
  }

  String _statusLabel(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.approuve:
        return 'Approuvé ✓';
      case ValidationStatus.rejete:
        return 'Rejeté ✗';
      case ValidationStatus.aCorriger:
        return 'À corriger';
      default:
        return 'En attente';
    }
  }
}
