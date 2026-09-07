import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/components/elef_button.dart';
import '../../../core/design_system/components/elef_input.dart';
import '../../../core/design_system/components/elef_badge.dart';
import '../../../core/design_system/components/elef_tabs.dart';
import '../../../core/engines/image_generation_engine.dart';

/// Modèle local pour un média dans la bibliothèque
class MediaAsset {
  final String id;
  final String title;
  final String subject;
  final String prompt;
  final String imageUrl;
  final String type; // 'ai_generated' | 'vector_schema' | 'photo' | 'diagram'
  final String aspectRatio;
  final String cacheHash;
  final DateTime createdAt;

  const MediaAsset({
    required this.id,
    required this.title,
    required this.subject,
    required this.prompt,
    required this.imageUrl,
    required this.type,
    required this.aspectRatio,
    required this.cacheHash,
    required this.createdAt,
  });
}

/// Écran Médiathèque & Générateur d'Illustrations IA EDLEARN / ELEF v2
///
/// Permet de stocker, rechercher et générer des illustrations pédagogiques
/// scientifiques avec cache intelligent pour éviter les coûts d'API redondants.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  String _searchQuery = '';
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Tous les médias', 'Illustrations IA', 'Schémas Scientifiques', 'Diagrammes'];

  // Catalogue d'actifs initiaux
  final List<MediaAsset> _assets = [
    MediaAsset(
      id: 'media_1',
      title: 'Représentation géométrique d\'une suite arithmétique',
      subject: 'Mathématiques',
      prompt: 'Marches d\'escalier régulières avec hauteur constante r et droites discrètes',
      imageUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&auto=format&fit=crop&q=80',
      type: 'ai_generated',
      aspectRatio: '16:9',
      cacheHash: 'fnv_7a8f9c1b',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MediaAsset(
      id: 'media_2',
      title: 'Oscillations et amortissement d\'un circuit RLC',
      subject: 'Physique-Chimie',
      prompt: 'Courbe sinusoïdale amortie enveloppée par une exponentielle décroissante',
      imageUrl: 'https://images.unsplash.com/photo-1507413245164-6160d8298b31?w=600&auto=format&fit=crop&q=80',
      type: 'ai_generated',
      aspectRatio: '16:9',
      cacheHash: 'fnv_5d2e8e4a',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    MediaAsset(
      id: 'media_3',
      title: 'Schéma d\'un réducteur mécanique à engrenages',
      subject: 'Sciences de l\'Ingénieur',
      prompt: 'Plan technique en coupe d\'un engrenage cylindrique hélicoïdal avec arbre menant',
      imageUrl: 'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=600&auto=format&fit=crop&q=80',
      type: 'vector_schema',
      aspectRatio: '4:3',
      cacheHash: 'fnv_3c9b1f2e',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MediaAsset(
      id: 'media_4',
      title: 'Arbre binaire de recherche équilibré',
      subject: 'Informatique',
      prompt: 'Structure de nœuds en arbre binaire avec clés ordonnées et hauteurs équilibrées AVL',
      imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=600&auto=format&fit=crop&q=80',
      type: 'diagram',
      aspectRatio: '1:1',
      cacheHash: 'fnv_9a4f6d8c',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  void _openAiGeneratorDialog() {
    final promptCtrl = TextEditingController(
      text: 'Visualisation géométrique de la convergence d\'une suite géométrique avec raison q = 0.5',
    );
    String selectedSubject = 'Mathématiques';
    String selectedStyle = 'Schéma vectoriel 2D';
    String selectedRatio = '16:9';
    bool isGenerating = false;
    GeneratedImageResult? lastResult;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: ElefColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: ElefRadius.xl,
                side: const BorderSide(color: ElefColors.borderMedium),
              ),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête de la modale
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ElefColors.primaryGlow,
                            borderRadius: ElefRadius.md,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: ElefColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Générateur d\'Illustrations Scientifiques IA',
                                style: ElefTypography.heading2.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Moteur ImageGenerationEngine avec cache intelligent SHA-256',
                                style: ElefTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: ElefColors.textMuted),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: ElefColors.borderSubtle),

                    // Sélecteur Discipline & Style
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Discipline', style: ElefTypography.caption),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF090D18),
                                  borderRadius: ElefRadius.md,
                                  border: Border.all(color: ElefColors.borderSubtle),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedSubject,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  dropdownColor: ElefColors.surfaceCard,
                                  style: ElefTypography.bodySmall.copyWith(color: Colors.white),
                                  items: ['Mathématiques', 'Physique-Chimie', 'Informatique', 'Sciences de l\'Ingénieur']
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => selectedSubject = val!),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Style de Rendu', style: ElefTypography.caption),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF090D18),
                                  borderRadius: ElefRadius.md,
                                  border: Border.all(color: ElefColors.borderSubtle),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedStyle,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  dropdownColor: ElefColors.surfaceCard,
                                  style: ElefTypography.bodySmall.copyWith(color: Colors.white),
                                  items: ['Schéma vectoriel 2D', 'Rendu 3D scientifique', 'Plan technique d\'atelier']
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => selectedStyle = val!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prompt Pédagogique
                    Text('Description détaillée du concept à illustrer', style: ElefTypography.caption),
                    const SizedBox(height: 6),
                    TextField(
                      controller: promptCtrl,
                      style: ElefTypography.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ex: Schéma d\'un condensateur se déchargeant dans une bobine...',
                        hintStyle: const TextStyle(color: ElefColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFF090D18),
                        border: OutlineInputBorder(
                          borderRadius: ElefRadius.md,
                          borderSide: const BorderSide(color: ElefColors.borderSubtle),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Résultat de la génération (si disponible)
                    if (lastResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1020),
                          borderRadius: ElefRadius.md,
                          border: Border.all(color: ElefColors.success.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: ElefColors.success, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Génération réussie',
                                        style: ElefTypography.labelMedium.copyWith(color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      ElefBadge(
                                        label: lastResult!.fromCache ? 'Cache Hit ⚡' : 'Nouvelle Génération',
                                        color: lastResult!.fromCache ? ElefColors.info : ElefColors.success,
                                        tone: ElefBadgeTone.subtle,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Hash: ${lastResult!.cacheHash} • Mode: ${lastResult!.fromCache ? "Cache instantané (0 token)" : "Génération IA active"}',
                                    style: ElefTypography.caption.copyWith(color: ElefColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Boutons d'action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElefButton.ghost(
                          label: 'Annuler',
                          size: ElefButtonSize.sm,
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                        const SizedBox(width: 10),
                        ElefButton.primary(
                          label: isGenerating ? 'Génération en cours...' : 'Générer l\'Illustration',
                          icon: Icons.auto_awesome_rounded,
                          size: ElefButtonSize.sm,
                          isLoading: isGenerating,
                          onPressed: isGenerating
                              ? null
                              : () async {
                                  setDialogState(() => isGenerating = true);
                                  final styleEnum = selectedStyle.contains('3D')
                                      ? ImageStyleType.scientificDiagram
                                      : selectedStyle.contains('technique')
                                          ? ImageStyleType.technicalBlueprint
                                          : ImageStyleType.modernFlatPedagogical;

                                  final res = await ImageGenerationEngine.generate(
                                    ImageGenerationRequest(
                                      prompt: promptCtrl.text.trim(),
                                      subject: selectedSubject,
                                      classLevel: 'Terminale',
                                      style: styleEnum,
                                    ),
                                  );

                                  final newAsset = MediaAsset(
                                    id: 'media_${DateTime.now().microsecondsSinceEpoch}',
                                    title: promptCtrl.text.trim().split(' ').take(6).join(' '),
                                    subject: selectedSubject,
                                    prompt: promptCtrl.text.trim(),
                                    imageUrl: res.imageUrl,
                                    type: 'ai_generated',
                                    aspectRatio: selectedRatio,
                                    cacheHash: res.cacheHash,
                                    createdAt: DateTime.now(),
                                  );

                                  setState(() {
                                    _assets.insert(0, newAsset);
                                  });

                                  setDialogState(() {
                                    isGenerating = false;
                                    lastResult = res;
                                  });
                                },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssets = _assets.where((asset) {
      final matchesSearch = _searchQuery.isEmpty ||
          asset.title.toLowerCase().contains(_searchQuery) ||
          asset.subject.toLowerCase().contains(_searchQuery) ||
          asset.prompt.toLowerCase().contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilterIndex == 1) return asset.type == 'ai_generated';
      if (_selectedFilterIndex == 2) return asset.type == 'vector_schema';
      if (_selectedFilterIndex == 3) return asset.type == 'diagram';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: ElefColors.background,
      body: Column(
        children: [
          // En-tête de la Médiathèque
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: ElefColors.surfaceDark,
              border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ElefColors.primaryGlow,
                    borderRadius: ElefRadius.md,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: ElefColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Médiathèque & Illustrations Scientifiques IA',
                        style: ElefTypography.heading1.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Générez, réutilisez et insérez des schémas pédagogiques avec cache anti-duplication',
                        style: ElefTypography.caption,
                      ),
                    ],
                  ),
                ),
                ElefButton.primary(
                  label: 'Générer une Illustration IA',
                  icon: Icons.auto_awesome_rounded,
                  size: ElefButtonSize.sm,
                  onPressed: _openAiGeneratorDialog,
                ),
              ],
            ),
          ),

          // Barre de filtres & recherche
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0C1222),
              border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElefTabs(
                    tabs: _filters,
                    selectedIndex: _selectedFilterIndex,
                    onTabSelected: (i) => setState(() => _selectedFilterIndex = i),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: ElefSearchField(
                    hintText: 'Rechercher par titre, discipline, prompt...',
                    onChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),

          // Grille des Médias
          Expanded(
            child: filteredAssets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_not_supported_rounded, size: 54, color: ElefColors.textMuted),
                        const SizedBox(height: 14),
                        Text(
                          'Aucune illustration trouvée',
                          style: ElefTypography.titleMedium.copyWith(color: ElefColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Modifiez vos filtres ou générez une nouvelle illustration IA ci-dessus',
                          style: ElefTypography.bodySmall,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: filteredAssets.length,
                    itemBuilder: (context, index) {
                      return _buildAssetCard(filteredAssets[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(MediaAsset asset) {
    final disciplineColor = ElefColors.forSubject(asset.subject);

    return Container(
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Preview Container
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ElefRadius.rawLg - 1),
                    topRight: Radius.circular(ElefRadius.rawLg - 1),
                  ),
                  child: Image.network(
                    asset.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: const Color(0xFF090D18),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: ElefColors.textMuted, size: 36),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: ElefBadge(
                    label: asset.subject,
                    color: disciplineColor,
                    tone: ElefBadgeTone.subtle,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: ElefRadius.xs,
                    ),
                    child: Text(
                      asset.aspectRatio,
                      style: ElefTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Détails de l'image
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.title,
                  style: ElefTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  asset.prompt,
                  style: ElefTypography.caption.copyWith(
                    color: ElefColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cached_rounded, size: 14, color: ElefColors.info),
                        const SizedBox(width: 4),
                        Text(
                          asset.cacheHash,
                          style: ElefTypography.code.copyWith(fontSize: 10.5, color: ElefColors.textMuted),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: ElefColors.textSecondary),
                          tooltip: 'Copier l\'URL',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('URL copiée dans le presse-papier')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: ElefColors.primary),
                          tooltip: 'Insérer dans le cours',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Illustration "${asset.title}" sélectionnée')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
