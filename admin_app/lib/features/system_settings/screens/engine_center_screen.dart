import 'package:flutter/material.dart';
import '../../../core/engines/capability_registry.dart';
import '../../../core/engines/engine_diagnostics.dart';
import '../../../core/theme/app_theme.dart';

class EngineCenterScreen extends StatefulWidget {
  const EngineCenterScreen({super.key});
  @override
  State<EngineCenterScreen> createState() => _EngineCenterScreenState();
}

class _EngineCenterScreenState extends State<EngineCenterScreen> {
  final Map<CapabilityType, EngineDiagnostic> _results = {};
  void _check(CapabilityType type) =>
      setState(() => _results[type] = EngineDiagnostics.run(type));

  @override
  Widget build(BuildContext context) {
    final capabilities = CapabilityRegistry.getAll();
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Centre des moteurs',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Catalogue des capacités déclarées. Les contrôles locaux ne certifient ni un service IA, ni le rendu élève, ni le fonctionnement hors connexion.',
          ),
          const SizedBox(height: 12),
          Text(
            '${capabilities.length} capacités déclarées • ${capabilities.where((c) => c.executionMode == EngineExecutionMode.local).length} configurations locales',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Vérifier les contrôles locaux'),
              onPressed: () => setState(() {
                for (final cap in capabilities) {
                  _results[cap.type] = EngineDiagnostics.run(cap.type);
                }
              }),
            ),
          ),
          const SizedBox(height: 16),
          for (final cap in capabilities)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cap.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Fournisseur déclaré : ${cap.providerName}'),
                    const SizedBox(height: 8),
                    Text(
                      _results[cap.type]?.detail ??
                          'Disponibilité non vérifiée.',
                      style: TextStyle(
                        color:
                            _results[cap.type]?.checked == true &&
                                _results[cap.type]?.passed == false
                            ? AppTheme.accentRose
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _check(cap.type),
                      child: const Text('Vérifier localement'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
