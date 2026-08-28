/// Bloc de contenu pédagogique structuré générique.
///
/// Remplace la lecture de clés fixes codées en dur (`contentJson['theoreme']`,
/// `contentJson['formule']`, ...) par une liste de blocs typés, résolus au rendu par
/// `BlockRendererRegistry` (voir `.agents/skills/pedagogical-renderer/SKILL.md` et la section U2.3 de
/// `docs/CAHIER_DES_CHARGES_MASTER_MAJ_2026.md` : « ne pas hardcoder une longue chaîne de if par type »).
///
/// CF-001 : voir `docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md`.
class ContentBlock {
  /// Type du bloc — détermine le renderer utilisé. Valeurs connues aujourd'hui : `paragraph`,
  /// `definition`, `theoreme`, `formule`, `methode`, `exemple`, `piege`, `conseil_examen`. Un type
  /// inconnu tombe sur un rendu paragraphe sûr (jamais de crash — voir `BlockRendererRegistry`).
  final String type;
  final String? heading;
  final String body;
  final List<String> formulas;
  final int order;

  const ContentBlock({
    required this.type,
    this.heading,
    required this.body,
    this.formulas = const [],
    this.order = 0,
  });

  /// Format natif futur : `content_json['blocks'] = [ {type, heading, body, formulas, order}, ... ]`.
  factory ContentBlock.fromJson(Map<String, dynamic> json, {int fallbackOrder = 0}) {
    final rawFormulas = json['formulas'];
    return ContentBlock(
      type: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim().toLowerCase()
          : 'paragraph',
      heading: json['heading'] as String?,
      body: (json['body'] as String?) ?? '',
      formulas: rawFormulas is List
          ? rawFormulas.map((f) => f.toString()).toList()
          : const [],
      order: (json['order'] as num?)?.toInt() ?? fallbackOrder,
    );
  }

  /// Une section produite par l'edge function `ai-course-structuring`
  /// (`{heading, type: 'theoreme'|'definition'|'formule'|'methode'|'exemple', body, latex_formulas}`).
  factory ContentBlock.fromAiSection(Map<String, dynamic> section, int order) {
    final rawFormulas = section['latex_formulas'];
    return ContentBlock(
      type: (section['type'] as String?)?.trim().isNotEmpty == true
          ? (section['type'] as String).trim().toLowerCase()
          : 'paragraph',
      heading: section['heading'] as String?,
      body: (section['body'] as String?) ?? '',
      formulas: rawFormulas is List
          ? rawFormulas.map((f) => f.toString()).toList()
          : const [],
      order: order,
    );
  }
}
