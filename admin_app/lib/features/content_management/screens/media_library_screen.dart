import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// Bibliothèque persistante partagée avec les éditeurs de contenu.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  final ValueChanged<MediaAsset>? onSelected;
  const MediaLibraryScreen({super.key, this.onSelected});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  String _query = '';
  String? _type;
  bool _uploading = false;
  String? _uploadError;
  static const _filters = <String?, String>{
    null: 'Tous',
    'image': 'Images',
    'video': 'Vidéos',
    'audio': 'Audio',
    'document': 'Documents',
  };

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final userId = ref.read(authProvider).valueOrNull?.id;
      if (userId == null || userId.isEmpty) {
        throw StateError('Session administrateur requise');
      }
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.bytes == null) throw StateError('Fichier illisible');
      await ref
          .read(supabaseServiceProvider)
          .uploadMedia(
            bytes: file.bytes!,
            filename: file.name,
            uploadedBy: userId,
          );
      if (!mounted) return;
      ref.invalidate(mediaLibraryProvider);
      _notify('Fichier ajouté à la médiathèque.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _uploadError =
              'Import impossible. Vérifie ta connexion, ta session et le fichier, puis réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(MediaAsset asset) async {
    try {
      await Clipboard.setData(ClipboardData(text: asset.url));
      if (mounted) _notify('URL copiée dans le presse-papier.');
    } catch (_) {
      if (mounted) _notify('Copie impossible. Réessaie depuis le navigateur.');
    }
  }

  Future<void> _open(MediaAsset asset) async {
    final uri = Uri.tryParse(asset.url);
    try {
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          !await launchUrl(uri)) {
        throw StateError('Ouverture impossible');
      }
    } catch (_) {
      if (mounted) _notify('Impossible d’ouvrir ce média.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaLibraryProvider(null));
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Médiathèque',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fichiers enregistrés et réutilisables dans les cours et exercices.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _uploading ? null : _upload,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _uploading
                              ? 'Import en cours…'
                              : 'Importer un fichier',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(mediaLibraryProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                      ),
                    ],
                  ),
                  if (_uploadError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _uploadError!,
                      style: const TextStyle(color: AppTheme.accentRose),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Génération d’images IA non raccordée. Importe une illustration existante pour l’utiliser dans un cours.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un fichier',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filters.entries
                        .map(
                          (entry) => ChoiceChip(
                            label: Text(entry.value),
                            selected: _type == entry.key,
                            onSelected: (_) =>
                                setState(() => _type = entry.key),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          media.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Impossible de charger la médiathèque.'),
                    TextButton(
                      onPressed: () => ref.invalidate(mediaLibraryProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
            data: (assets) {
              final filtered = assets
                  .where(
                    (asset) =>
                        (_type == null || asset.type == _type) &&
                        asset.filename.toLowerCase().contains(_query),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      assets.isEmpty
                          ? 'Aucun fichier enregistré. Importe ton premier média.'
                          : 'Aucun fichier ne correspond à ces filtres.',
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _assetCard(filtered[index]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _assetCard(MediaAsset asset) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: asset.type == 'image'
                    ? Image.network(
                        asset.url,
                        fit: BoxFit.cover,
                        semanticLabel: asset.filename,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : Icon(switch (asset.type) {
                        'video' => Icons.videocam_outlined,
                        'audio' => Icons.audiotrack,
                        _ => Icons.description_outlined,
                      }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.filename,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_filters[asset.type] ?? asset.type),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _open(asset),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir'),
              ),
              TextButton.icon(
                onPressed: () => _copy(asset),
                icon: const Icon(Icons.copy),
                label: const Text('Copier l’URL'),
              ),
              if (widget.onSelected != null)
                FilledButton(
                  onPressed: () => widget.onSelected!(asset),
                  child: const Text('Sélectionner'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
