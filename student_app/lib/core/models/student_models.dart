class StudentAccount {
  final String id;
  final String phoneNumber;
  final String? email;
  final bool isParentAccount;
  final String? parentPin;
  final DateTime createdAt;

  StudentAccount({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.isParentAccount = false,
    this.parentPin,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String? ?? '',
      email: json['email'] as String?,
      isParentAccount: json['is_parent_account'] as bool? ?? false,
      parentPin: json['parent_pin'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class StudentProfile {
  final String id;
  final String accountId;
  final String name;
  final String? avatarUrl;
  final String classNodeId;
  final String className;
  final String? schoolName;
  final String countryId;
  final String activeTier; // 'gratuit', 'decouverte', 'mensuel', 'annuel'
  final DateTime? tierExpiresAt;
  final int totalPoints;
  final int streakDays;
  final DateTime createdAt;

  StudentProfile({
    required this.id,
    required this.accountId,
    required this.name,
    this.avatarUrl,
    required this.classNodeId,
    required this.className,
    this.schoolName,
    required this.countryId,
    this.activeTier = 'gratuit',
    this.tierExpiresAt,
    this.totalPoints = 0,
    this.streakDays = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      name: json['name'] as String? ?? 'Élève',
      avatarUrl: json['avatar_url'] as String?,
      classNodeId: json['class_node_id'] as String? ?? '',
      className: json['class_name'] as String? ?? 'Classe',
      schoolName: json['school_name'] as String?,
      countryId: json['country_id'] as String? ?? '',
      activeTier: json['active_tier'] as String? ?? 'gratuit',
      tierExpiresAt: json['tier_expires_at'] != null
          ? DateTime.parse(json['tier_expires_at'] as String)
          : null,
      totalPoints: (json['total_points'] as int?) ?? 150,
      streakDays: (json['streak_days'] as int?) ?? 3,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  bool get hasActiveSubscription {
    if (activeTier == 'gratuit') return false;
    if (tierExpiresAt == null) return true;
    return tierExpiresAt!.isAfter(DateTime.now());
  }

  StudentProfile copyWith({
    String? name,
    String? avatarUrl,
    String? classNodeId,
    String? className,
    String? schoolName,
    String? activeTier,
    DateTime? tierExpiresAt,
    int? totalPoints,
    int? streakDays,
  }) {
    return StudentProfile(
      id: id,
      accountId: accountId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      classNodeId: classNodeId ?? this.classNodeId,
      className: className ?? this.className,
      schoolName: schoolName ?? this.schoolName,
      countryId: countryId,
      activeTier: activeTier ?? this.activeTier,
      tierExpiresAt: tierExpiresAt ?? this.tierExpiresAt,
      totalPoints: totalPoints ?? this.totalPoints,
      streakDays: streakDays ?? this.streakDays,
      createdAt: createdAt,
    );
  }
}

class Subject {
  final String id;
  final String name;
  final String code;
  final String? iconName;
  final int chaptersCount;
  final double progressPercent;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.iconName,
    this.chaptersCount = 0,
    this.progressPercent = 0.0,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String? ?? '',
      iconName: json['icon_name'] as String?,
      chaptersCount: (json['chapters_count'] as int?) ?? 6,
      progressPercent: double.parse((json['progress_percent'] as num?)?.toString() ?? '0.35'),
    );
  }
}

class Chapter {
  final String id;
  final String subjectId;
  final String? termId;
  final String title;
  final String? introduction;
  final int displayOrder;
  final bool isUnlocked;
  final int lessonsCount;
  final int exercisesCount;

  Chapter({
    required this.id,
    required this.subjectId,
    this.termId,
    required this.title,
    this.introduction,
    this.displayOrder = 0,
    this.isUnlocked = true,
    this.lessonsCount = 0,
    this.exercisesCount = 0,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      termId: json['term_id'] as String?,
      title: json['title'] as String,
      introduction: json['introduction'] as String?,
      displayOrder: (json['display_order'] as int?) ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? true,
      lessonsCount: (json['lessons_count'] as int?) ?? 3,
      exercisesCount: (json['exercises_count'] as int?) ?? 8,
    );
  }
}

class Lesson {
  final String id;
  final String chapterId;
  final String title;
  final Map<String, dynamic> contentJson;
  final String minSubscriptionTier;
  final bool isFree;
  final int readingTimeMinutes;

  Lesson({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.contentJson,
    this.minSubscriptionTier = 'gratuit',
    this.isFree = false,
    this.readingTimeMinutes = 15,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      contentJson: Map<String, dynamic>.from(json['content_json'] ?? {}),
      minSubscriptionTier: json['min_subscription_tier'] as String? ?? 'gratuit',
      isFree: json['is_free'] as bool? ?? (json['min_subscription_tier'] == 'gratuit'),
      readingTimeMinutes: (json['reading_time_minutes'] as int?) ?? 15,
    );
  }
}

class Exercise {
  final String id;
  final String? lessonId;
  final String? chapterId;
  final String questionText;
  final String type; // 'qcm', 'saisie', 'vrai_faux'
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int points;

  Exercise({
    required this.id,
    this.lessonId,
    this.chapterId,
    required this.questionText,
    this.type = 'qcm',
    this.options = const [],
    required this.correctIndex,
    required this.explanation,
    this.points = 10,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<String> parsedOptions = rawOptions is List
        ? rawOptions.map((o) => o.toString()).toList()
        : [];

    return Exercise(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      questionText: json['question_text'] as String? ?? '',
      type: json['type'] as String? ?? 'qcm',
      options: parsedOptions,
      correctIndex: (json['correct_index'] as int?) ?? 0,
      explanation: json['explanation'] as String? ?? '',
      points: (json['points'] as int?) ?? 10,
    );
  }
}

class ForumPost {
  final String id;
  final String classNodeId;
  final String profileId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int repliesCount;
  final bool isFlagged;
  final DateTime createdAt;

  ForumPost({
    required this.id,
    required this.classNodeId,
    required this.profileId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.imageUrl,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isFlagged = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      classNodeId: json['class_node_id'] as String,
      profileId: json['profile_id'] as String,
      authorName: json['author_name'] as String? ?? 'Camarade de classe',
      authorAvatar: json['author_avatar'] as String?,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      likesCount: (json['likes_count'] as int?) ?? 0,
      repliesCount: (json['replies_count'] as int?) ?? 0,
      isFlagged: json['is_flagged'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class OfficialExam {
  final String id;
  final String title;
  final String countryId;
  final String classNodeId;
  final int year;
  final String? session;
  final String examType; // 'officiel', 'etablissement'
  final String? schoolName;
  final String? documentUrl;
  final String? correctionUrl;

  OfficialExam({
    required this.id,
    required this.title,
    required this.countryId,
    required this.classNodeId,
    required this.year,
    this.session,
    this.examType = 'officiel',
    this.schoolName,
    this.documentUrl,
    this.correctionUrl,
  });

  factory OfficialExam.fromJson(Map<String, dynamic> json) {
    return OfficialExam(
      id: json['id'] as String,
      title: json['title'] as String,
      countryId: json['country_id'] as String,
      classNodeId: json['class_node_id'] as String,
      year: (json['year'] as int?) ?? 2026,
      session: json['session'] as String?,
      examType: json['exam_type'] as String? ?? 'officiel',
      schoolName: json['school_name'] as String?,
      documentUrl: json['document_url'] as String?,
      correctionUrl: json['correction_url'] as String?,
    );
  }
}
