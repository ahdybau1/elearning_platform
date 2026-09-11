import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/tokens/elef_spacing.dart';

/// Collecte des programmes scolaires → Arbre Académique (demande #1/#2).
///
/// Page de **suivi des collectes** : chaque collecte recherche/crawle des sources officielles,
/// extrait la structure (classes, séries, matières) et les programmes annuels (chapitres) qui y
/// sont **explicitement** présents, puis propose ces éléments à la revue. Rien n'est écrit dans
/// l'arbre sans validation. Les éléments ambigus/incomplets portent le statut « À vérifier » ;
/// les programmes introuvables sont signalés, jamais inventés.
class CurriculumAutopilotScreen extends ConsumerWidget {
  const CurriculumAutopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importsAsync = ref.watch(curriculumImportsProvider);
    return Scaffold(
      backgroundColor: ElefColors.background,
      body: ListView(
        padding: ElefSpacing.paddingLg,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Collecte des Programmes', style: ElefTypography.displayMedium),
              const SizedBox(height: ElefSpacing.xs),
              Text(
                "Recherche → collecte → extraction → structuration → intégration réelle dans "
                "l'arbre académique. Revue humaine obligatoire. Aucun programme inventé.",
                style: ElefTypography.bodyMedium,
              ),
              const SizedBox(height: ElefSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _newCollectionDialog(context, ref),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Nouvelle collecte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ElefColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElefSpacing.lg),
          importsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _errorBox('Erreur : $e',
                () => ref.invalidate(curriculumImportsProvider)),
            data: (imports) {
              if (imports.isEmpty) {
                return _emptyBox(
                    "Aucune collecte lancée. Cliquez « Nouvelle collecte » et fournissez des URL "
                    "de programmes officiels (MINESEC, inspections de pédagogie, dépôts "
                    "d'établissements). Le cas Cameroun (secondaire général francophone) est "
                    "pré-câblé pour la structure de référence.");
              }
              return Column(
                children: imports
                    .map((imp) => _importCard(context, ref, imp))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _importCard(BuildContext context, WidgetRef ref, CurriculumImport imp) {
    final sc = _statusColor(imp.status);
    return Container(
      margin: const EdgeInsets.only(bottom: ElefSpacing.md),
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: ElefRadius.lg,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ImportDetailScreen(importId: imp.id))),
          child: Padding(
            padding: ElefSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(imp.scopeLabel,
                          style: ElefTypography.titleMedium),
                    ),
                    _pill(_statusLabel(imp.status), sc),
                  ],
                ),
                const SizedBox(height: ElefSpacing.xs),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(imp.createdAt.toLocal()),
                  style: ElefTypography.caption,
                ),
                const SizedBox(height: ElefSpacing.sm),
                Wrap(
                  spacing: ElefSpacing.sm,
                  runSpacing: ElefSpacing.xs,
                  children: [
                    _chip('${imp.proposed} éléments'),
                    _chip('${imp.summary['classes'] ?? 0} classes'),
                    _chip('${imp.summary['series'] ?? 0} séries'),
                    _chip('${imp.summary['subjects'] ?? 0} matières'),
                    _chip('${imp.chapters} chapitres'),
                    if (imp.matched > 0) _chip('${imp.matched} déjà présents'),
                    if (imp.ambiguous > 0)
                      _chip('${imp.ambiguous} à vérifier',
                          color: ElefColors.warning),
                  ],
                ),
                if (imp.gaps.isNotEmpty) ...[
                  const SizedBox(height: ElefSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.report_gmailerrorred_rounded,
                          size: 14, color: ElefColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${imp.gaps.length} lacune(s) signalée(s)',
                            style: ElefTypography.caption
                                .copyWith(color: ElefColors.warning)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newCollectionDialog(BuildContext context, WidgetRef ref) async {
    final urls = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String? scopeId;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, r, _) {
        final eduTypes = r.watch(nodesByTypeProvider('education_type'));
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            backgroundColor: ElefColors.surfaceCard,
            title: Text('Nouvelle collecte de programmes',
                style: ElefTypography.heading2),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Périmètre. Par défaut : Cameroun › Section Francophone › Enseignement "
                    "Général (3ème → Terminale, séries A/C/D).",
                    style: ElefTypography.bodySmall,
                  ),
                  const SizedBox(height: ElefSpacing.sm),
                  eduTypes.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e', style: ElefTypography.bodySmall),
                    data: (nodes) => DropdownButtonFormField<String?>(
                      initialValue: scopeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Enseignement (facultatif)',
                          border: OutlineInputBorder()),
                      dropdownColor: ElefColors.surfaceElevated,
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Défaut (Cameroun général francophone)')),
                        ...nodes.map((n) => DropdownMenuItem<String?>(
                            value: n.id, child: Text(n.name))),
                      ],
                      onChanged: (v) => setD(() => scopeId = v),
                    ),
                  ),
                  const SizedBox(height: ElefSpacing.md),
                  Text('URL des sources (une par ligne) — priorité aux sites officiels.',
                      style: ElefTypography.bodySmall),
                  const SizedBox(height: ElefSpacing.xs),
                  TextField(
                    controller: urls,
                    maxLines: 5,
                    style: ElefTypography.bodySmall
                        .copyWith(color: ElefColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText:
                          "https://minesec.gov.cm/\nhttps://…/programme-officiel-1ere-C.pdf",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lancer la collecte')),
            ],
          ),
        );
      }),
    );
    if (go != true) return;
    final seedUrls = urls.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.startsWith('http'))
        .toList();
    messenger.showSnackBar(const SnackBar(
        content: Text('Collecte en cours… (crawl + extraction + structuration)')));
    try {
      final res = await ref.read(supabaseServiceProvider).collectCurriculum(
            scopeNodeId: scopeId,
            seedUrls: seedUrls,
          );
      ref.invalidate(curriculumImportsProvider);
      if (res['error'] != null) {
        messenger.showSnackBar(SnackBar(content: Text('Échec : ${res['error']}')));
        return;
      }
      final s = (res['summary'] as Map?) ?? {};
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Collecte terminée : ${s['proposed'] ?? 0} éléments proposés, '
              '${(res['gaps'] as List?)?.length ?? 0} lacune(s). Ouvrez la collecte pour relire.')));
      if (res['import_id'] != null) {
        navigator.push(MaterialPageRoute(
            builder: (_) => _ImportDetailScreen(importId: res['import_id'] as String)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  static Color _statusColor(String s) => switch (s) {
        'applied' => ElefColors.success,
        'partially_applied' => ElefColors.primary,
        'proposed' => ElefColors.warning,
        'collecting' => ElefColors.info,
        'failed' => ElefColors.danger,
        'cancelled' => ElefColors.textMuted,
        _ => ElefColors.textMuted,
      };
  static String _statusLabel(String s) => switch (s) {
        'applied' => 'Appliqué',
        'partially_applied' => 'Partiellement appliqué',
        'proposed' => 'À relire',
        'collecting' => 'Collecte…',
        'failed' => 'Échec',
        'cancelled' => 'Annulé',
        _ => s,
      };
}

Widget _pill(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15), borderRadius: ElefRadius.xs),
      child: Text(t,
          style: ElefTypography.badge.copyWith(color: c)),
    );

