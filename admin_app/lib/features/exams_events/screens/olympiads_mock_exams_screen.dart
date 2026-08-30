import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class OlympiadsMockExamsScreen extends ConsumerStatefulWidget {
  const OlympiadsMockExamsScreen({super.key});

  @override
  ConsumerState<OlympiadsMockExamsScreen> createState() =>
      _OlympiadsMockExamsScreenState();
}

class _OlympiadsMockExamsScreenState extends ConsumerState<OlympiadsMockExamsScreen> {
  int _activeSubTab = 0; // 0: Événements, 1: Contestations de Notes (Disputes)

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final disputesAsync = ref.watch(gradeDisputesProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olympiades & Contestations de Notes',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion des événements compétitifs et file des réclamations avec 2nd correcteur obligatoire',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: () => _showEventModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer un Événement'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sub tabs
          Row(
            children: [
              _buildSubTab(0, 'Événements & Concours (${eventsAsync.valueOrNull?.length ?? 0})'),
              const SizedBox(width: 12),
              _buildSubTab(1, 'Contestations de Notes (${disputesAsync.valueOrNull?.length ?? 0})'),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _activeSubTab == 0
                ? _buildEventsView(eventsAsync)
                : _buildDisputesView(disputesAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int idx, String label) {
    final isSelected = _activeSubTab == idx;
    return InkWell(
      onTap: () => setState(() => _activeSubTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.primaryBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsView(AsyncValue<List<Event>> eventsAsync) {
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Text(
              'Aucun événement créé — commencez par "Créer un Événement".',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          );
        }
        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, idx) {
            final ev = events[idx];
            final isOlympiad = ev.type == 'olympiade';
            final resultsAsync = ref.watch(eventResultsProvider(ev.id));

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.15),
                    child: Icon(
                      isOlympiad ? Icons.emoji_events_rounded : Icons.fact_check_rounded,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isOlympiad ? "Olympiade" : "Examen Blanc"} • '
                          '${DateFormat('dd/MM/yyyy').format(ev.startDate)} - ${DateFormat('dd/MM/yyyy').format(ev.endDate)} • '
                          '${ev.pricingMode == 'inclus' ? 'Inclus dans abonnement' : 'Payant (${ev.price.toStringAsFixed(0)} FCFA)'}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resultsAsync.when(
                            data: (results) => '${results.length} élève(s) noté(s)',
                            loading: () => 'Chargement...',
                            error: (_, _) => 'Erreur de chargement',
                          ),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentEmerald, fontWeight: FontWeight.w600),
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
                        onPressed: () => _showCorrectionModal(context, ev),
                        icon: const Icon(Icons.grading_rounded, size: 16),
                        label: const Text('Interface de Correction'),
                      ),
                      IconButton(
                        onPressed: () => _showEventModal(context, existing: ev),
                        icon: const Icon(Icons.edit_rounded, color: AppTheme.accentBlue, size: 20),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        onPressed: () => _showDeleteEventConfirmation(context, ev),
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRose, size: 20),
                        tooltip: 'Supprimer définitivement',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
    );
  }

