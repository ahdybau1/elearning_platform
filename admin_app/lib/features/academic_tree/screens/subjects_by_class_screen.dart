import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

/// Écran « Matières par classe » (§44 du référentiel national des matières) : seul endroit de
/// l'admin où l'on attribue réellement une matière à une classe/série/spécialité — jusqu'ici, cette
/// attribution n'existait qu'en base (migrations 90-92), sans page pour la piloter.
///
/// Distingue matières obligatoires et optionnelles (regroupées par `choice_group`, ex. langues
/// vivantes au choix), affiche la provenance (statut de vérification, référence officielle) plutôt
/// que de présenter chaque rattachement comme un fait acquis identique aux autres.
class SubjectsByClassScreen extends ConsumerWidget {
  final AcademicNode node;
  final String displayLabel;

  const SubjectsByClassScreen({
    super.key,
    required this.node,
    required this.displayLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(subjectAssignmentsProvider(node.id));

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Matières — $displayLabel',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentEmerald,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une matière'),
        onPressed: () => _showAssignSubjectModal(context, ref),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Impossible de charger les matières.\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(subjectAssignmentsProvider(node.id)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (links) => _buildContent(context, ref, links),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<SubjectClassLink> links) {
    if (links.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                'Aucune matière rattachée à "$displayLabel".',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Cela peut être normal si le référentiel officiel de ce niveau n\'a pas encore été '
                'confirmé (ex: matières professionnelles d\'une spécialité technique) — dans ce cas, '
                'mieux vaut laisser vide plutôt qu\'inventer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final mandatory = links.where((l) => l.isMandatory).toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
    final optional = links.where((l) => l.isOptional).toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
    final optionalByGroup = <String, List<SubjectClassLink>>{};
    for (final l in optional) {
      optionalByGroup.putIfAbsent(l.choiceGroup ?? 'Autres options', () => []).add(l);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        if (mandatory.isNotEmpty) ...[
          _sectionTitle('Matières obligatoires (${mandatory.length})'),
          const SizedBox(height: 10),
          ...mandatory.map((l) => _linkCard(context, ref, l)),
          const SizedBox(height: 24),
        ],
        if (optionalByGroup.isNotEmpty)
          for (final entry in optionalByGroup.entries) ...[
            _sectionTitle('Au choix — ${entry.key} (${entry.value.length})'),
            const SizedBox(height: 10),
            ...entry.value.map((l) => _linkCard(context, ref, l)),
            const SizedBox(height: 24),
          ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _linkCard(BuildContext context, WidgetRef ref, SubjectClassLink link) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        link.subjectName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _verificationBadge(link.verificationStatus),
                  ],
                ),
                if (link.curriculumName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Curriculum : ${link.curriculumName}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
                if (link.coefficient != null || link.weeklyHours != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (link.coefficient != null) 'Coefficient ${link.coefficient}',
                      if (link.weeklyHours != null) '${link.weeklyHours} h/semaine',
                    ].join(' · '),
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
                if (link.officialReference != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    link.officialReference!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (link.notes != null && link.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    link.notes!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accentBlue),
            onPressed: () => _showAssignSubjectModal(context, ref, existing: link),
          ),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentRose),
            onPressed: () => _confirmRemove(context, ref, link),
          ),
        ],
      ),
    );
  }

  Widget _verificationBadge(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'OFFICIAL_VERIFIED':
        color = AppTheme.accentEmerald;
        label = 'Officiel vérifié';
        break;
      case 'SECONDARY_SOURCE_CONFIRMED':
        color = AppTheme.accentAmber;
        label = 'Source secondaire';
        break;
      default:
        color = AppTheme.accentRose;
        label = 'À vérifier';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, SubjectClassLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.warning_amber_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Retirer cette matière ?',
          onClose: () => Navigator.pop(ctx, false),
        ),
        content: Text(
          '« ${link.subjectName} » ne sera plus rattachée à "$displayLabel". '
          'La matière elle-même n\'est pas supprimée du catalogue.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = ref.read(supabaseServiceProvider);
    await service.removeSubjectAssignment(link.id);
    ref.invalidate(subjectAssignmentsProvider(node.id));
  }

  Future<void> _showAssignSubjectModal(
    BuildContext context,
    WidgetRef ref, {
    SubjectClassLink? existing,
  }) async {
    final subjectsAsync = await ref.read(
      subjectsProvider((countryId: node.countryId, includeInactive: false)).future,
    );

    Subject? selectedSubject =
        existing != null ? subjectsAsync.where((s) => s.id == existing.subjectId).firstOrNull : null;
    bool creatingNew = existing == null && subjectsAsync.isEmpty;
    final newNameCtrl = TextEditingController();
    final newCodeCtrl = TextEditingController();
    bool isMandatory = existing?.isMandatory ?? true;
    final choiceGroupCtrl = TextEditingController(text: existing?.choiceGroup ?? '');
    String verificationStatus = existing?.verificationStatus ?? 'TO_VERIFY';
    final coefficientCtrl = TextEditingController(text: existing?.coefficient?.toString() ?? '');
    final weeklyHoursCtrl = TextEditingController(text: existing?.weeklyHours?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final officialRefCtrl = TextEditingController(text: existing?.officialReference ?? '');
    bool isSubmitting = false;
    String? submitError;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.menu_book_rounded,
            iconColor: AppTheme.accentEmerald,
            text: existing == null ? 'Ajouter une matière' : 'Modifier ce rattachement',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sous "$displayLabel"',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  if (existing == null)
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Matière existante'),
                          selected: !creatingNew,
                          onSelected: (_) => setModalState(() => creatingNew = false),
                        ),
                        ChoiceChip(
                          label: const Text('Nouvelle matière'),
                          selected: creatingNew,
                          onSelected: (_) => setModalState(() => creatingNew = true),
                        ),
                      ],
                    ),
                  if (existing == null && !creatingNew)
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<Subject>(
                      // ignore: deprecated_member_use
                      value: selectedSubject,
                      isExpanded: true,
                      dropdownColor: AppTheme.primaryDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Matière du catalogue'),
                      items: subjectsAsync
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedSubject = v),
                    )
                  else if (existing == null && creatingNew) ...[
                    TextField(
                      controller: newNameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Nom de la matière'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newCodeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Code interne (ex: ALGORITHMIQUE_PROGRAMMATION)',
                      ),
                    ),
                  ] else
                    Text(
                      existing!.subjectName,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Obligatoire', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text('Sinon : optionnelle / au choix',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    value: isMandatory,
                    onChanged: (v) => setModalState(() => isMandatory = v),
                  ),
                  if (!isMandatory)
                    TextField(
                      controller: choiceGroupCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Groupe de choix (ex: LANGUE_VIVANTE_II)',
                        helperText: 'Laisser vide si ce n\'est pas une option groupée',
                      ),
                    ),
                  const SizedBox(height: 12),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: verificationStatus,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Statut de vérification'),
                    items: const [
                      DropdownMenuItem(value: 'OFFICIAL_VERIFIED', child: Text('Officiel vérifié')),
                      DropdownMenuItem(
                        value: 'SECONDARY_SOURCE_CONFIRMED',
                        child: Text('Source secondaire confirmée'),
                      ),
                      DropdownMenuItem(value: 'TO_VERIFY', child: Text('À vérifier')),
                    ],
                    onChanged: (v) => setModalState(() => verificationStatus = v ?? 'TO_VERIFY'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: coefficientCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Coefficient'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weeklyHoursCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Heures/semaine'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: officialRefCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Référence officielle (optionnel)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Text(submitError!, style: const TextStyle(color: AppTheme.accentRose, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setModalState(() {
                        isSubmitting = true;
                        submitError = null;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        String subjectId;
                        if (existing != null) {
                          subjectId = existing.subjectId;
                        } else if (creatingNew) {
                          final name = newNameCtrl.text.trim();
                          final code = newCodeCtrl.text.trim().toUpperCase();
                          if (name.isEmpty || code.isEmpty) {
                            throw Exception('Nom et code requis pour une nouvelle matière.');
                          }
                          subjectId = await service.getOrCreateSubjectByCode(
                            name: name,
                            code: code,
                            countryId: node.countryId,
                          );
                        } else {
                          if (selectedSubject == null) {
                            throw Exception('Choisissez une matière.');
                          }
                          subjectId = selectedSubject!.id;
                        }
                        await service.assignSubjectToNode(
                          subjectId: subjectId,
                          classNodeId: node.id,
                          isMandatory: isMandatory,
                          isOptional: !isMandatory,
                          choiceGroup: isMandatory || choiceGroupCtrl.text.trim().isEmpty
                              ? null
                              : choiceGroupCtrl.text.trim(),
                          verificationStatus: verificationStatus,
                          officialReference:
                              officialRefCtrl.text.trim().isEmpty ? null : officialRefCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          coefficient: num.tryParse(coefficientCtrl.text.trim()),
                          weeklyHours: num.tryParse(weeklyHoursCtrl.text.trim()),
                        );
                        ref.invalidate(subjectAssignmentsProvider(node.id));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isSubmitting = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
