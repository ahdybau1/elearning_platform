import 'package:flutter/material.dart';
import '../../../core/design_system/components/elef_badge.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/engines/capability_registry.dart';
import '../../../core/engines/engine_diagnostics.dart';

/// Centre des Moteurs & Diagnostics d'Exécution ELEF.
///
/// Permet de visualiser l'ensemble des capacités (calcul formel, simulateurs déterministes,
/// compilateur KaTeX, bacs à sable code, modèles IA) et d'exécuter des tests de santé locaux.
class EngineCenterScreen extends StatefulWidget {
  const EngineCenterScreen({super.key});

  @override
  State<EngineCenterScreen> createState() => _EngineCenterScreenState();
}

class _EngineCenterScreenState extends State<EngineCenterScreen> {
  final Map<CapabilityType, EngineDiagnostic> _results = {};
  EngineExecutionMode? _filterMode;

  void _check(CapabilityType type) {
    setState(() => _results[type] = EngineDiagnostics.run(type));
  }

  void _checkAll(List<EngineCapability> capabilities) {
    setState(() {
      for (final cap in capabilities) {
        _results[cap.type] = EngineDiagnostics.run(cap.type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allCapabilities = CapabilityRegistry.getAll();
    final localCount = allCapabilities
        .where((c) => c.executionMode == EngineExecutionMode.local)
        .length;
    final hybridCount = allCapabilities
        .where((c) => c.executionMode == EngineExecutionMode.hybrid)
        .length;
    final serverCount = allCapabilities
        .where((c) => c.executionMode == EngineExecutionMode.server)
        .length;

    final filteredCapabilities = _filterMode == null
        ? allCapabilities
        : allCapabilities.where((c) => c.executionMode == _filterMode).toList();

    return Scaffold(
      backgroundColor: ElefColors.background,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // En-tête de section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ElefColors.primary.withAlpha(30),
                  borderRadius: ElefRadius.md,
                ),
                child: const Icon(
                  Icons.memory_rounded,
                  color: ElefColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centre des moteurs',
                      style: ElefTypography.heading1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Catalogue des capacités déclarées. Les contrôles locaux ne certifient ni un service IA, ni le rendu élève, ni le fonctionnement hors connexion.',
                      style: ElefTypography.bodySmall.copyWith(
                        color: ElefColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Métriques et badges de synthèse
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElefBadge(
                label: '${allCapabilities.length} capacités déclarées',
                color: ElefColors.textPrimary,
                tone: ElefBadgeTone.subtle,
                icon: Icons.layers_outlined,
              ),
              ElefBadge(
                label: '$localCount configurations locales',
                color: ElefColors.success,
                tone: ElefBadgeTone.subtle,
                icon: Icons.offline_bolt_rounded,
              ),
              ElefBadge(
                label: '$hybridCount hybrides',
                color: ElefColors.secondary,
                tone: ElefBadgeTone.subtle,
                icon: Icons.sync_alt_rounded,
              ),
              ElefBadge(
                label: '$serverCount serveur',
                color: ElefColors.disciplinePhysics,
                tone: ElefBadgeTone.subtle,
                icon: Icons.cloud_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barre d'action et filtres
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('Vérifier les contrôles locaux'),
                style: FilledButton.styleFrom(
                  backgroundColor: ElefColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: ElefRadius.md),
                ),
                onPressed: () => _checkAll(allCapabilities),
              ),
              // Filtres d'affichage
              Wrap(
                spacing: 6,
                children: [
                  _filterChip('Tous', null),
                  _filterChip('Local', EngineExecutionMode.local),
                  _filterChip('Hybride', EngineExecutionMode.hybrid),
                  _filterChip('Serveur', EngineExecutionMode.server),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Liste des cartes de capacités
          for (final cap in filteredCapabilities)
            _buildCapabilityCard(cap),
        ],
      ),
    );
  }

  Widget _filterChip(String label, EngineExecutionMode? mode) {
    final isSelected = _filterMode == mode;
    return ChoiceChip(
      label: Text(label),
      labelStyle: ElefTypography.caption.copyWith(
        color: isSelected ? Colors.white : ElefColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: ElefColors.surfaceElevated,
      backgroundColor: ElefColors.surfaceDark,
      side: BorderSide(
        color: isSelected ? ElefColors.primary : ElefColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: ElefRadius.sm),
      onSelected: (_) => setState(() => _filterMode = mode),
    );
  }

  Widget _buildCapabilityCard(EngineCapability cap) {
    final diag = _results[cap.type];
    final (modeColor, modeIcon, modeLabel) = switch (cap.executionMode) {
      EngineExecutionMode.local => (
        ElefColors.success,
        Icons.offline_bolt_rounded,
        'LOCAL'
      ),
      EngineExecutionMode.hybrid => (
        ElefColors.secondary,
        Icons.sync_alt_rounded,
        'HYBRIDE'
      ),
      EngineExecutionMode.server => (
        ElefColors.disciplinePhysics,
        Icons.cloud_outlined,
        'SERVEUR'
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre & Badge d'exécution
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    cap.label,
                    style: ElefTypography.titleSmall.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElefBadge(
                  label: modeLabel,
                  color: modeColor,
                  icon: modeIcon,
                  tone: ElefBadgeTone.subtle,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cap.description,
              style: ElefTypography.caption.copyWith(
                color: ElefColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // Fournisseurs déclarés
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D18),
                    borderRadius: ElefRadius.sm,
                    border: Border.all(color: ElefColors.borderSubtle),
                  ),
                  child: Text(
                    'Fournisseur déclaré : ${cap.providerName}',
                    style: ElefTypography.caption.copyWith(
                      color: ElefColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (cap.fallbackProvider != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D18),
                      borderRadius: ElefRadius.sm,
                      border: Border.all(color: ElefColors.borderSubtle),
                    ),
                    child: Text(
                      'Repli : ${cap.fallbackProvider}',
                      style: ElefTypography.caption.copyWith(
                        color: ElefColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Diagnostic local
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: diag == null
                    ? const Color(0xFF090D18)
                    : diag.passed
                        ? ElefColors.success.withAlpha(20)
                        : ElefColors.danger.withAlpha(20),
                borderRadius: ElefRadius.md,
                border: Border.all(
                  color: diag == null
                      ? ElefColors.borderSubtle
                      : diag.passed
                          ? ElefColors.success.withAlpha(60)
                          : ElefColors.danger.withAlpha(60),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    diag == null
                        ? Icons.info_outline_rounded
                        : diag.passed
                            ? Icons.check_circle_outline_rounded
                            : Icons.highlight_off_rounded,
                    size: 16,
                    color: diag == null
                        ? ElefColors.textMuted
                        : diag.passed
                            ? ElefColors.success
                            : ElefColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      diag?.detail ?? 'Disponibilité non vérifiée.',
                      style: ElefTypography.caption.copyWith(
                        color: diag == null
                            ? ElefColors.textMuted
                            : diag.passed
                                ? ElefColors.success
                                : ElefColors.danger,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bouton de diagnostic individuel
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Vérifier localement'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ElefColors.primary,
                  side: const BorderSide(color: ElefColors.borderMedium),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: ElefRadius.md),
                ),
                onPressed: () => _check(cap.type),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
