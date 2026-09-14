import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/ingestion_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// WP3 — Centre Sources & Ingestion (consigne #6).
///
/// Gère les sources documentaires (texte collé, URL), les jobs de collecte/extraction/
/// classement/indexation en arrière-plan (progression, annulation, reprise, historique
/// d'erreurs) et la revue humaine des extraits avant intégration au RAG.
///
/// Limites honnêtes affichées : profondeur de collecte 0 (page unique) ; OCR d'images/PDF
/// scannés indisponible (aucun moteur vision auto-hébergé à coût zéro).
class IngestionCenterScreen extends ConsumerStatefulWidget {
  const IngestionCenterScreen({super.key});

  @override
  ConsumerState<IngestionCenterScreen> createState() =>
      _IngestionCenterScreenState();
}

enum _Tab { sources, jobs, extracts }

class _IngestionCenterScreenState extends ConsumerState<IngestionCenterScreen> {
  _Tab _tab = _Tab.sources;
  bool _workerBusy = false;

  Future<void> _runWorker() async {
    setState(() => _workerBusy = true);
    try {
      final res =
          await ref.read(supabaseServiceProvider).runIngestionWorker();
      if (!mounted) return;
      ref.invalidate(ingestionJobsProvider);
      ref.invalidate(extractedDocsProvider);
      ref.invalidate(ingestionSourcesProvider);
      final n = res['processed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['error'] != null
              ? 'Worker : ${res['error']}'
              : '$n job(s) traité(s).')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _workerBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Centre Sources & Ingestion',
                        style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      'Collecte (URL / texte), extraction, déduplication, classement pédagogique, '
                      'revue humaine puis indexation RAG. Traitement en arrière-plan, non bloquant.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _workerBusy ? null : _runWorker,
                icon: _workerBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text(_workerBusy ? 'Traitement…' : 'Traiter la file'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<_Tab>(
            segments: const [
              ButtonSegment(
                  value: _Tab.sources,
                  icon: Icon(Icons.source_rounded, size: 16),
                  label: Text('Sources')),
              ButtonSegment(
                  value: _Tab.jobs,
                  icon: Icon(Icons.dynamic_feed_rounded, size: 16),
                  label: Text('Jobs')),
              ButtonSegment(
                  value: _Tab.extracts,
                  icon: Icon(Icons.rate_review_rounded, size: 16),
                  label: Text('Extraits à relire')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 14),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case _Tab.sources:
        return _SourcesTab(onChanged: _invalidateAll);
      case _Tab.jobs:
        return _JobsTab(onChanged: _invalidateAll);
      case _Tab.extracts:
        return _ExtractsTab(onChanged: _invalidateAll);
    }
  }

  void _invalidateAll() {
    ref.invalidate(ingestionSourcesProvider);
    ref.invalidate(ingestionJobsProvider);
    ref.invalidate(extractedDocsProvider);
  }
}

Widget _err(String m, VoidCallback retry) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(m,
            style: GoogleFonts.inter(color: AppTheme.accentRose),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: retry, child: const Text('Réessayer')),
      ]),
    );

Widget _pill(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.bold, color: c)),
    );

const _jobColors = <String, Color>{
  'done': AppTheme.accentEmerald,
  'running': AppTheme.accentCyan,
  'queued': AppTheme.textMuted,
  'paused': AppTheme.accentAmber,
  'failed': AppTheme.accentRose,
  'cancelled': AppTheme.textMuted,
};

// ══════════════════════════════ SOURCES ══════════════════════════════

