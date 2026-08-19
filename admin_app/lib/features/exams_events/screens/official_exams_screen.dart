import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';
import '../../content_management/widgets/media_attachment_picker.dart';

class OfficialExamsScreen extends ConsumerStatefulWidget {
  const OfficialExamsScreen({super.key});

  @override
  ConsumerState<OfficialExamsScreen> createState() => _OfficialExamsScreenState();
}

class _OfficialExamsScreenState extends ConsumerState<OfficialExamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedClassFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(nodesByTypeProvider('class'));
    final examsAsync = ref.watch(officialExamsProvider(const {}));

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Examens Officiels Nationaux',
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sujets et corrigés d\'examens officiels (BEPC, Probatoire, Baccalauréat Cameroun)',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => _showCreateExamModal(context, classesAsync.valueOrNull ?? []),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nouvel Examen Officiel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (examsAsync.valueOrNull?.isEmpty ?? true)
                        ? null
                        : () => _showUploadPaperModal(context, examsAsync.valueOrNull!),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text('Uploader un Sujet / Corrigé', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un examen officiel (BEPC, Bac, Probatoire)...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                classesAsync.when(
                  data: (classes) => DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedClassFilter,
                      dropdownColor: AppTheme.primarySurface,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes les classes')),
                        ...classes.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedClassFilter = val),
                    ),
                  ),
                  loading: () => const SizedBox(width: 120, child: LinearProgressIndicator()),
                  error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: examsAsync.when(
              data: (exams) {
                final filtered = exams.where((exam) {
                  final q = _searchQuery.toLowerCase();
                  final nameMatches = exam.name.toLowerCase().contains(q);
                  final classMatches = _selectedClassFilter == null || exam.classNodeId == _selectedClassFilter;
                  return nameMatches && classMatches;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      exams.isEmpty
                          ? 'Aucun examen officiel créé — commencez par "Nouvel Examen Officiel".'
                          : 'Aucun examen ne correspond à la recherche.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final exam = filtered[idx];
                    final classes = classesAsync.valueOrNull ?? [];
                    final className = classes
                        .firstWhere(
                          (c) => c.id == exam.classNodeId,
                          orElse: () => AcademicNode(id: '', nodeType: NodeType.classType, name: '—', code: ''),
                        )
                        .name;
                    final papersAsync = ref.watch(examPapersProvider(exam.id));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.accentEmerald.withValues(alpha: 0.15),
                            child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.accentEmerald, size: 28),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(exam.name,
                                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(
                                  '$className${exam.examDate != null ? ' • Session officielle : ${exam.examDate!.toLocal().toString().split(' ').first}' : ''}',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.accentCyan, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  papersAsync.when(
                                    data: (papers) => '${papers.length} Sujets & Corrigés enregistrés',
                                    loading: () => 'Chargement...',
                                    error: (_, _) => 'Erreur de chargement',
                                  ),
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _showManagePapersModal(context, exam),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('Gérer les Sujets'),
                          ),
                        ],
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

  void _showCreateExamModal(BuildContext context, List<AcademicNode> classes) {
    final nameCtrl = TextEditingController();
    DateTime? examDate;
    String? selectedClassId = classes.isNotEmpty ? classes.first.id : null;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.add_rounded,
            text: 'Nouvel Examen Officiel',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nom (ex: BEPC, Probatoire C & D, Baccalauréat)'),
                  ),
                  const SizedBox(height: 12),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedClassId,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Classe concernée'),
                    items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setModalState(() => selectedClassId = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setModalState(() => examDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      examDate == null ? 'Date de session (optionnel)' : examDate!.toString().split(' ').first,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: isLoading || selectedClassId == null
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        final countries = await service.fetchNodesByType('country');
                        if (countries.isEmpty) {
                          throw Exception('Aucun pays configuré dans l\'arbre académique');
                        }
                        await service.createOfficialExam(
                          countryId: countries.first.id,
                          classNodeId: selectedClassId!,
                          name: nameCtrl.text.trim(),
                          examDate: examDate,
                        );
                        ref.invalidate(officialExamsProvider(const {}));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur: $e')),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadPaperModal(BuildContext context, List<OfficialExam> exams) {
    String selectedExamId = exams.first.id;
    String? selectedSubjectId;
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());
    List<MediaAsset> documentAssets = [];
    List<MediaAsset> correctionAssets = [];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.upload_file_rounded,
            iconColor: AppTheme.accentEmerald,
            text: 'Uploader un Sujet / Corrigé',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedExamId,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Examen Officiel'),
                    items: exams.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setModalState(() => selectedExamId = v ?? selectedExamId),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: false)));
                      return subjectsAsync.when(
                        data: (subjects) {
                          selectedSubjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
                          // ignore: deprecated_member_use
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final year = int.tryParse(yearCtrl.text.trim());
                      if (selectedSubjectId == null || year == null || documentAssets.isEmpty) return;
                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.addExamPaper(
                          examId: selectedExamId,
                          subjectId: selectedSubjectId!,
                          year: year,
                          documentUrl: documentAssets.first.url,
                          correctionUrl: correctionAssets.isEmpty ? null : correctionAssets.first.url,
                        );
                        ref.invalidate(examPapersProvider(selectedExamId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sujet d\'examen ajouté avec succès !')),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur: $e')),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer le Sujet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManagePapersModal(BuildContext context, OfficialExam exam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.folder_open_rounded,
          text: 'Sujets et Corrigés : ${exam.name}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 520,
          height: 380,
          child: Consumer(
            builder: (context, ref, _) {
              final papersAsync = ref.watch(examPapersProvider(exam.id));
              return papersAsync.when(
                data: (papers) {
                  if (papers.isEmpty) {
                    return Center(
                      child: Text('Aucune épreuve répertoriée.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                    );
                  }
                  return ListView.separated(
                    itemCount: papers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final paper = papers[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accentRose, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Année ${paper.year}',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(
                                    paper.correctionUrl != null ? 'Sujet & Corrigé' : 'Sujet seul',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRose, size: 18),
                              onPressed: () async {
                                final service = ref.read(supabaseServiceProvider);
                                await service.deleteExamPaper(paper.id);
                                ref.invalidate(examPapersProvider(exam.id));
                              },
                            ),
                          ],
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }
}
