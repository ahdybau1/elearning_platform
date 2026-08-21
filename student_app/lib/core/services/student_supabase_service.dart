import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_models.dart';

class StudentSupabaseService {
  final SupabaseClient client;

  StudentSupabaseService(this.client);

  static final StudentSupabaseService instance = StudentSupabaseService(
    Supabase.instance.client,
  );

  static bool _isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value.trim());
  }

  // ─── Arbre Académique (inscription réelle) ────────────────────
  // Hiérarchie plate à profondeur variable (pays → section → type d'enseignement → classe → série,
  // certains niveaux pouvant être sautés — voir docs/cahier_des_charges.md §2.1/§2.2 et la note
  // "Generalized node scoping" côté admin_app). Le sélecteur de classe à l'inscription descend
  // l'arbre récursivement via parent_id sans supposer de profondeur fixe : un nœud sans enfant EST
  // la classe à laquelle le profil doit être rattaché, quel que soit son node_type.

  Future<List<StudentAcademicNode>> fetchChildAcademicNodes(String? parentId) async {
    final query = _isValidUuid(parentId)
        ? client.from('academic_nodes').select().eq('parent_id', parentId!).eq('is_active', true)
        : client.from('academic_nodes').select().filter('parent_id', 'is', null).eq('is_active', true);
    final rows = await query.order('display_order').then((rows) => rows as List);
    return rows
        .map((r) => StudentAcademicNode.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Année scolaire courante pour un pays donné (voir §23 du cahier des charges) — utilisée comme
  /// valeur réelle de `profiles.school_year` à la création d'un profil, jamais une valeur inventée.
  Future<String?> fetchCurrentSchoolYear(String countryId) async {
    if (!_isValidUuid(countryId)) return null;
    final row = await client
        .from('school_years')
        .select('name')
        .eq('country_id', countryId)
        .eq('is_current', true)
        .maybeSingle();
    return row?['name'] as String?;
  }

  // ─── Subjects & Academic Structure ───────────────────────────

  Future<List<Subject>> fetchSubjects({String? countryId}) async {
    try {
      var query = client.from('subjects').select();
      if (_isValidUuid(countryId)) {
        query = query.eq('country_id', countryId!);
      }
      final rows = await query.order('name').then((rows) => rows as List);
      if (rows.isNotEmpty) {
        return (rows)
            .map((r) => Subject.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (_) {}

    // Reference demo subjects
    return [
      Subject(id: '00000000-0000-0000-0000-000000000101', name: 'Mathématiques', code: 'MATH', chaptersCount: 8, progressPercent: 0.65),
      Subject(id: '00000000-0000-0000-0000-000000000102', name: 'Physique - Chimie', code: 'PHYS', chaptersCount: 7, progressPercent: 0.40),
      Subject(id: '00000000-0000-0000-0000-000000000103', name: 'Sciences de la Vie & Terre', code: 'SVT', chaptersCount: 6, progressPercent: 0.20),
      Subject(id: '00000000-0000-0000-0000-000000000104', name: 'Français & Littérature', code: 'FRAN', chaptersCount: 5, progressPercent: 0.85),
      Subject(id: '00000000-0000-0000-0000-000000000105', name: 'Anglais (English Language)', code: 'ANGL', chaptersCount: 6, progressPercent: 0.50),
      Subject(id: '00000000-0000-0000-0000-000000000106', name: 'Histoire - Géographie', code: 'HIST', chaptersCount: 5, progressPercent: 0.10),
    ];
  }

  // ─── Chapters & Déblocage Trimestriel Invisible ───────────────

  Future<List<Chapter>> fetchChapters(String subjectId) async {
    try {
      if (_isValidUuid(subjectId)) {
        final rows = await client
            .from('chapters')
            .select()
            .eq('subject_id', subjectId)
            .order('display_order')
            .then((rows) => rows as List);
        if (rows.isNotEmpty) {
          return (rows)
              .map((r) => Chapter.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback chapters with invisible trimester unlocking logic
    return [
      Chapter(
        id: '00000000-0000-0000-0000-000000000201',
        subjectId: subjectId,
        title: 'Chapitre 1 : Nombres Complexes & Trigonométrie',
        introduction: 'Forme algébrique, trigonométrique et exponentielle. Applications géométriques.',
        displayOrder: 1,
        isUnlocked: true,
        lessonsCount: 4,
        exercisesCount: 12,
      ),
      Chapter(
        id: '00000000-0000-0000-0000-000000000202',
        subjectId: subjectId,
        title: 'Chapitre 2 : Limites & Continuité d\'une Fonction',
        introduction: 'Théorème des valeurs intermédiaires, asymptotes et branches infinies.',
        displayOrder: 2,
        isUnlocked: true,
        lessonsCount: 3,
        exercisesCount: 10,
      ),
      Chapter(
        id: '00000000-0000-0000-0000-000000000203',
        subjectId: subjectId,
        title: 'Chapitre 3 : Dérivation & Étude de Fonctions',
        introduction: 'Dérivée d\'une fonction composée, convexité et points d\'inflexion.',
        displayOrder: 3,
        isUnlocked: true,
        lessonsCount: 4,
        exercisesCount: 14,
      ),
      Chapter(
        id: '00000000-0000-0000-0000-000000000204',
        subjectId: subjectId,
        title: 'Chapitre 4 : Fonctions Logarithme & Exponentielle (2e Trimestre)',
        introduction: 'Propriétés analytiques, croissances comparées et résolutions d\'équations.',
        displayOrder: 4,
        isUnlocked: false, // Locked until 2nd trimester (déblocage invisible)
        lessonsCount: 5,
        exercisesCount: 15,
      ),
    ];
  }

  // ─── Lessons & Content ────────────────────────────────────────

  Future<List<Lesson>> fetchLessons(String chapterId) async {
    try {
      if (_isValidUuid(chapterId)) {
        final rows = await client
            .from('lessons')
            .select()
            .eq('chapter_id', chapterId)
            .order('display_order')
            .then((rows) => rows as List);
        if (rows.isNotEmpty) {
          return (rows)
              .map((r) => Lesson.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      }
    } catch (_) {}

    return [
      Lesson(
        id: '00000000-0000-0000-0000-000000000301',
        chapterId: chapterId,
        title: 'Leçon 1 : Forme Algébrique et Conjugaison',
        minSubscriptionTier: 'gratuit',
        isFree: true,
        readingTimeMinutes: 12,
        contentJson: {
          'body': r"Un nombre complexe z s'écrit sous la forme algébrique z = a + ib où a est la partie réelle et b la partie imaginaire.",
          'theoreme': r"Théorème Fondamental : Deux nombres complexes sont égaux si et seulement s'ils ont même partie réelle et même partie imaginaire.",
          'formule': r"\bar{z} = a - ib, |z| = \sqrt{a^2 + b^2}",
          'piege': r"Attention : \sqrt{a^2 + b^2} ne contient JAMAIS le terme i.",
        },
      ),
      Lesson(
        id: '00000000-0000-0000-0000-000000000302',
        chapterId: chapterId,
        title: 'Leçon 2 : Forme Trigonométrique et Argument',
        minSubscriptionTier: 'mensuel',
        isFree: false,
        readingTimeMinutes: 18,
        contentJson: {
          'body': r"Pour tout nombre complexe non nul z, on peut écrire z = r(\cos\theta + i\sin\theta) = r e^{i\theta}.",
          'theoreme': r"Formule de Moivre : Pour tout entier relatif n, (\cos\theta + i\sin\theta)^n = \cos(n\theta) + i\sin(n\theta).",
          'formule': r"e^{i\pi} + 1 = 0 (Identité d'Euler)",
          'methode': r"Pour passer de la forme algébrique à trigonométrique : 1. Calculer le module r. 2. Factoriser par r. 3. Identifier \cos\theta et \sin\theta.",
        },
      ),
    ];
  }

  // ─── Exercises ────────────────────────────────────────────────

  Future<List<Exercise>> fetchExercises(String chapterId) async {
    try {
      if (_isValidUuid(chapterId)) {
        final rows = await client
            .from('exercises')
            .select()
            .eq('chapter_id', chapterId)
            .order('display_order')
            .then((rows) => rows as List);
        if (rows.isNotEmpty) {
          return (rows)
              .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      }
    } catch (_) {}

    return [
      Exercise(
        id: '1',
        chapterId: chapterId,
        questionText: r"Soit z = 1 + i\sqrt{3}. Quel est le module |z| ?",
        type: 'qcm',
        options: ['1', '2', r"\sqrt{3}", '4'],
        correctIndex: 1,
        explanation: r"|z| = \sqrt{1^2 + (\sqrt{3})^2} = \sqrt{1 + 3} = \sqrt{4} = 2.",
        points: 10,
      ),
      Exercise(
        id: '2',
        chapterId: chapterId,
        questionText: r"Quel est l'argument principal \theta de z = 1 + i\sqrt{3} ?",
        type: 'qcm',
        options: [r"\frac{\pi}{6}", r"\frac{\pi}{4}", r"\frac{\pi}{3}", r"\frac{\pi}{2}"],
        correctIndex: 2,
        explanation: r"\cos\theta = 1/2 et \sin\theta = \sqrt{3}/2, donc \theta = \frac{\pi}{3} [2\pi].",
        points: 15,
      ),
    ];
  }

  // ─── Forum de Classe & Modération ─────────────────────────────

  Future<List<ForumPost>> fetchForumPosts(String classNodeId) async {
    try {
      if (_isValidUuid(classNodeId)) {
        final rows = await client
            .from('forum_posts')
            .select()
            .eq('class_node_id', classNodeId)
            .eq('is_flagged', false)
            .order('created_at', ascending: false)
            .then((rows) => rows as List);
        if (rows.isNotEmpty) {
          return (rows)
              .map((r) => ForumPost.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      }
    } catch (_) {}

    return [
      ForumPost(
        id: '1',
        classNodeId: classNodeId,
        profileId: 'prof_01',
        authorName: 'Marc (Délégué de classe)',
        content: 'Quelqu\'un a compris la méthode de résolution de l\'exercice 4 sur les racines n-ièmes de l\'unité ?',
        likesCount: 5,
        repliesCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ForumPost(
        id: '2',
        classNodeId: classNodeId,
        profileId: 'prof_02',
        authorName: 'Élodie K.',
        content: 'N\'oubliez pas le devoir sur table de Physique-Chimie prévu ce jeudi sur l\'optique ondulatoire !',
        likesCount: 12,
        repliesCount: 4,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  Future<void> createForumPost({
    required String classNodeId,
    required String profileId,
    required String authorName,
    required String content,
  }) async {
    if (!_isValidUuid(classNodeId)) return;

    await client.from('forum_posts').insert({
      'class_node_id': classNodeId,
      'profile_id': _isValidUuid(profileId) ? profileId : '00000000-0000-0000-0000-000000000001',
      'author_name': authorName,
      'content': content,
      'is_flagged': false,
    });
  }

  // ─── Examens Officiels & Épreuves d'Établissements ────────────

  Future<List<OfficialExam>> fetchOfficialExams(String classNodeId) async {
    try {
      if (_isValidUuid(classNodeId)) {
        final rows = await client
            .from('official_exams')
            .select()
            .eq('class_node_id', classNodeId)
            .order('year', ascending: false)
            .then((rows) => rows as List);
        if (rows.isNotEmpty) {
          return (rows)
              .map((r) => OfficialExam.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      }
    } catch (_) {}

    return [
      OfficialExam(
        id: '1',
        title: 'Baccalauréat National C — Session 2025',
        countryId: '00000000-0000-0000-0000-000000000001',
        classNodeId: classNodeId,
        year: 2025,
        session: 'Normale',
        examType: 'officiel',
      ),
      OfficialExam(
        id: '2',
        title: 'Épreuve d\'Excellence — Collège Libermann Douala',
        countryId: '00000000-0000-0000-0000-000000000001',
        classNodeId: classNodeId,
        year: 2026,
        schoolName: 'Collège Libermann',
        examType: 'etablissement',
      ),
    ];
  }

  // ─── Paramètres Globaux ───────────────────────────────────────

  /// Repli volontairement "hors maintenance" en cas d'erreur (réseau, colonne absente...) : mieux
  /// vaut laisser l'application fonctionner normalement qu'enfermer tous les élèves derrière un
  /// écran de maintenance à cause d'un souci de récupération de ce réglage, pas du réglage lui-même.
  Future<AppSettings> fetchAppSettings() async {
    try {
      final rows = await client.from('app_settings').select().limit(1).then((r) => r as List);
      if (rows.isNotEmpty) {
        return AppSettings.fromJson(Map<String, dynamic>.from(rows.first));
      }
    } catch (_) {}
    return AppSettings(appName: 'E-Learning');
  }
}