class _SourcesTab extends ConsumerWidget {
  final VoidCallback onChanged;
  const _SourcesTab({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingestionSourcesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _showSourceDialog(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nouvelle source'),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                _err('Erreur : $e', () => ref.invalidate(ingestionSourcesProvider)),
            data: (sources) {
              if (sources.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune source. Créez-en une (URL ou texte collé) pour lancer une collecte.',
                    style: GoogleFonts.inter(color: AppTheme.textMuted),
                  ),
                );
              }
              return ListView.separated(
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _sourceCard(context, ref, sources[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sourceCard(BuildContext context, WidgetRef ref, AiSource s) {
    final svc = ref.read(supabaseServiceProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(s.sourceType.toUpperCase(), AppTheme.accentIndigo),
              _pill(s.status.toUpperCase(),
                  s.status == 'active' ? AppTheme.accentEmerald : AppTheme.textMuted),
              if (s.validated) _pill('INDEXÉ RAG', AppTheme.accentEmerald),
              if (!s.accessTermsAck && s.sourceType == 'url')
                _pill('CGU NON ATTESTÉES', AppTheme.accentRose),
              Text(s.title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          if (s.sourceUrl != null)
            Text(s.sourceUrl!,
                style: GoogleFonts.firaCode(
                    fontSize: 11, color: AppTheme.accentCyan)),
          if (s.collectedAt != null)
            Text(
                'Dernière collecte : ${DateFormat('dd/MM/yyyy HH:mm').format(s.collectedAt!.toLocal())}',
                style:
                    GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _actionBtn('Collecter / Extraire', Icons.download_rounded, () async {
                final messenger = ScaffoldMessenger.of(context);
                await svc.enqueueIngestionJob(
                    s.id, s.sourceType == 'url' ? 'crawl' : 'extract');
                onChanged();
                messenger.showSnackBar(const SnackBar(
                    content: Text('Job de collecte mis en file.')));
              }),
              _actionBtn('Classer', Icons.category_rounded, () async {
                final messenger = ScaffoldMessenger.of(context);
                await svc.enqueueIngestionJob(s.id, 'classify');
                onChanged();
                messenger.showSnackBar(const SnackBar(
                    content: Text('Job de classement mis en file.')));
              }),
              _actionBtn(
                  s.status == 'archived' ? 'Réactiver' : 'Archiver',
                  s.status == 'archived'
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded, () async {
                await svc.updateIngestionSource(s.id,
                    status: s.status == 'archived' ? 'active' : 'archived');
                onChanged();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.accentCyan,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      );

  Future<void> _showSourceDialog(BuildContext context, WidgetRef ref) async {
    String type = 'url';
    final title = TextEditingController();
    final url = TextEditingController();
    final text = TextEditingController();
    final provenance = TextEditingController();
    final depth = TextEditingController(text: '0');
    bool ack = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: Text('Nouvelle source',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'url', label: Text('URL')),
                      ButtonSegment(
                          value: 'manual_upload', label: Text('Texte collé')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setD(() => type = s.first),
                  ),
                  const SizedBox(height: 10),
                  _f(title, 'Titre de la source'),
                  if (type == 'url') ...[
                    _f(url, 'URL (https://…)'),
                    _f(depth, 'Profondeur de collecte (0 = page unique)'),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Profondeur > 0 non disponible dans cette itération. '
                        'OCR d\'images/PDF scannés indisponible.',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.accentAmber),
                      ),
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ack,
                      onChanged: (v) => setD(() => ack = v ?? false),
                      title: Text(
                        'J\'atteste avoir vérifié robots.txt et les conditions '
                        'd\'utilisation de cette source.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ] else
                    _f(text, 'Texte à ingérer', lines: 6),
                  _f(provenance, 'Provenance (facultatif)'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  if (type == 'url' &&
                      (!url.text.startsWith('http') || !ack)) {
                    return;
                  }
                  if (type == 'manual_upload' && text.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final svc = ref.read(supabaseServiceProvider);
      await svc.createIngestionSource(
        title: title.text.trim(),
        sourceType: type,
        sourceUrl: type == 'url' ? url.text.trim() : null,
        rawText: type == 'manual_upload' ? text.text : null,
        crawlRules: type == 'url'
            ? {'max_depth': int.tryParse(depth.text) ?? 0, 'max_pages': 1}
            : null,
        accessTermsAck: type == 'url' ? ack : true,
        provenance:
            provenance.text.trim().isEmpty ? null : provenance.text.trim(),
      );
      onChanged();
    }
  }

  Widget _f(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          maxLines: lines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.primaryDark,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
      );
}

// ══════════════════════════════ JOBS ══════════════════════════════

class _JobsTab extends ConsumerWidget {
  final VoidCallback onChanged;
  const _JobsTab({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingestionJobsProvider(null));
    final svc = ref.read(supabaseServiceProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _err('Erreur : $e', () => ref.invalidate(ingestionJobsProvider)),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Center(
              child: Text('Aucun job. Lancez une collecte depuis « Sources ».',
                  style: GoogleFonts.inter(color: AppTheme.textMuted)));
        }
        return ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final j = jobs[i];
            final color = _jobColors[j.status] ?? AppTheme.textMuted;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _pill(j.jobType.toUpperCase(), AppTheme.accentIndigo),
                      const SizedBox(width: 6),
                      _pill(j.status.toUpperCase(), color),
                      const Spacer(),
                      Text(
                          '${DateFormat('dd/MM HH:mm').format(j.createdAt.toLocal())} · essai ${j.attempts}/${j.maxAttempts}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: j.progressPct / 100,
                      minHeight: 5,
                      backgroundColor: AppTheme.primaryDark,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  if (j.result.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(jsonEncode(j.result),
                        style: GoogleFonts.firaCode(
                            fontSize: 10, color: Colors.white54)),
                  ],
                  if (j.errorHistory.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...j.errorHistory.take(3).map((e) => Text(
                        '⚠ ${e['message']}',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.accentRose))),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!j.isTerminal && j.status != 'cancelled')
                        TextButton.icon(
                          onPressed: () async {
                            await svc.cancelIngestionJob(j.id);
                            onChanged();
                          },
                          icon: const Icon(Icons.cancel_rounded, size: 14),
                          label: const Text('Annuler'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textMuted),
                        ),
                      if (j.status == 'failed')
                        TextButton.icon(
                          onPressed: () async {
                            await svc.retryIngestionJob(j.id);
                            onChanged();
                          },
                          icon: const Icon(Icons.replay_rounded, size: 14),
                          label: const Text('Relancer'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentAmber),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════ EXTRAITS ══════════════════════════════

class _ExtractsTab extends ConsumerWidget {
  final VoidCallback onChanged;
  const _ExtractsTab({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(extractedDocsProvider('preview'));
    final svc = ref.read(supabaseServiceProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _err('Erreur : $e', () => ref.invalidate(extractedDocsProvider)),
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
              child: Text(
                  'Aucun extrait en attente de revue. Lancez une collecte puis « Traiter la file ».',
                  style: GoogleFonts.inter(color: AppTheme.textMuted)));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final chapters =
                (d.classification['chapter_candidates'] as List?) ?? const [];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(d.title ?? 'Extrait',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      if (d.isDuplicate) _pill('DOUBLON', AppTheme.accentAmber),
                      const SizedBox(width: 6),
                      Text('${d.wordCount} mots',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                  if (d.metadata['url'] != null)
                    Text(d.metadata['url'].toString(),
                        style: GoogleFonts.firaCode(
                            fontSize: 10, color: AppTheme.accentCyan)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryDark,
                        borderRadius: BorderRadius.circular(6)),
                    child: SingleChildScrollView(
                      child: Text(d.extractedText,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chapters.isEmpty
                        ? 'Classement : aucun chapitre candidat (revue humaine requise).'
                        : 'Classement proposé : ${chapters.map((c) => (c as Map)['title']).join(", ")}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.accentIndigo),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await svc.reviewExtractedDoc(d.id,
                              approve: true, sourceId: d.sourceId);
                          onChanged();
                        },
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: const Text('Valider → indexer RAG'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final reason = await _ask(context, 'Motif du rejet');
                          if (reason == null) return;
                          await svc.reviewExtractedDoc(d.id,
                              approve: false, rejectionReason: reason);
                          onChanged();
                        },
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: const Text('Rejeter'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentRose),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _ask(BuildContext context, String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(title,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
        content: TextField(
            controller: c,
            autofocus: true,
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Confirmer')),
        ],
      ),
    );
  }
}
