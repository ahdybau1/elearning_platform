import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/system_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String _statusFilter = 'Actives'; // Actives, Toutes, Archivées

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

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
                    'Gestion des Bannières d\'Annonces',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diffusion de messages ciblés par pays/classe avec affichage temporisé automatique',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAnnouncementModal(context),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Publier une Annonce'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Text('Filtrer : ',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: ['Actives', 'Toutes', 'Archivées'].map((st) {
                    final isSel = _statusFilter == st;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(st),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : AppTheme.textMuted,
                      ),
                      selectedColor: AppTheme.accentBlue,
                      backgroundColor: AppTheme.primaryDark,
                      onSelected: (_) => setState(() => _statusFilter = st),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: announcementsAsync.when(
              data: (allAnnouncements) {
                final now = DateTime.now();
                final announcements = allAnnouncements.where((a) {
                  if (_statusFilter == 'Toutes') return true;
                  if (_statusFilter == 'Archivées') return !a.isActive;
                  return a.isActive;
                }).toList();

                if (announcements.isEmpty) {
                  return Center(
                    child: Text(
                      allAnnouncements.isEmpty
                          ? 'Aucune bannière d\'annonce — commencez par "Publier une Annonce".'
                          : 'Aucune annonce pour ce filtre.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, idx) {
                    final ann = announcements[idx];
                    final isWarning = ann.urgency == 'warning' || ann.urgency == 'urgent';
                    final isExpired = ann.endDate.isBefore(now);
                    final isScheduled = ann.startDate.isAfter(now);
                    final statusLabel = !ann.isActive
                        ? 'Archivée'
                        : isExpired
                            ? 'Expirée'
                            : isScheduled
                                ? 'Programmée'
                                : 'Active';
                    final statusColor = !ann.isActive
                        ? AppTheme.textMuted
                        : isExpired
                            ? AppTheme.accentRose
                            : isScheduled
                                ? AppTheme.accentCyan
                                : AppTheme.accentEmerald;

                    return Opacity(
                      opacity: ann.isActive ? 1.0 : 0.55,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWarning ? AppTheme.accentAmber : AppTheme.primaryBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isWarning
                                  ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                  : AppTheme.accentBlue.withValues(alpha: 0.15),
                              child: Icon(
                                isWarning ? Icons.warning_rounded : Icons.campaign_rounded,
                                color: isWarning ? AppTheme.accentAmber : AppTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ann.title,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: GoogleFonts.inter(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ann.message,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Urgence : ${ann.urgency.toUpperCase()}',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                      Text(
                                        '${DateFormat('dd/MM/yyyy').format(ann.startDate.toLocal())} → ${DateFormat('dd/MM/yyyy').format(ann.endDate.toLocal())}',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                      Consumer(
                                        builder: (context, ref, _) {
                                          final countryAsync = ref.watch(nodeByIdProvider(ann.targetCountryId));
                                          final classAsync = ref.watch(nodeByIdProvider(ann.targetClassId));
                                          final parts = [
                                            countryAsync.valueOrNull?.name,
                                            classAsync.valueOrNull?.name,
                                          ].whereType<String>().toList();
                                          return Text(
                                            parts.isEmpty ? 'Cible : Tous les pays / toutes les classes' : 'Cible : ${parts.join(' • ')}',
                                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                              tooltip: 'Modifier',
                              onPressed: () => _showAnnouncementModal(context, existing: ann),
                            ),
                            IconButton(
                              icon: Icon(
                                ann.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                                color: AppTheme.accentAmber,
                              ),
                              tooltip: ann.isActive ? 'Archiver' : 'Désarchiver',
                              onPressed: () => ann.isActive
                                  ? _showArchiveConfirmation(context, ann)
                                  : _toggleActive(context, ann, true),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, Announcement ann, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(supabaseServiceProvider).updateAnnouncement(ann.id, isActive: isActive);
      ref.invalidate(announcementsStreamProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Annonce désarchivée.' : 'Annonce archivée.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
  }

  void _showArchiveConfirmation(BuildContext context, Announcement ann) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver cette annonce ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'La bannière "${ann.title}" ne sera plus diffusée aux utilisateurs. Vous pourrez la désarchiver plus tard.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(context, ann, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementModal(BuildContext context, {Announcement? existing}) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final messageController = TextEditingController(text: existing?.message ?? '');
    String urgency = existing?.urgency ?? 'info';
    String? targetCountryId = existing?.targetCountryId;
    String? targetClassId = existing?.targetClassId;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime endDate = existing?.endDate ?? DateTime.now().add(const Duration(days: 30));
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.campaign_rounded,
            text: isEditing ? 'Modifier la Bannière d\'Annonce' : 'Publier une Bannière d\'Annonce',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Titre de l\'annonce'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Message de l\'annonce'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: urgency,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Niveau d\'urgence'),
                    items: const [
                      DropdownMenuItem(value: 'info', child: Text('Informatif (Bleu)')),
                      DropdownMenuItem(value: 'warning', child: Text('Avertissement (Orange)')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent (Rouge)')),
                    ],
                    onChanged: (v) => setModalState(() => urgency = v ?? 'info'),
                  ),
                  const SizedBox(height: 16),
                  Text('Ciblage (optionnel — vide = diffusion à tous)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final countriesAsync = ref.watch(nodesByTypeProvider('country'));
                      final countries = countriesAsync.valueOrNull ?? [];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: targetCountryId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Pays ciblé'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous les pays')),
                          ...countries.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setModalState(() => targetCountryId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(nodesByTypeProvider('class'));
                      final seriesAsync = ref.watch(nodesByTypeProvider('series'));
                      final classOptions = <AcademicNode>[
                        ...classesAsync.valueOrNull ?? [],
                        ...seriesAsync.valueOrNull ?? [],
                      ]..sort((a, b) => a.name.compareTo(b.name));
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: targetClassId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Classe / Série ciblée'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes les classes')),
                          ...classOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setModalState(() => targetClassId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Période de diffusion',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text('Début : ${DateFormat('dd/MM/yyyy').format(startDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text('Fin : ${DateFormat('dd/MM/yyyy').format(endDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 12),
                    Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ],
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
                      final title = titleController.text.trim();
                      final message = messageController.text.trim();
                      if (title.isEmpty || message.isEmpty) {
                        setModalState(() => formError = 'Le titre et le message sont obligatoires.');
                        return;
                      }
                      if (!endDate.isAfter(startDate)) {
                        setModalState(() => formError = 'La date de fin doit être après la date de début.');
                        return;
                      }

                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateAnnouncement(
                            existing.id,
                            title: title,
                            message: message,
                            urgency: urgency,
                            startDate: startDate,
                            endDate: endDate,
                            clearTargetCountry: targetCountryId == null,
                            targetCountryId: targetCountryId,
                            clearTargetClass: targetClassId == null,
                            targetClassId: targetClassId,
                          );
                        } else {
                          await service.createAnnouncement(
                            title: title,
                            message: message,
                            urgency: urgency,
                            targetCountryId: targetCountryId,
                            targetClassId: targetClassId,
                            startDate: startDate,
                            endDate: endDate,
                          );
                        }

                        ref.invalidate(announcementsStreamProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                isEditing ? 'Annonce mise à jour.' : 'Annonce "$title" publiée avec succès !',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Enregistrer' : 'Publier L\'Annonce'),
            ),
          ],
        ),
      ),
    );
  }
}
