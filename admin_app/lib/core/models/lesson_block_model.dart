/// Modèle de bloc universel pour le Lesson Builder EDLEARN / ELEF (v2).
///
/// Compatible avec le format attendu par `student_app` (`content_json['blocks']`),
/// tout en fournissant une structure riche avec métadonnées pour les composants
/// scientifiques, interactifs et les fiches visuelles « trait pour trait ».
class LessonBlock {
  final String id;
  final String type;
  final String? heading;
  final String body;
  final List<String> formulas;
  final int order;
  final Map<String, dynamic> metadata;

  const LessonBlock({
    required this.id,
    required this.type,
    this.heading,
    required this.body,
    this.formulas = const [],
    this.order = 0,
    this.metadata = const {},
  });

  /// Création depuis JSON
  factory LessonBlock.fromJson(Map<String, dynamic> json, {int fallbackOrder = 0}) {
    final rawFormulas = json['formulas'] ?? json['latex_formulas'];
    final List<String> parsedFormulas = rawFormulas is List
        ? rawFormulas.map((f) => f.toString()).toList()
        : const [];

    final rawMetadata = json['metadata'];
    final Map<String, dynamic> parsedMetadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : {};

    // Déplacer les champs personnalisés vers metadata s'ils sont à la racine
    for (final entry in json.entries) {
      if (!['id', 'type', 'heading', 'body', 'formulas', 'latex_formulas', 'order', 'metadata'].contains(entry.key)) {
        parsedMetadata[entry.key] = entry.value;
      }
    }

    return LessonBlock(
      id: json['id'] as String? ?? 'blk_${DateTime.now().microsecondsSinceEpoch}',
      type: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim().toLowerCase()
          : 'paragraph',
      heading: json['heading'] as String?,
      body: (json['body'] as String?) ?? '',
      formulas: parsedFormulas,
      order: (json['order'] as num?)?.toInt() ?? fallbackOrder,
      metadata: parsedMetadata,
    );
  }

  /// Sérialisation en JSON canonique
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (heading != null) 'heading': heading,
      'body': body,
      if (formulas.isNotEmpty) 'formulas': formulas,
      'order': order,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Clone avec modifications partielles
  LessonBlock copyWith({
    String? id,
    String? type,
    String? heading,
    String? body,
    List<String>? formulas,
    int? order,
    Map<String, dynamic>? metadata,
  }) {
    return LessonBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      formulas: formulas ?? this.formulas,
      order: order ?? this.order,
      metadata: metadata ?? this.metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory helpers pour créer rapidement des blocs types
  // ---------------------------------------------------------------------------

  /// Paragraphe standard de cours
  factory LessonBlock.paragraph({
    String? heading,
    required String body,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      type: 'paragraph',
      heading: heading,
      body: body,
      order: order,
    );
  }

  /// Définition formelle
  factory LessonBlock.definition({
    String? heading,
    required String body,
    List<String> formulas = const [],
    int order = 0,
  }) {
    return LessonBlock(
      id: 'def_${DateTime.now().microsecondsSinceEpoch}',
      type: 'definition',
      heading: heading ?? 'Définition',
      body: body,
      formulas: formulas,
      order: order,
    );
  }

  /// Théorème
  factory LessonBlock.theorem({
    String? heading,
    required String body,
    List<String> formulas = const [],
    int order = 0,
  }) {
    return LessonBlock(
      id: 'thm_${DateTime.now().microsecondsSinceEpoch}',
      type: 'theoreme',
      heading: heading ?? 'Théorème',
      body: body,
      formulas: formulas,
      order: order,
    );
  }

  /// Formule isolée
  factory LessonBlock.formula({
    String? heading,
    required String latexFormula,
    String? explanation,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'form_${DateTime.now().microsecondsSinceEpoch}',
      type: 'formule',
      heading: heading ?? 'Formule Clé',
      body: explanation ?? '',
      formulas: [latexFormula],
      order: order,
    );
  }

  /// Méthode / Savoir-faire
  factory LessonBlock.method({
    String? heading,
    required String body,
    List<String> steps = const [],
    int order = 0,
  }) {
    return LessonBlock(
      id: 'meth_${DateTime.now().microsecondsSinceEpoch}',
      type: 'methode',
      heading: heading ?? 'Méthode & Savoir-Faire',
      body: body,
      order: order,
      metadata: {'steps': steps},
    );
  }

  /// Exemple guidé
  factory LessonBlock.example({
    String? heading,
    required String body,
    List<String> formulas = const [],
    int order = 0,
  }) {
    return LessonBlock(
      id: 'ex_${DateTime.now().microsecondsSinceEpoch}',
      type: 'exemple',
      heading: heading ?? 'Exemple d\'Application',
      body: body,
      formulas: formulas,
      order: order,
    );
  }

  /// Piège d'examen / Erreur fréquente
  factory LessonBlock.trap({
    String? heading,
    required String body,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'trap_${DateTime.now().microsecondsSinceEpoch}',
      type: 'piege',
      heading: heading ?? 'Attention : Piège Fréquent',
      body: body,
      order: order,
    );
  }

  /// Conseil d'examen
  factory LessonBlock.examTip({
    String? heading,
    required String body,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'tip_${DateTime.now().microsecondsSinceEpoch}',
      type: 'conseil_examen',
      heading: heading ?? 'Conseil pour le Bac / Brevet',
      body: body,
      order: order,
    );
  }

  /// Fiche Récapitulative Visuelle (Trait pour trait)
  factory LessonBlock.summaryCard({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> columns,
    String? keyFormula,
    List<String> bulletPoints = const [],
    String? examTrap,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'sum_${DateTime.now().microsecondsSinceEpoch}',
      type: 'summary_card',
      heading: title,
      body: subtitle,
      formulas: keyFormula != null ? [keyFormula] : const [],
      order: order,
      metadata: {
        'subtitle': subtitle,
        'columns': columns,
        'keyFormula': keyFormula,
        'bulletPoints': bulletPoints,
        'examTrap': examTrap,
      },
    );
  }

  /// Bloc interactif de graphe de fonction (GraphEngine)
  factory LessonBlock.graphPlot({
    String? heading,
    required String expression,
    double xMin = -5,
    double xMax = 5,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'plot_${DateTime.now().microsecondsSinceEpoch}',
      type: 'graph_plot',
      heading: heading ?? 'Tracé de Fonction Interactif',
      body: 'Expression: $expression',
      order: order,
      metadata: {
        'expression': expression,
        'xMin': xMin,
        'xMax': xMax,
      },
    );
  }

  /// Bloc Bac à sable Code / Algorithmique
  factory LessonBlock.codeRunner({
    String? heading,
    required String language,
    required String initialCode,
    String? expectedOutput,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'code_${DateTime.now().microsecondsSinceEpoch}',
      type: 'code_runner',
      heading: heading ?? 'Atelier Programmation ($language)',
      body: initialCode,
      order: order,
      metadata: {
        'language': language,
        'expectedOutput': expectedOutput,
      },
    );
  }

  /// Image pédagogique / illustration générée par IA
  factory LessonBlock.mediaImage({
    String? heading,
    required String imageUrl,
    String? caption,
    String? altText,
    int order = 0,
  }) {
    return LessonBlock(
      id: 'img_${DateTime.now().microsecondsSinceEpoch}',
      type: 'image',
      heading: heading,
      body: caption ?? '',
      order: order,
      metadata: {
        'imageUrl': imageUrl,
        'caption': caption,
        'altText': altText,
      },
    );
  }
}
