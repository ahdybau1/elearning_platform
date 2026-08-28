import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// ADM-AI-001/002 (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §9) — Agent Registry + Agent Detail.
///
/// IA-001 "Contracts" du plan (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : affiche le vrai registre
/// (migration 55), pas une simulation. Chaque agent listé est réellement déployé (voir
/// docs/AUDIT_REPORT.md) — aucun des 21 agents restants du catalogue des 26 n'apparaît ici tant
/// qu'il n'a pas d'implémentation réelle, conformément à la règle « pas de faux tableau de bord ».
class AiAgentRegistryScreen extends ConsumerWidget {
  const AiAgentRegistryScreen({super.key});

  static const _statusColors = <String, Color>{
    'active': AppTheme.accentEmerald,
    'draft': AppTheme.accentAmber,
    'deprecated': AppTheme.textMuted,
    'production': AppTheme.accentEmerald,
    'candidate': AppTheme.accentCyan,
    'retired': AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(aiAgentsProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registre des Agents IA',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'IA-001 "Contracts" — contrat réel (mission, schémas I/O, politique de modèle) de chaque agent '
            'effectivement déployé, relié à l\'Edge Function qui l\'exécute aujourd\'hui.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: agentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur : $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
              data: (agents) {
                if (agents.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun agent enregistré — le registre IA-001 n\'a pas encore été peuplé.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: agents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _AgentCard(agent: agents[i], statusColors: _statusColors),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatefulWidget {
  final AiAgent agent;
  final Map<String, Color> statusColors;
  const _AgentCard({required this.agent, required this.statusColors});

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final latestVersion = agent.versions.isNotEmpty ? agent.versions.first : null;
    final statusColor = widget.statusColors[agent.status] ?? AppTheme.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(agent.agentId,
                        style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.accentCyan)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(agent.name,
                                style: GoogleFonts.outfit(
                                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(agent.status,
                                  style: GoogleFonts.inter(
                                      fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(agent.mission,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4)),
                        if (latestVersion?.edgeFunctionName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 12, color: AppTheme.accentAmber),
                              const SizedBox(width: 4),
                              Text('Edge Function : ${latestVersion!.edgeFunctionName}',
                                  style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(width: 12),
                              Text('v${latestVersion.version} · ${latestVersion.status}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppTheme.primaryBorder, height: 1),
                  const SizedBox(height: 14),
                  if (agent.nonMission != null) ...[
                    _detailLabel('Non-mission'),
                    Text(agent.nonMission!, style: _detailStyle),
                    const SizedBox(height: 12),
                  ],
                  if (agent.catalogueRelation != null) ...[
                    _detailLabel('Correspondance avec le catalogue officiel (§7)'),
                    Text(agent.catalogueRelation!, style: _detailStyle),
                    const SizedBox(height: 12),
                  ],
                  if (latestVersion != null) ...[
                    _detailLabel('Politique de modèle'),
                    _jsonBlock(latestVersion.modelPolicy),
                    const SizedBox(height: 12),
                    _detailLabel('Schéma d\'entrée réel'),
                    _jsonBlock(latestVersion.inputSchema),
                    const SizedBox(height: 12),
                    _detailLabel('Schéma de sortie réel'),
                    _jsonBlock(latestVersion.outputSchema),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _detailStyle = TextStyle(fontSize: 12, color: Colors.white70, height: 1.4);

  Widget _detailLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentIndigo)),
      );

  Widget _jsonBlock(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        encoder.convert(data),
        style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white70, height: 1.5),
      ),
    );
  }
}
