import '../models/enums.dart';

class Subject {
  final String id;
  final String name;
  final String code;
  final String? countryId;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.countryId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      countryId: json['country_id'] as String?,
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
        'created_at': createdAt.toIso8601String(),
      };
}

class Chapter {
  final String id;
  final String subjectId;
  final String? termId;
  final String title;
  final String? introduction;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Lesson> lessons;

  Chapter({
    required this.id,
    required this.subjectId,
    this.termId,
    required this.title,
    this.introduction,
    this.displayOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Lesson>? lessons,
  })  : createdAt = createdAt ?? DateTime.now(),
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
      termId: json['term_id'] as String?,
      title: json['title'] as String,
      introduction: json['introduction'] as String?,
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
        'term_id': termId,
        'title': title,
        'introduction': introduction,
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
  final DateTime createdAt;

  Term({
    required this.id,
    required this.countryId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.schoolYear,
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
        'min_subscription_tier': minSubscriptionTier,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class Exercise {
  final String id;
  final String? lessonId;
  final String? chapterId;
  final ExerciseType type;
  final ExerciseDifficulty difficulty;
  final ExerciseFormat format;
  final String title;
  final Map<String, dynamic> instructionsJson;
  final Map<String, dynamic> solutionJson;
  final String minSubscriptionTier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExerciseVersion> versions;

  Exercise({
    required this.id,
    this.lessonId,
    this.chapterId,
    required this.type,
    required this.difficulty,
    required this.format,
    required this.title,
    Map<String, dynamic>? instructionsJson,
    Map<String, dynamic>? solutionJson,
    this.minSubscriptionTier = 'gratuit',
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
      type: ExerciseType.training,
      difficulty: ExerciseDifficulty.facile,
      format: ExerciseFormat.qcm,
      title: json['title'] as String,
      instructionsJson:
          Map<String, dynamic>.from(json['instructions_json'] ?? {}),
      solutionJson:
          Map<String, dynamic>.from(json['solution_json'] ?? {}),
      minSubscriptionTier:
          json['min_subscription_tier'] as String? ?? 'gratuit',
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
        'type': type.toString().split('.').last,
        'difficulty': difficulty.toString().split('.').last,
        'format': format.toString().split('.').last,
        'title': title,
        'instructions_json': instructionsJson,
        'solution_json': solutionJson,
        'min_subscription_tier': minSubscriptionTier,
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
  })  : aiReportJson = aiReportJson ?? {},
        createdAt = createdAt ?? DateTime.now();

  factory ValidationQueueItem.fromJson(Map<String, dynamic> json) {
    return ValidationQueueItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      contentType: ContentType.lesson,
      authorId: json['author_id'] as String,
      status: ValidationStatus.brouillon,
      aiReportJson: Map<String, dynamic>.from(json['ai_report_json'] ?? {}),
      reviewerId: json['reviewer_id'] as String?,
      reviewNotes: json['review_notes'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content_id': contentId,
        'content_type':
            contentType.toString().split('.').last,
        'author_id': authorId,
        'status': status.toString().split('.').last,
        'ai_report_json': aiReportJson,
        'reviewer_id': reviewerId,
        'review_notes': reviewNotes,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
