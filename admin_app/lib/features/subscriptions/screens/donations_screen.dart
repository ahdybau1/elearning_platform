import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_dialog_title.dart';

const _donationOperators = [
  'Espèces',
  'Chèque',
  'Virement Bancaire',
  'Carte Bancaire',
  'Orange Money',
  'MTN Mobile Money',
  'Autre',
];

IconData _iconForCampaignMedia(String url) {
  switch (SupabaseService.inferMediaType(url)) {
    case 'image':
      return Icons.image_rounded;
    case 'video':
      return Icons.videocam_rounded;
    case 'audio':
      return Icons.audiotrack_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

class DonationsScreen extends ConsumerStatefulWidget {
  const DonationsScreen({super.key});

  @override
  ConsumerState<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends ConsumerState<DonationsScreen> {
  int _activeTab = 0; // 0: Campagnes Caritatives, 1: Historique des Dons
  String? _donationCampaignFilter; // null = toutes les campagnes

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(charityCampaignsProvider);
    final donationsAsync = ref.watch(donationsProvider(_donationCampaignFilter));

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppTheme.accentEmerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dons & Œuvres Caritatives',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Financement participatif de bourses et d\'équipements scolaires pour élèves défavorisés',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () => _activeTab == 0
                      ? _showCampaignDialog(context)
                      : _showRecordDonationDialog(context),
                  icon: Icon(_activeTab == 0 ? Icons.add_rounded : Icons.receipt_long_rounded, size: 18),
                  label: Text(_activeTab == 0 ? 'Créer une Campagne' : 'Enregistrer un Don'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab bar
            Row(
              children: [
                _buildTabButton('Campagnes en Cours', 0),
                const SizedBox(width: 12),
                _buildTabButton('Historique des Versements', 1),
              ],
            ),
            const SizedBox(height: 24),

            // Tab content
            Expanded(
              child: _activeTab == 0
                  ? _buildCampaignsTab(campaignsAsync)
                  : _buildDonationsTab(donationsAsync, campaignsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSel = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.accentEmerald.withValues(alpha: 0.15) : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? AppTheme.accentEmerald : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
            color: isSel ? AppTheme.accentEmerald : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab(AsyncValue<List<CharityCampaign>> campaignsAsync) {
    return campaignsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return _buildEmptyState(
            Icons.volunteer_activism_outlined,
            'Aucune campagne pour le moment',
            'Créez une campagne pour commencer à collecter des dons destinés\naux bourses et équipements scolaires.',
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemCount: campaigns.length,
          itemBuilder: (context, index) => _buildCampaignCard(campaigns[index]),
        );
      },
    );
  }

  Widget _buildCampaignMediaPreview(String url) {
    final type = SupabaseService.inferMediaType(url);
    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
          child: Image.network(
            url,
            height: 70,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              height: 70,
              color: AppTheme.surfaceDark,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 20),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_iconForCampaignMedia(url), size: 16, color: AppTheme.accentCyan),
            const SizedBox(width: 8),
            Text(
              type == 'video' ? 'Voir la vidéo illustrative' : 'Écouter l\'illustration audio',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentCyan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(CharityCampaign c) {
    final progress = (c.collectedAmount / (c.targetAmount > 0 ? c.targetAmount : 1)).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(1);

    return Opacity(
      opacity: c.isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.isActive ? AppTheme.borderColor : AppTheme.accentAmber),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (!c.isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Archivée',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (c.imageUrl != null) ...[
              _buildCampaignMediaPreview(c.imageUrl!),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: Text(
                c.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.surfaceDark,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentEmerald),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collecté: ${c.collectedAmount.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentEmerald,
                  ),
                ),
                Text(
                  'Objectif: ${c.targetAmount.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentBlue),
                  tooltip: 'Modifier',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _showCampaignDialog(context, existing: c),
                ),
                IconButton(
                  icon: Icon(
                    c.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                    size: 18,
                    color: AppTheme.accentAmber,
                  ),
                  tooltip: c.isActive ? 'Archiver' : 'Désarchiver',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => c.isActive
                      ? _showArchiveCampaignConfirmation(context, c)
                      : _toggleCampaignActive(c, true),
                ),
                if (!c.isActive)
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppTheme.accentRose),
                    tooltip: 'Supprimer définitivement',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _showDeleteCampaignConfirmation(context, c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCampaignActive(CharityCampaign c, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateCharityCampaign(c.id, isActive: isActive);
      ref.invalidate(charityCampaignsProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Campagne désarchivée.' : 'Campagne archivée.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
      );
    }
  }

  void _showArchiveCampaignConfirmation(BuildContext context, CharityCampaign c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver "${c.title}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 420,
          child: Text(
            'La campagne ne sera plus visible ni ouverte aux nouveaux dons, mais pas supprimée — '
            'vous pourrez la désarchiver ou la supprimer définitivement plus tard. Les dons déjà '
            'enregistrés restent conservés.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleCampaignActive(c, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCampaignConfirmation(BuildContext context, CharityCampaign c) {
    final confirmController = TextEditingController();
    bool nameMatches = false;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer "${c.title}" ?',
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
                    'IRRÉVERSIBLE : la campagne sera définitivement supprimée. Les dons déjà '
                    'enregistrés sont conservés mais ne seront plus rattachés à aucune campagne.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tapez "${c.title}" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: c.title),
                  onChanged: (v) => setModalState(() => nameMatches = v.trim() == c.title),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(errorText!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
              onPressed: (isLoading || !nameMatches)
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.deleteCharityCampaign(c.id);
                        ref.invalidate(charityCampaignsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Campagne "${c.title}" supprimée définitivement.'),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationsTab(
    AsyncValue<List<Donation>> donationsAsync,
    AsyncValue<List<CharityCampaign>> campaignsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Filtrer par campagne :',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: _donationCampaignFilter,
                isExpanded: true,
                dropdownColor: AppTheme.primaryDark,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Toutes les campagnes')),
                  ...(campaignsAsync.valueOrNull ?? []).map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.isActive ? c.title : '${c.title} — archivée', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _donationCampaignFilter = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: donationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (donations) {
              if (donations.isEmpty) {
                return _buildEmptyState(
                  Icons.receipt_long_outlined,
                  'Aucun don enregistré',
                  'Les dons reçus via l\'application ou saisis manuellement\napparaîtront ici.',
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: ListView.separated(
                  itemCount: donations.length,
                  separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
                  itemBuilder: (context, index) {
                    final d = donations[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_rounded, color: AppTheme.accentEmerald, size: 20),
                      ),
                      title: Text(
                        d.donorName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      subtitle: Text(
                        '${d.donorEmail ?? d.donorPhone ?? 'Donateur Anonyme'} • ${DateFormat('dd/MM/yyyy HH:mm').format(d.createdAt)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              d.operator,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '+${d.amount.toStringAsFixed(0)} ${d.currency}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCampaignDialog(BuildContext context, {CharityCampaign? existing}) {
    final isEditing = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final targetCtrl = TextEditingController(text: existing?.targetAmount.toStringAsFixed(0) ?? '1000000');
    String? mediaUrl = existing?.imageUrl;
    String? mediaFilename = existing?.imageUrl != null ? existing!.imageUrl!.split('/').last : null;
    bool isUploadingMedia = false;
    String? mediaUploadError;
    String? submitError;
    bool isLoading = false;

    Future<void> pickAndUploadMedia(void Function(void Function()) setDlgState, WidgetRef ref) async {
      setDlgState(() {
        isUploadingMedia = true;
        mediaUploadError = null;
      });
      try {
        final result = await FilePicker.platform.pickFiles(withData: true);
        final file = result?.files.single;
        final bytes = file?.bytes;
        if (file == null || bytes == null) {
          setDlgState(() => isUploadingMedia = false);
          return;
        }
        final service = ref.read(supabaseServiceProvider);
        final uploadedBy = ref.read(authProvider).valueOrNull?.id ?? '00000000-0000-0000-0000-000000000001';
        final asset = await service.uploadMedia(bytes: bytes, filename: file.name, uploadedBy: uploadedBy);
        setDlgState(() {
          mediaUrl = asset.url;
          mediaFilename = asset.filename;
          isUploadingMedia = false;
        });
      } catch (e) {
        setDlgState(() {
          isUploadingMedia = false;
          mediaUploadError = 'Échec de l\'upload : $e';
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.campaign_rounded,
            text: isEditing ? 'Modifier "${existing.title}"' : 'Créer une Campagne de Dons',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Titre de la campagne',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description du projet et bénéficiaires',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Objectif de collecte (XAF)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Le montant collecté (${existing.collectedAmount.toStringAsFixed(0)} XAF) est calculé '
                      'automatiquement à partir des dons enregistrés — il ne se modifie pas ici.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('Illustration (image, audio ou vidéo — optionnel)',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) => Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUploadingMedia ? null : () => pickAndUploadMedia(setDlgState, ref),
                          icon: isUploadingMedia
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(isUploadingMedia
                              ? 'Envoi en cours...'
                              : (mediaUrl != null ? 'Remplacer le fichier' : 'Choisir un fichier')),
                        ),
                        const SizedBox(width: 10),
                        if (mediaFilename != null)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(_iconForCampaignMedia(mediaFilename!), size: 14, color: AppTheme.accentCyan),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(mediaFilename!,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (mediaUploadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(mediaUploadError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  if (submitError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        setDlgState(() => submitError = 'Le titre est obligatoire.');
                        return;
                      }
                      final description = descCtrl.text.trim();
                      if (description.isEmpty) {
                        setDlgState(() => submitError = 'La description est obligatoire.');
                        return;
                      }
                      final target = double.tryParse(targetCtrl.text.trim());
                      if (target == null || target <= 0) {
                        setDlgState(() => submitError = 'Objectif invalide — entrez un nombre positif.');
                        return;
                      }
                      setDlgState(() {
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateCharityCampaign(
                            existing.id,
                            title: title,
                            description: description,
                            targetAmount: target,
                            imageUrl: mediaUrl,
                          );
                        } else {
                          await service.createCharityCampaign(
                            title: title,
                            description: description,
                            targetAmount: target,
                            startDate: DateTime.now(),
                            imageUrl: mediaUrl,
                          );
                        }
                        ref.invalidate(charityCampaignsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlgState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Enregistrer' : 'Lancer la Campagne', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordDonationDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String operator = _donationOperators.first;
    String? campaignId = _donationCampaignFilter;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.receipt_long_rounded,
            text: 'Enregistrer un Don Reçu Hors Application',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pour un don reçu en espèces, par chèque ou par virement direct, non capté par un '
                    'moyen de paiement en ligne.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nom du donateur',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email (optionnel)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Téléphone (optionnel)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Montant (XAF)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: operator,
                          dropdownColor: AppTheme.primaryDark,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Mode de réception',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                          items: _donationOperators
                              .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setDlgState(() => operator = v ?? operator),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      final campaignsAsync = ref.watch(charityCampaignsProvider);
                      final campaigns = campaignsAsync.valueOrNull ?? [];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: campaignId,
                        isExpanded: true,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Campagne liée (optionnel)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.campaign_rounded, size: 20),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Don général (aucune campagne)'),
                          ),
                          ...campaigns.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.isActive ? c.title : '${c.title} — archivée',
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setDlgState(() => campaignId = v),
                      );
                    },
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDlgState(() => submitError = 'Le nom du donateur est obligatoire.');
                        return;
                      }
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) {
                        setDlgState(() => submitError = 'Montant invalide — entrez un nombre positif.');
                        return;
                      }
                      setDlgState(() {
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createDonation(
                          donorName: name,
                          donorEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                          donorPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          amount: amount,
                          operator: operator,
                          charityCampaignId: campaignId,
                        );
                        ref.invalidate(donationsProvider(_donationCampaignFilter));
                        ref.invalidate(charityCampaignsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlgState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer le Don', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
