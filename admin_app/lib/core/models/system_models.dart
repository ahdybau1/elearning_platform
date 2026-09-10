/// IA-001 "Contracts" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, migration 55) : registre réel des
/// agents IA déployés. Une version par agent aujourd'hui (1.0.0), reliée à l'Edge Function Deno qui
/// l'exécute réellement — pas encore de Sovereign AI Gateway FastAPI (IA-002+).
class AiAgentVersion {
  final String id;
  final String version;
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic> outputSchema;
  final Map<String, dynamic> modelPolicy;
  final String quotaClass;
  final String status; // 'draft' | 'candidate' | 'production' | 'retired'
  final String? edgeFunctionName;
  // WP2 — Control Plane : champs administrables (migration 78).
  final String? promptTemplate;
  final String? promptNotes;
  final List<String> allowedTools;
  final List<String> allowedSources;
  final Map<String, dynamic> limits; // {max_tokens, timeout_ms, max_concurrency}
  final Map<String, dynamic> fallbackStrategy; // {retry, backoff_ms, fallback_agent}

  AiAgentVersion({
    required this.id,
    required this.version,
    Map<String, dynamic>? inputSchema,
    Map<String, dynamic>? outputSchema,
    Map<String, dynamic>? modelPolicy,
    this.quotaClass = 'standard',
    this.status = 'draft',
    this.edgeFunctionName,
    this.promptTemplate,
    this.promptNotes,
    List<String>? allowedTools,
    List<String>? allowedSources,
    Map<String, dynamic>? limits,
    Map<String, dynamic>? fallbackStrategy,
  })  : inputSchema = inputSchema ?? {},
        outputSchema = outputSchema ?? {},
        modelPolicy = modelPolicy ?? {},
        allowedTools = allowedTools ?? const [],
        allowedSources = allowedSources ?? const [],
        limits = limits ?? {},
        fallbackStrategy = fallbackStrategy ?? {};

  static List<String> _strList(dynamic raw) => (raw as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const [];

  factory AiAgentVersion.fromJson(Map<String, dynamic> json) => AiAgentVersion(
        id: json['id'] as String,
        version: json['version'] as String,
        inputSchema: (json['input_schema'] as Map?)?.cast<String, dynamic>(),
        outputSchema: (json['output_schema'] as Map?)?.cast<String, dynamic>(),
        modelPolicy: (json['model_policy'] as Map?)?.cast<String, dynamic>(),
        quotaClass: json['quota_class'] as String? ?? 'standard',
        status: json['status'] as String? ?? 'draft',
        edgeFunctionName: json['edge_function_name'] as String?,
        promptTemplate: json['prompt_template'] as String?,
        promptNotes: json['prompt_notes'] as String?,
        allowedTools: _strList(json['allowed_tools']),
        allowedSources: _strList(json['allowed_sources']),
        limits: (json['limits'] as Map?)?.cast<String, dynamic>(),
        fallbackStrategy:
            (json['fallback_strategy'] as Map?)?.cast<String, dynamic>(),
      );
}

class AiAgent {
  final String id;
  final String agentId;
  final String name;
  final String mission;
  final String? nonMission;
  final String? catalogueRelation;
  final String status; // 'draft' | 'active' | 'deprecated'
  final String? owner;
  final List<AiAgentVersion> versions;
  // WP2 — Control Plane (migration 78).
  final bool enabled;
  final bool requiresHumanReview;
  final List<String> dependsOn;
  final String runtime; // 'edge_function' | 'gateway_native' | 'none'
  final String? description;

  AiAgent({
    required this.id,
    required this.agentId,
    required this.name,
    required this.mission,
    this.nonMission,
    this.catalogueRelation,
    this.status = 'draft',
    this.owner,
    List<AiAgentVersion>? versions,
    this.enabled = true,
    this.requiresHumanReview = false,
    List<String>? dependsOn,
    this.runtime = 'edge_function',
    this.description,
  })  : versions = versions ?? [],
        dependsOn = dependsOn ?? const [];