  Widget _buildDisputesView(AsyncValue<List<GradeDispute>> disputesAsync) {
    return disputesAsync.when(
      data: (disputes) {
        if (disputes.isEmpty) {
          return Center(
            child: Text('Aucune contestation de note pour le moment.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          );
        }
        return ListView.builder(
          itemCount: disputes.length,
          itemBuilder: (context, idx) {
            final disp = disputes[idx];
            final isOpen = disp.status == 'ouvert' || disp.status == 'en_cours';
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isOpen ? AppTheme.accentAmber : AppTheme.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Réclamation : ${disp.studentName ?? 'Élève'} — ${disp.eventTitle ?? 'Événement'}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Note initiale : ${disp.originalScore.toStringAsFixed(1)}/20',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _disputeStatusColor(disp.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_disputeStatusLabel(disp.status),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _disputeStatusColor(disp.status))),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Motif de l\'élève : "${disp.reason}"',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (!isOpen) ...[
                    const SizedBox(height: 10),
                    Text(
                      disp.status == 'resolu'
                          ? 'Note révisée : ${disp.revisedScore?.toStringAsFixed(1)}/20 — ${disp.resolutionNotes ?? ''}'
                          : 'Note maintenue — ${disp.resolutionNotes ?? ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                  if (isOpen) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showDisputeDecisionModal(context, disp, accept: false),
                          child: Text('Maintenir ${disp.originalScore.toStringAsFixed(1)}/20'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                          onPressed: () => _showDisputeDecisionModal(context, disp, accept: true),
                          child: const Text('Réviser la Note'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
    );
  }

  Color _disputeStatusColor(String status) {
    switch (status) {
      case 'resolu':
        return AppTheme.accentEmerald;
      case 'rejete':
        return AppTheme.textMuted;
      default:
        return AppTheme.accentAmber;
    }
  }

  String _disputeStatusLabel(String status) {
    switch (status) {
      case 'resolu':
        return 'Note révisée';
      case 'rejete':
        return 'Note maintenue';
      case 'en_cours':
        return 'En cours de relecture';
      default:
        return 'Ouverte';
    }
  }

  void _showDisputeDecisionModal(BuildContext context, GradeDispute dispute, {required bool accept}) {
    final revisedScoreCtrl = TextEditingController(text: dispute.originalScore.toStringAsFixed(1));
    final notesCtrl = TextEditingController();
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: accept ? Icons.check_circle_rounded : Icons.block_rounded,
            iconColor: accept ? AppTheme.accentEmerald : AppTheme.textMuted,
            text: accept ? 'Réviser la note' : 'Maintenir la note',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accept) ...[
                  TextField(
                    controller: revisedScoreCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nouvelle note (/20)'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  autofocus: !accept,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: accept ? 'Motif de la révision' : 'Motif du maintien',
                    hintText: accept
                        ? 'ex : raisonnement correct malgré une erreur d\'arrondi'
                        : 'ex : résultat final faux, barème officiel non applicable',
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: accept ? AppTheme.accentEmerald : AppTheme.textMuted),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (notesCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le motif est obligatoire.');
                        return;
                      }
                      double? revisedScore;
                      if (accept) {
                        revisedScore = double.tryParse(revisedScoreCtrl.text.trim());
                        if (revisedScore == null) {
                          setModalState(() => formError = 'Note invalide.');
                          return;
                        }
                      }
                      final adminId = ref.read(authProvider).valueOrNull?.id;
                      if (adminId == null) {
                        setModalState(() => formError = 'Session administrateur non résolue — rechargez la page.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.resolveGradeDispute(
                          dispute.id,
                          accepted: accept,
                          revisedScore: revisedScore,
                          resolutionNotes: notesCtrl.text.trim(),
                          reviewerId: adminId,
                        );
                        ref.invalidate(gradeDisputesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(accept ? 'Note révisée à ${revisedScore!.toStringAsFixed(1)}/20.' : 'Note maintenue.'),
                            ),
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
                  : Text(accept ? 'Confirmer la Révision' : 'Confirmer le Maintien'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteEventConfirmation(BuildContext context, Event event) {
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
            text: 'Supprimer "${event.title}" ?',
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
                    'IRRÉVERSIBLE : l\'événement ET tous les résultats déjà saisis seront définitivement '
                    'supprimés.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tapez "${event.title}" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: event.title),
                  onChanged: (v) => setModalState(() => nameMatches = v.trim() == event.title),
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
                        await service.deleteEvent(event.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Événement "${event.title}" supprimé définitivement.'),
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

  void _showEventModal(BuildContext context, {Event? existing}) {
    final isEditing = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '500');
    String selectedType = existing?.type ?? 'examen_blanc';
    String? selectedClassId = existing?.classNodeId;
    String pricingMode = existing?.pricingMode ?? 'inclus';
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime endDate = existing?.endDate ?? DateTime.now().add(const Duration(days: 5));
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.add_rounded,
            text: isEditing ? 'Modifier "${existing.title}"' : 'Créer un Événement',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedType,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'examen_blanc', child: Text('Examen Blanc')),
                      DropdownMenuItem(value: 'olympiade', child: Text('Olympiade')),
                    ],
                    onChanged: (v) => setModalState(() => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Titre (ex: Grand Examen Blanc BEPC 2026)'),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(nodesByTypeProvider('class'));
                      final seriesAsync = ref.watch(nodesByTypeProvider('series'));
                      if (classesAsync.isLoading || seriesAsync.isLoading) {
                        return const LinearProgressIndicator();
                      }
                      final classOptions = <AcademicNode>[
                        ...classesAsync.valueOrNull ?? [],
                        ...seriesAsync.valueOrNull ?? [],
                      ]..sort((a, b) => a.name.compareTo(b.name));
                      return classesAsync.when(
                        data: (classes) {
                          selectedClassId ??= classOptions.isNotEmpty ? classOptions.first.id : null;
                          return DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: selectedClassId,
                            dropdownColor: AppTheme.primaryDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Classe / Série concernée'),
                            items: classOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (v) => setModalState(() => selectedClassId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text('Début : ${DateFormat('dd/MM/yyyy').format(startDate)}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text('Fin : ${DateFormat('dd/MM/yyyy').format(endDate)}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: pricingMode,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Tarification'),
                    items: const [
                      DropdownMenuItem(value: 'inclus', child: Text('Inclus dans l\'abonnement')),
                      DropdownMenuItem(value: 'payant', child: Text('Payant séparément')),
                    ],
                    onChanged: (v) => setModalState(() => pricingMode = v ?? pricingMode),
                  ),
                  if (pricingMode == 'payant') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Prix (XAF)'),
                    ),
                  ],
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le titre est obligatoire.');
                        return;
                      }
                      if (selectedClassId == null) {
                        setModalState(() => formError = 'Sélectionnez une classe.');
                        return;
                      }
                      if (!endDate.isAfter(startDate)) {
                        setModalState(() => formError = 'La date de fin doit être après la date de début.');
                        return;
                      }
                      final price = pricingMode == 'payant' ? double.tryParse(priceCtrl.text.trim()) : 0.0;
                      if (price == null || price < 0) {
                        setModalState(() => formError = 'Prix invalide.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateEvent(
                            existing.id,
                            title: titleCtrl.text.trim(),
                            startDate: startDate,
                            endDate: endDate,
                            pricingMode: pricingMode,
                            price: price,
                          );
                        } else {
                          final countries = await service.fetchNodesByType('country');
                          if (countries.isEmpty) {
                            throw Exception('Aucun pays configuré dans l\'arbre académique');
                          }
                          await service.createEvent(
                            type: selectedType,
                            countryId: countries.first.id,
                            classNodeId: selectedClassId!,
                            title: titleCtrl.text.trim(),
                            startDate: startDate,
                            endDate: endDate,
                            pricingMode: pricingMode,
                            price: price,
                          );
                        }
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
                  : Text(isEditing ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCorrectionModal(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.grading_rounded,
          text: 'Interface de Correction — ${event.title}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 560,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _showAddResultModal(context, event),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Saisir une Note'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final resultsAsync = ref.watch(eventResultsProvider(event.id));
                    return resultsAsync.when(
                      data: (results) {
                        if (results.isEmpty) {
                          return Center(
                            child: Text(
                              'Aucune note saisie pour le moment.\nUtilisez "Saisir une Note" pour noter un élève '
                              '(écrit numérique/QCM directement ; oral et manuscrit après correction hors-ligne '
                              'de l\'enregistrement/la copie).',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(color: AppTheme.primaryBorder, height: 1),
                          itemBuilder: (context, idx) {
                            final r = results[idx];
                            return ListTile(
                              dense: true,
                              title: Text(r.studentDisplayName, style: GoogleFonts.inter(color: Colors.white)),
                              trailing: Text('${r.score.toStringAsFixed(1)}/20',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
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

  void _showAddResultModal(BuildContext context, Event event) {
    final emailCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    List<StudentProfile> foundProfiles = [];
    StudentProfile? selectedProfile;
    bool isSearching = false;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.grading_rounded,
            text: 'Saisir une Note',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email du compte élève',
                    suffixIcon: IconButton(
                      icon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                          : const Icon(Icons.search_rounded),
                      onPressed: isSearching
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              if (email.isEmpty) return;
                              setModalState(() {
                                isSearching = true;
                                formError = null;
                                foundProfiles = [];
                                selectedProfile = null;
                              });
                              try {
                                final service = ref.read(supabaseServiceProvider);
                                final accounts = await service.fetchAccounts(search: email);
                                if (accounts.isEmpty) {
                                  setModalState(() {
                                    isSearching = false;
                                    formError = 'Aucun compte élève trouvé pour cet email.';
                                  });
                                  return;
                                }
                                final profiles = await service.fetchProfilesForAccount(accounts.first.id);
                                setModalState(() {
                                  isSearching = false;
                                  foundProfiles = profiles;
                                  selectedProfile = profiles.isNotEmpty ? profiles.first : null;
                                  if (profiles.isEmpty) formError = 'Ce compte élève n\'a aucun profil.';
                                });
                              } catch (e) {
                                setModalState(() {
                                  isSearching = false;
                                  formError = '$e';
                                });
                              }
                            },
                    ),
                  ),
                ),
                if (foundProfiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StudentProfile>(
                    // ignore: deprecated_member_use
                    value: selectedProfile,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Profil'),
                    items: foundProfiles
                        .map((p) => DropdownMenuItem(value: p, child: Text('Profil ${p.schoolYear} (${p.status})')))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedProfile = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Note (/20)'),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedProfile == null) {
                        setModalState(() => formError = 'Recherchez et sélectionnez un profil élève.');
                        return;
                      }
                      final score = double.tryParse(scoreCtrl.text.trim());
                      if (score == null || score < 0 || score > 20) {
                        setModalState(() => formError = 'Note invalide (0 à 20).');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.addEventResult(
                          eventId: event.id,
                          profileId: selectedProfile!.id,
                          score: score,
                        );
                        ref.invalidate(eventResultsProvider(event.id));
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
                  : const Text('Enregistrer la Note'),
            ),
          ],
        ),
      ),
    );
  }
}
