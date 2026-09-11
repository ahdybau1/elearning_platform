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

/// Un run de l'agent de scraping (découverte web + crawl récursif). Migration 84.
class CurriculumScrapeRun {
  final String id;
  final String? countryCode;
  final String scopeLabel;
  final int maxDepth;
  final int maxPages;
  final String status; // discovering|crawling|extracting|proposed|failed|cancelled
  final Map<String, dynamic> discovery;
  final Map<String, dynamic> stats;
  final String? importId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  CurriculumScrapeRun({
    required this.id,
    this.countryCode,
    required this.scopeLabel,
    this.maxDepth = 2,
    this.maxPages = 120,
    required this.status,
    Map<String, dynamic>? discovery,
    Map<String, dynamic>? stats,
    this.importId,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  })  : discovery = discovery ?? const {},
        stats = stats ?? const {};

  int _s(String k) => (stats[k] as num?)?.toInt() ?? 0;
  int get pagesFetched => _s('pages_fetched');
  int get pagesQueued => _s('pages_queued');
  int get pagesFailed => _s('pages_failed');
  int get domains => _s('domains');
  int get findings => _s('findings');
  int get items => _s('items');
  bool get running =>
      status == 'discovering' || status == 'crawling' || status == 'extracting';

  factory CurriculumScrapeRun.fromJson(Map<String, dynamic> j) =>
      CurriculumScrapeRun(
        id: j['id'] as String,
        countryCode: j['country_code'] as String?,
        scopeLabel: j['scope_label'] as String? ?? '',
        maxDepth: (j['max_depth'] as int?) ?? 2,
        maxPages: (j['max_pages'] as int?) ?? 120,
        status: j['status'] as String? ?? 'discovering',
        discovery: (j['discovery'] as Map?)?.cast<String, dynamic>(),
        stats: (j['stats'] as Map?)?.cast<String, dynamic>(),
        importId: j['import_id'] as String?,
        errorMessage: j['error_message'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
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