  /// L'agent est réellement exécutable depuis l'admin aujourd'hui.
  bool get isOnline =>
      enabled &&
      runtime == 'edge_function' &&
      versions.isNotEmpty &&
      (versions.first.edgeFunctionName ?? '').isNotEmpty &&
      versions.first.edgeFunctionName != 'gateway_native';

  String get offlineReason {
    if (!enabled) return 'Désactivé';
    if (runtime == 'gateway_native') {
      return 'Défini côté Gateway FastAPI (non déployé) — hors ligne';
    }
    if (runtime == 'none' || versions.isEmpty) {
      return 'Aucune implémentation rattachée (brouillon)';
    }
    return 'Aucune Edge Function rattachée';
  }

  factory AiAgent.fromJson(Map<String, dynamic> json) => AiAgent(
        id: json['id'] as String,
        agentId: json['agent_id'] as String,
        name: json['name'] as String,
        mission: json['mission'] as String,
        nonMission: json['non_mission'] as String?,
        catalogueRelation: json['catalogue_relation'] as String?,
        status: json['status'] as String? ?? 'draft',
        owner: json['owner'] as String?,
        versions: ((json['ai_agent_versions'] as List?) ?? const [])
            .map((v) => AiAgentVersion.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        enabled: json['enabled'] as bool? ?? true,
        requiresHumanReview: json['requires_human_review'] as bool? ?? false,
        dependsOn: AiAgentVersion._strList(json['depends_on']),
        runtime: json['runtime'] as String? ?? 'edge_function',
        description: json['description'] as String?,
      );
}

/// WP2 — une exécution unitaire d'un agent (table `ai_agent_runs`, migration 78).
class AiAgentRun {
  final String id;
  final String agentKey;
  final String trigger; // manual_test | workflow | production
  final String status; // running | success | failed | cancelled
  final bool? outputValid;
  final String? errorMessage;
  final Map<String, dynamic>? inputPreview;
  final Map<String, dynamic>? output;
  final int tokensUsed;
  final int? durationMs;
  final DateTime createdAt;
  final DateTime? completedAt;

  AiAgentRun({
    required this.id,
    required this.agentKey,
    required this.trigger,
    required this.status,
    this.outputValid,
    this.errorMessage,
    this.inputPreview,
    this.output,
    this.tokensUsed = 0,
    this.durationMs,
    required this.createdAt,
    this.completedAt,
  });

  bool get isFailed => status == 'failed';

  factory AiAgentRun.fromJson(Map<String, dynamic> json) => AiAgentRun(
        id: json['id'] as String,
        agentKey: json['agent_key'] as String? ?? '',
        trigger: json['trigger'] as String? ?? 'manual_test',
        status: json['status'] as String? ?? 'running',
        outputValid: json['output_valid'] as bool?,
        errorMessage: json['error_message'] as String?,
        inputPreview: (json['input_preview'] as Map?)?.cast<String, dynamic>(),
        output: (json['output'] as Map?)?.cast<String, dynamic>(),
        tokensUsed: (json['tokens_used'] as int?) ?? 0,
        durationMs: json['duration_ms'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );
}

/// WP2 — un workflow multi-agents (tables `ai_workflows` / `ai_workflow_steps`, migration 78).
class AiWorkflow {
  final String id;
  final String workflowKey;
  final String title;
  final String status; // pending|running|paused|completed|failed|cancelled
  final int progressPct;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiWorkflowStep> steps;

  AiWorkflow({
    required this.id,
    required this.workflowKey,
    required this.title,
    required this.status,
    this.progressPct = 0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    List<AiWorkflowStep>? steps,
  }) : steps = steps ?? const [];

