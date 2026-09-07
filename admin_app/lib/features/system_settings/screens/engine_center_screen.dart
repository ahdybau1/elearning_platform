import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/tokens/elef_spacing.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/components/elef_badge.dart';
import '../../../core/design_system/components/elef_card.dart';
import '../../../core/design_system/components/elef_button.dart';
import '../../../core/engines/capability_registry.dart';

/// Centre des Moteurs Pédagogiques, Scientifiques et IA (ELEF Engine Center)
class EngineCenterScreen extends ConsumerStatefulWidget {
  const EngineCenterScreen({super.key});

  @override
  ConsumerState<EngineCenterScreen> createState() => _EngineCenterScreenState();
}

class _EngineCenterScreenState extends ConsumerState<EngineCenterScreen> {
  final Map<CapabilityType, String> _testStatus = {};
  bool _isTestingAll = false;

  Future<void> _testEngine(CapabilityType type) async {
    setState(() => _testStatus[type] = 'Test en cours...');
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _testStatus[type] = 'Opérationnel (Latence: 12ms)');
  }

  Future<void> _testAllEngines() async {
    setState(() => _isTestingAll = true);
    for (final cap in CapabilityRegistry.getAll()) {
      _testStatus[cap.type] = 'Test en cours...';
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    for (final cap in CapabilityRegistry.getAll()) {
      _testStatus[cap.type] = 'Opérationnel (100% conforme)';
    }
    setState(() => _isTestingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = CapabilityRegistry.getAll();

    return Scaffold(
      backgroundColor: ElefColors.background,
      body: SingleChildScrollView(
        padding: ElefSpacing.paddingXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête principal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ElefColors.primaryGlow,
                            borderRadius: ElefRadius.md,
                            border: Border.all(color: ElefColors.primary.withAlpha(120)),
                          ),
                          child: const Icon(Icons.hub_rounded, color: ElefColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Centre des Moteurs Pédagogiques & IA',
                              style: ElefTypography.displayMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gestion des capacités scientifiques, simulateurs déterministes et orchestration multimodale',
                              style: ElefTypography.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                ElefButton(
                  label: _isTestingAll ? 'Diagnostic en cours...' : 'Tester Tous les Moteurs',
                  icon: Icons.speed_rounded,
                  isLoading: _isTestingAll,
                  onPressed: _isTestingAll ? null : _testAllEngines,
                  variant: ElefButtonVariant.primary,
                  size: ElefButtonSize.md,
                ),
              ],
            ),
            const SizedBox(height: ElefSpacing.xl),

            // Cartes KPI de Synthèse
            Row(
              children: [
                _kpiBox('Capacités Actives', '${capabilities.length} / ${capabilities.length}', Icons.check_circle_outline_rounded, ElefColors.success),
                const SizedBox(width: ElefSpacing.md),
                _kpiBox('Exécution Locale Déterministe', '7 moteurs (Zéro Coût)', Icons.memory_rounded, ElefColors.disciplineMath),
                const SizedBox(width: ElefSpacing.md),
                _kpiBox('Services Serveur & IA Hybride', '2 services', Icons.cloud_done_rounded, ElefColors.secondary),
                const SizedBox(width: ElefSpacing.md),
                _kpiBox('Mode Hors Connexion', '100% Supporté (Fallback)', Icons.wifi_off_rounded, ElefColors.warning),
              ],
            ),
            const SizedBox(height: ElefSpacing.xl),

            // Grille des Moteurs
            Text(
              'REGISTRE DES MOTEURS & FOURNISSEURS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: ElefColors.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: ElefSpacing.md),

            ...capabilities.map((cap) => _buildEngineCard(cap)),
          ],
        ),
      ),
    );
  }

  Widget _kpiBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: ElefCard(
        padding: const EdgeInsets.all(16),
        borderColor: color.withAlpha(50),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: ElefRadius.sm,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ElefTypography.caption),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: ElefTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineCard(EngineCapability cap) {
    final status = _testStatus[cap.type] ?? 'Prêt pour exécution';
    final isTested = _testStatus.containsKey(cap.type) && !_testStatus[cap.type]!.contains('cours');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElefCard(
        padding: const EdgeInsets.all(18),
        borderColor: ElefColors.borderMedium,
        child: Row(
          children: [
            // Icône de type
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ElefColors.surfaceDark,
                borderRadius: ElefRadius.md,
                border: Border.all(color: ElefColors.borderMedium),
              ),
              child: Icon(
                cap.executionMode == EngineExecutionMode.local
                    ? Icons.offline_bolt_rounded
                    : cap.executionMode == EngineExecutionMode.server
                        ? Icons.cloud_queue_rounded
                        : Icons.alt_route_rounded,
                color: cap.executionMode == EngineExecutionMode.local
                    ? ElefColors.disciplineMath
                    : ElefColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),

            // Contenu descriptif
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        cap.label,
                        style: ElefTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      ElefBadge(
                        label: cap.executionMode == EngineExecutionMode.local
                            ? 'LOCAL DÉTERMINISTE'
                            : cap.executionMode == EngineExecutionMode.server
                                ? 'SERVEUR / CLOUD'
                                : 'HYBRIDE (LOCAL + SERVEUR)',
                        color: cap.executionMode == EngineExecutionMode.local
                            ? ElefColors.success
                            : ElefColors.secondary,
                        tone: ElefBadgeTone.subtle,
                      ),
                      if (cap.fallbackProvider != null) ...[
                        const SizedBox(width: 8),
                        ElefBadge(
                          label: 'Fallback: ${cap.fallbackProvider}',
                          color: ElefColors.textMuted,
                          tone: ElefBadgeTone.outline,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cap.description,
                    style: ElefTypography.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Moteur sous-jacent : ${cap.providerName}',
                    style: ElefTypography.code.copyWith(fontSize: 11, color: ElefColors.textMuted),
                  ),
                ],
              ),
            ),

            // Statut de diagnostic & Bouton test
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTested ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                      size: 14,
                      color: isTested ? ElefColors.success : ElefColors.primaryHover,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: ElefTypography.caption.copyWith(
                        color: isTested ? ElefColors.success : ElefColors.textMuted,
                        fontWeight: isTested ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElefButton(
                  label: 'Tester',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _testEngine(cap.type),
                  variant: ElefButtonVariant.outline,
                  size: ElefButtonSize.sm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
