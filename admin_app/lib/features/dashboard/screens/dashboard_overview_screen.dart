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

    final selectedCountryIds = ref.watch(selectedCountryIdsProvider);
    final countriesAsync = ref.watch(nodesByTypeProvider('country'));
    final countries = countriesAsync.valueOrNull ?? [];
    final countryScopeLabel = selectedCountryIds == null
        ? 'Tous les pays'
        : selectedCountryIds.length == 1
        ? (countries
                  .where((c) => c.id == selectedCountryIds.first)
                  .firstOrNull
                  ?.name ??
              '1 pays')
        : '${selectedCountryIds.length} pays';

    final validationAsync = ref.watch(validationQueueProvider);
    final aiCallsAsync = ref.watch(aiAgentCallsProvider(30));
    final activeProfilesAsync = ref.watch(activeProfilesCountProvider);
    final publishedLessonsAsync = ref.watch(publishedLessonsCountProvider);
    final exercisesAsync = ref.watch(exercisesCountProvider);
    final openTicketsAsync = ref.watch(openTicketsCountProvider);

    final validationCount = validationAsync.asData?.value.length ?? 0;
    final activeProfiles = activeProfilesAsync.asData?.value ?? 0;
    final publishedLessons = publishedLessonsAsync.asData?.value ?? 0;
    final exercisesCount = exercisesAsync.asData?.value ?? 0;
    final openTickets = openTicketsAsync.asData?.value ?? 0;

    final aiCalls = aiCallsAsync.asData?.value ?? [];
    double totalAiCost = 0;
    for (final call in aiCalls) {
      totalAiCost += call.costEstimate;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
                      'Vue d\'ensemble de l\'activité, des contenus et des performances du système ($countryScopeLabel)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(validationQueueProvider);
                  // ignore: unused_result
                  ref.refresh(activeProfilesCountProvider);
                  // ignore: unused_result
                  ref.refresh(publishedLessonsCountProvider);
                  // ignore: unused_result
                  ref.refresh(exercisesCountProvider);
                  // ignore: unused_result
                  ref.refresh(openTicketsCountProvider);
                  // ignore: unused_result
                  ref.refresh(aiAgentCallsProvider(30));
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Overview KPI Cards Grid — sur mobile (une seule colonne), 5-6 cartes bordées
          // pleine largeur empilées n'apportaient aucune séparation utile (elles étaient déjà
          // seules sur leur ligne) : juste des cadres en plus les uns sous les autres. Retour
          // utilisateur réel très explicite, 2026-09-01 : "trop de box et d'élément dans un
          // même interface". Sous 700px, on passe donc à une simple grille 2 colonnes de
          // chiffres nus (comme les tuiles de stats d'iOS/WhatsApp), sans cadre ni fond.
          LayoutBuilder(
            builder: (context, constraints) {
              final kpis = [
                _KpiData(
                  title: 'Contenus en Attente de Validation',
                  value: validationCount.toString(),
                  subtitle: '$validationCount leçons/exercices',
                  icon: Icons.fact_check_rounded,
                  color: AppTheme.accentAmber,
                  isLoading: validationAsync.isLoading,
                ),
                _KpiData(
                  title: 'Élèves Actifs',
                  value: activeProfiles > 0
                      ? _formatCount(activeProfiles)
                      : '—',
                  subtitle: '$activeProfiles profils actifs',
                  icon: Icons.school_rounded,
                  color: AppTheme.accentBlue,
                  isLoading: activeProfilesAsync.isLoading,
                ),
                _KpiData(
                  title: 'Cours & Leçons Publiés',
                  value: publishedLessons > 0
                      ? _formatCount(publishedLessons)
                      : '—',
                  subtitle: '$publishedLessons leçons publiées',
                  icon: Icons.menu_book_rounded,
                  color: AppTheme.accentEmerald,
                  isLoading: publishedLessonsAsync.isLoading,
                ),
                _KpiData(
                  title: 'Exercices en Banque',
                  value: exercisesCount > 0 ? _formatCount(exercisesCount) : '—',
                  subtitle: '$exercisesCount exercices au total',
                  icon: Icons.quiz_rounded,
                  color: AppTheme.accentIndigo,
                  isLoading: exercisesAsync.isLoading,
                ),
                _KpiData(
                  title: 'Tickets Support Ouverts',
                  value: openTickets.toString(),
                  subtitle: '$openTickets en attente de traitement',
                  icon: Icons.support_agent_rounded,
                  color: AppTheme.accentRose,
                  isLoading: openTicketsAsync.isLoading,
                ),
                // Absente entièrement pour un admin sans la permission viewAiCosts — pas de
                // carte verrouillée qui trahirait l'existence de cette donnée.
                if (authState.canViewAiCosts)
                  _KpiData(
                    title: 'Coût IA (30 derniers jours)',
                    value: '${totalAiCost.toStringAsFixed(2)} \$',
                    subtitle: '${aiCalls.length} appels API',
                    icon: Icons.psychology_rounded,
                    color: AppTheme.accentCyan,
                  ),
              ];

              if (constraints.maxWidth <= 700) {
                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: kpis.map((k) => _buildKpiFlat(k)).toList(),
                );
              }

              final crossAxisCount = constraints.maxWidth > 1100 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: kpis
                    .map(
                      (k) => _buildKpiCard(
                        title: k.title,
                        value: k.value,
                        subtitle: k.subtitle,
                        icon: k.icon,
                        color: k.color,
                        isLoading: k.isLoading,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),

          // System Activity & Validation Workflow Status Row — 2 colonnes fixes (flex 3/2)
          // sans seuil mobile : sur téléphone chaque boîte n'avait plus que ~50% de largeur,
          // en-têtes tronqués ("Conte...", "Agent...", retour utilisateur réel, 2026-08-30).
          // Sous 900px, elles s'empilent en pleine largeur — et sur mobile, sans cadre du
          // tout : deux Container bordés empilés n'étaient que des bordures redondantes
          // autour de sections déjà seules sur l'écran (retour utilisateur réel très
          // explicite, "trop de box et d'élément dans un même interface", 2026-09-01).
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 900;
              final validationInner = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contenus en Attente de Validation',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.2),
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
                                  .map(
                                    (item) => _buildValidationItem(ref, item),
                                  )
                                  .toList(),
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Text(
                          'Erreur: $err',
                          style: GoogleFonts.inter(color: AppTheme.accentRose),
                        ),
                      ),
                    ),
                  ],
                );
              final validationBox = isMobile
                  ? validationInner
                  : Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBorder),
                      ),
                      child: validationInner,
                    );

              // Absente entièrement sans la permission viewAiCosts — même principe que la carte
              // KPI : pas de fuite du détail des coûts/appels IA à un admin non autorisé.
              if (!authState.canViewAiCosts) {
                return validationBox;
              }

              final aiUsageInner = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          color: AppTheme.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Agents IA - Consommation API',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
                          style: GoogleFonts.inter(color: AppTheme.accentRose),
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
                        children: [
                          Expanded(
                            child: Text(
                              'Coût Total Estimé (30j) :',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                );
              final aiUsageBox = isMobile
                  ? aiUsageInner
                  : Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBorder),
                      ),
                      child: aiUsageInner,
                    );

              if (isMobile) {
                return Column(
                  children: [
                    validationBox,
                    const SizedBox(height: 24),
                    aiUsageBox,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: validationBox),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: aiUsageBox),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isLoading = false,
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
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
            )
          else
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Rendu plat sur mobile : une simple tuile chiffre + libellé, sans cadre ni fond — 6
  /// cartes bordées pleine largeur empilées n'ajoutaient qu'une répétition de bordures sans
  /// séparer quoi que ce soit (retour utilisateur réel, 2026-09-01).
  Widget _buildKpiFlat(_KpiData k) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(k.icon, color: k.color, size: 18),
        const SizedBox(height: 8),
        k.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: k.color),
              )
            : Text(
                k.value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        const SizedBox(height: 2),
        Text(
          k.title,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildValidationItem(WidgetRef ref, dynamic item) {
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
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$author • Statut: ${item.status}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.createdAt.toLocal().toString().split(' ').first,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
            tooltip: 'Aller à la File de Validation',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () =>
                ref.read(selectedNavIndexProvider.notifier).state = 4,
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
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            requests,
            overflow: TextOverflow.ellipsis,
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

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;

  _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });
}