Widget _chip(String t, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ElefColors.surfaceDark,
        borderRadius: ElefRadius.xs,
        border: Border.all(color: (color ?? ElefColors.borderSubtle)),
      ),
      child: Text(t,
          style: ElefTypography.caption
              .copyWith(color: color ?? ElefColors.textSecondary)),
    );

Widget _errorBox(String m, VoidCallback retry) => Container(
      padding: ElefSpacing.paddingLg,
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(m,
            style: ElefTypography.bodyMedium.copyWith(color: ElefColors.danger),
            textAlign: TextAlign.center),
        const SizedBox(height: ElefSpacing.sm),
        OutlinedButton(onPressed: retry, child: const Text('Réessayer')),
      ]),
    );

Widget _emptyBox(String m) => Container(
      padding: ElefSpacing.paddingLg,
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Text(m, style: ElefTypography.bodyMedium),
    );

// ════════════════════════ PAGE DÉTAIL D'UN IMPORT ════════════════════════

class _ImportDetailScreen extends ConsumerWidget {
  final String importId;
  const _ImportDetailScreen({required this.importId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imports = ref.watch(curriculumImportsProvider).valueOrNull ?? [];
    final imp = imports.where((i) => i.id == importId).firstOrNull;
    final itemsAsync = ref.watch(curriculumImportItemsProvider(importId));
    final svc = ref.read(supabaseServiceProvider);

    Future<void> act(String label, Future<Map<String, dynamic>> Function() f) async {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('$label…')));
      final res = await f();
      ref.invalidate(curriculumImportsProvider);
      ref.invalidate(curriculumImportItemsProvider(importId));
      ref.invalidate(academicTreeProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(res['error'] != null
            ? 'Échec : ${res['error']}'
            : (res['applied'] != null
                ? 'Appliqué : ${_fmtApplied(res['applied'] as Map)}'
                : (res['removed'] != null
                    ? 'Annulé : ${_fmtRemoved(res['removed'] as Map)}'
                    : 'Terminé.'))),
      ));
    }

    return Scaffold(
      backgroundColor: ElefColors.background,
      appBar: AppBar(
        backgroundColor: ElefColors.surfaceDark,
        title: Text(imp?.scopeLabel ?? 'Collecte', style: ElefTypography.heading3),
        leading: BackButton(color: ElefColors.textPrimary),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorBox('Erreur : $e',
            () => ref.invalidate(curriculumImportItemsProvider(importId))),
        data: (items) {
          final byKind = <String, List<CurriculumImportItem>>{};
          for (final it in items) {
            byKind.putIfAbsent(it.itemKind, () => []).add(it);
          }
          const order = ['class', 'series', 'subject', 'chapter'];
          const label = {
            'class': 'Classes',
            'series': 'Séries',
            'subject': 'Matières',
            'chapter': 'Chapitres (programmes)'
          };
          return ListView(
            padding: ElefSpacing.paddingLg,
            children: [
              if (imp != null) ...[
                _sourcesBlock(imp),
                const SizedBox(height: ElefSpacing.md),
                if (imp.gaps.isNotEmpty) _gapsBlock(imp),
                const SizedBox(height: ElefSpacing.md),
              ],
              for (final k in order)
                if (byKind[k]?.isNotEmpty ?? false) ...[
                  Text('${label[k]} · ${byKind[k]!.length}',
                      style: ElefTypography.heading3),
                  const SizedBox(height: ElefSpacing.xs),
                  ...byKind[k]!.map((it) => _itemRow(context, svc, ref, it)),
                  const SizedBox(height: ElefSpacing.md),
                ],
              if (items.isEmpty)
                _emptyBox("Aucun élément proposé — la collecte n'a rien pu extraire."),
            ],
          );
        },
      ),
      bottomNavigationBar: (imp == null || imp.status == 'cancelled')
          ? null
          : SafeArea(
              child: Container(
                padding: ElefSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: ElefColors.surfaceDark,
                  border: Border(top: BorderSide(color: ElefColors.borderSubtle)),
                ),
                child: Wrap(
                  spacing: ElefSpacing.sm,
                  runSpacing: ElefSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => act('Annulation de l\'import',
                          () => svc.cancelCurriculumImport(importId)),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Annuler l\'import'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: ElefColors.danger),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => act('Application des éléments vérifiés',
                          () => svc.applyCurriculumImport(importId,
                              mode: 'verified_only')),
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: const Text('Appliquer les vérifiés'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => act('Application dans l\'arbre',
                          () => svc.applyCurriculumImport(importId, mode: 'all')),
                      icon: const Icon(Icons.account_tree_rounded, size: 16),
                      label: const Text('Appliquer tout'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ElefColors.primary,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sourcesBlock(CurriculumImport imp) => Container(
        padding: ElefSpacing.paddingMd,
        decoration: BoxDecoration(
          color: ElefColors.surfaceCard,
          borderRadius: ElefRadius.lg,
          border: Border.all(color: ElefColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sources réellement consultées', style: ElefTypography.titleSmall),
            const SizedBox(height: ElefSpacing.xs),
            if (imp.sourcesConsulted.isEmpty)
              Text('Aucune source web fournie — seule la structure de référence a été proposée.',
                  style: ElefTypography.bodySmall)
            else
              ...imp.sourcesConsulted.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                            s['ok'] == true
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 14,
                            color: s['ok'] == true
                                ? ElefColors.success
                                : ElefColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s['url']}  ·  HTTP ${s['http_status'] ?? '—'}'
                            '${s['year'] != null ? "  ·  version ${s['year']}" : ""}'
                            '${s['provider'] != null ? "  ·  ${s['provider']}" : ""}',
                            style: ElefTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      );

  Widget _gapsBlock(CurriculumImport imp) => Container(
        padding: ElefSpacing.paddingMd,
        decoration: BoxDecoration(
          color: ElefColors.warningBg,
          borderRadius: ElefRadius.lg,
          border: Border.all(color: ElefColors.warningBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lacunes signalées (programmes introuvables / incomplets / ambigus)',
                style: ElefTypography.titleSmall
                    .copyWith(color: ElefColors.warning)),
            const SizedBox(height: ElefSpacing.xs),
            ...imp.gaps.map((g) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('•  $g',
                      style: ElefTypography.bodySmall
                          .copyWith(color: ElefColors.textSecondary)),
                )),
          ],
        ),
      );

  Widget _itemRow(BuildContext context, dynamic svc, WidgetRef ref,
      CurriculumImportItem it) {
    final vsColor = switch (it.verificationStatus) {
      'ambiguous' => ElefColors.warning,
      'incomplete' => ElefColors.warning,
      _ => ElefColors.success,
    };
    final applied = it.status == 'applied';
    final rejected = it.status == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: ElefSpacing.xs),
      padding: ElefSpacing.paddingSm,
      decoration: BoxDecoration(
        color: ElefColors.surfaceDark,
        borderRadius: ElefRadius.md,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.proposedName,
                  style: ElefTypography.bodyMedium.copyWith(
                    color: rejected
                        ? ElefColors.textMuted
                        : ElefColors.textPrimary,
                    decoration:
                        rejected ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (it.verificationStatus != 'ok')
                _pill('À VÉRIFIER', vsColor),
              const SizedBox(width: 6),
              if (it.hasMatch) _pill('DÉJÀ PRÉSENT', ElefColors.info),
              if (applied) ...[
                const SizedBox(width: 6),
                _pill('APPLIQUÉ', ElefColors.success),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(it.parentPath, style: ElefTypography.caption),
          if ((it.sourceExcerpt ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              '« ${it.sourceExcerpt} »'
              '${it.sourceUrl != null ? "  — ${it.sourceUrl}" : ""}'
              '${it.sourceYear != null ? " (${it.sourceYear})" : ""}',
              style: ElefTypography.caption
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (!applied && !rejected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: ElefSpacing.sm,
                children: [
                  if (it.status != 'verified')
                    TextButton.icon(
                      onPressed: () async {
                        await svc.setCurriculumItemStatus(it.id, 'verified');
                        ref.invalidate(curriculumImportItemsProvider(importId));
                      },
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Vérifier'),
                      style: TextButton.styleFrom(
                          foregroundColor: ElefColors.success),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      await svc.setCurriculumItemStatus(it.id, 'rejected');
                      ref.invalidate(curriculumImportItemsProvider(importId));
                    },
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Rejeter'),
                    style: TextButton.styleFrom(
                        foregroundColor: ElefColors.danger),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtApplied(Map a) =>
      '${a['classes']} classe(s), ${a['series']} série(s), ${a['subjects']} matière(s), '
      '${a['links']} lien(s), ${a['chapters']} chapitre(s)'
      '${(a['errors'] as List?)?.isNotEmpty == true ? " — ${(a['errors'] as List).length} erreur(s)" : ""}';
  static String _fmtRemoved(Map r) =>
      '${r['classes']} classe(s), ${r['series']} série(s), ${r['subjects']} matière(s), '
      '${r['chapters']} chapitre(s), ${r['subjectLinks']} lien(s) retiré(s)';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
