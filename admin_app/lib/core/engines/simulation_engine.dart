enum SimulationType { circuitRlc, molecular3d, ballisticsNewton }

/// Spécification d'un laboratoire de simulation interactif
class SimulationSpec {
  final SimulationType type;
  final String title;
  final String description;
  final Map<String, dynamic> initialParameters;

  const SimulationSpec({
    required this.type,
    required this.title,
    required this.description,
    required this.initialParameters,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'description': description,
    'initial_parameters': initialParameters,
  };

  factory SimulationSpec.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'circuitRlc';
    final type = SimulationType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => SimulationType.circuitRlc,
    );
    return SimulationSpec(
      type: type,
      title: json['title'] as String? ?? 'Simulation Pédagogique',
      description: json['description'] as String? ?? '',
      initialParameters: Map<String, dynamic>.from(json['initial_parameters'] ?? {}),
    );
  }
}

/// Moteur de laboratoire et simulateur interactif
class SimulationEngine {
  SimulationEngine._();

  static SimulationSpec rlcPreset() => const SimulationSpec(
    type: SimulationType.circuitRlc,
    title: 'Circuit RC / RLC & Oscilloscope Vectoriel',
    description: 'Mesure de la constante de temps tau = RC et réponse indicielle à un échelon de tension.',
    initialParameters: {'resistance': 2000.0, 'capacitance': 100.0, 'voltage': 5.0},
  );

  static SimulationSpec molecularPreset() => const SimulationSpec(
    type: SimulationType.molecular3d,
    title: 'Visualiseur Moléculaire 3D (CPK)',
    description: 'Exploration stéréochimique et conformations 3D des molécules organiques.',
    initialParameters: {'molecule': 'ethanol', 'bonds': true},
  );

  static SimulationSpec ballisticsPreset() => const SimulationSpec(
    type: SimulationType.ballisticsNewton,
    title: 'Mouvement de Projectile dans un Champ de Pesanteur',
    description: 'Trajectoire parabolique, calcul de la flèche maximale et de la portée.',
    initialParameters: {'angle': 45.0, 'velocity': 20.0, 'gravity': 9.8},
  );
}
