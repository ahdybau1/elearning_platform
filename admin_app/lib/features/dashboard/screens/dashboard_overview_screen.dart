import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/data_providers.dart';

class DashboardOverviewScreen extends ConsumerWidget {
  const DashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final authState =
        authAsync.valueOrNull ??
        AdminUserState(
          id: '',
          email: '',
          firstName: 'Invité',
          lastName: '',
          role: AdminRole.superAdmin,
        );

    final validationAsync = ref.watch(validationQueueProvider);
    final aiCallsAsync = ref.watch(aiAgentCallsProvider(30));

    final validationCount = validationAsync.asData?.value.length ?? 0;

    final aiCalls = aiCallsAsync.asData?.value ?? [];
    double totalAiCost = 0;
    for (final call in aiCalls) {
      totalAiCost += call.costEstimate;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tableau de Bord Global',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vue d\'ensemble de l\'activité, des contenus et des performances du système (${authState.selectedCountry})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(validationQueueProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Overview KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100
                  ? 4
                  : (constraints.maxWidth > 700 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: 'Contenus en Attente de Validation',
                    value: validationCount.toString(),
                    subtitle: '$validationCount leçons/exercices',
                    icon: Icons.fact_check_rounded,
                    color: AppTheme.accentAmber,
                  ),
                  _buildKpiCard(
                    title: 'Élèves Actifs',
                    value: '14,280',
                    subtitle: '+12% ce mois',
                    icon: Icons.school_rounded,
                    color: AppTheme.accentBlue,
                  ),
                  _buildKpiCard(
                    title: 'Cours & Leçons Publiés',
                    value: '1,450',
                    subtitle: '98% de couverture du programme',
                    icon: Icons.menu_book_rounded,
                    color: AppTheme.accentEmerald,
                  ),
                  _buildKpiCard(
                    title: 'Exercices en Banque',
                    value: '18,920',
                    subtitle: '3,400 générés par IA',
                    icon: Icons.quiz_rounded,
                    color: AppTheme.accentIndigo,
                  ),
                  _buildFinancialKpiCard(
                    context: context,
                    canViewFinancials: authState.canViewFinancials,
                    title: 'Coût IA (30 derniers jours)',
                    value: '${totalAiCost.toStringAsFixed(2)} \$',
                    subtitle: '${aiCalls.length} appels API',
                    icon: Icons.psychology_rounded,
                    color: AppTheme.accentCyan,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // System Activity & Validation Workflow Status Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Validation Queue Box
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(24),
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
                            'Contenus en Attente de Validation',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$validationCount en attente',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      validationAsync.when(
                        data: (items) => items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Text(
                                    'Aucun contenu en attente de validation.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: items
                                    .map((item) => _buildValidationItem(item))
                                    .toList(),
                              ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(
                          child: Text(
                            'Erreur: $err',
                            style: GoogleFonts.inter(
                              color: AppTheme.accentRose,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // AI Usage & Cost Tracker Summary
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.psychology_rounded,
                            color: AppTheme.accentCyan,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Agents IA - Consommation API',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      aiCallsAsync.when(
                        data: (calls) => calls.isEmpty
                            ? Center(
                                child: Text(
                                  'Aucun appel IA enregistré.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              )
                            : Column(
                                children: calls
                                    .map(
                                      (call) => _buildAiUsageRow(
                                        call.agentType,
                                        '${call.tokensUsed} tokens',
                                        '\$${call.costEstimate.toStringAsFixed(2)}',
                                      ),
                                    )
                                    .toList(),
                              ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(
                          child: Text(
                            'Erreur: $err',
                            style: GoogleFonts.inter(
                              color: AppTheme.accentRose,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Coût Total Estimé (30j) :',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${totalAiCost.toStringAsFixed(2)} \$',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialKpiCard({
    required BuildContext context,
    required bool canViewFinancials,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canViewFinancials
              ? AppTheme.primaryBorder
              : AppTheme.accentRose.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: canViewFinancials
                    ? color.withValues(alpha: 0.15)
                    : AppTheme.accentRose.withValues(alpha: 0.15),
                child: Icon(
                  canViewFinancials ? icon : Icons.lock_rounded,
                  color: canViewFinancials ? color : AppTheme.accentRose,
                  size: 20,
                ),
              ),
            ],
          ),
          if (canViewFinancials)
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: AppTheme.accentRose,
                ),
                const SizedBox(width: 8),
                Text(
                  '•••••••• \$',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          Text(
            canViewFinancials
                ? subtitle
                : 'Accès réservé au Super-Administrateur',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: canViewFinancials ? color : AppTheme.accentRose,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationItem(dynamic item) {
    final title = item.title ?? 'Titre inconnu';
    final author = item.authorId ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentAmber,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$author • Statut: ${item.status}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.createdAt.toLocal().toString().split('.').first,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAiUsageRow(String task, String requests, String cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              task,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
          ),
          Text(
            requests,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 16),
          Text(
            cost,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
