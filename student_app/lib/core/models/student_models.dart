import 'content_block.dart';

// Reflète exactement la table réelle `accounts` (voir docs/cahier_des_charges.md, §36.1) — un
// compte = une identité unique. Un compte "parent" est un modèle SÉPARÉ (`parent_accounts`, §17),
// pas un simple booléen ici comme le laissait croire l'ancien modèle 100% fictif.
class StudentAccount {
  final String id;
  final String authUserId;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final DateTime? birthDate;
  final String? schoolName;
  final DateTime createdAt;

  StudentAccount({
    required this.id,
    required this.authUserId,
    required this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.birthDate,
    this.schoolName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Anniversaire aujourd'hui — jour et mois seuls comparés, l'année n'importe pas.
  bool get isBirthdayToday {
    if (birthDate == null) return false;
    final now = DateTime.now();
    return now.day == birthDate!.day && now.month == birthDate!.month;
  }

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String? ?? '',
      email: json['email'] as String,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      birthDate: json['birth_date'] != null ? DateTime.tryParse(json['birth_date'] as String) : null,
      schoolName: json['school_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

// Reflète exactement la table réelle `account_settings` (§11.1 du cahier des charges — Paramètres).
// La langue d'interface n'a volontairement pas de champ ici : elle reste fixée à 'fr' tant qu'aucune
// traduction anglaise réelle n'existe (voir settings_screen.dart).
class AccountSettings {
  final bool notifSubscription;
  final bool notifForum;
  final bool notifRevision;
  final String themeMode; // 'light' | 'dark' | 'system'
  final bool highContrast;
  final double fontScale;
  final bool subtitlesEnabled;
  final bool forumProfileVisible;

  const AccountSettings({
    this.notifSubscription = true,
    this.notifForum = true,
    this.notifRevision = true,
    this.themeMode = 'dark',
    this.highContrast = false,
    this.fontScale = 1.0,
    this.subtitlesEnabled = true,
    this.forumProfileVisible = true,
  });

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    return AccountSettings(
      notifSubscription: json['notif_subscription'] as bool? ?? true,
      notifForum: json['notif_forum'] as bool? ?? true,
      notifRevision: json['notif_revision'] as bool? ?? true,
      themeMode: json['theme_mode'] as String? ?? 'dark',
      highContrast: json['high_contrast'] as bool? ?? false,
      fontScale: (json['font_scale'] as num?)?.toDouble() ?? 1.0,
      subtitlesEnabled: json['subtitles_enabled'] as bool? ?? true,
      forumProfileVisible: json['forum_profile_visible'] as bool? ?? true,
    );
  }

  AccountSettings copyWith({
    bool? notifSubscription,
    bool? notifForum,
    bool? notifRevision,
    String? themeMode,
    bool? highContrast,
    double? fontScale,
    bool? subtitlesEnabled,
    bool? forumProfileVisible,
  }) {
    return AccountSettings(
      notifSubscription: notifSubscription ?? this.notifSubscription,
      notifForum: notifForum ?? this.notifForum,
      notifRevision: notifRevision ?? this.notifRevision,
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      fontScale: fontScale ?? this.fontScale,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      forumProfileVisible: forumProfileVisible ?? this.forumProfileVisible,
    );
  }
}

// Reflète exactement la table réelle `parent_accounts` (§17 du cahier des charges — identité PROPRE
// du parent, créée séparément du compte élève par un administrateur, jamais un simple PIN).
class ParentAccount {
  final String id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final bool isActive;

  ParentAccount({
    required this.id,
    required this.email,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.isActive = true,
  });

  factory ParentAccount.fromJson(Map<String, dynamic> json) {
    return ParentAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// Un enfant lié (via `parent_profile_links`) tel que vu depuis l'Espace Parent — combine l'identité
// réelle de l'élève (`accounts`) et son profil (`profiles`/`academic_nodes`), jamais les données du
// compte du PARENT lui-même (bug de l'ancien Espace Parent qui affichait `authState.account`, celui
// de l'élève actuellement connecté, faute d'un vrai lien parent).
class LinkedChildProfile {
  final String profileId;
  final String childFirstName;
  final String childLastName;
  final String className;
  final String schoolYear;
  final String subscriptionTier;
  final String status;

  LinkedChildProfile({
    required this.profileId,
    required this.childFirstName,
    required this.childLastName,
    required this.className,
    required this.schoolYear,
    required this.subscriptionTier,
    required this.status,
  });

  String get displayName => '$childFirstName $childLastName'.trim().isEmpty ? className : '$childFirstName $childLastName'.trim();
  bool get hasActiveSubscription => subscriptionTier != 'gratuit';

  factory LinkedChildProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? json;
    final account = profile['accounts'] as Map<String, dynamic>?;
    final classNode = profile['academic_nodes'] as Map<String, dynamic>?;
    return LinkedChildProfile(
      profileId: profile['id'] as String,
      childFirstName: account?['first_name'] as String? ?? '',
      childLastName: account?['last_name'] as String? ?? '',
      className: classNode?['name'] as String? ?? 'Classe',
      schoolYear: profile['school_year'] as String? ?? '',
      subscriptionTier: profile['subscription_tier'] as String? ?? 'gratuit',
      status: profile['status'] as String? ?? 'actif',
    );
  }
}

// Reflète exactement la ligne réelle `transactions`, filtrée aux profils liés au parent (§17 :
// « Gestion de l'abonnement et des paiements »).
class ParentTransaction {
  final String id;
  final double amount;
  final String operator;
  final String status;
  final DateTime createdAt;

  ParentTransaction({
    required this.id,
    required this.amount,
    required this.operator,
    required this.status,
    required this.createdAt,
  });

  factory ParentTransaction.fromJson(Map<String, dynamic> json) {
    return ParentTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      operator: json['operator'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Reflète exactement la table réelle `profiles` : un profil = une classe précise + un abonnement
// propre, rattaché à UN compte (§2.3 du cahier des charges — pas "un enfant différent" comme le
// laissait croire l'ancien modèle : plusieurs profils suivent plusieurs classes de LA MÊME
// personne ; le suivi de plusieurs enfants différents passe par l'Espace Parent, §17).
class StudentProfile {
  final String id;
  final String accountId;
  final String classNodeId;
  final String className;
  final String status; // 'actif' | 'archive'
  final String subscriptionTier; // 'gratuit', 'journalier', 'hebdomadaire', 'mensuel', 'annuel'
  final String schoolYear;
  final DateTime createdAt;

  StudentProfile({
    required this.id,
    required this.accountId,
    required this.classNodeId,
    required this.className,
    this.status = 'actif',
    this.subscriptionTier = 'gratuit',
    required this.schoolYear,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Nom affiché dans le sélecteur de profil — un profil représente une classe suivie, pas une
  /// personne distincte ; pas de champ "nom" séparé dans le schéma réel.
  String get name => className;

  bool get hasActiveSubscription => subscriptionTier != 'gratuit';

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final classNode = json['academic_nodes'] as Map<String, dynamic>?;
    return StudentProfile(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      classNodeId: json['class_node_id'] as String? ?? '',
      className: classNode?['name'] as String? ?? 'Classe',
      status: json['status'] as String? ?? 'actif',
      subscriptionTier: json['subscription_tier'] as String? ?? 'gratuit',
      schoolYear: json['school_year'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

// Arbre académique générique (pays → section → type d'enseignement → classe → série), profondeur
// variable selon le pays — voir §2.1/§2.2 du cahier des charges. Utilisé pour la sélection de
// classe réelle à l'inscription, au lieu des listes fictives codées en dur de l'ancien wizard.
class StudentAcademicNode {
  final String id;
  final String? parentId;
  final String nodeType; // country | section | education_type | class | series
  final String name;
  final String? countryId;

  StudentAcademicNode({
    required this.id,
    this.parentId,
    required this.nodeType,
    required this.name,
    this.countryId,
  });

  factory StudentAcademicNode.fromJson(Map<String, dynamic> json) {
    return StudentAcademicNode(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      nodeType: json['node_type'] as String,
      name: json['name'] as String,
      countryId: json['country_id'] as String?,
    );
  }
}

// §2.7 et §3.3 du cahier des charges : contexte temporel réel (trimestre en cours, année scolaire,
// déblocage progressif basé sur la vraie date), calculé côté service à partir des vraies tables
// `terms`/`school_years` — remplace l'ancien bandeau codé en dur ("Trimestre 1", 65% fixe).
class TermInfo {
  final String termName;
  final String? schoolYearName;
  final double progressRatio;
  final bool isBetweenTerms;

  TermInfo({
    required this.termName,
    this.schoolYearName,
    required this.progressRatio,
    this.isBetweenTerms = false,
  });
}

// Pas de champ `progressPercent` : aucune table de suivi de progression réelle n'existe encore
// (§3.5 du cahier des charges — pourcentage de leçons vues par matière). Mieux vaut l'omettre côté
// UI que d'inventer un pourcentage.
class Subject {
  final String id;
  final String name;
  final String code;
  final String? iconName;
  final int chaptersCount;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.iconName,
    this.chaptersCount = 0,
  });

  Subject copyWith({int? chaptersCount}) {
    return Subject(
      id: id,
      name: name,
      code: code,
      iconName: iconName,
      chaptersCount: chaptersCount ?? this.chaptersCount,
    );
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String? ?? '',
      iconName: json['icon_name'] as String?,
      chaptersCount: (json['chapters_count'] as int?) ?? 0,
    );
  }
}

// §3.3 du cahier des charges : déblocage progressif par trimestre, cumulatif et invisible (l'élève
// ne voit jamais le mot « Trimestre » comme niveau de navigation, seulement un statut sur le
// chapitre). `isUnlocked` est calculé côté client depuis `terms.start_date` — un chapitre sans
// trimestre assigné (`termId == null`) est traité comme débloqué par défaut (aucune règle de
// blocage configurée pour lui).
class Chapter {
  final String id;
  final String subjectId;
  final String? termId;
  final String? termName;
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
    this.termName,
    required this.title,
    this.introduction,
    this.displayOrder = 0,
    this.isUnlocked = true,
    this.lessonsCount = 0,
    this.exercisesCount = 0,
  });

  Chapter copyWith({int? lessonsCount, int? exercisesCount}) {
    return Chapter(
      id: id,
      subjectId: subjectId,
      termId: termId,
      termName: termName,
      title: title,
      introduction: introduction,
      displayOrder: displayOrder,
      isUnlocked: isUnlocked,
      lessonsCount: lessonsCount ?? this.lessonsCount,
      exercisesCount: exercisesCount ?? this.exercisesCount,
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final term = json['terms'] as Map<String, dynamic>?;
    final startDateStr = term?['start_date'] as String?;
    final isUnlocked = startDateStr == null || !DateTime.parse(startDateStr).isAfter(DateTime.now());
    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      termId: json['term_id'] as String?,
      termName: term?['name'] as String?,
      title: json['title'] as String,
      introduction: json['introduction'] as String?,
      displayOrder: (json['display_order'] as int?) ?? 0,
      isUnlocked: isUnlocked,
      lessonsCount: (json['lessons_count'] as int?) ?? 0,
      exercisesCount: (json['exercises_count'] as int?) ?? 0,
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

  /// Dérive la liste de blocs structurés (CF-001, `docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md`) à
  /// partir de `contentJson`, sans jamais modifier `contentJson` lui-même (non-régression : tout code
  /// existant qui lit `contentJson` directement continue de fonctionner à l'identique).
  ///
  /// Trois sources possibles, dans cet ordre :
  /// 1. `contentJson['blocks']` — format natif futur (Block Editor Admin, CF-002).
  /// 2. `contentJson['ai_structured']` — sortie réelle de l'edge function `ai-course-structuring`
  ///    (`{summary, sections: [{heading, type, body, latex_formulas}], common_traps, exam_tips,
  ///    quiz_questions}`, voir `admin_app/.../lessons_manager_screen.dart`). Avant CF-001 cette
  ///    structure était capturée et stockée mais jamais réellement affichée à l'élève — seul le texte
  ///    brut `body` (un résumé markdown aplati) l'était, sans mise en forme. `quiz_questions` n'est pas
  ///    exploité ici : c'est un chantier Exercise Factory séparé (voir plan CF-003), pas de la lecture
  ///    de leçon.
  /// 3. Repli : texte brut historique `contentJson['body']` (leçons créées avant l'IA de structuration,
  ///    ou sans notes suffisantes) — jamais un écran vide.
  List<ContentBlock> get blocks {
    final rawBlocks = contentJson['blocks'];
    if (rawBlocks is List && rawBlocks.isNotEmpty) {
      final parsed = <ContentBlock>[];
      for (var i = 0; i < rawBlocks.length; i++) {
        final b = rawBlocks[i];
        if (b is Map) {
          parsed.add(ContentBlock.fromJson(Map<String, dynamic>.from(b), fallbackOrder: i));
        }
      }
      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a.order.compareTo(b.order));
        return parsed;
      }
    }

    final aiStructured = contentJson['ai_structured'];
    if (aiStructured is Map) {
      final structured = Map<String, dynamic>.from(aiStructured);
      final result = <ContentBlock>[];
      var order = 0;

      final summary = structured['summary'] as String?;
      if (summary != null && summary.trim().isNotEmpty) {
        result.add(ContentBlock(type: 'paragraph', body: summary.trim(), order: order++));
      }

      final sections = (structured['sections'] as List?) ?? const [];
      for (final s in sections) {
        if (s is Map) {
          result.add(ContentBlock.fromAiSection(Map<String, dynamic>.from(s), order++));
        }
      }

      final traps = ((structured['common_traps'] as List?) ?? const [])
          .map((t) => t.toString())
          .where((t) => t.trim().isNotEmpty)
          .toList();
      if (traps.isNotEmpty) {
        result.add(ContentBlock(
          type: 'piege',
          body: traps.map((t) => '•  $t').join('\n'),
          order: order++,
        ));
      }

      final tips = ((structured['exam_tips'] as List?) ?? const [])
          .map((t) => t.toString())
          .where((t) => t.trim().isNotEmpty)
          .toList();
      if (tips.isNotEmpty) {
        result.add(ContentBlock(
          type: 'conseil_examen',
          body: tips.map((t) => '•  $t').join('\n'),
          order: order++,
        ));
      }

      if (result.isNotEmpty) return result;
    }

    final body = contentJson['body'] as String?;
    return [
      ContentBlock(
        type: 'paragraph',
        body: (body != null && body.trim().isNotEmpty)
            ? body
            : 'Contenu pédagogique officiel conforme au programme.',
        order: 0,
      ),
    ];
  }
}

/// Reflète la vraie table `exercises` : le contenu de la question vit dans `instructions_json`
/// (`statement`/`options`/`media`) et la correction dans `solution_json` (`correct_index`/
/// `correction`) — pas de colonnes plates `question_text`/`options`/`correct_index` en base. `type`
/// ici est en réalité la catégorie pédagogique ('entraînement'/'évaluation', gate RLS distincte),
/// `format` porte la vraie nature de la question ('qcm', etc.) ; `points` n'existe nulle part en
/// base (aucun barème réel n'est encore défini) — valeur d'affichage fixe assumée comme telle.
class Exercise {
  final String id;
  final String? lessonId;
  final String? chapterId;
  final String? classNodeId;
  final String title;
  final String format; // 'qcm', ...
  final String difficulty;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int points;
  final String? chapterTitle;
  final String? subjectName;

  Exercise({
    required this.id,
    this.lessonId,
    this.chapterId,
    this.classNodeId,
    required this.title,
    this.format = 'qcm',
    this.difficulty = 'facile',
    required this.questionText,
    this.options = const [],
    required this.correctIndex,
    required this.explanation,
    this.points = 10,
    this.chapterTitle,
    this.subjectName,
  });

  /// Ni lié à une leçon ni à un chapitre : exercice de brassage multi-chapitres (§3.2 du CDC).
  bool get isIndependent => lessonId == null && chapterId == null;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final instructions = Map<String, dynamic>.from(json['instructions_json'] as Map? ?? {});
    final solution = Map<String, dynamic>.from(json['solution_json'] as Map? ?? {});
    final rawOptions = instructions['options'];
    final List<String> parsedOptions = rawOptions is List
        ? rawOptions.map((o) => o.toString()).toList()
        : [];

    // Le libellé chapitre/matière peut venir soit directement (exercice lié à un chapitre), soit
    // via la leçon (exercice lié à une leçon, qui elle-même appartient à un chapitre) — jamais les
    // deux en même temps en pratique, on prend le premier trouvé.
    final directChapter = json['chapters'] as Map<String, dynamic>?;
    final lesson = json['lessons'] as Map<String, dynamic>?;
    final lessonChapter = lesson?['chapters'] as Map<String, dynamic>?;
    final subject = (directChapter?['subjects'] ?? lessonChapter?['subjects']) as Map<String, dynamic>?;

    return Exercise(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      classNodeId: json['class_node_id'] as String?,
      title: json['title'] as String? ?? '',
      format: json['format'] as String? ?? 'qcm',
      difficulty: json['difficulty'] as String? ?? 'facile',
      questionText: instructions['statement'] as String? ?? '',
      options: parsedOptions,
      correctIndex: (solution['correct_index'] as int?) ?? 0,
      explanation: solution['correction'] as String? ?? '',
      points: 10,
      chapterTitle: (directChapter?['title'] ?? lesson?['title']) as String?,
      subjectName: subject?['name'] as String?,
    );
  }
}

// Reflète la vraie table `forum_posts` : un post appartient à un `forum_threads` (qui, lui, porte
// `class_node_id`), pas directement à une classe — et il n'existe ni compteur de likes ni réponses
// imbriquées en base (aucune table `forum_post_likes`, pas de `parent_post_id`). Un ancien modèle
// inventait ces champs et une valeur de repli codée en dur masquait silencieusement l'échec réel des
// requêtes (colonnes inexistantes) — corrigé pour refléter le schéma réel.
class ForumPost {
  final String id;
  final String threadId;
  final String authorId;
  final String authorName;
  final String content;
  final bool flagged;
  final DateTime createdAt;

  ForumPost({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.flagged = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final account = json['accounts'] as Map<String, dynamic>?;
    final name = '${account?['first_name'] ?? ''} ${account?['last_name'] ?? ''}'.trim();
    return ForumPost(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      authorId: json['author_id'] as String,
      authorName: name.isNotEmpty ? name : 'Élève',
      content: json['content'] as String,
      flagged: json['flagged'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

// Reflète la vraie table `official_exams` (§4 du cahier des charges) : UN examen national est
// rattaché à UNE classe précise (BEPC → 3e, Probatoire → 1ère, Baccalauréat → Terminale, au
// Cameroun). C'est cette table, et non un champ texte inventé, qui détermine si un profil doit
// même voir la fonctionnalité — un niveau sans ligne ici n'affiche simplement pas la page.
class OfficialExam {
  final String id;
  final String name;
  final String classNodeId;
  final DateTime? examDate;

  OfficialExam({
    required this.id,
    required this.name,
    required this.classNodeId,
    this.examDate,
  });

  factory OfficialExam.fromJson(Map<String, dynamic> json) {
    return OfficialExam(
      id: json['id'] as String,
      name: json['name'] as String,
      classNodeId: json['class_node_id'] as String,
      examDate: json['exam_date'] != null ? DateTime.tryParse(json['exam_date'] as String) : null,
    );
  }
}

// Reflète la vraie table `exam_papers` — un sujet d'annale précis, rattaché à UN examen (donc
// transitivement à une seule classe) et une matière.
class ExamPaper {
  final String id;
  final String examId;
  final String subjectId;
  final String? subjectName;
  final int year;
  final String documentUrl;
  final String? correctionUrl;
  final bool isCorrectionUnlocked;

  ExamPaper({
    required this.id,
    required this.examId,
    required this.subjectId,
    this.subjectName,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
    this.isCorrectionUnlocked = false,
  });

  factory ExamPaper.fromJson(Map<String, dynamic> json) {
    final subject = json['subjects'] as Map<String, dynamic>?;
    return ExamPaper(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      subjectId: json['subject_id'] as String,
      subjectName: subject?['name'] as String?,
      year: (json['year'] as int?) ?? 2026,
      documentUrl: json['document_url'] as String? ?? '',
      correctionUrl: json['correction_url'] as String?,
      isCorrectionUnlocked: json['is_correction_unlocked'] as bool? ?? false,
    );
  }
}

/// Reflète la vraie table `events` (§14 du cahier des charges) — un concours blanc ou une olympiade
/// programmé pour une classe précise. Aucun lien vers un contenu d'épreuve n'existe en base (pas de
/// question/exercice associé) : la correction se fait hors-ligne, ce modèle ne sert donc qu'à
/// informer et à afficher les résultats déjà saisis, jamais à faire passer l'épreuve dans l'app.
class MockEvent {
  final String id;
  final String type; // 'examen_blanc' | 'olympiade'
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String pricingMode; // 'inclus' | 'payant'
  final double price;

  MockEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.pricingMode,
    required this.price,
  });

  bool get isOlympiad => type == 'olympiade';
  bool get hasEnded => DateTime.now().isAfter(endDate);
  bool get isOngoing => !hasEnded && DateTime.now().isAfter(startDate);

  factory MockEvent.fromJson(Map<String, dynamic> json) {
    return MockEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      pricingMode: json['pricing_mode'] as String? ?? 'inclus',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Le propre résultat de l'élève à un événement — jamais celui d'un autre (RLS `owns_profile`).
class MyEventResult {
  final String id;
  final String eventId;
  final double score;
  final int? rank;
  final double? percentile;

  MyEventResult({
    required this.id,
    required this.eventId,
    required this.score,
    this.rank,
    this.percentile,
  });

  factory MyEventResult.fromJson(Map<String, dynamic> json) {
    return MyEventResult(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int?,
      percentile: (json['percentile'] as num?)?.toDouble(),
    );
  }
}

/// Une ligne du classement public d'un événement (voir migration 47, `get_event_leaderboard`) —
/// délibérément minimal (prénom + classe seulement, jamais le nom de famille ni l'email).
class LeaderboardEntry {
  final int? rank;
  final double score;
  final String firstName;
  final String className;

  LeaderboardEntry({
    required this.rank,
    required this.score,
    required this.firstName,
    required this.className,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int?,
      score: (json['score'] as num).toDouble(),
      firstName: json['first_name'] as String? ?? 'Élève',
      className: json['class_name'] as String? ?? '',
    );
  }
}

/// Reflète la vraie table `shop_documents` — RLS `shop_documents_select` gate déjà par palier
/// d'abonnement (`current_user_has_feature_access`), une liste vide reflète donc soit l'absence de
/// document publié pour cette classe, soit un palier insuffisant.
class ShopDocument {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String documentUrl;
  final String? previewUrl;
  final int downloadsCount;

  ShopDocument({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.documentUrl,
    this.previewUrl,
    this.downloadsCount = 0,
  });

  factory ShopDocument.fromJson(Map<String, dynamic> json) {
    return ShopDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      documentUrl: json['document_url'] as String? ?? '',
      previewUrl: json['preview_url'] as String?,
      downloadsCount: (json['downloads_count'] as int?) ?? 0,
    );
  }
}

class Establishment {
  final String id;
  final String name;
  final String city;

  Establishment({required this.id, required this.name, required this.city});

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
    );
  }
}

class EstablishmentPaper {
  final String id;
  final String establishmentId;
  final String? establishmentName;
  final String subjectId;
  final String? subjectName;
  final int year;
  final String documentUrl;
  final String? correctionUrl;

  EstablishmentPaper({
    required this.id,
    required this.establishmentId,
    this.establishmentName,
    required this.subjectId,
    this.subjectName,
    required this.year,
    required this.documentUrl,
    this.correctionUrl,
  });

  factory EstablishmentPaper.fromJson(Map<String, dynamic> json) {
    final establishment = json['establishments'] as Map<String, dynamic>?;
    final subject = json['subjects'] as Map<String, dynamic>?;
    return EstablishmentPaper(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      establishmentName: establishment?['name'] as String?,
      subjectId: json['subject_id'] as String,
      subjectName: subject?['name'] as String?,
      year: (json['year'] as int?) ?? 2026,
      documentUrl: json['document_url'] as String? ?? '',
      correctionUrl: json['correction_url'] as String?,
    );
  }
}

class WhatsappCommunity {
  final String id;
  final String classNodeId;
  final String inviteLink;
  final int memberCountEstimate;

  WhatsappCommunity({
    required this.id,
    required this.classNodeId,
    required this.inviteLink,
    this.memberCountEstimate = 0,
  });

  factory WhatsappCommunity.fromJson(Map<String, dynamic> json) {
    return WhatsappCommunity(
      id: json['id'] as String,
      classNodeId: json['class_node_id'] as String,
      inviteLink: json['invite_link'] as String,
      memberCountEstimate: (json['member_count_estimate'] as int?) ?? 0,
    );
  }
}

class CharityCampaign {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double collectedAmount;
  final String? imageUrl;

  CharityCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.collectedAmount,
    this.imageUrl,
  });

  double get progressRatio => targetAmount > 0 ? (collectedAmount / targetAmount).clamp(0, 1) : 0;

  factory CharityCampaign.fromJson(Map<String, dynamic> json) {
    return CharityCampaign(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      targetAmount: double.parse((json['target_amount'] as num?)?.toString() ?? '0'),
      collectedAmount: double.parse((json['collected_amount'] as num?)?.toString() ?? '0'),
      imageUrl: json['image_url'] as String?,
    );
  }
}

class SupportTicket {
  final String id;
  final String category; // paiement | technique | contenu | autre
  final String subject;
  final String description;
  final String status; // ouvert | en_cours | repondu | ferme
  final String? replyMessage;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    this.status = 'ouvert',
    this.replyMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'autre',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'ouvert',
      replyMessage: json['reply_message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class AppSettings {
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

  AppSettings({
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
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      appName: json['app_name'] as String? ?? 'E-Learning',
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
    );
  }
}
