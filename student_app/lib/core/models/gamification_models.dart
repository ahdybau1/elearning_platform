// §14 du cahier des charges : badges, streak, points d'expérience — tout calculé côté serveur
// depuis de vraies preuves d'activité (get_profile_gamification, migration 87), jamais un chiffre
// inventé ici. Fichier séparé de `student_models.dart` : regroupe un sous-domaine autonome, comme
// `published_exam_question.dart`.

class GamificationSummary {
  final int xp;
  final int streakDays;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final int lessonsCompleted;
  final int attemptsCount;
  final int correctAttempts;
  final int chaptersCompleted;

  const GamificationSummary({
    required this.xp,
    required this.streakDays,
    required this.longestStreak,
    this.lastActiveDate,
    required this.lessonsCompleted,
    required this.attemptsCount,
    required this.correctAttempts,
    required this.chaptersCompleted,
  });

  /// Aucune activité du tout — l'état honnête à distinguer d'un streak "rompu" (qui, lui, a un
  /// historique réel mais retombé à 0 aujourd'hui).
  bool get hasAnyActivity => lessonsCompleted > 0 || attemptsCount > 0;

  factory GamificationSummary.fromJson(Map<String, dynamic> json) {
    return GamificationSummary(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['last_active_date'] != null
          ? DateTime.parse(json['last_active_date'] as String)
          : null,
      lessonsCompleted: (json['lessons_completed'] as num?)?.toInt() ?? 0,
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
      correctAttempts: (json['correct_attempts'] as num?)?.toInt() ?? 0,
      chaptersCompleted: (json['chapters_completed'] as num?)?.toInt() ?? 0,
    );
  }
}

class BadgeProgress {
  final String code;
  final String name;
  final String description;
  final String iconKey;
  final String criteriaType;
  final int criteriaThreshold;
  final int currentValue;
  final DateTime? earnedAt;

  const BadgeProgress({
    required this.code,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.criteriaType,
    required this.criteriaThreshold,
    required this.currentValue,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  double get progressRatio =>
      criteriaThreshold <= 0 ? 0 : (currentValue / criteriaThreshold).clamp(0.0, 1.0);
}
