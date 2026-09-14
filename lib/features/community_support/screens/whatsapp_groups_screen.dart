import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/community_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class WhatsappGroupsScreen extends ConsumerStatefulWidget {
  const WhatsappGroupsScreen({super.key});

  @override
  ConsumerState<WhatsappGroupsScreen> createState() => _WhatsappGroupsScreenState();
}

class _WhatsappGroupsScreenState extends ConsumerState<WhatsappGroupsScreen> {
  String _statusFilter = 'Tous'; // Tous, Actif, Archivé

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(whatsappCommunitiesProvider(null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Communautés d\'Étude WhatsApp Officielles',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion des liens d\'invitation des groupes WhatsApp officiels par classe (Cloisonnement strict)',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showGroupModal(context),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(
                  'Ajouter un Groupe WhatsApp',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Filtrer par Statut : ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: ['Tous', 'Actif', 'Archivé'].map((st) {
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
                      selectedColor: AppTheme.accentEmerald,
                      backgroundColor: AppTheme.primaryDark,
                      onSelected: (_) => setState(() => _statusFilter = st),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Groups List
          Expanded(
            child: communitiesAsync.when(
              data: (communities) {
                final filtered = communities.where((c) {
                  if (_statusFilter == 'Tous') return true;
                  if (_statusFilter == 'Actif') return c.isActive;
                  return !c.isActive;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      communities.isEmpty
                          ? 'Aucun groupe WhatsApp créé — commencez par "Ajouter un Groupe WhatsApp".'
                          : 'Aucun groupe WhatsApp avec ce statut.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final grp = filtered[idx];
                    final statusBg = grp.isActive
                        ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                        : AppTheme.accentAmber.withValues(alpha: 0.15);
                    final statusFg = grp.isActive ? AppTheme.accentEmerald : AppTheme.accentAmber;

                    return Opacity(
                      opacity: grp.isActive ? 1.0 : 0.55,
                      child: Container(
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
                              radius: 24,
                              backgroundColor: AppTheme.accentEmerald.withValues(alpha: 0.15),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppTheme.accentEmerald,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, _) {
                                            final nodeAsync = ref.watch(nodeByIdProvider(grp.classNodeId));
                                            return Text(
                                              nodeAsync.valueOrNull?.name ?? '...',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          grp.isActive ? 'Actif' : 'Archivé',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusFg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lien d\'invitation : ${grp.inviteLink}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Membres (estimation manuelle) : ${grp.memberCountEstimate}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 4,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentCyan,
                                    side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: grp.inviteLink));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppTheme.accentEmerald,
                                          content: Text('Lien copié dans le presse-papiers.'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copier Lien'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                                  tooltip: 'Modifier',
                                  onPressed: () => _showGroupModal(context, existing: grp),
                                ),
                                IconButton(
                                  icon: Icon(
                                    grp.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                                    color: AppTheme.accentAmber,
                                  ),
                                  tooltip: grp.isActive ? 'Archiver' : 'Désarchiver',
                                  onPressed: () => grp.isActive
                                      ? _showArchiveConfirmation(context, grp)
                                      : _toggleActive(context, grp, true),
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

  Future<void> _toggleActive(BuildContext context, WhatsappCommunity grp, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (isActive) {
        await service.upsertWhatsappCommunity(
          id: grp.id,
          classNodeId: grp.classNodeId,
          inviteLink: grp.inviteLink,
          memberCountEstimate: grp.memberCountEstimate,
          isActive: true,
        );
      } else {
        await service.deleteWhatsappCommunity(grp.id);
      }
      ref.invalidate(whatsappCommunitiesProvider(null));
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Groupe désarchivé.' : 'Groupe archivé.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
  }

  void _showArchiveConfirmation(BuildContext context, WhatsappCommunity grp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver ce groupe ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'Le lien d\'invitation ne sera plus affiché aux élèves de cette classe, mais reste conservé — '
          'vous pourrez le désarchiver plus tard.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(context, grp, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showGroupModal(BuildContext context, {WhatsappCommunity? existing}) {
    final isEditing = existing != null;
    final linkCtrl = TextEditingController(text: existing?.inviteLink ?? '');
    final countCtrl = TextEditingController(text: existing?.memberCountEstimate.toString() ?? '0');
    String? selectedClassId = existing?.classNodeId;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.groups_rounded,
            text: isEditing ? 'Modifier le Groupe WhatsApp' : 'Ajouter un Groupe WhatsApp',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  TextField(
                    controller: linkCtrl,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Lien d\'invitation WhatsApp (https://chat...)',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countCtrl,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de membres (estimation manuelle)',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
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
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final link = linkCtrl.text.trim();
                      if (link.isEmpty || !link.startsWith('https://chat.whatsapp.com/')) {
                        setModalState(() => formError =
                            'Lien invalide — doit commencer par https://chat.whatsapp.com/');
                        return;
                      }
                      if (selectedClassId == null) {
                        setModalState(() => formError = 'Sélectionnez une classe.');
                        return;
                      }
                      final count = int.tryParse(countCtrl.text.trim());
                      if (count == null || count < 0) {
                        setModalState(() => formError = 'Nombre de membres invalide.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.upsertWhatsappCommunity(
                          id: existing?.id,
                          classNodeId: selectedClassId!,
                          inviteLink: link,
                          memberCountEstimate: count,
                          isActive: existing?.isActive ?? true,
                        );
                        ref.invalidate(whatsappCommunitiesProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'Groupe mis à jour.' : 'Nouveau groupe WhatsApp enregistré !'),
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