  factory AiWorkflow.fromJson(Map<String, dynamic> json) => AiWorkflow(
        id: json['id'] as String,
        workflowKey: json['workflow_key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        progressPct: (json['progress_pct'] as int?) ?? 0,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        steps: ((json['ai_workflow_steps'] as List?) ?? const [])
            .map((s) => AiWorkflowStep.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList()
          ..sort((a, b) => a.stepIndex.compareTo(b.stepIndex)),
      );
}

class AiWorkflowStep {
  final String id;
  final int stepIndex;
  final String agentKey;
  final String title;
  final String status; // pending|running|success|failed|skipped
  final String? errorMessage;

  AiWorkflowStep({
    required this.id,
    required this.stepIndex,
    required this.agentKey,
    required this.title,
    required this.status,
    this.errorMessage,
  });

  factory AiWorkflowStep.fromJson(Map<String, dynamic> json) => AiWorkflowStep(
        id: json['id'] as String,
        stepIndex: (json['step_index'] as int?) ?? 0,
        agentKey: json['agent_key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        errorMessage: json['error_message'] as String?,
      );
}

/// CF-004 (docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md, migration 53) : request_id/model/
/// duration_ms/status/error_message sont réels depuis le 2026-08-28 — avant cette migration, un
/// appel IA échoué n'était même pas enregistré du tout (invisible), et le modèle exact utilisé
/// (Claude vs Gemini, quelle version) n'était jamais persisté.
class AiAgentCall {
  final String id;
  final String? requestId;
  final String agentType;
  final String provider;
  final String? model;
  final int tokensUsed;
  final double costEstimate;
  final int? durationMs;
  final String status; // 'success' | 'failed'
  final String? errorMessage;
  final DateTime createdAt;

  AiAgentCall({
    required this.id,
    this.requestId,
    required this.agentType,
    required this.provider,
    this.model,
    required this.tokensUsed,
    required this.costEstimate,
    this.durationMs,
    this.status = 'success',
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFailed => status == 'failed';

  factory AiAgentCall.fromJson(Map<String, dynamic> json) {
    return AiAgentCall(
      id: json['id'] as String,
      requestId: json['request_id'] as String?,
      agentType: json['agent_type'] as String,
      provider: json['provider'] as String,
      model: json['model'] as String?,
      tokensUsed: (json['tokens_used'] as int?) ?? 0,
      costEstimate: double.parse(
          (json['cost_estimate'] as num?)?.toString() ?? '0'),
      durationMs: json['duration_ms'] as int?,
      status: json['status'] as String? ?? 'success',
      errorMessage: json['error_message'] as String?,
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
  final String processingStatus;
  final DateTime createdAt;

  ExamPaper({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
    this.isCorrectionUnlocked = false,
    this.processingStatus = 'not_started',
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
      processingStatus:
          (json['processing_status'] as String?) ?? 'not_started',
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
  final String? termId;
  final int year;
  final String documentUrl;
  final String? correctionUrl;
  final String processingStatus;
  final DateTime createdAt;

  EstablishmentPaper({
    required this.id,
    required this.establishmentId,
    required this.classNodeId,
    required this.subjectId,
    this.termId,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
    this.processingStatus = 'not_started',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EstablishmentPaper.fromJson(Map<String, dynamic> json) {
    return EstablishmentPaper(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      classNodeId: json['class_node_id'] as String,
      subjectId: json['subject_id'] as String,
      termId: json['term_id'] as String?,
      year: json['year'] as int,
      documentUrl: json['document_url'] as String,
      correctionUrl: json['correction_url'] as String?,
      processingStatus:
          (json['processing_status'] as String?) ?? 'not_started',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Question extraite par l'IA (Exam Resource Factory, docs/CAHIER_IA_ZERO_COUT_MASTER.md, Annexe
/// D.8-D.9) à partir d'un sujet national (`examPaperId`) ou d'établissement
/// (`establishmentPaperId`) — exactement un des deux est renseigné. Reste `waiting_review` tant
/// qu'un admin ne l'a pas relue.
class ExamPaperQuestion {
  final int revision;
  final String id;
  final String? examPaperId;
  final String? establishmentPaperId;
  final int questionOrder;
  final String statement;
  final String? proposedAnswer;
  final double? confidence;
  final String status;
  final String? reviewerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamPaperQuestion({
    this.revision = 1,
    required this.id,
    this.examPaperId,
    this.establishmentPaperId,
    required this.questionOrder,
    required this.statement,
    this.proposedAnswer,
    this.confidence,
    this.status = 'waiting_review',
    this.reviewerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ExamPaperQuestion.fromJson(Map<String, dynamic> json) {
    return ExamPaperQuestion(
      revision: (json['revision'] as int?) ?? 1,
      id: json['id'] as String,
      examPaperId: json['exam_paper_id'] as String?,
      establishmentPaperId: json['establishment_paper_id'] as String?,
      questionOrder: (json['question_order'] as int?) ?? 0,
      statement: json['statement'] as String,
      proposedAnswer: json['proposed_answer'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      status: (json['status'] as String?) ?? 'waiting_review',
      reviewerNotes: json['reviewer_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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

class AppSettings {
  final String id;
  final String appName;
  final String? tagline;
  final String? supportEmail;
  final String? supportPhone;
  final String? supportWhatsappLink;
  final String? termsUrl;
  final String? privacyPolicyUrl;
  final String? legalNoticeUrl;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? minSupportedAppVersion;
  final List<String> enabledLanguages;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    required this.appName,
    this.tagline,
    this.supportEmail,
    this.supportPhone,
    this.supportWhatsappLink,
    this.termsUrl,
    this.privacyPolicyUrl,
    this.legalNoticeUrl,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minSupportedAppVersion,
    this.enabledLanguages = const ['fr'],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] as String,
      appName: json['app_name'] as String? ?? 'pq learn',
      tagline: json['tagline'] as String?,
      supportEmail: json['support_email'] as String?,
      supportPhone: json['support_phone'] as String?,
      supportWhatsappLink: json['support_whatsapp_link'] as String?,
      termsUrl: json['terms_url'] as String?,
      privacyPolicyUrl: json['privacy_policy_url'] as String?,
      legalNoticeUrl: json['legal_notice_url'] as String?,
      maintenanceMode: (json['maintenance_mode'] as bool?) ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      minSupportedAppVersion: json['min_supported_app_version'] as String?,
      enabledLanguages:
          (json['enabled_languages'] as List?)?.map((e) => e.toString()).toList() ?? const ['fr'],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Tentative d'exercice rédigée (reponse_courte/redaction), avec la proposition de CorrectionAgent
/// (AIA-AGT-005) si elle a déjà tourné. `officialCorrect` reste `null` tant qu'un admin n'a pas
/// validé — jamais écrit par l'IA elle-même (voir supabase/functions/ai-correction/index.ts).
class ExerciseAttemptForReview {
  final String id;
  final String exerciseId;
  final String? exerciseTitle;
  final String statement;
  final String submittedText;
  final double? aiScore;
  final double? aiConfidence;
  final String? aiFeedback;
  final List<String> aiMisconceptions;
  final bool needsHumanReview;
  final bool? officialCorrect;
  final DateTime createdAt;

  ExerciseAttemptForReview({
    required this.id,
    required this.exerciseId,
    this.exerciseTitle,
    required this.statement,
    required this.submittedText,
    this.aiScore,
    this.aiConfidence,
    this.aiFeedback,
    this.aiMisconceptions = const [],
    this.needsHumanReview = false,
    this.officialCorrect,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCorrected => aiScore != null;

  factory ExerciseAttemptForReview.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercises'] as Map<String, dynamic>?;
    final instructions = exercise?['instructions_json'] as Map<String, dynamic>?;
    final submitted = json['submitted_answer'] as Map<String, dynamic>?;
    return ExerciseAttemptForReview(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseTitle: exercise?['title'] as String?,
      statement: (instructions?['statement'] as String?) ?? '',
      submittedText: (submitted?['text'] as String?) ?? '',
      aiScore: (json['ai_score'] as num?)?.toDouble(),
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      aiFeedback: json['ai_feedback'] as String?,
      aiMisconceptions:
          (json['ai_misconceptions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      needsHumanReview: (json['needs_human_review'] as bool?) ?? false,
      officialCorrect: json['official_correct'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
