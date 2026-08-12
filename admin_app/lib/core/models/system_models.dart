class AiAgentCall {
  final String id;
  final String agentType;
  final String provider;
  final int tokensUsed;
  final double costEstimate;
  final DateTime createdAt;

  AiAgentCall({
    required this.id,
    required this.agentType,
    required this.provider,
    required this.tokensUsed,
    required this.costEstimate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AiAgentCall.fromJson(Map<String, dynamic> json) {
    return AiAgentCall(
      id: json['id'] as String,
      agentType: json['agent_type'] as String,
      provider: json['provider'] as String,
      tokensUsed: (json['tokens_used'] as int?) ?? 0,
      costEstimate: double.parse(
          (json['cost_estimate'] as num?)?.toString() ?? '0'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class NotificationTemplate {
  final String id;
  final String eventKey;
  final String channel;
  final String titleTemplate;
  final String bodyTemplate;
  final DateTime createdAt;

  NotificationTemplate({
    required this.id,
    required this.eventKey,
    required this.channel,
    required this.titleTemplate,
    required this.bodyTemplate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory NotificationTemplate.fromJson(Map<String, dynamic> json) {
    return NotificationTemplate(
      id: json['id'] as String,
      eventKey: json['event_key'] as String,
      channel: json['channel'] as String,
      titleTemplate: json['title_template'] as String,
      bodyTemplate: json['body_template'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final String urgency;
  final String? targetCountryId;
  final String? targetClassId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.urgency,
    this.targetCountryId,
    this.targetClassId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      urgency: json['urgency'] as String? ?? 'info',
      targetCountryId: json['target_country_id'] as String?,
      targetClassId: json['target_class_id'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class Event {
  final String id;
  final String type;
  final String countryId;
  final String classNodeId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String pricingMode;
  final double price;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.type,
    required this.countryId,
    required this.classNodeId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.pricingMode,
    required this.price,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      type: json['type'] as String,
      countryId: json['country_id'] as String,
      classNodeId: json['class_node_id'] as String,
      title: json['title'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      pricingMode: json['pricing_mode'] as String? ?? 'inclus',
      price: double.parse((json['price'] as num?)?.toString() ?? '0'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class OfficialExam {
  final String id;
  final String countryId;
  final String classNodeId;
  final String name;
  final DateTime? examDate;
  final DateTime createdAt;
  final List<ExamPaper> papers;

  OfficialExam({
    required this.id,
    required this.countryId,
    required this.classNodeId,
    required this.name,
    this.examDate,
    DateTime? createdAt,
    List<ExamPaper>? papers,
  })  : createdAt = createdAt ?? DateTime.now(),
        papers = papers ?? [];

  factory OfficialExam.fromJson(Map<String, dynamic> json) {
    final papersData = json['papers'];
    final List<ExamPaper> parsedPapers;
    if (papersData != null && papersData is List) {
      parsedPapers = papersData
          .map((p) => ExamPaper.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    } else {
      parsedPapers = [];
    }

    return OfficialExam(
      id: json['id'] as String,
      countryId: json['country_id'] as String,
      classNodeId: json['class_node_id'] as String,
      name: json['name'] as String,
      examDate: json['exam_date'] != null
          ? DateTime.parse(json['exam_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      papers: parsedPapers,
    );
  }
}

class ExamPaper {
  final String id;
  final String examId;
  final String subjectId;
  final int year;
  final String documentUrl;
  final String? correctionUrl;
  final bool isCorrectionUnlocked;
  final DateTime createdAt;

  ExamPaper({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
    this.isCorrectionUnlocked = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExamPaper.fromJson(Map<String, dynamic> json) {
    return ExamPaper(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      subjectId: json['subject_id'] as String,
      year: (json['year'] as int?) ?? DateTime.now().year,
      documentUrl: json['document_url'] as String,
      correctionUrl: json['correction_url'] as String?,
      isCorrectionUnlocked:
          (json['is_correction_unlocked'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class Establishment {
  final String id;
  final String countryId;
  final String name;
  final String city;
  final DateTime createdAt;

  Establishment({
    required this.id,
    required this.countryId,
    required this.name,
    required this.city,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: json['id'] as String,
      countryId: json['country_id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
