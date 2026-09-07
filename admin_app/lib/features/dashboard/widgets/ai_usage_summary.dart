import 'package:flutter/material.dart';
import '../../../core/models/system_models.dart';

/// Synthèse des appels déjà chargés ; aucune nouvelle requête ni modification de droits.
class AiUsageSummary extends StatefulWidget {
  final List<AiAgentCall> calls;
  const AiUsageSummary({super.key, required this.calls});
  @override
  State<AiUsageSummary> createState() => _AiUsageSummaryState();
}

class _AiUsageSummaryState extends State<AiUsageSummary> {
  bool _showAll = false;
  String _cost(double value) =>
      '${value.toStringAsFixed(value > 0 && value < 0.01 ? 4 : 2)} USD estimés';

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AiAgentCall>>{};
    for (final call in widget.calls) {
      (groups[call.agentType] ??= []).add(call);
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) {
        final count = b.value.length.compareTo(a.value.length);
        return count == 0 ? a.key.compareTo(b.key) : count;
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.calls.length} appels • ${groups.length} agents'),
        const SizedBox(height: 8),
        for (final group in sorted.take(_showAll ? sorted.length : 5))
          ExpansionTile(
            key: ValueKey(group.key),
            tilePadding: EdgeInsets.zero,
            title: Text(group.key, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '${group.value.length} appels • ${group.value.fold<int>(0, (n, call) => n + call.tokensUsed)} tokens\n'
              '${_cost(group.value.fold<double>(0, (n, call) => n + call.costEstimate))} • ${group.value.where((call) => call.isFailed).length} échecs',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  primary: false,
                  itemCount: group.value.length,
                  itemBuilder: (_, index) {
                    final call = group.value[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${call.createdAt.toLocal()} • ${call.status}',
                      ),
                      subtitle: Text(
                        '${call.tokensUsed} tokens • ${_cost(call.costEstimate)}',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        if (sorted.length > 5)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll
                  ? 'Réduire la liste'
                  : 'Afficher les ${sorted.length} agents',
            ),
          ),
      ],
    );
  }
}
