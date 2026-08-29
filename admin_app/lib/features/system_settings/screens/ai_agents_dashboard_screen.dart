import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

const _agentTypeLabels = <String, String>{
  'course_structuring': 'Structuration de Cours',
  'exercise_generation': 'Génération d\'Exercices',
  'catalog_generation': 'Génération de Catalogue',
  'moderation': 'Modération Automatique',
  'student_tutor_chat': 'Tuteur Numérique (élève)',
};

const _providerLabels = <String, String>{
  'gemini': 'Gemini (Google)',
  'gateway': 'Gateway (Python)',
  'mock': 'Simulation (clé API absente)',
  'local_regex': 'Filtre local (sans IA)',
  'none': 'Échec (aucun fournisseur)',
};

const _providerColors = <String, Color>{
  'gemini': AppTheme.accentEmerald,
  'gateway': AppTheme.accentIndigo,
  'mock': AppTheme.accentAmber,
  'local_regex': AppTheme.textMuted,
  'none': AppTheme.accentRose,
};

class AiAgentsDashboardScreen extends ConsumerStatefulWidget {
  const AiAgentsDashboardScreen({super.key});

  @override
  ConsumerState<AiAgentsDashboardScreen> createState() => _AiAgentsDashboardScreenState();
}

class _AiAgentsDashboardScreenState extends ConsumerState<AiAgentsDashboardScreen> {
  int _periodDays = 30;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: false)));
    final callsAsync = ref.watch(aiAgentCallsProvider(_periodDays));

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agents IA & Coûts',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Suivi réel des coûts API (Gemini) et catalogue d\'éléments par matière',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                ),
                // Renvoie vers l'écran dédié plutôt que de dupliquer sa logique de création ici
                // (voir 05_flutter_architecture.md, règle 4 : pas de logique dupliquée).
                onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 22,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Gérer le Catalogue Pédagogique'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Modèles réellement utilisés aujourd'hui (voir le registre IA-001, écran « Registre des
          // Agents IA ») — Claude retiré le 2026-08-29 : ANTHROPIC_API_KEY n'a jamais été configurée
          // sur ce projet, donc jamais réellement utilisé malgré ce qu'affichait cet écran avant.
          Row(
            children: [
              _buildModelCard(
                'Gemini 3.6 Flash (Google)',
                'Tuteur, structuration, exercices, catalogue',
                'Gratuit en Free Tier',
                '0 \$ (free tier)',
                AppTheme.accentEmerald,
              ),
              const SizedBox(width: 16),
              _buildModelCard(
                'Gemini Embedding 001 (Google)',
                'Recherche RAG (ai_rag_chunks)',
                '768 dimensions',
                '0 \$ (free tier)',
                AppTheme.accentIndigo,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Real cost/usage tracking (ai_agent_calls)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Suivi Réel de la Consommation IA',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [7, 30, 90].map((d) {
                  final isSel = _periodDays == d;
                  return ChoiceChip(
                    selected: isSel,
                    showCheckmark: false,
                    label: Text('$d jours'),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel ? Colors.white : AppTheme.textMuted,
                    ),
                    selectedColor: AppTheme.accentCyan,
                    backgroundColor: AppTheme.primarySurface,
                    onSelected: (_) => setState(() => _periodDays = d),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          callsAsync.when(
            data: (calls) => _buildUsageSection(calls),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Catalogue Exhaustif des Éléments Pédagogiques par Matière (Prérequis IA)',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Catalog Grid — données réelles (content_catalog), un onglet par matière
          Expanded(
            child: subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return Center(
                    child: Text('Aucune matière créée.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted)),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, idx) {
                final subject = subjects[idx];
                final catalogAsync = ref.watch(contentCatalogProvider(subject.id));
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            subject.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(
                            Icons.category_rounded,
                            size: 18,
                            color: AppTheme.accentCyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: catalogAsync.when(
                          data: (items) {
                            if (items.isEmpty) {
                              return Text(
                                'Aucun élément de catalogue pour cette matière.',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                              );
                            }
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: items.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryDark,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.elementType,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('Erreur: $err',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentRose)),
                        ),
                      ),
                    ],
                  ),
                );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSection(List<AiAgentCall> calls) {
    if (calls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Text(
          'Aucun appel IA enregistré sur cette période — les agents (structuration de cours, '
          'génération d\'exercices, catalogue, modération) écriront ici dès leur premier usage.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
        ),
      );
    }

    final totalTokens = calls.fold<int>(0, (sum, c) => sum + c.tokensUsed);
    final totalCost = calls.fold<double>(0, (sum, c) => sum + c.costEstimate);
    // CF-004 : avant la migration 53, un appel échoué n'était même pas enregistré — ce taux
    // d'échec n'était donc jamais mesurable, même approximativement.
    final failedCalls = calls.where((c) => c.isFailed).toList();
    final failureRate = calls.isNotEmpty ? failedCalls.length / calls.length : 0.0;
    final durationsMs = calls.map((c) => c.durationMs).whereType<int>().toList();
    final avgDurationMs =
        durationsMs.isNotEmpty ? durationsMs.reduce((a, b) => a + b) / durationsMs.length : null;

    final byAgent = <String, List<AiAgentCall>>{};
    final byProvider = <String, List<AiAgentCall>>{};
    for (final c in calls) {
      byAgent.putIfAbsent(c.agentType, () => []).add(c);
      byProvider.putIfAbsent(c.provider, () => []).add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row
        Row(
          children: [
            _buildKpiCard('Appels IA', '${calls.length}', Icons.bolt_rounded, AppTheme.accentCyan),
            const SizedBox(width: 16),
            _buildKpiCard('Tokens consommés', NumberFormat.decimalPattern('fr').format(totalTokens),
                Icons.data_usage_rounded, AppTheme.accentBlue),
            const SizedBox(width: 16),
            _buildKpiCard('Coût estimé', '\$${totalCost.toStringAsFixed(4)}', Icons.payments_rounded,
                AppTheme.accentEmerald),
            const SizedBox(width: 16),
            _buildKpiCard(
              'Taux d\'échec',
              '${(failureRate * 100).toStringAsFixed(1)}% (${failedCalls.length})',
              Icons.error_outline_rounded,
              failedCalls.isEmpty ? AppTheme.textMuted : AppTheme.accentRose,
            ),
            const SizedBox(width: 16),
            _buildKpiCard(
              'Durée moyenne',
              avgDurationMs != null ? '${avgDurationMs.round()} ms' : '—',
              Icons.timer_outlined,
              AppTheme.accentIndigo,
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBreakdownCard('Par Agent', byAgent, totalCost, _agentTypeLabels, null)),
            const SizedBox(width: 16),
            Expanded(child: _buildBreakdownCard('Par Fournisseur', byProvider, totalCost, _providerLabels, _providerColors)),
          ],
        ),
        const SizedBox(height: 16),

        // Recent calls
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Derniers Appels', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                'Un appel en échec (jamais visible avant le 2026-08-28 — voir CF-004) reste journalisé ici, en rouge, avec son motif.',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 10),
              ...calls.take(15).map((c) => Tooltip(
                    message: c.isFailed
                        ? (c.errorMessage ?? 'Échec sans message enregistré.')
                        : (c.model != null ? 'Modèle : ${c.model}' : ''),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.isFailed ? AppTheme.accentRose.withValues(alpha: 0.08) : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            c.isFailed ? Icons.error_rounded : Icons.check_circle_rounded,
                            size: 13,
                            color: c.isFailed ? AppTheme.accentRose : AppTheme.accentEmerald,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(_agentTypeLabels[c.agentType] ?? c.agentType,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(c.model ?? (_providerLabels[c.provider] ?? c.provider),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _providerColors[c.provider] ?? Colors.white38)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${c.tokensUsed} tok.',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(c.durationMs != null ? '${c.durationMs} ms' : '—',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('\$${c.costEstimate.toStringAsFixed(5)}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(c.createdAt.toLocal()),
                              textAlign: TextAlign.end,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(
    String title,
    Map<String, List<AiAgentCall>> grouped,
    double totalCost,
    Map<String, String> labels,
    Map<String, Color>? colors,
  ) {
    final entries = grouped.entries.toList()
      ..sort((a, b) =>
          b.value.fold<double>(0, (s, c) => s + c.costEstimate).compareTo(a.value.fold<double>(0, (s, c) => s + c.costEstimate)));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final cost = e.value.fold<double>(0, (s, c) => s + c.costEstimate);
            final ratio = totalCost > 0 ? (cost / totalCost).clamp(0.0, 1.0) : 0.0;
            final color = colors?[e.key] ?? AppTheme.accentCyan;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(labels[e.key] ?? e.key,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                      Text('${e.value.length} appel${e.value.length > 1 ? 's' : ''} · \$${cost.toStringAsFixed(4)}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppTheme.primaryDark,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModelCard(
    String name,
    String task,
    String reason,
    String rate,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tâche : $task',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reason,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
