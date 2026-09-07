/// Spécification d'un script ou bloc de code
class CodeExecutionSpec {
  final String language;
  final String initialCode;
  final String? expectedOutput;
  final bool isInteractive;

  const CodeExecutionSpec({
    this.language = 'python',
    required this.initialCode,
    this.expectedOutput,
    this.isInteractive = true,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'initial_code': initialCode,
    if (expectedOutput != null) 'expected_output': expectedOutput,
    'is_interactive': isInteractive,
  };

  factory CodeExecutionSpec.fromJson(Map<String, dynamic> json) {
    return CodeExecutionSpec(
      language: json['language'] as String? ?? 'python',
      initialCode: json['initial_code'] as String? ?? '',
      expectedOutput: json['expected_output'] as String?,
      isInteractive: json['is_interactive'] as bool? ?? true,
    );
  }
}

/// Moteur de bac à sable pour l'exécution d'algorithmes et de scripts pédagogiques
class CodeExecutionEngine {
  CodeExecutionEngine._();

  static CodeExecutionSpec heronAlgorithmPreset() {
    return const CodeExecutionSpec(
      language: 'python',
      initialCode: '''def racine_heron(a, n_iterations=6):
    """Méthode de Héron pour approximer la racine carrée"""
    x = a / 2.0
    for i in range(1, n_iterations + 1):
        x = 0.5 * (x + a / x)
        print(f"Iteration {i}: x = {x:.8f}")
    return x

valeur = 2
print(f"--- Calcul de sqrt({valeur}) par la méthode de Héron ---")
res = racine_heron(valeur)
print(f"Resultat final: {res:.8f}")
''',
    );
  }
}
