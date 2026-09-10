import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// ADM-AI-001/002 (docs/CAHIER_TECHNIQUE_ADMIN_AI_CONTROL_PLANE.md ; docs/CAHIER_DES_CHARGES_AGENTS_IA.md §9)
/// + consigne #4 « centraliser la gestion de tous les agents IA prévus ».
///
/// Control-plane IA : registre **éditable** (activation, prompt/versions, outils, sources, limites,
/// dépendances, validation humaine, repli), **console de test** (entrée → sortie structurée + vérif
/// de schéma), **historique des exécutions** (`ai_agent_runs`) et **suivi de workflows multi-agents**
/// (`ai_workflows`). Runtime = Edge Functions Supabase (coût zéro) : les agents `gateway_native`
/// sont catalogués mais signalés « hors ligne (non déployé) », jamais masqués.
class AiAgentRegistryScreen extends ConsumerStatefulWidget {
  const AiAgentRegistryScreen({super.key});

  @override
  ConsumerState<AiAgentRegistryScreen> createState() =>
      _AiAgentRegistryScreenState();
}

enum _CpView { agents, history, workflows }

class _AiAgentRegistryScreenState extends ConsumerState<AiAgentRegistryScreen> {
  _CpView _view = _CpView.agents;
  String _search = '';
  String _runtimeFilter = 'tous'; // tous | en_ligne | hors_ligne | brouillon
  String? _historyAgentFilter; // null = tous

