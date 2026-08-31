import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class ShopManagementScreen extends ConsumerStatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  ConsumerState<ShopManagementScreen> createState() =>
      _ShopManagementScreenState();
}

class _ShopManagementScreenState extends ConsumerState<ShopManagementScreen> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(academicTreeProvider);
    final shopDocsAsync = ref.watch(shopDocumentsProvider(_selectedClassId));

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — Column plutôt que Row : un bouton au libellé long ("Mettre en Vente un
            // Document") comme simple frère d'un Expanded affamait le titre (retour utilisateur
            // réel, texte écrit à la verticale lettre par lettre, 2026-08-30 — même bug que
            // school_year_promotion_screen.dart).
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
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
                            'Boutique & Documents Payants',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Vente de fiches synthèses, annales corrigées et livrets, avec filigrane forensique à l\'affichage',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showDocDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Mettre en Vente un Document'),
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
            const SizedBox(height: 12),
            // Depuis la Matrice de Droits (clé 'shop_documents'), un document reste invisible pour
            // tout élève dont le palier n'y donne pas accès — INDÉPENDAMMENT de son prix "à la
            // carte" ci-dessous. Sans ce rappel, rien sur cet écran n'indiquait cette double
            // condition d'accès (prix payé À LA FOIS palier suffisant).
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un document n\'est visible que pour les élèves dont le palier d\'abonnement '
                      'donne accès à "Boutique de Documents" (voir Matrice de Droits) — le prix '
                      'ci-dessous s\'applique en plus de cette condition, pas à sa place.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Class Filter
            classesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => const SizedBox(),
              data: (nodes) {
                final classNodes = _extractClassNodes(nodes);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Toutes les classes'),
                          selected: _selectedClassId == null,
                          onSelected: (_) => setState(() => _selectedClassId = null),
                          selectedColor: AppTheme.accentEmerald.withValues(alpha: 0.2),
                          backgroundColor: AppTheme.cardBackground,
                          labelStyle: GoogleFonts.inter(
                            color: _selectedClassId == null ? AppTheme.accentEmerald : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      ...classNodes.map((c) {
                        final isSel = c.id == _selectedClassId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedClassId = c.id),
                            selectedColor: AppTheme.accentEmerald.withValues(alpha: 0.2),
                            backgroundColor: AppTheme.cardBackground,
                            labelStyle: GoogleFonts.inter(
                              color: isSel ? AppTheme.accentEmerald : AppTheme.textSecondary,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Documents classés par dossier de Matière (le filtre Classe ci-dessus s'applique en
            // amont) — plus la grille plate qui devenait vite illisible dès quelques dizaines de
            // documents.
            Expanded(
              child: shopDocsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (docs) {
                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }
                  return Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync =
                          ref.watch(subjectsProvider((countryId: null, includeInactive: true)));
                      final subjectNames = <String, String>{
                        for (final s in subjectsAsync.valueOrNull ?? <Subject>[]) s.id: s.name,
                      };
                      final bySubject = <String?, List<ShopDocument>>{};
                      for (final doc in docs) {
                        bySubject.putIfAbsent(doc.subjectId, () => []).add(doc);
                      }
                      final subjectIds = bySubject.keys.toList()
                        ..sort((a, b) {
                          if (a == null) return 1;
                          if (b == null) return -1;
                          return (subjectNames[a] ?? a).compareTo(subjectNames[b] ?? b);
                        });
                      return ListView.builder(
                        itemCount: subjectIds.length,
                        itemBuilder: (context, idx) {
                          final subjectId = subjectIds[idx];
                          final subjectDocs = bySubject[subjectId]!;
                          return _buildSubjectFolder(
                            subjectId == null ? 'Sans matière assignée' : (subjectNames[subjectId] ?? '...'),
                            subjectDocs,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BUG CRITIQUE corrigé : `AcademicNode` n'a pas de champ `.type` (le vrai champ s'appelle
  /// `.nodeType`, un enum `NodeType`, pas une chaîne). Comme cette fonction prenait `List<dynamic>`
  /// plutôt que `List<AcademicNode>`, Dart ne vérifiait rien à la compilation — l'appel
  /// `node.type == 'classe'` plantait au RUNTIME dès que ce widget essayait de s'afficher avec de
  /// vraies données (`NoSuchMethodError`), ce que `flutter analyze` ne pouvait pas détecter. La
  /// chaîne française 'classe' ne correspondait de toute façon à aucune valeur réelle ('class' en
  /// anglais côté base). Inclut aussi les Séries, comme partout ailleurs dans l'app où une "classe
  /// cible" peut être une Classe ou une Série.
  List<AcademicNode> _extractClassNodes(List<AcademicNode> nodes) {
    final result = <AcademicNode>[];
    for (final node in nodes) {
      if (node.nodeType == NodeType.classType || node.nodeType == NodeType.series) {
        result.add(node);
      }
      if (node.children.isNotEmpty) {
        result.addAll(_extractClassNodes(node.children));
      }
    }
    return result;
  }

  Widget _buildSubjectFolder(String subjectName, List<ShopDocument> docs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('shop-subject-$subjectName'),
          initiallyExpanded: true,
          leading: const Icon(Icons.folder_rounded, color: AppTheme.accentEmerald),
          title: Text(
            subjectName,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentEmerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${docs.length}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildShopDocCard(docs[index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Aucun document en vente pour cette sélection',
            style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des livrets d\'exercices ou fiches de révision à la carte.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopDocCard(ShopDocument doc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doc.isActive ? AppTheme.borderColor : AppTheme.accentAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${doc.price.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentEmerald,
                  ),
                ),
              ),
              const Spacer(),
              if (!doc.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ARCHIVÉ',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.download_rounded, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${doc.downloadsCount} ventes',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            doc.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: doc.isActive ? Colors.white : Colors.white38,
              decoration: doc.isActive ? null : TextDecoration.lineThrough,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              doc.description ?? 'Document pédagogique officiel téléchargeable',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.security_rounded, size: 14, color: AppTheme.accentCyan),
              const SizedBox(width: 4),
              Text(
                'Filigrane forensique',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w500,
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
                onPressed: () => _showDocDialog(context, existing: doc),
              ),
              IconButton(
                icon: Icon(
                  doc.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                  size: 18,
                  color: AppTheme.accentAmber,
                ),
                tooltip: doc.isActive ? 'Archiver' : 'Désarchiver',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => doc.isActive
                    ? _showArchiveConfirmation(context, doc)
                    : _toggleActive(doc, true),
              ),
              if (!doc.isActive)
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppTheme.accentRose),
                  tooltip: 'Supprimer définitivement',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _showDeleteConfirmation(context, doc),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(ShopDocument doc, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateShopDocument(doc.id, isActive: isActive);
      ref.invalidate(shopDocumentsProvider(_selectedClassId));
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Document désarchivé.' : 'Document archivé.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
      );
    }
  }

  /// Avant : l'icône poubelle appelait `deleteShopDocument` (suppression PHYSIQUE réelle)
  /// directement au clic — aucune confirmation, aucun retour de succès/erreur, sur une action
  /// irréversible qui efface aussi l'historique `downloads_count`.
  void _showArchiveConfirmation(BuildContext context, ShopDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver "${doc.title}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 420,
          child: Text(
            'Le document ne sera plus visible ni achetable, mais pas supprimé — vous pourrez le '
            'désarchiver ou le supprimer définitivement plus tard.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(doc, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ShopDocument doc) {
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
            text: 'Supprimer "${doc.title}" ?',
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
                    'IRRÉVERSIBLE : le document et son historique de ${doc.downloadsCount} vente(s) '
                    'seront définitivement supprimés.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tapez "${doc.title}" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: doc.title),
                  onChanged: (v) => setModalState(() => nameMatches = v.trim() == doc.title),
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
                        await service.deleteShopDocument(doc.id);
                        ref.invalidate(shopDocumentsProvider(_selectedClassId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Document "${doc.title}" supprimé définitivement.'),
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

  /// Avant : `classNodeId` retombait sur un UUID FACTICE ('00000000-...') dès que le filtre "Toutes
  /// les classes" était actif — combiné au bug de `_extractClassNodes` (qui empêchait toute
  /// sélection réelle de classe), CHAQUE document créé était rattaché à une classe inexistante.
  /// L'URL du document et le prix retombaient de même silencieusement sur des valeurs factices
  /// (un lien de démo mort, 500 XAF) au lieu de bloquer la soumission. Sert aussi pour l'édition.
  void _showDocDialog(BuildContext context, {ShopDocument? existing}) {
    final isEditing = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '500');
    String? selectedClassId = existing?.classNodeId ?? _selectedClassId;
    String? selectedSubjectId = existing?.subjectId;
    String? documentUrl = existing?.documentUrl;
    String? documentFilename = existing?.documentUrl != null ? existing!.documentUrl.split('/').last : null;
    String? previewUrl = existing?.previewUrl;
    String? previewFilename = existing?.previewUrl != null ? existing!.previewUrl!.split('/').last : null;
    bool isUploadingDoc = false;
    bool isUploadingPreview = false;
    String? docUploadError;
    String? previewUploadError;
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    Future<void> pickAndUpload({
      required bool isPreview,
      required void Function(void Function()) setDlgState,
      required WidgetRef ref,
    }) async {
      setDlgState(() {
        if (isPreview) {
          isUploadingPreview = true;
          previewUploadError = null;
        } else {
          isUploadingDoc = true;
          docUploadError = null;
        }
      });
      try {
        final result = await FilePicker.platform.pickFiles(withData: true);
        final file = result?.files.single;
        final bytes = file?.bytes;
        if (file == null || bytes == null) {
          setDlgState(() {
            if (isPreview) {
              isUploadingPreview = false;
            } else {
              isUploadingDoc = false;
            }
          });
          return;
        }
        final service = ref.read(supabaseServiceProvider);
        final uploadedBy = ref.read(authProvider).valueOrNull?.id ?? '00000000-0000-0000-0000-000000000001';
        final asset = await service.uploadMedia(bytes: bytes, filename: file.name, uploadedBy: uploadedBy);
        setDlgState(() {
          if (isPreview) {
            previewUrl = asset.url;
            previewFilename = asset.filename;
            isUploadingPreview = false;
          } else {
            documentUrl = asset.url;
            documentFilename = asset.filename;
            isUploadingDoc = false;
          }
        });
      } catch (e) {
        setDlgState(() {
          if (isPreview) {
            isUploadingPreview = false;
            previewUploadError = 'Échec de l\'upload : $e';
          } else {
            isUploadingDoc = false;
            docUploadError = 'Échec de l\'upload : $e';
          }
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
            icon: Icons.sell_rounded,
            text: isEditing ? 'Modifier "${existing.title}"' : 'Mettre en Vente un Document',
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
                    decoration: InputDecoration(
                      labelText: 'Titre du document',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Prix unitaire (XAF)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Document PDF',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) => Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUploadingDoc
                              ? null
                              : () => pickAndUpload(isPreview: false, setDlgState: setDlgState, ref: ref),
                          icon: isUploadingDoc
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(isUploadingDoc
                              ? 'Envoi en cours...'
                              : (documentUrl != null ? 'Remplacer le fichier' : 'Choisir un fichier')),
                        ),
                        const SizedBox(width: 10),
                        if (documentFilename != null)
                          Expanded(
                            child: Text(documentFilename!,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                  if (docUploadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(docUploadError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  const SizedBox(height: 18),
                  Text('Aperçu (optionnel)',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) => Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUploadingPreview
                              ? null
                              : () => pickAndUpload(isPreview: true, setDlgState: setDlgState, ref: ref),
                          icon: isUploadingPreview
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(isUploadingPreview
                              ? 'Envoi en cours...'
                              : (previewUrl != null ? 'Remplacer le fichier' : 'Choisir un fichier')),
                        ),
                        const SizedBox(width: 10),
                        if (previewFilename != null)
                          Expanded(
                            child: Text(previewFilename!,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                  if (previewUploadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(previewUploadError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(academicTreeProvider);
                      final classNodes = classesAsync.valueOrNull != null
                          ? _extractClassNodes(classesAsync.valueOrNull!)
                          : <AcademicNode>[];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: selectedClassId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Classe / Série ciblée',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.school_rounded, size: 20),
                        ),
                        items: classNodes
                            .map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setDlgState(() {
                          selectedClassId = v;
                          selectedSubjectId = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      if (selectedClassId == null) {
                        return const SizedBox.shrink();
                      }
                      final subjectsAsync = ref.watch(subjectsForClassProvider(selectedClassId!));
                      final subjects = subjectsAsync.valueOrNull ?? <Subject>[];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: subjects.any((s) => s.id == selectedSubjectId) ? selectedSubjectId : null,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Matière (optionnel — pour le classement en dossiers)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Sans matière assignée')),
                          ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) => setDlgState(() => selectedSubjectId = v),
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
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        setDlgState(() => fieldError = 'Le titre est obligatoire');
                        return;
                      }
                      final price = double.tryParse(priceCtrl.text.trim());
                      if (price == null || price < 0) {
                        setDlgState(() => submitError = 'Prix invalide — entrez un nombre valide.');
                        return;
                      }
                      final url = documentUrl;
                      if (url == null || url.isEmpty) {
                        setDlgState(() => submitError = 'Le document à vendre est obligatoire — choisissez un fichier.');
                        return;
                      }
                      if (selectedClassId == null) {
                        setDlgState(() => submitError = 'La classe/série ciblée est obligatoire.');
                        return;
                      }
                      setDlgState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateShopDocument(
                            existing.id,
                            title: title,
                            description: descCtrl.text.trim(),
                            price: price,
                            documentUrl: url,
                            previewUrl: previewUrl,
                            clearSubject: selectedSubjectId == null,
                            subjectId: selectedSubjectId,
                          );
                        } else {
                          await service.createShopDocument(
                            classNodeId: selectedClassId!,
                            subjectId: selectedSubjectId,
                            title: title,
                            description: descCtrl.text.trim(),
                            price: price,
                            documentUrl: url,
                            previewUrl: previewUrl,
                          );
                        }
                        ref.invalidate(shopDocumentsProvider(_selectedClassId));
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
                  : Text(isEditing ? 'Enregistrer' : 'Publier', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
