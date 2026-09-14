/// WP3 — Centre Sources & Ingestion (migration 79).
library;

class AiSource {
  final String id;
  final String title;
  final String sourceType; // manual_upload | url | document | lesson | ...
  final String? sourceUrl;
  final String? rawText;
  final Map<String, dynamic> crawlRules;
  final String? schedule;
  final bool accessTermsAck;
  final String? provenance;
  final DateTime? collectedAt;
  final String status; // draft | active | paused | archived
  final bool validated;
  final DateTime createdAt;

  AiSource({
    required this.id,
    required this.title,
    required this.sourceType,
    this.sourceUrl,
    this.rawText,
    Map<String, dynamic>? crawlRules,
    this.schedule,
    this.accessTermsAck = false,
    this.provenance,
    this.collectedAt,
    this.status = 'draft',
    this.validated = false,
    required this.createdAt,
  }) : crawlRules = crawlRules ?? const {};

  factory AiSource.fromJson(Map<String, dynamic> j) => AiSource(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Sans titre',
        sourceType: j['source_type'] as String? ?? 'manual_upload',
        sourceUrl: j['source_url'] as String?,
        rawText: j['raw_text'] as String?,
        crawlRules: (j['crawl_rules'] as Map?)?.cast<String, dynamic>(),
        schedule: j['schedule'] as String?,
        accessTermsAck: j['access_terms_ack'] as bool? ?? false,
        provenance: j['provenance'] as String?,
        collectedAt: j['collected_at'] != null
            ? DateTime.parse(j['collected_at'] as String)
            : null,
        status: j['status'] as String? ?? 'draft',
        validated: j['validated'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AiIngestionJob {
  final String id;
  final String sourceId;
  final String jobType; // extract | crawl | classify | embed
  final String status; // queued | running | paused | failed | done | cancelled
  final int progressPct;
  final int attempts;
  final int maxAttempts;
  final List<Map<String, dynamic>> errorHistory;
  final Map<String, dynamic> result;
  final bool cancelRequested;
  final DateTime createdAt;
  final DateTime? finishedAt;

  AiIngestionJob({
    required this.id,
    required this.sourceId,
    required this.jobType,
    required this.status,
    this.progressPct = 0,
    this.attempts = 0,
    this.maxAttempts = 3,
    List<Map<String, dynamic>>? errorHistory,
    Map<String, dynamic>? result,
    this.cancelRequested = false,
    required this.createdAt,
    this.finishedAt,
  })  : errorHistory = errorHistory ?? const [],
        result = result ?? const {};

  bool get isTerminal =>
      status == 'done' || status == 'cancelled';
  bool get canRetry => status == 'failed' && attempts < maxAttempts;

  factory AiIngestionJob.fromJson(Map<String, dynamic> j) => AiIngestionJob(
        id: j['id'] as String,
        sourceId: j['source_id'] as String,
        jobType: j['job_type'] as String,
        status: j['status'] as String? ?? 'queued',
        progressPct: (j['progress_pct'] as int?) ?? 0,
        attempts: (j['attempts'] as int?) ?? 0,
        maxAttempts: (j['max_attempts'] as int?) ?? 3,
        errorHistory: ((j['error_history'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        result: (j['result'] as Map?)?.cast<String, dynamic>(),
        cancelRequested: j['cancel_requested'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        finishedAt: j['finished_at'] != null
            ? DateTime.parse(j['finished_at'] as String)
            : null,
      );
}

class AiExtractedDoc {
  final String id;
  final String sourceId;
  final String? title;
  final String extractedText;
  final Map<String, dynamic> metadata;
  final bool isDuplicate;
  final Map<String, dynamic> classification;
  final String? proposedChapterId;
  final String reviewStatus; // preview | validated | rejected
  final String? rejectionReason;
  final DateTime createdAt;

  AiExtractedDoc({
    required this.id,
    required this.sourceId,
    this.title,
    this.extractedText = '',
    Map<String, dynamic>? metadata,
    this.isDuplicate = false,
    Map<String, dynamic>? classification,
    this.proposedChapterId,
    this.reviewStatus = 'preview',
    this.rejectionReason,
    required this.createdAt,
  })  : metadata = metadata ?? const {},
        classification = classification ?? const {};

  int get wordCount =>
      int.tryParse(metadata['word_count']?.toString() ?? '') ?? 0;

  factory AiExtractedDoc.fromJson(Map<String, dynamic> j) => AiExtractedDoc(
        id: j['id'] as String,
        sourceId: j['source_id'] as String,
        title: j['title'] as String?,
        extractedText: j['extracted_text'] as String? ?? '',
        metadata: (j['metadata'] as Map?)?.cast<String, dynamic>(),
        isDuplicate: j['is_duplicate'] as bool? ?? false,
        classification:
            (j['classification'] as Map?)?.cast<String, dynamic>(),
        proposedChapterId: j['proposed_chapter_id'] as String?,
        reviewStatus: j['review_status'] as String? ?? 'preview',
        rejectionReason: j['rejection_reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
