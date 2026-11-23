import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// « Contrôle des programmes » : tout ce qui empêche un élève de voir un programme complet et
/// propre, calculé en base (vue `curriculum_anomalies`, migration 96) plutôt que deviné ici.
class CurriculumControlScreen extends ConsumerStatefulWidget {
  const CurriculumControlScreen({super.key});

  @override
  ConsumerState<CurriculumControlScreen> createState() => _CurriculumControlScreenState();
}

class _KindInfo {
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  const _KindInfo(this.label, this.hint, this.icon, this.color);
}

const _kinds = <String, _KindInfo>{
  'CHAPITRE_TEMPORAIRE': _KindInfo(
    'Chapitres de test',
    'Visibles des élèves : à retirer.',
    Icons.science_outlined,
    AppTheme.accentRose,
  ),
  'CHAPITRES_INVISIBLES': _KindInfo(
    'Chapitres invisibles',
    'Posés sur une classe pour une matière qu\'aucune de ses séries n\'étudie. Rattacher la matière '
        'à la bonne série (Arbre académique → Matières) ou déplacer les chapitres.',
    Icons.visibility_off_outlined,
    AppTheme.accentAmber,
  ),
  'NUMEROTATION_EN_DOUBLE': _KindInfo(
    'Programmes mélangés',
    'Deux chapitres portent le même numéro dans le même trimestre : souvent deux imports '
        'superposés. Garder une seule version (Leçons & Cours).',
    Icons.content_copy_outlined,
    AppTheme.accentAmber,
  ),
  'MATIERE_SANS_CHAPITRE': _KindInfo(
    'Matières vides',
    'L\'élève voit la matière mais aucun chapitre. À produire ou importer (Collecte des '
        'Programmes, Studio de cours).',
    Icons.menu_book_outlined,
    AppTheme.accentBlue,
  ),
  'NIVEAU_SANS_MATIERE': _KindInfo(
    'Niveaux sans matière',
    'Classe, série ou spécialité sans aucune matière. Ne rien inventer : attendre une source '
        'officielle, puis rattacher dans Arbre académique → Matières.',
    Icons.account_tree_outlined,
    AppTheme.textMuted,
  ),
};

class _CurriculumControlScreenState extends ConsumerState<CurriculumControlScreen> {
  String? _kind;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(curriculumAnomaliesProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _message(
          'Contrôle indisponible',
          'La migration 96 (couverture des programmes) n\'est peut-être pas encore appliquée.\n$e',
          retry: true,
        ),
        data: (items) => _build(items),
      ),
    );
  }

  Widget _message(String title, String body, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
              if (retry) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(curriculumAnomaliesProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _build(List<CurriculumAnomaly> all) {
    if (all.isEmpty) {
      return _message('Aucun problème détecté', 'Tous les niveaux ont des matières, et chaque matière a des chapitres visibles.');
    }
    final counts = <String, int>{};
    for (final a in all) {
      counts[a.kind] = (counts[a.kind] ?? 0) + 1;
    }
    final kind = _kind ?? _kinds.keys.firstWhere((k) => counts.containsKey(k), orElse: () => all.first.kind);
    final q = _query.toLowerCase();
    final shown = all
        .where((a) => a.kind == kind)
        .where((a) =>
            q.isEmpty ||
            (a.nodeLabel ?? '').toLowerCase().contains(q) ||
            (a.subjectName ?? '').toLowerCase().contains(q) ||
            a.detail.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => (a.nodeLabel ?? '').compareTo(b.nodeLabel ?? ''));
    final info = _kinds[kind];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text('Contrôle des programmes',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Ce que les élèves ne peuvent pas voir correctement, classe par classe.',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in _kinds.keys)
              if (counts.containsKey(k))
                ChoiceChip(
                  avatar: Icon(_kinds[k]!.icon, size: 16, color: _kinds[k]!.color),
                  label: Text('${_kinds[k]!.label} · ${counts[k]}'),
                  selected: k == kind,
                  onSelected: (_) => setState(() => _kind = k),
                ),
          ],
        ),
        if (info != null) ...[
          const SizedBox(height: 12),
          Text(info.hint, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Filtrer : Terminale D, Physique…',
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        for (final a in shown) _tile(a, info),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('Rien pour ce filtre.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
      ],
    );
  }

  Widget _tile(CurriculumAnomaly a, _KindInfo? info) {
    final title = [a.nodeLabel, a.subjectName].whereType<String>().join(' — ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        children: [
          Icon(info?.icon ?? Icons.info_outline, size: 18, color: info?.color ?? AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(a.detail, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (a.kind == 'CHAPITRE_TEMPORAIRE' && a.chapterId != null)
            TextButton(
              onPressed: () async {
                await ref.read(supabaseServiceProvider).deactivateChapter(a.chapterId!);
                ref.invalidate(curriculumAnomaliesProvider);
              },
              child: const Text('Retirer'),
            ),
        ],
      ),
    );
  }
}
