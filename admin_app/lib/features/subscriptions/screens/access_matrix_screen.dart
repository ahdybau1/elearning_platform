import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';

class AccessMatrixScreen extends ConsumerStatefulWidget {
  const AccessMatrixScreen({super.key});

  @override
  ConsumerState<AccessMatrixScreen> createState() => _AccessMatrixScreenState();
}

class _AccessMatrixScreenState extends ConsumerState<AccessMatrixScreen> {
  final String _selectedTier = 'Gratuit';
  String _selectedClass = 'Classe de 3ème';

  static const _features = [
    'Cours & Leçons (Lecture)',
    'Exercices d\'Entraînement',
    'Exercices d\'Évaluation (Corrigés)',
    'Examens Officiels Nationaux (BEPC/Bac)',
    'Épreuves d\'Établissement',
    'Assistant IA (Nombre Q/jour)',
    'Téléchargement Hors-Ligne',
    'Forum & Communautés',
    'Publicités Interstitielles',
  ];

  static const _tierNames = [
    'Gratuit',
    'Journalier',
    'Hebdomadaire',
    'Mensuel',
    'Annuel',
  ];

  final Map<String, Map<String, String>> _matrixState = {
    for (final tier in _tierNames)
      tier: {
        for (final feature in _features) feature: _defaultAccess(tier, feature),
      },
  };

  static String _defaultAccess(String tier, String feature) {
    final isTopTier = tier == 'Mensuel' || tier == 'Annuel';
    final isMidTier = tier == 'Hebdomadaire';
    final isLowTier = tier == 'Journalier';

    if (feature == 'Cours & Leçons (Lecture)') return 'Accès complet';
    if (feature == 'Exercices d\'Entraînement') return 'Accès complet';
    if (feature == 'Exercices d\'Évaluation (Corrigés)') {
      if (isTopTier) return 'Accès complet';
      if (isMidTier || isLowTier) return 'Accès complet';
      return 'Aucun accès';
    }
    if (feature == 'Examens Officiels Nationaux (BEPC/Bac)') {
      if (isTopTier) return 'Accès complet';
      if (isMidTier || isLowTier) return 'Aucun accès';
      return 'Aucun accès';
    }
    if (feature == 'Épreuves d\'Établissement') {
      if (isTopTier) return 'Accès complet';
      if (isMidTier) return 'Limité (1/jour)';
      return 'Aucun accès';
    }
    if (feature == 'Assistant IA (Nombre Q/jour)') {
      if (isTopTier) return 'Accès complet (Illimité)';
      if (isMidTier) return 'Limité (10 Q/jour)';
      if (isLowTier) return 'Limité (3 Q/jour)';
      return 'Aucun accès';
    }
    if (feature == 'Téléchargement Hors-Ligne') {
      if (isTopTier) return 'Accès complet';
      if (isMidTier) return 'Limité (1 chapitre)';
      return 'Aucun accès';
    }
    if (feature == 'Forum & Communautés') return 'Accès complet';
    if (feature == 'Publicités Interstitielles') {
      if (isTopTier) return 'Non affichées';
      return 'Affichées';
    }
    return 'Aucun accès';
  }

  final String _selectedTierId = '';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
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
                        'Matrice de Droits Dynamique (Droits d\'accès)',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configuration dynamique des autorisations par Palier × Fonctionnalité (Alimente le floutage de l\'application élève)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                    ),
                    onPressed: () async {
                      await _saveMatrixToDatabase(ref);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Matrice de droits enregistrée et synchronisée en temps réel !',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Enregistrer la Matrice'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Class Selector Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Classe sélectionnée :',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedClass,
                      dropdownColor: AppTheme.primarySurface,
                      items:
                          [
                            'Classe de 3ème',
                            'Classe de 2nde',
                            'Classe de Terminale C',
                          ].map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (v) => setState(() => _selectedClass = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Interactive Matrix Table Grid
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppTheme.primaryDark,
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                'Fonctionnalité / Contenu',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ..._tierNames.map(
                              (tier) => DataColumn(
                                label: Text(
                                  tier,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: _features.map((feature) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    feature,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                ..._tierNames.map((tier) {
                                  final accessValue =
                                      _matrixState[tier]![feature] ??
                                      'Aucun accès';
                                  return DataCell(
                                    InkWell(
                                      onTap: () => _editCellAccess(
                                        context,
                                        tier,
                                        feature,
                                        accessValue,
                                      ),
                                      child: _buildAccessBadge(accessValue),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveMatrixToDatabase(WidgetRef ref) async {
    final service = ref.read(supabaseServiceProvider);
    for (final tierName in _tierNames) {
      final accessMap = _matrixState[tierName]!;
      await service.updateAccessEntries(tierName, accessMap);
    }
    ref.refresh(accessMatrixProvider(''));
  }

  Widget _buildAccessBadge(String value) {
    Color bg;
    Color fg;
    IconData icon;

    if (value.startsWith('Accès complet')) {
      bg = AppTheme.accentEmerald.withValues(alpha: 0.15);
      fg = AppTheme.accentEmerald;
      icon = Icons.check_circle_rounded;
    } else if (value.startsWith('Limité')) {
      bg = AppTheme.accentAmber.withValues(alpha: 0.15);
      fg = AppTheme.accentAmber;
      icon = Icons.tune_rounded;
    } else if (value == 'Affichées') {
      bg = AppTheme.accentRose.withValues(alpha: 0.15);
      fg = AppTheme.accentRose;
      icon = Icons.campaign_rounded;
    } else {
      bg = Colors.white.withValues(alpha: 0.05);
      fg = Colors.white38;
      icon = Icons.block_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  void _editCellAccess(
    BuildContext context,
    String tier,
    String feature,
    String currentValue,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Modifier l\'accès : $feature ($tier)',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Accès complet',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentEmerald,
              ),
              onTap: () {
                setState(() => _matrixState[tier]![feature] = 'Accès complet');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text(
                'Limité (avec paramètre de restriction)',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(
                Icons.tune_rounded,
                color: AppTheme.accentAmber,
              ),
              onTap: () {
                setState(
                  () => _matrixState[tier]![feature] = 'Limité (3 par jour)',
                );
                Navigator.pop(context);
              },
            ),
            if (feature == 'Publicités Interstitielles')
              ListTile(
                title: const Text(
                  'Affichées',
                  style: TextStyle(color: Colors.white),
                ),
                leading: const Icon(
                  Icons.campaign_rounded,
                  color: AppTheme.accentRose,
                ),
                onTap: () {
                  setState(() => _matrixState[tier]![feature] = 'Affichées');
                  Navigator.pop(context);
                },
              ),
            ListTile(
              title: const Text(
                'Aucun accès (Flouté dans l\'app élève)',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(
                Icons.block_rounded,
                color: AppTheme.accentRose,
              ),
              onTap: () {
                setState(() => _matrixState[tier]![feature] = 'Aucun accès');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