  static const _statusColors = <String, Color>{
    'active': AppTheme.accentEmerald,
    'draft': AppTheme.accentAmber,
    'deprecated': AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Control-Plane IA',
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Pilotage réel des agents : activation, prompts & versions, outils, sources, limites, '
            'dépendances, validation humaine, repli. Console de test, historique d\'exécutions et '
            'workflows multi-agents. Exécution : Edge Functions Supabase (coût zéro).',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_CpView>(
            segments: const [
              ButtonSegment(
                  value: _CpView.agents,
                  icon: Icon(Icons.hub_rounded, size: 16),
                  label: Text('Agents')),
              ButtonSegment(
                  value: _CpView.history,
                  icon: Icon(Icons.history_rounded, size: 16),
                  label: Text('Historique')),
              ButtonSegment(
                  value: _CpView.workflows,
                  icon: Icon(Icons.account_tree_rounded, size: 16),
                  label: Text('Workflows')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case _CpView.agents:
        return _buildAgentsView();
      case _CpView.history:
        return _buildHistoryView();
      case _CpView.workflows:
        return _buildWorkflowsView();
    }
  }

  // ─────────────────────────────── AGENTS ───────────────────────────────

  Widget _buildAgentsView() {
    final agentsAsync = ref.watch(aiAgentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Rechercher un agent…',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primaryDark,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            ...[
              ('tous', 'Tous'),
              ('en_ligne', 'En ligne'),
              ('hors_ligne', 'Hors ligne'),
              ('brouillon', 'Brouillon'),
            ].map((f) => ChoiceChip(
                  label: Text(f.$2),
                  labelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _runtimeFilter == f.$1
                          ? Colors.white
                          : AppTheme.textMuted),
                  selected: _runtimeFilter == f.$1,
                  showCheckmark: false,
                  selectedColor: AppTheme.accentCyan,
                  backgroundColor: AppTheme.primarySurface,
                  onSelected: (_) => setState(() => _runtimeFilter = f.$1),
                )),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: agentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox('Erreur de chargement du registre : $e',
                () => ref.invalidate(aiAgentsProvider)),
            data: (agents) {
              final filtered = agents.where((a) {
                if (_search.isNotEmpty &&
                    !a.name.toLowerCase().contains(_search) &&
                    !a.agentId.toLowerCase().contains(_search) &&
                    !a.mission.toLowerCase().contains(_search)) {
                  return false;
                }
                switch (_runtimeFilter) {
                  case 'en_ligne':
                    return a.isOnline;
                  case 'hors_ligne':
                    return !a.isOnline && a.runtime != 'none';
                  case 'brouillon':
                    return a.runtime == 'none' || a.status == 'draft';
                  default:
                    return true;
                }
              }).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Aucun agent ne correspond au filtre.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted)),
                );
              }
              final online = agents.where((a) => a.isOnline).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${agents.length} agents catalogués · $online exécutables en ligne · '
                    '${agents.length - online} hors ligne / brouillon',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _AgentControlCard(
                        agent: filtered[i],
                        statusColors: _statusColors,
                        onChanged: () => ref.invalidate(aiAgentsProvider),
                        onOpenHistory: (key) => setState(() {
                          _historyAgentFilter = key;
                          _view = _CpView.history;
                        }),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── HISTORIQUE ───────────────────────────────

  Widget _buildHistoryView() {
    final runsAsync = ref.watch(aiAgentRunsProvider(_historyAgentFilter));
    final agentsAsync = ref.watch(aiAgentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String?>(
              value: _historyAgentFilter,
              dropdownColor: AppTheme.primarySurface,
              hint: Text('Tous les agents',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted)),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
              underline: const SizedBox(),
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text('Tous les agents')),
                ...(agentsAsync.valueOrNull ?? [])
                    .map((a) => DropdownMenuItem<String?>(
                        value: a.agentId,
                        child: Text('${a.agentId} — ${a.name}'))),
              ],
              onChanged: (v) => setState(() => _historyAgentFilter = v),
            ),
            TextButton.icon(
              onPressed: () => ref.invalidate(aiAgentRunsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Rafraîchir'),
            ),
            runsAsync.maybeWhen(
              data: (runs) => TextButton.icon(
                onPressed: runs.isEmpty ? null : () => _exportRunsCsv(runs),
                icon: const Icon(Icons.file_download_rounded, size: 15),
                label: const Text('Exporter CSV (presse-papiers)'),
              ),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: runsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox('Erreur : $e',
                () => ref.invalidate(aiAgentRunsProvider)),
            data: (runs) {
              if (runs.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune exécution enregistrée${_historyAgentFilter != null ? ' pour cet agent' : ''}.\n'
                    'Lancez un test depuis l\'onglet « Agents » ou un workflow.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textMuted),
                  ),
                );
              }
              return ListView.separated(
                itemCount: runs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _RunTile(run: runs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _exportRunsCsv(List<AiAgentRun> runs) {
    final buf = StringBuffer(
        'agent_key;trigger;status;output_valid;duration_ms;tokens;created_at;error\n');
    for (final r in runs) {
      buf.writeln([
        r.agentKey,
        r.trigger,
        r.status,
        r.outputValid ?? '',
        r.durationMs ?? '',
        r.tokensUsed,
        r.createdAt.toIso8601String(),
        (r.errorMessage ?? '').replaceAll('\n', ' ').replaceAll(';', ','),
      ].join(';'));
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${runs.length} exécutions copiées au format CSV.')));
  }

  // ─────────────────────────────── WORKFLOWS ───────────────────────────────

  Widget _buildWorkflowsView() {
    final wfAsync = ref.watch(aiWorkflowsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chaînes d\'agents (import → structuration → mapping → validation…). '
                'Progression, étapes, erreurs et reprise après échec.',
                style:
                    GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _launchDemoWorkflow,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Lancer une démonstration'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: wfAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox(
                'Erreur : $e', () => ref.invalidate(aiWorkflowsProvider)),
            data: (workflows) {
              if (workflows.isEmpty) {
                return Center(
                  child: Text(
                    'Aucun workflow exécuté.\nCliquez « Lancer une démonstration » pour '
                    'enchaîner Rattachement curriculaire → Pré-contrôle pédagogique.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textMuted),
                  ),
                );
              }
              return ListView.separated(
                itemCount: workflows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _WorkflowCard(
                  workflow: workflows[i],
                  onResumed: () => ref.invalidate(aiWorkflowsProvider),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _launchDemoWorkflow() async {
    final service = ref.read(supabaseServiceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow de démonstration lancé…')));
    try {
      final res = await service.startAiWorkflow(
        workflowKey: 'demo_pipeline',
        title: 'Démo : rattachement curriculaire → contre-analyse',
        context: {
          'text':
              'Suites numériques : raison de récurrence, convergence, limites, '
                  'suites arithmétiques et géométriques.'
        },
        steps: const [
          {'agent_key': 'AIA-AGT-017', 'title': 'Rattachement curriculaire'},
          {'agent_key': 'AIA-AGT-017', 'title': 'Contre-analyse curriculaire'},
        ],
      );
      if (!mounted) return;
      ref.invalidate(aiWorkflowsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['error'] != null
            ? 'Échec : ${res['error']}'
            : 'Workflow ${res['status']} (${res['completed_steps']}/${res['total_steps']} étapes).'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Widget _errorBox(String msg, VoidCallback retry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg,
                style: GoogleFonts.inter(color: AppTheme.accentRose),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: retry, child: const Text('Réessayer')),
          ],
        ),
      );
}

// ══════════════════════════════ AGENT CARD ══════════════════════════════

class _AgentControlCard extends ConsumerStatefulWidget {
  final AiAgent agent;
  final Map<String, Color> statusColors;
  final VoidCallback onChanged;
  final void Function(String agentKey) onOpenHistory;

  const _AgentControlCard({
    required this.agent,
    required this.statusColors,
    required this.onChanged,
    required this.onOpenHistory,
  });

  @override
  ConsumerState<_AgentControlCard> createState() => _AgentControlCardState();
}

class _AgentControlCardState extends ConsumerState<_AgentControlCard> {
  bool _expanded = false;
  bool _busy = false;
  final _testInput = TextEditingController();
  Map<String, dynamic>? _testResult;
  bool _testing = false;

  @override
  void dispose() {
    _testInput.dispose();
    super.dispose();
  }

  AiAgent get agent => widget.agent;
  AiAgentVersion? get version =>
      agent.versions.isNotEmpty ? agent.versions.first : null;

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .updateAiAgentConfig(agent.id, enabled: value);
      widget.onChanged();
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleHitl(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .updateAiAgentConfig(agent.id, requiresHumanReview: value);
      widget.onChanged();
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTest() async {
    final v = version;
    if (v == null) return;
    Map<String, dynamic> parsed;
    try {
      parsed = _testInput.text.trim().isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(_testInput.text) as Map);
    } catch (_) {
      _snack('Entrée JSON invalide.');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final res = await ref
          .read(supabaseServiceProvider)
          .invokeAiAgent(agent.agentId, parsed);
      setState(() => _testResult = res);
      ref.invalidate(aiAgentRunsProvider);
    } catch (e) {
      setState(() => _testResult = {'error': '$e'});
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final v = version;
    final statusColor =
        widget.statusColors[agent.status] ?? AppTheme.textMuted;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryDark,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(agent.agentId,
                                  style: GoogleFonts.firaCode(
                                      fontSize: 11,
                                      color: AppTheme.accentCyan)),
                            ),
                            Text(agent.name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            _pill(agent.status, statusColor),
                            agent.isOnline
                                ? _pill('EN LIGNE', AppTheme.accentEmerald)
                                : _pill('HORS LIGNE', AppTheme.accentRose),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(agent.mission,
                            maxLines: _expanded ? 6 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      _busy
                          ? const SizedBox(
                              width: 32,
                              height: 20,
                              child: Center(
                                  child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))))
                          : Switch(
                              value: agent.enabled,
                              activeThumbColor: AppTheme.accentEmerald,
                              onChanged: _toggleEnabled,
                            ),
                      Text('Actif',
                          style: GoogleFonts.inter(
                              fontSize: 9, color: AppTheme.textMuted)),
                    ],
                  ),
                  Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (_expanded && v != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppTheme.primaryBorder, height: 1),
                  const SizedBox(height: 12),
                  if (!agent.isOnline)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppTheme.accentRose.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppTheme.accentRose.withValues(alpha: 0.4))),
                      child: Text('Non exécutable : ${agent.offlineReason}.',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.accentRose)),
                    ),
                  _kv('Runtime',
                      '${agent.runtime} · ${v.edgeFunctionName ?? "—"} · v${v.version} (${v.status})'),
                  if (agent.nonMission != null)
                    _kv('Non-mission', agent.nonMission!),
                  if (agent.catalogueRelation != null)
                    _kv('Catalogue (§7)', agent.catalogueRelation!),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: agent.requiresHumanReview,
                    activeThumbColor: AppTheme.accentAmber,
                    title: Text('Validation humaine requise avant usage',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white)),
                    onChanged: _busy ? null : _toggleHitl,
                  ),
                  const SizedBox(height: 4),
                  _configChips('Outils autorisés', v.allowedTools,
                      (list) => _saveVersion(allowedTools: list)),
                  _configChips('Sources autorisées', v.allowedSources,
                      (list) => _saveVersion(allowedSources: list)),
                  _limitsRow(v),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _editPromptDialog(v),
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: Text(v.promptTemplate == null
                            ? 'Définir le prompt'
                            : 'Modifier le prompt'),
                      ),
                      _versionStatusDropdown(v),
                      TextButton.icon(
                        onPressed: () =>
                            widget.onOpenHistory(agent.agentId),
                        icon: const Icon(Icons.history_rounded, size: 15),
                        label: const Text('Historique de cet agent'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _collapsibleJson('Schéma d\'entrée', v.inputSchema),
                  _collapsibleJson('Schéma de sortie', v.outputSchema),
                  const SizedBox(height: 12),
                  _testConsole(v),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveVersion({
    List<String>? allowedTools,
    List<String>? allowedSources,
    Map<String, dynamic>? limits,
    String? status,
    String? promptTemplate,
    String? promptNotes,
  }) async {
    try {
      await ref.read(supabaseServiceProvider).updateAiAgentVersion(
            version!.id,
            allowedTools: allowedTools,
            allowedSources: allowedSources,
            limits: limits,
            status: status,
            promptTemplate: promptTemplate,
            promptNotes: promptNotes,
          );
      widget.onChanged();
      _snack('Configuration enregistrée.');
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Widget _configChips(
      String label, List<String> values, void Function(List<String>) onSave) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentIndigo)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...values.map((val) => Chip(
                    label: Text(val,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white70)),
                    backgroundColor: AppTheme.primaryDark,
                    deleteIconColor: AppTheme.textMuted,
                    onDeleted: () =>
                        onSave(values.where((e) => e != val).toList()),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Ajouter'),
                labelStyle: GoogleFonts.inter(fontSize: 11),
                backgroundColor: AppTheme.primaryDark,
                onPressed: () async {
                  final v = await _promptText('Ajouter à « $label »');
                  if (v != null && v.trim().isNotEmpty) {
                    onSave([...values, v.trim()]);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limitsRow(AiAgentVersion v) {
    final l = v.limits;
    String cur(String k) => l[k]?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Limites',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentIndigo)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _limitField('max_tokens', cur('max_tokens'), v),
              _limitField('timeout_ms', cur('timeout_ms'), v),
              _limitField('max_concurrency', cur('max_concurrency'), v),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limitField(String key, String value, AiAgentVersion v) {
    return SizedBox(
      width: 150,
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          labelText: key,
          labelStyle:
              GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
          filled: true,
          fillColor: AppTheme.primaryDark,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none),
        ),
        onFieldSubmitted: (val) {
          final newLimits = Map<String, dynamic>.from(v.limits);
          final n = int.tryParse(val);
          if (n == null) {
            newLimits.remove(key);
          } else {
            newLimits[key] = n;
          }
          _saveVersion(limits: newLimits);
        },
      ),
    );
  }

  Widget _versionStatusDropdown(AiAgentVersion v) {
    return DropdownButton<String>(
      value: v.status,
      dropdownColor: AppTheme.primarySurface,
      style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
      underline: const SizedBox(),
      items: const ['draft', 'candidate', 'production', 'retired']
          .map((s) => DropdownMenuItem(value: s, child: Text('Version : $s')))
          .toList(),
      onChanged: (s) {
        if (s != null && s != v.status) _saveVersion(status: s);
      },
    );
  }

  Future<void> _editPromptDialog(AiAgentVersion v) async {
    final ctrl = TextEditingController(text: v.promptTemplate ?? '');
    final notesCtrl = TextEditingController(text: v.promptNotes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text('Prompt — ${agent.name} (v${v.version})',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 12,
                style: GoogleFonts.firaCode(
                    fontSize: 12, color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Instructions système de l\'agent…',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'Note de version (changelog)',
                    border: OutlineInputBorder()),
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
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (saved == true) {
      await _saveVersion(
          promptTemplate: ctrl.text, promptNotes: notesCtrl.text);
    }
  }

  Future<String?> _promptText(String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(title,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Ajouter')),
        ],
      ),
    );
  }

  Widget _testConsole(AiAgentVersion v) {
    final result = _testResult;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded,
                  size: 15, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              Text('Console de test',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testInput,
            maxLines: 4,
            style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Entrée JSON, ex : '
                  '${_exampleInput(v.inputSchema)}',
              hintStyle: GoogleFonts.firaCode(
                  fontSize: 11, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.primarySurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed:
                    (!agent.isOnline || _testing) ? null : _runTest,
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(_testing ? 'Exécution…' : 'Exécuter'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan),
              ),
              const SizedBox(width: 8),
              if (!agent.isOnline)
                Expanded(
                  child: Text('Indisponible : ${agent.offlineReason}.',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppTheme.accentRose)),
                ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            _testResultView(result),
          ],
        ],
      ),
    );
  }

  Widget _testResultView(Map<String, dynamic> result) {
    final status = result['status']?.toString() ?? 'inconnu';
    final ok = status == 'success';
    final valid = result['output_valid'] == true;
    final issues = (result['validation_issues'] as List?) ?? const [];
    final err = result['error'] ?? result['error_message'];
    final output = result['output'];
    const encoder = JsonEncoder.withIndent('  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill(status.toUpperCase(),
                ok ? AppTheme.accentEmerald : AppTheme.accentRose),
            if (result['duration_ms'] != null)
              Text('${result['duration_ms']} ms',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textMuted)),
            _pill(valid ? 'SCHÉMA OK' : 'SCHÉMA NON VALIDÉ',
                valid ? AppTheme.accentEmerald : AppTheme.accentAmber),
            if (result['run_id'] != null)
              Text('run ${result['run_id'].toString().substring(0, 8)}',
                  style: GoogleFonts.firaCode(
                      fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        if (err != null) ...[
          const SizedBox(height: 6),
          Text('$err',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppTheme.accentRose)),
        ],
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...issues.map((i) => Text('• $i',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppTheme.accentAmber))),
        ],
        if (output != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(6)),
            child: SingleChildScrollView(
              child: SelectableText(
                encoder.convert(output),
                style: GoogleFonts.firaCode(
                    fontSize: 11, color: Colors.white70, height: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _exampleInput(Map<String, dynamic> schema) {
    final props = (schema['properties'] as Map?) ?? {};
    if (props.isEmpty) return '{}';
    final first = props.keys.take(2).map((k) => '"$k": "…"').join(', ');
    return '{ $first }';
  }

  Widget _collapsibleJson(String label, Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentIndigo)),
        iconColor: AppTheme.textMuted,
        collapsedIconColor: AppTheme.textMuted,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(6)),
            child: SelectableText(encoder.convert(data),
                style: GoogleFonts.firaCode(
                    fontSize: 10, color: Colors.white70, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$k : ',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentIndigo)),
              TextSpan(
                  text: v,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white70, height: 1.4)),
            ],
          ),
        ),
      );
}

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );

