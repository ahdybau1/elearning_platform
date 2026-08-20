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

/// Résultat d'un élève à un examen blanc / une olympiade (Section 11 du CDC).
class EventResult {
  final String id;
  final String eventId;
  final String profileId;
  final String? studentFirstName;
  final String? studentLastName;
  final double score;
  final int? rank;
  final double? percentile;
  final DateTime createdAt;

  EventResult({
    required this.id,
    required this.eventId,
    required this.profileId,
    this.studentFirstName,
    this.studentLastName,
    required this.score,
    this.rank,
    this.percentile,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get studentDisplayName {
    if (studentFirstName != null && studentLastName != null) {
      return '$studentFirstName $studentLastName';
    }
    return profileId;
  }

  factory EventResult.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final account = profile?['accounts'] as Map<String, dynamic>?;
    return EventResult(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      profileId: json['profile_id'] as String,
      studentFirstName: account?['first_name'] as String?,
      studentLastName: account?['last_name'] as String?,
      score: double.parse((json['score'] as num).toString()),
      rank: json['rank'] as int?,
      percentile: json['percentile'] != null ? double.parse((json['percentile'] as num).toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Contestation de note (Section 27 du CDC) — second correcteur obligatoire.
class GradeDispute {
  final String id;
  final String eventResultId;
  final String reason;
  final String status;
  final double originalScore;
  final double? revisedScore;
  final String? assignedReviewerId;
  final String? resolutionNotes;
  final DateTime createdAt;
  final String? studentName;
  final String? eventTitle;

  GradeDispute({
    required this.id,
    required this.eventResultId,
    required this.reason,
    required this.status,
    required this.originalScore,
    this.revisedScore,
    this.assignedReviewerId,
    this.resolutionNotes,
    DateTime? createdAt,
    this.studentName,
    this.eventTitle,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GradeDispute.fromJson(Map<String, dynamic> json) {
    final result = json['event_results'] as Map<String, dynamic>?;
    final profile = result?['profiles'] as Map<String, dynamic>?;
    final account = profile?['accounts'] as Map<String, dynamic>?;
    final event = result?['events'] as Map<String, dynamic>?;
    return GradeDispute(
      id: json['id'] as String,
      eventResultId: json['event_result_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'ouvert',
      originalScore: double.parse((json['original_score'] as num).toString()),
      revisedScore: json['revised_score'] != null ? double.parse((json['revised_score'] as num).toString()) : null,
      assignedReviewerId: json['assigned_reviewer_id'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      studentName: account != null ? '${account['first_name']} ${account['last_name']}' : null,
      eventTitle: event?['title'] as String?,
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
  final bool isActive;
  final DateTime createdAt;

  Establishment({
    required this.id,
    required this.countryId,
    required this.name,
    required this.city,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: json['id'] as String,
      countryId: json['country_id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Épreuve interne d'un établissement (Section 4.2 du CDC) — distincte des examens officiels
/// nationaux : devoirs/compositions propres à un lycée/collège précis.
class EstablishmentPaper {
  final String id;
  final String establishmentId;
  final String classNodeId;
  final String subjectId;
  final int year;
  final String documentUrl;
  final String? correctionUrl;
  final DateTime createdAt;

  EstablishmentPaper({
    required this.id,
    required this.establishmentId,
    required this.classNodeId,
    required this.subjectId,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EstablishmentPaper.fromJson(Map<String, dynamic> json) {
    return EstablishmentPaper(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      classNodeId: json['class_node_id'] as String,
      subjectId: json['subject_id'] as String,
      year: json['year'] as int,
      documentUrl: json['document_url'] as String,
      correctionUrl: json['correction_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Rattachement d'un enseignant à un établissement (Section 22 du CDC : périmètre matières/classes
/// défini indépendamment par établissement).
class TeacherEstablishmentLink {
  final String id;
  final String establishmentId;
  final String establishmentName;
  final String establishmentCity;
  final List<String> subjectsScope;
  final List<String> classesScope;

  TeacherEstablishmentLink({
    required this.id,
    required this.establishmentId,
    required this.establishmentName,
    required this.establishmentCity,
    this.subjectsScope = const [],
    this.classesScope = const [],
  });

  factory TeacherEstablishmentLink.fromJson(Map<String, dynamic> json) {
    final est = json['establishments'] as Map<String, dynamic>?;
    return TeacherEstablishmentLink(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      establishmentName: est?['name'] as String? ?? 'Établissement',
      establishmentCity: est?['city'] as String? ?? '',
      subjectsScope: (json['subjects_scope'] as List?)?.map((e) => e.toString()).toList() ?? [],
      classesScope: (json['classes_scope'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
