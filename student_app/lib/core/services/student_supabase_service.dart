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

  /// Matières réellement enseignées dans la classe du profil actif, via `subject_class_links` —
  /// jamais par pays (§2.4 du cahier des charges : cloisonnement strict, un profil ne voit QUE le
  /// contenu de sa classe/série). L'ancienne version filtrait par `country_id`, ce qui montrait
  /// TOUTES les matières du pays y compris celles jamais enseignées dans la classe de l'élève — un
  /// vrai bug de cloisonnement, pas juste un manque de données. Aucun repli sur de fausses matières
  /// : une classe sans matière liée doit afficher une liste vide honnête.
  Future<List<Subject>> fetchSubjects({required String classNodeId}) async {
    if (!_isValidUuid(classNodeId)) return [];

    final linkRows = await client
        .from('subject_class_links')
        .select('subjects(*)')
        .eq('class_node_id', classNodeId)
        .then((r) => r as List);

    final subjects = linkRows
        .map((r) => (r as Map<String, dynamic>)['subjects'])
        .whereType<Map<String, dynamic>>()
        .map((j) => Subject.fromJson(j))
        .toList();
    if (subjects.isEmpty) return [];

    // Nombre réel de chapitres actifs par matière, précisément pour cette classe (un chapitre
    // appartient à une classe précise, pas à toutes les classes liées à sa matière — voir le
    // commentaire sur `chapters.class_node_id` dans reset_project_schema.sql).
    final chapterRows = await client
        .from('chapters')
        .select('subject_id')
        .eq('class_node_id', classNodeId)
        .eq('is_active', true)
        .then((r) => r as List);
    final countsBySubject = <String, int>{};
    for (final row in chapterRows) {
      final sid = (row as Map<String, dynamic>)['subject_id'] as String?;
      if (sid != null) countsBySubject[sid] = (countsBySubject[sid] ?? 0) + 1;
    }

    final result = subjects.map((s) => s.copyWith(chaptersCount: countsBySubject[s.id] ?? 0)).toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // ─── Chapters & Déblocage Trimestriel Invisible ───────────────

  /// Chapitres réels d'une matière PRÉCISÉMENT pour la classe du profil actif — filtrer par
  /// `subject_id` seul (comme l'ancienne version) montrerait aussi les chapitres d'autres classes
  /// partageant la même matière via `subject_class_links`, un chapitre étant rattaché à une classe
  /// précise (voir le commentaire sur `chapters.class_node_id` dans reset_project_schema.sql).
  /// Le déblocage par trimestre (§3.3) est calculé réellement depuis `terms.start_date` dans
  /// `Chapter.fromJson`, plus de statut fictif toujours "Trimestre 2".
  Future<List<Chapter>> fetchChapters({required String subjectId, required String classNodeId}) async {
    if (!_isValidUuid(subjectId) || !_isValidUuid(classNodeId)) return [];

    final rows = await client
        .from('chapters')
        .select('*, terms(name, start_date)')
        .eq('subject_id', subjectId)
        .eq('class_node_id', classNodeId)
        .eq('is_active', true)
        .order('display_order')
        .then((r) => r as List);

    final chapters = rows.map((r) => Chapter.fromJson(Map<String, dynamic>.from(r))).toList();
    if (chapters.isEmpty) return [];

    final chapterIds = chapters.map((c) => c.id).toList();
    final lessonRows = await client
        .from('lessons')
        .select('chapter_id')
        .inFilter('chapter_id', chapterIds)
        .eq('is_active', true)
        .then((r) => r as List);
    final exerciseRows = await client
        .from('exercises')
        .select('chapter_id')
        .inFilter('chapter_id', chapterIds)
        .eq('is_active', true)
        .then((r) => r as List);

    final lessonCounts = <String, int>{};
    for (final row in lessonRows) {
      final cid = (row as Map<String, dynamic>)['chapter_id'] as String?;
      if (cid != null) lessonCounts[cid] = (lessonCounts[cid] ?? 0) + 1;
    }
    final exerciseCounts = <String, int>{};
    for (final row in exerciseRows) {
      final cid = (row as Map<String, dynamic>)['chapter_id'] as String?;
      if (cid != null) exerciseCounts[cid] = (exerciseCounts[cid] ?? 0) + 1;
    }

    return chapters
        .map((c) => c.copyWith(lessonsCount: lessonCounts[c.id] ?? 0, exercisesCount: exerciseCounts[c.id] ?? 0))
        .toList();
  }

  // ─── Lessons & Content ────────────────────────────────────────

  /// `chapterId` est déjà précisément scopé (un chapitre appartient à une seule classe), donc pas
  /// de filtre supplémentaire nécessaire ici. Plus de repli sur les 2 leçons fictives "Nombres
  /// Complexes" codées en dur — une liste vide reflète honnêtement l'absence de contenu publié.
  Future<List<Lesson>> fetchLessons(String chapterId) async {
    if (!_isValidUuid(chapterId)) return [];
    final rows = await client
        .from('lessons')
        .select()
        .eq('chapter_id', chapterId)
        .eq('is_active', true)
        .order('display_order')
        .then((r) => r as List);
    return rows.map((r) => Lesson.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  // ─── Exercises ────────────────────────────────────────────────

  /// Même principe que fetchLessons : plus de repli sur les 2 exercices fictifs codés en dur.
  Future<List<Exercise>> fetchExercises(String chapterId) async {
    if (!_isValidUuid(chapterId)) return [];
    final rows = await client
        .from('exercises')
        .select()
        .eq('chapter_id', chapterId)
        .eq('is_active', true)
        .order('display_order')
        .then((r) => r as List);
    return rows.map((r) => Exercise.fromJson(Map<String, dynamic>.from(r))).toList();
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

  // ─── Épreuves par Établissement (§5 du CDC) ───────────────────
  // Lectures publiques réelles (RLS `establishments_select`/`establishment_papers_select` : USING
  // (true)) — catalogue ouvert par design, tout élève peut consulter les épreuves de n'importe quel
  // établissement. Pas de repli sur de fausses données : une liste vide est un état honnête tant
  // qu'aucun établissement n'a été créé côté administration.

  Future<List<Establishment>> fetchEstablishments() async {
    final rows = await client
        .from('establishments')
        .select()
        .eq('is_active', true)
        .order('name')
        .then((r) => r as List);
    return rows.map((r) => Establishment.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<EstablishmentPaper>> fetchEstablishmentPapers({
    required String classNodeId,
    String? establishmentId,
  }) async {
    if (!_isValidUuid(classNodeId)) return [];
    var query = client
        .from('establishment_papers')
        .select('*, establishments(name), subjects(name)')
        .eq('class_node_id', classNodeId);
    if (_isValidUuid(establishmentId)) {
      query = query.eq('establishment_id', establishmentId!);
    }
    final rows = await query.order('year', ascending: false).then((r) => r as List);
    return rows.map((r) => EstablishmentPaper.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  // ─── Communautés d'Étude WhatsApp (§16 du CDC) ────────────────
  // RLS `whatsapp_communities_select` gate déjà par classe ET palier d'abonnement
  // (`current_user_has_feature_access('whatsapp_groups')`) — une liste vide reflète soit l'absence
  // de communauté pour cette classe, soit un palier insuffisant ; les deux sont honnêtes ici, pas
  // besoin de les distinguer côté client (le message reste correct dans les deux cas).
  Future<WhatsappCommunity?> fetchWhatsappCommunity(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return null;
    final row = await client
        .from('whatsapp_communities')
        .select()
        .eq('class_node_id', classNodeId)
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : WhatsappCommunity.fromJson(Map<String, dynamic>.from(row));
  }

  // ─── Soutien / Dons (§12 du CDC) ───────────────────────────────
  // Le catalogue des causes est public et réel (RLS `charity_campaigns_select`). En revanche
  // `donations` n'a AUCUNE policy d'insertion cliente (voir reset_project_schema.sql) — un don ne
  // peut être enregistré que via un futur Edge Function `initiate-donation` payant, qui n'existe
  // pas encore faute d'agrégateur Mobile Money connecté. Ne jamais simuler un don réussi ici.
  Future<List<CharityCampaign>> fetchCharityCampaigns() async {
    final rows = await client
        .from('charity_campaigns')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => CharityCampaign.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  // ─── Messagerie / Tickets Support (§9 du CDC) ─────────────────
  // RLS réelle (`support_tickets_select`/`support_tickets_insert` : owns_account(account_id)) —
  // chaque élève ne voit et ne crée que ses propres tickets.
  Future<List<SupportTicket>> fetchSupportTickets(String accountId) async {
    if (!_isValidUuid(accountId)) return [];
    final rows = await client
        .from('support_tickets')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => SupportTicket.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> createSupportTicket({
    required String accountId,
    required String category,
    required String subject,
    required String description,
  }) async {
    await client.from('support_tickets').insert({
      'account_id': accountId,
      'category': category,
      'subject': subject,
      'description': description,
      'requester_type': 'eleve',
    });
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
