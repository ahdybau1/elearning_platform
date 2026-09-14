enum CapabilityType {
  latex,
  plot2d,
  geometry,
  physicsSimulation,
  chemistrySimulation,
  circuitSimulation,
  molecular3d,
  codeExecution,
  imageGeneration,
  imageVisionOcr,
  speechToText,
  textToSpeech,
  localAi,
  serverAi,
  pedagogicalStructuring,
}

enum EngineExecutionMode { local, server, hybrid }

class EngineCapability {
  final CapabilityType type;
  final String label;
  final String description;
  final EngineExecutionMode executionMode;
  final bool isAvailable;
  final String providerName; // e.g. "SymPy / Dart Native", "Canvas Vectoriel", "Canvas 3D / CPK", "WASM Sandbox", "Gemini Pro / Local Fallback"
  final String? fallbackProvider;

  const EngineCapability({
    required this.type,
    required this.label,
    required this.description,
    required this.executionMode,
    this.isAvailable = true,
    required this.providerName,
    this.fallbackProvider,
  });
}

/// Registre des capacités de calcul, simulation, rendu et IA d'ELEF
class CapabilityRegistry {
  CapabilityRegistry._();

  static final Map<CapabilityType, EngineCapability> _capabilities = {
    CapabilityType.latex: const EngineCapability(
      type: CapabilityType.latex,
      label: 'Rendu Formules Mathématiques',
      description: 'Compilation vectorielle KaTeX & MathJax avec zéro fuite de code brut',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'flutter_math_fork + LatexToUnicodeConverter',
      fallbackProvider: 'Unicode Text Math Parser',
    ),
    CapabilityType.plot2d: const EngineCapability(
      type: CapabilityType.plot2d,
      label: 'Tracé de Courbes & Tangentes 2D',
      description: 'Grapheur analytique dynamique, calcul de dérivée et extremum',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'Elef GraphEngine (Dart Vectoriel)',
      fallbackProvider: 'Tableau de Valeurs Synthétique',
    ),
    CapabilityType.physicsSimulation: const EngineCapability(
      type: CapabilityType.physicsSimulation,
      label: 'Simulateur Physique & Mécanique',
      description: 'Résolution des équations différentielles (balistique, chute, oscillations)',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'Elef Newton Physics Engine',
    ),
    CapabilityType.circuitSimulation: const EngineCapability(
      type: CapabilityType.circuitSimulation,
      label: 'Simulateur Électronique & RLC',
      description: 'Oscilloscope vectoriel temps réel et calcul exact de tau = RC',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'Elef Circuit Engine (ngspice / Vector)',
    ),
    CapabilityType.molecular3d: const EngineCapability(
      type: CapabilityType.molecular3d,
      label: 'Visualiseur Moléculaire 3D',
      description: 'Projection 3D temps réel avec rotation tactile et couleurs CPK',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'Elef Molecular 3D Engine',
    ),
    CapabilityType.codeExecution: const EngineCapability(
      type: CapabilityType.codeExecution,
      label: 'Exécution d\'Algorithmes & Python',
      description: 'Bac à sable client sécurisé avec capture des flux stdout',
      executionMode: EngineExecutionMode.local,
      isAvailable: true,
      providerName: 'Elef Python Sandbox Engine',
    ),
    CapabilityType.imageGeneration: const EngineCapability(
      type: CapabilityType.imageGeneration,
      label: 'Génération d\'Illustrations IA',
      description: 'Création d\'illustrations pédagogiques contextualisées avec cache intelligent SHA-256',
      executionMode: EngineExecutionMode.server,
      isAvailable: true,
      providerName: 'ELEF Multi-Provider IA Hub (Gemini / Edge)',
      fallbackProvider: 'Médiathèque Locale',
    ),
    CapabilityType.imageVisionOcr: const EngineCapability(
      type: CapabilityType.imageVisionOcr,
      label: 'Vision & Transcription Manuscrite',
      description: 'Analyse d\'énoncés photographiés, schémas, équations et copies d\'élèves',
      executionMode: EngineExecutionMode.hybrid,
      isAvailable: true,
      providerName: 'Multimodal Vision Engine',
      fallbackProvider: 'OCR Local Déterministe',
    ),
    CapabilityType.pedagogicalStructuring: const EngineCapability(
      type: CapabilityType.pedagogicalStructuring,
      label: 'Structuration Pédagogique (Curriculum Autopilot)',
      description: 'Moissonnage et découpage conforme aux arrêtés ministériels (APC)',
      executionMode: EngineExecutionMode.hybrid,
      isAvailable: true,
      providerName: 'AIA-AGT-017 Curriculum Autopilot',
    ),
  };

  static List<EngineCapability> getAll() => _capabilities.values.toList();

  static bool hasCapability(CapabilityType type) =>
      _capabilities[type]?.isAvailable ?? false;

  static EngineCapability? get(CapabilityType type) => _capabilities[type];
}
