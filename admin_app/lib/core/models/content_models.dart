import '../models/enums.dart';

class Subject {
  final String id;
  final String name;
  final String code;
  final String? countryId;
  final bool isActive;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.countryId,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      countryId: json['country_id'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'country_id': countryId,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

class Chapter {
  final String id;
  final String subjectId;
  final String? classNodeId;
  final String? termId;
  final String title;
  final String? introduction;
  final List<Map<String, dynamic>> introMedia;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Lesson> lessons;

  Chapter({
    required this.id,
    required this.subjectId,
    this.classNodeId,
    this.termId,
    required this.title,
    this.introduction,
    List<Map<String, dynamic>>? introMedia,
    this.displayOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Lesson>? lessons,
  })  : introMedia = introMedia ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        lessons = lessons ?? [];

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final lessonsData = json['lessons'];
    final List<Lesson> parsedLessons;
    if (lessonsData != null && lessonsData is List) {
      parsedLessons = lessonsData
          .map((l) => Lesson.fromJson(Map<String, dynamic>.from(l)))
          .toList();
    } else {
      parsedLessons = [];
    }

    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      classNodeId: json['class_node_id'] as String?,
      termId: json['term_id'] as String?,
      title: json['title'] as String,
      introduction: json['introduction'] as String?,
      introMedia: ((json['intro_media_json'] as List?) ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList(),
      displayOrder: (json['display_order'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      lessons: parsedLessons,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'class_node_id': classNodeId,
        'term_id': termId,
        'title': title,
        'introduction': introduction,
        'intro_media_json': introMedia,
        'display_order': displayOrder,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class Term {
  final String id;
  final String countryId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String schoolYear;
  final bool isActive;
  final DateTime createdAt;

  Term({
    required this.id,
    required this.countryId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.schoolYear,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      id: json['id'] as String,
      countryId: json['country_id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      schoolYear: json['school_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country_id': countryId,
        'name': name,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'school_year': schoolYear,
        'created_at': createdAt.toIso8601String(),
      };
}

class Lesson {
  final String id;
  final String chapterId;
  final String title;
  final Map<String, dynamic> contentJson;
  final int displayOrder;
  final bool isPublished;
  final bool isActive;
  final String minSubscriptionTier;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lesson({
    required this.id,
    required this.chapterId,
    required this.title,
    Map<String, dynamic>? contentJson,
    this.displayOrder = 0,
    this.isPublished = false,
    this.isActive = true,
    this.minSubscriptionTier = 'gratuit',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : contentJson = contentJson ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      contentJson:
          Map<String, dynamic>.from(json['content_json'] ?? {}),
      displayOrder: (json['display_order'] as int?) ?? 0,
      isPublished: (json['is_published'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      minSubscriptionTier: json['min_subscription_tier'] as String? ?? 'gratuit',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter_id': chapterId,
        'title': title,
        'content_json': contentJson,
        'display_order': displayOrder,
        'is_published': isPublished,
        'is_active': isActive,
        'min_subscription_tier': minSubscriptionTier,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class LessonVersion {
  final String id;
  final String lessonId;
  final int versionNumber;
  final Map<String, dynamic> contentJson;
  final String publishedBy;
  final DateTime publishedAt;

  LessonVersion({
    required this.id,
    required this.lessonId,
    required this.versionNumber,
    required this.contentJson,
    required this.publishedBy,
    DateTime? publishedAt,
  }) : publishedAt = publishedAt ?? DateTime.now();

  factory LessonVersion.fromJson(Map<String, dynamic> json) {
    return LessonVersion(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      versionNumber: (json['version_number'] as int?) ?? 1,
      contentJson: Map<String, dynamic>.from(json['content_json'] ?? {}),
      publishedBy: json['published_by'] as String,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
    );
  }
}

class Exercise {
  final String id;
  final String? lessonId;
  final String? chapterId;
  final String? classNodeId;
  final String? termId;
  final ExerciseType type;
  final ExerciseDifficulty difficulty;
  final ExerciseFormat format;
  final String title;
  final Map<String, dynamic> instructionsJson;
  final Map<String, dynamic> solutionJson;
  final String minSubscriptionTier;
  final bool isPublished;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExerciseVersion> versions;

  Exercise({
    required this.id,
    this.lessonId,
    this.chapterId,
    this.classNodeId,
    this.termId,
    required this.type,
    required this.difficulty,
    required this.format,
    required this.title,
    Map<String, dynamic>? instructionsJson,
    Map<String, dynamic>? solutionJson,
    this.minSubscriptionTier = 'gratuit',
    this.isPublished = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ExerciseVersion>? versions,
  })  : instructionsJson = instructionsJson ?? {},
        solutionJson = solutionJson ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        versions = versions ?? [];

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      classNodeId: json['class_node_id'] as String?,
      termId: json['term_id'] as String?,
      type: exerciseTypeFromDb(json['type'] as String?),
      difficulty: exerciseDifficultyFromDb(json['difficulty'] as String?),
      format: exerciseFormatFromDb(json['format'] as String?),
      title: json['title'] as String,
      instructionsJson:
          Map<String, dynamic>.from(json['instructions_json'] ?? {}),
      solutionJson:
          Map<String, dynamic>.from(json['solution_json'] ?? {}),
      minSubscriptionTier:
          json['min_subscription_tier'] as String? ?? 'gratuit',
      isPublished: (json['is_published'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'chapter_id': chapterId,
        'class_node_id': classNodeId,
        'term_id': termId,
        'type': exerciseTypeToDb(type),
        'difficulty': exerciseDifficultyToDb(difficulty),
        'format': exerciseFormatToDb(format),
        'title': title,
        'instructions_json': instructionsJson,
        'solution_json': solutionJson,
        'min_subscription_tier': minSubscriptionTier,
        'is_published': isPublished,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ExerciseVersion {
  final String id;
  final String exerciseId;
  final int versionNumber;
  final Map<String, dynamic> contentJson;
  final String publishedBy;
  final DateTime publishedAt;

  ExerciseVersion({
    required this.id,
    required this.exerciseId,
    required this.versionNumber,
    required this.contentJson,
    required this.publishedBy,
    DateTime? publishedAt,
  }) : publishedAt = publishedAt ?? DateTime.now();

  factory ExerciseVersion.fromJson(Map<String, dynamic> json) {
    return ExerciseVersion(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      versionNumber: (json['version_number'] as int?) ?? 1,
      contentJson: Map<String, dynamic>.from(json['content_json'] ?? {}),
      publishedBy: json['published_by'] as String,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
    );
  }
}

class ValidationQueueItem {
  final String id;
  final String contentId;
  final ContentType contentType;
  final String authorId;
  final ValidationStatus status;
  final Map<String, dynamic> aiReportJson;
  final String? reviewerId;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? title; // from joined content row or ai_report_json metadata

  ValidationQueueItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.authorId,
    required this.status,
    Map<String, dynamic>? aiReportJson,
    this.reviewerId,
    this.reviewNotes,
    this.reviewedAt,
    DateTime? createdAt,
    this.title,
  })  : aiReportJson = aiReportJson ?? {},
        createdAt = createdAt ?? DateTime.now();

  static ContentType _parseContentType(String? raw) {
    switch (raw) {
      case 'exercise':
        return ContentType.exercise;
      default:
        return ContentType.lesson;
    }
  }

  static ValidationStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'en_attente':
        return ValidationStatus.enAttente;
      case 'approuve':
        return ValidationStatus.approuve;
      case 'rejete':
        return ValidationStatus.rejete;
      case 'a_corriger':
        return ValidationStatus.aCorriger;
      default:
        return ValidationStatus.brouillon;
    }
  }

  factory ValidationQueueItem.fromJson(Map<String, dynamic> json) {
    final aiReport = Map<String, dynamic>.from(json['ai_report_json'] ?? {});
    // title can come from joined content row or ai_report metadata
    final title = json['title'] as String? ??
        aiReport['title'] as String? ??
        json['content_id'] as String?;
    return ValidationQueueItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      contentType: _parseContentType(json['content_type'] as String?),
      authorId: json['author_id'] as String,
      status: _parseStatus(json['status'] as String?),
      aiReportJson: aiReport,
      reviewerId: json['reviewer_id'] as String?,
      reviewNotes: json['review_notes'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      title: title,
    );
  }

  /// Returns DB string for the status field
  String get statusString {
    switch (status) {
      case ValidationStatus.enAttente:
        return 'en_attente';
      case ValidationStatus.approuve:
        return 'approuve';
      case ValidationStatus.rejete:
        return 'rejete';
      case ValidationStatus.aCorriger:
        return 'a_corriger';
      default:
        return 'brouillon';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content_id': contentId,
        'content_type': contentType.name,
        'author_id': authorId,
        'status': statusString,
        'ai_report_json': aiReportJson,
        'reviewer_id': reviewerId,
        'review_notes': reviewNotes,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

class MediaAsset {
  final String id;
  final String filename;
  final String type; // image, video, audio, document
  final String url;
  final int? sizeBytes;
  final String uploadedBy;
  final DateTime createdAt;

  MediaAsset({
    required this.id,
    required this.filename,
    required this.type,
    required this.url,
    this.sizeBytes,
    required this.uploadedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] as String,
      filename: json['filename'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      sizeBytes: json['size_bytes'] as int?,
      uploadedBy: json['uploaded_by'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class ContentCatalogItem {
  final String id;
  final String subjectId;
  final String elementType;
  final String? description;
  final DateTime createdAt;

  ContentCatalogItem({
    required this.id,
    required this.subjectId,
    required this.elementType,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ContentCatalogItem.fromJson(Map<String, dynamic> json) {
    return ContentCatalogItem(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      elementType: json['element_type'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'element_type': elementType,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}

