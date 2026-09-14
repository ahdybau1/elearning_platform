import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';
import '../../content_management/widgets/media_attachment_picker.dart';
import '../widgets/exam_paper_ai_processing_action.dart';

/// Fusionne classes et séries dans une seule liste de sélection (une série est un "classe" plus
/// précise pour les niveaux qui en ont — même logique que Leçons & Cours).
List<AcademicNode> _mergeClassOptions(List<AcademicNode> classes, List<AcademicNode> series) {
  return [...classes, ...series]..sort((a, b) => a.name.compareTo(b.name));
}

class SchoolPapersScreen extends ConsumerStatefulWidget {
  const SchoolPapersScreen({super.key});

  @override
  ConsumerState<SchoolPapersScreen> createState() => _SchoolPapersScreenState();
}

class _SchoolPapersScreenState extends ConsumerState<SchoolPapersScreen> {
  @override
  Widget build(BuildContext context) {
    final establishmentsAsync = ref.watch(establishmentsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column plutôt que Row : un bouton comme simple frère d'un Expanded ne rétrécit
          // jamais lui-même — il affamait le titre sur mobile (même bug que
          // school_year_promotion_screen.dart, 2026-08-30).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des Épreuves par Établissement',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Devoirs et compositions internes propres à chaque lycée/collège (Catalogue ouvert à tous les élèves)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _showEstablishmentModal(context),
                icon: const Icon(Icons.domain_add_rounded, size: 18),
                label: const Text('Créer un Établissement'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: establishmentsAsync.when(
              data: (establishments) {
                if (establishments.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun établissement créé — commencez par "Créer un Établissement".',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: establishments.length,
                  itemBuilder: (context, idx) {
                    final est = establishments[idx];
                    final papersAsync = ref.watch(establishmentPapersProvider(est.id));
                    final teacherCountAsync = ref.watch(establishmentTeacherCountProvider(est.id));

                    return Opacity(
                      opacity: est.isActive ? 1.0 : 0.55,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: est.isActive ? AppTheme.primaryBorder : AppTheme.accentAmber),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.accentIndigo.withValues(alpha: 0.15),
                              child: const Icon(Icons.domain_rounded, color: AppTheme.accentIndigo),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          est.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      if (!est.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentAmber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Archivé',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ville : ${est.city} • '
                                    '${papersAsync.valueOrNull?.length ?? '...'} épreuve(s) • '
                                    '${teacherCountAsync.valueOrNull ?? '...'} enseignant(s) rattaché(s)',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 4,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                                  onPressed: () => _showManagePapersModal(context, est),
                                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                                  label: const Text('Voir Épreuves'),
                                ),
                                IconButton(
                                  onPressed: () => _showEstablishmentModal(context, existing: est),
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.accentBlue, size: 20),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  onPressed: () => est.isActive
                                      ? _showArchiveConfirmation(context, est)
                                      : _toggleActive(context, est, true),
                                  icon: Icon(
                                    est.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                                    color: AppTheme.accentAmber,
                                    size: 20,
                                  ),
                                  tooltip: est.isActive ? 'Archiver' : 'Désarchiver',
                                ),
                                if (!est.isActive)
                                  IconButton(
                                    onPressed: () => _showDeleteConfirmation(context, est),
                                    icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRose, size: 20),
                                    tooltip: 'Supprimer définitivement',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, Establishment est, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateEstablishment(est.id, isActive: isActive);
      ref.invalidate(establishmentsProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Établissement désarchivé.' : 'Établissement archivé.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
  }

  void _showArchiveConfirmation(BuildContext context, Establishment est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver "${est.name}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'L\'établissement ne sera plus proposé pour de nouveaux rattachements d\'enseignant ni de '
          'nouvelles épreuves, mais rien n\'est supprimé — les épreuves déjà publiées restent '
          'consultables par les élèves. Vous pourrez le désarchiver ou le supprimer définitivement plus tard.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(context, est, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Establishment est) {
    final confirmController = TextEditingController();
    bool nameMatches = false;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer "${est.name}" ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'IRRÉVERSIBLE : l\'établissement ET toutes ses épreuves seront définitivement '
                    'supprimés. Les rattachements d\'enseignants à cet établissement seront également retirés.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tapez "${est.name}" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: est.name),
                  onChanged: (v) => setModalState(() => nameMatches = v.trim() == est.name),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(errorText!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
              onPressed: (isLoading || !nameMatches)
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.deleteEstablishment(est.id);
                        ref.invalidate(establishmentsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Établissement "${est.name}" supprimé définitivement.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEstablishmentModal(BuildContext context, {Establishment? existing}) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.domain_add_rounded,
            text: isEditing ? 'Modifier "${existing.name}"' : 'Créer un Établissement Physique',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'établissement (ex: Lycée de Biyem-Assi)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Ville / Région'),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le nom est obligatoire.');
                        return;
                      }
                      if (cityCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'La ville est obligatoire.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateEstablishment(
                            existing.id,
                            name: nameCtrl.text.trim(),
                            city: cityCtrl.text.trim(),
                          );
                        } else {
                          final countries = await service.fetchNodesByType('country');
                          if (countries.isEmpty) {
                            throw Exception('Aucun pays configuré dans l\'arbre académique');
                          }
                          await service.createEstablishment(
                            countryId: countries.first.id,
                            name: nameCtrl.text.trim(),
                            city: cityCtrl.text.trim(),
                          );
                        }
                        ref.invalidate(establishmentsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Enregistrer' : 'Créer l\'établissement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManagePapersModal(BuildContext context, Establishment est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.menu_book_rounded,
          text: 'Épreuves : ${est.name}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 620,
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _showAddPaperModal(context, est),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Uploader une Épreuve'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final papersAsync = ref.watch(establishmentPapersProvider(est.id));
                    final termsAsync = ref.watch(termsProvider(null));
                    final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: true)));
                    return papersAsync.when(
                      data: (papers) {
                        if (papers.isEmpty) {
                          return Center(
                            child: Text('Aucune épreuve répertoriée.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                          );
                        }
                        final terms = termsAsync.valueOrNull ?? [];
                        final orderedTerms = [...terms]..sort((a, b) => a.startDate.compareTo(b.startDate));
                        final byTerm = <String?, List<EstablishmentPaper>>{};
                        for (final p in papers) {
                          byTerm.putIfAbsent(p.termId, () => []).add(p);
                        }
                        final orderedTermIds = [
                          for (final t in orderedTerms)
                            if (byTerm.containsKey(t.id)) t.id,
                          if (byTerm.containsKey(null)) null,
                        ];
                        final subjectNames = <String, String>{
                          for (final s in subjectsAsync.valueOrNull ?? []) s.id: s.name,
                        };

                        return ListView.builder(
                          itemCount: orderedTermIds.length,
                          itemBuilder: (context, idx) {
                            final termId = orderedTermIds[idx];
                            final termPapers = byTerm[termId]!;
                            final termName = termId == null
                                ? 'Sans trimestre assigné'
                                : (terms.where((t) => t.id == termId).firstOrNull?.name ?? '...');

                            final bySubject = <String?, List<EstablishmentPaper>>{};
                            for (final p in termPapers) {
                              bySubject.putIfAbsent(p.subjectId, () => []).add(p);
                            }
                            final orderedSubjectIds = bySubject.keys.toList()
                              ..sort((a, b) {
                                if (a == null) return 1;
                                if (b == null) return -1;
                                return (subjectNames[a] ?? a).compareTo(subjectNames[b] ?? b);
                              });

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primaryBorder),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: PageStorageKey('paper-term-${termId ?? "none"}'),
                                  initiallyExpanded: true,
                                  leading: const Icon(Icons.folder_rounded, color: AppTheme.accentCyan, size: 20),
                                  title: Text(termName,
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  trailing: Text('${termPapers.length}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  children: [
                                    for (final subjectId in orderedSubjectIds) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text(
                                          subjectId == null ? 'Sans matière' : (subjectNames[subjectId] ?? '...'),
                                          style: GoogleFonts.inter(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                                        ),
                                      ),
                                      ...bySubject[subjectId]!.map((paper) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primarySurface,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accentRose, size: 22),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Année ${paper.year}',
                                                            style: GoogleFonts.outfit(
                                                                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                                        Text(
                                                          paper.correctionUrl != null ? 'Sujet & Corrigé' : 'Sujet seul',
                                                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  ExamPaperAiProcessingAction(
                                                    establishmentPaperId: paper.id,
                                                    processingStatus: paper.processingStatus,
                                                    paperLabel: '${est.name} — ${subjectNames[paper.subjectId] ?? ''} ${paper.year}',
                                                    onChanged: () => ref.invalidate(establishmentPapersProvider(est.id)),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility_rounded, color: AppTheme.accentCyan, size: 18),
                                                    tooltip: 'Aperçu du sujet',
                                                    onPressed: () =>
                                                        launchUrl(Uri.parse(paper.documentUrl), webOnlyWindowName: '_blank'),
                                                  ),
                                                  if (paper.correctionUrl != null)
                                                    IconButton(
                                                      icon: const Icon(Icons.fact_check_rounded,
                                                          color: AppTheme.accentEmerald, size: 18),
                                                      tooltip: 'Aperçu du corrigé',
                                                      onPressed: () => launchUrl(Uri.parse(paper.correctionUrl!),
                                                          webOnlyWindowName: '_blank'),
                                                    ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded,
                                                        color: AppTheme.accentRose, size: 18),
                                                    tooltip: 'Supprimer',
                                                    onPressed: () => _showDeletePaperConfirmation(context, est, paper),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showDeletePaperConfirmation(BuildContext context, Establishment est, EstablishmentPaper paper) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.delete_forever_rounded,
          iconColor: AppTheme.accentRose,
          text: 'Supprimer cette épreuve ${paper.year} ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'IRRÉVERSIBLE : l\'épreuve${paper.correctionUrl != null ? ' et son corrigé' : ''} de '
          '${est.name} (${paper.year}) seront définitivement supprimés.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await service.deleteEstablishmentPaper(paper.id);
                ref.invalidate(establishmentPapersProvider(est.id));
                messenger.showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Épreuve supprimée.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddPaperModal(BuildContext context, Establishment est) {
    String? selectedClassId;
    String? selectedSubjectId;
    String? selectedTermId;
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());
    List<MediaAsset> documentAssets = [];
    List<MediaAsset> correctionAssets = [];
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.upload_file_rounded,
            iconColor: AppTheme.accentEmerald,
            text: 'Uploader une Épreuve — ${est.name}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(nodesByTypeProvider('class'));
                      final seriesAsync = ref.watch(nodesByTypeProvider('series'));
                      final classOptions = _mergeClassOptions(
                        classesAsync.valueOrNull ?? [],
                        seriesAsync.valueOrNull ?? [],
                      );
                      if (classesAsync.isLoading || seriesAsync.isLoading) {
                        return const LinearProgressIndicator();
                      }
                      selectedClassId ??= classOptions.isNotEmpty ? classOptions.first.id : null;
                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: selectedClassId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Classe / Série'),
                        items: classOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setModalState(() => selectedClassId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: false)));
                      return subjectsAsync.when(
                        data: (subjects) {
                          selectedSubjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
                          return DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: selectedSubjectId,
                            dropdownColor: AppTheme.primaryDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Matière'),
                            items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                            onChanged: (v) => setModalState(() => selectedSubjectId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final termsAsync = ref.watch(termsProvider(null));
                      return termsAsync.when(
                        data: (terms) {
                          return DropdownButtonFormField<String?>(
                            // ignore: deprecated_member_use
                            value: selectedTermId,
                            dropdownColor: AppTheme.primaryDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Trimestre (optionnel)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Non précisé')),
                              ...terms.map((t) => DropdownMenuItem<String?>(value: t.id, child: Text(t.name))),
                            ],
                            onChanged: (v) => setModalState(() => selectedTermId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Année de la session'),
                  ),
                  const SizedBox(height: 16),
                  Text('Sujet (PDF)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  MediaAttachmentPicker(onChanged: (assets) => documentAssets = assets),
                  const SizedBox(height: 12),
                  Text('Corrigé (PDF, optionnel)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  MediaAttachmentPicker(onChanged: (assets) => correctionAssets = assets),
                  if (formError != null) ...[
                    const SizedBox(height: 12),
                    Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final year = int.tryParse(yearCtrl.text.trim());
                      if (selectedClassId == null) {
                        setModalState(() => formError = 'Sélectionnez une classe.');
                        return;
                      }
                      if (selectedSubjectId == null) {
                        setModalState(() => formError = 'Sélectionnez une matière.');
                        return;
                      }
                      if (year == null) {
                        setModalState(() => formError = 'Année invalide.');
                        return;
                      }
                      if (documentAssets.isEmpty) {
                        setModalState(() => formError = 'Le sujet (PDF) est obligatoire.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.addEstablishmentPaper(
                          establishmentId: est.id,
                          classNodeId: selectedClassId!,
                          subjectId: selectedSubjectId!,
                          termId: selectedTermId,
                          year: year,
                          documentUrl: documentAssets.first.url,
                          correctionUrl: correctionAssets.isEmpty ? null : correctionAssets.first.url,
                        );
                        ref.invalidate(establishmentPapersProvider(est.id));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Épreuve ajoutée avec succès !')),
                          );
                        }
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer l\'Épreuve'),
            ),
          ],
        ),
      ),
    );
  }
}