// ══════════════════════════════ RUN TILE ══════════════════════════════

class _RunTile extends StatelessWidget {
  final AiAgentRun run;
  const _RunTile({required this.run});

  @override
  Widget build(BuildContext context) {
    final ok = run.status == 'success';
    const encoder = JsonEncoder.withIndent('  ');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: AppTheme.primarySurface,
        collapsedBackgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
            ok
                ? Icons.check_circle_rounded
                : (run.status == 'running'
                    ? Icons.hourglass_top_rounded
                    : Icons.error_rounded),
            color: ok
                ? AppTheme.accentEmerald
                : (run.status == 'running'
                    ? AppTheme.accentAmber
                    : AppTheme.accentRose),
            size: 18),
        title: Row(
          children: [
            Text(run.agentKey,
                style: GoogleFonts.firaCode(
                    fontSize: 12, color: AppTheme.accentCyan)),
            const SizedBox(width: 8),
            _pill(run.trigger, AppTheme.accentIndigo),
            const Spacer(),
            Text(
                run.durationMs != null ? '${run.durationMs} ms' : '—',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        subtitle: Text(
          '${DateFormat('dd/MM HH:mm:ss').format(run.createdAt.toLocal())} · '
          '${run.outputValid == null ? "schéma n/a" : (run.outputValid! ? "schéma ok" : "schéma non validé")}'
          '${run.errorMessage != null ? " · ${run.errorMessage}" : ""}',
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (run.inputPreview != null) ...[
                  Text('Entrée',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentIndigo)),
                  SelectableText(encoder.convert(run.inputPreview),
                      style: GoogleFonts.firaCode(
                          fontSize: 10, color: Colors.white60)),
                  const SizedBox(height: 8),
                ],
                Text('Sortie',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentIndigo)),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(6)),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      run.output == null
                          ? '(aucune sortie)'
                          : encoder.convert(run.output),
                      style: GoogleFonts.firaCode(
                          fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════ WORKFLOW CARD ══════════════════════════════

class _WorkflowCard extends ConsumerStatefulWidget {
  final AiWorkflow workflow;
  final VoidCallback onResumed;
  const _WorkflowCard({required this.workflow, required this.onResumed});

  @override
  ConsumerState<_WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends ConsumerState<_WorkflowCard> {
  bool _resuming = false;

  static const _wfColors = <String, Color>{
    'completed': AppTheme.accentEmerald,
    'running': AppTheme.accentCyan,
    'pending': AppTheme.textMuted,
    'paused': AppTheme.accentAmber,
    'failed': AppTheme.accentRose,
    'cancelled': AppTheme.textMuted,
  };

  Future<void> _resume() async {
    setState(() => _resuming = true);
    try {
      final res = await ref
          .read(supabaseServiceProvider)
          .resumeAiWorkflow(widget.workflow.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['error'] != null
              ? 'Reprise échouée : ${res['error']}'
              : 'Workflow ${res['status']}.')));
      widget.onResumed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wf = widget.workflow;
    final color = _wfColors[wf.status] ?? AppTheme.textMuted;
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
                child: Text(wf.title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              _pill(wf.status.toUpperCase(), color),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wf.progressPct / 100,
              minHeight: 6,
              backgroundColor: AppTheme.primaryDark,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text('${wf.progressPct}% · ${wf.workflowKey}',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...wf.steps.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                        s.status == 'success'
                            ? Icons.check_circle_outline_rounded
                            : (s.status == 'failed'
                                ? Icons.highlight_off_rounded
                                : (s.status == 'running'
                                    ? Icons.hourglass_top_rounded
                                    : Icons.radio_button_unchecked_rounded)),
                        size: 15,
                        color: s.status == 'success'
                            ? AppTheme.accentEmerald
                            : (s.status == 'failed'
                                ? AppTheme.accentRose
                                : AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${s.stepIndex + 1}. ${s.title} · ${s.agentKey}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white70)),
                    ),
                    if (s.errorMessage != null)
                      Expanded(
                        child: Text(s.errorMessage!,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppTheme.accentRose)),
                      ),
                  ],
                ),
              )),
          if (wf.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(wf.errorMessage!,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppTheme.accentRose)),
          ],
          if (wf.status == 'failed' || wf.status == 'paused') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _resuming ? null : _resume,
                icon: _resuming
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.replay_rounded, size: 15),
                label: Text(_resuming ? 'Reprise…' : 'Reprendre'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentAmber),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
