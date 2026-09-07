import 'package:flutter/material.dart';
import '../../../core/models/curriculum_preview_data.dart';
import '../../../core/theme/app_theme.dart';
import 'academic_tree_screen.dart';

/// Aperçu de structure conservé sans simuler de collecte ni d’écriture distante.
class CurriculumAutopilotScreen extends StatelessWidget {
  const CurriculumAutopilotScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryDark,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Curriculum Autopilot',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Collecte automatique non raccordée à cet écran.',
          style: TextStyle(
            color: AppTheme.accentAmber,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aucun programme n’a été collecté, certifié ou injecté. Les programmes doivent être reliés à leurs sources, puis relus avant publication.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Ouvrir l’arbre académique'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Arbre académique')),
                  body: const AcademicTreeScreen(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'EXEMPLE DE STRUCTURE — NON VALIDÉ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cet exemple local du Cameroun illustre l’organisation attendue. Il ne constitue pas un référentiel officiel et n’est pas enregistré dans la base.',
        ),
        const SizedBox(height: 12),
        for (final node in sampleCurriculum()) _node(node),
      ],
    ),
  );

  Widget _node(CurriculumCandidateNode node) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
    childrenPadding: const EdgeInsets.only(left: 8),
    title: Text(node.title),
    children: [
      if (node.coefficient != null)
        Text('Coefficient d’exemple : ${node.coefficient}'),
      if (node.trimester != null)
        Text('Trimestre d’exemple : ${node.trimester}'),
      for (final skill in node.skills)
        ListTile(dense: true, title: Text(skill)),
      for (final child in node.children) _node(child),
    ],
  );
}
