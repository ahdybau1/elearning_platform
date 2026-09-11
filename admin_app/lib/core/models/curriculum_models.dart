/// Collecte de programmes → Arbre Académique (migration 83).
library;

class CurriculumImport {
  final String id;
  final String? scopeNodeId;
  final String scopeLabel;
  final List<String> seedUrls;
  final String status; // collecting|proposed|partially_applied|applied|cancelled|failed
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> sourcesConsulted;
  final List<String> gaps;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? appliedAt;

  CurriculumImport({
    required this.id,
    this.scopeNodeId,
    required this.scopeLabel,
    List<String>? seedUrls,
    required this.status,
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? sourcesConsulted,
    List<String>? gaps,
    this.errorMessage,
    required this.createdAt,
    this.appliedAt,
  })  : seedUrls = seedUrls ?? const [],
        summary = summary ?? const {},
        sourcesConsulted = sourcesConsulted ?? const [],
        gaps = gaps ?? const [];

  int get proposed => (summary['proposed'] as int?) ?? 0;
  int get ambiguous => (summary['ambiguous'] as int?) ?? 0;
  int get matched => (summary['matched'] as int?) ?? 0;
  int get chapters => (summary['chapters'] as int?) ?? 0;

  static List<String> _strs(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory CurriculumImport.fromJson(Map<String, dynamic> j) => CurriculumImport(
        id: j['id'] as String,
        scopeNodeId: j['scope_node_id'] as String?,
        scopeLabel: j['scope_label'] as String? ?? '',
        seedUrls: _strs(j['seed_urls']),
        status: j['status'] as String? ?? 'collecting',
        summary: (j['summary'] as Map?)?.cast<String, dynamic>(),
        sourcesConsulted: ((j['sources_consulted'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        gaps: _strs(j['gaps']),
        errorMessage: j['error_message'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        appliedAt: j['applied_at'] != null
            ? DateTime.parse(j['applied_at'] as String)
            : null,
      );
}

class CurriculumImportItem {
  final String id;
  final String importId;
  final String itemKind; // class|series|subject|chapter
  final String proposedName;
  final int displayOrder;
  final String parentPath;
  final double matchConfidence;
  final bool hasMatch;
  final String status; // proposed|verified|applied|rejected|skipped_duplicate
  final String verificationStatus; // ok|ambiguous|incomplete
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceYear;
  final String? sourceExcerpt;

  CurriculumImportItem({
    required this.id,
    required this.importId,
    required this.itemKind,
    required this.proposedName,
    this.displayOrder = 0,
    this.parentPath = '',
    this.matchConfidence = 0,
    this.hasMatch = false,
    required this.status,
    required this.verificationStatus,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceYear,
    this.sourceExcerpt,
  });

  factory CurriculumImportItem.fromJson(Map<String, dynamic> j) =>
      CurriculumImportItem(
        id: j['id'] as String,
        importId: j['import_id'] as String,
        itemKind: j['item_kind'] as String,
        proposedName: j['proposed_name'] as String? ?? '',
        displayOrder: (j['display_order'] as int?) ?? 0,
        parentPath: j['parent_path'] as String? ?? '',
        matchConfidence:
            double.tryParse((j['match_confidence'] ?? 0).toString()) ?? 0,
        hasMatch: j['matched_node_id'] != null ||
            j['matched_subject_id'] != null ||
            j['matched_chapter_id'] != null,
        status: j['status'] as String? ?? 'proposed',
        verificationStatus: j['verification_status'] as String? ?? 'ok',
        sourceTitle: j['source_title'] as String?,
        sourceUrl: j['source_url'] as String?,
        sourceYear: j['source_year'] as String?,
        sourceExcerpt: j['source_excerpt'] as String?,
      );
}
