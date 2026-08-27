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

  /// §2.7/§3.3 du cahier des charges : trimestre réellement en cours (et sa progression) déduits
  /// des vraies dates de `terms`, jamais un texte/pourcentage codé en dur. `class_node_id` permet
  /// de résoudre le pays via `academic_nodes.country_id` (colonne déjà dénormalisée sur chaque
  /// nœud) sans avoir à faire remonter l'appelant jusqu'à la racine de l'arbre lui-même.
  Future<TermInfo?> fetchCurrentTermInfo(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return null;
    final nodeRow = await client.from('academic_nodes').select('country_id').eq('id', classNodeId).maybeSingle();
    final countryId = nodeRow?['country_id'] as String?;
    if (countryId == null) return null;

    final schoolYearName = await fetchCurrentSchoolYear(countryId);

    final rows = await client
        .from('terms')
        .select('name, start_date, end_date')
        .eq('country_id', countryId)
        .eq('is_active', true)
        .order('start_date')
        .then((r) => r as List);
    if (rows.isEmpty) return null;

    final today = DateTime.now();
    Map<String, dynamic>? current;
    Map<String, dynamic>? lastStarted;
    for (final r in rows) {
      final start = DateTime.parse(r['start_date'] as String);
      final end = DateTime.parse(r['end_date'] as String);
      if (!today.isBefore(start)) lastStarted = Map<String, dynamic>.from(r);
      if (!today.isBefore(start) && !today.isAfter(end)) current = Map<String, dynamic>.from(r);
    }
    // Comportement cumulatif (§3.3) : entre deux trimestres, le dernier déjà commencé reste la
    // référence affichée (rien ne redevient invisible), plutôt que de ne rien afficher du tout.
    final active = current ?? lastStarted;
    if (active == null) return null;

    final start = DateTime.parse(active['start_date'] as String);
    final end = DateTime.parse(active['end_date'] as String);
    final totalDays = end.difference(start).inDays;
    final elapsedDays = today.difference(start).inDays;
    final ratio = totalDays <= 0 ? 1.0 : (elapsedDays / totalDays).clamp(0.0, 1.0);

    return TermInfo(
      termName: active['name'] as String,
      schoolYearName: schoolYearName,
      progressRatio: ratio,
      isBetweenTerms: current == null,
    );
  }

  /// §11.1 du cahier des charges : préférences réelles (notifications, apparence, accessibilité,
  /// confidentialité forum), une ligne par compte. `upsert` : la ligne n'existe pas forcément
  /// encore pour un compte déjà créé avant cette table (voir migration 40).
  Future<AccountSettings> fetchAccountSettings(String accountId) async {
    if (!_isValidUuid(accountId)) return const AccountSettings();
    final row = await client.from('account_settings').select().eq('account_id', accountId).maybeSingle();
    if (row == null) {
      await client.from('account_settings').upsert({'account_id': accountId});
      return const AccountSettings();
    }
    return AccountSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> upsertAccountSettings(String accountId, Map<String, dynamic> partial) async {
    if (!_isValidUuid(accountId)) return;
    await client.from('account_settings').upsert({
      'account_id': accountId,
      ...partial,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// §17 : code de liaison éphémère (24h) — l'élève le génère et le communique lui-même à son
  /// parent, qui le saisit à son inscription pour prouver le lien sans partager de mot de passe ni
  /// attendre une validation admin (voir migration 44, fonction redeem_parent_link_code). Réutilise
  /// un code déjà actif s'il en existe un plutôt que d'en empiler des inutilisés.
  Future<String> fetchOrCreateParentLinkCode(String profileId) async {
    final existing = await client
        .from('parent_link_codes')
        .select('code, expires_at')
        .eq('profile_id', profileId)
        .filter('used_at', 'is', null)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['code'] as String;

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans caractères ambigus (0/O, 1/I/l)
    final random = _randomCode(chars);
    await client.from('parent_link_codes').insert({
      'code': random,
      'profile_id': profileId,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
    return random;
  }

  String _randomCode(String alphabet) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = now;
    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(alphabet[seed % alphabet.length]);
    }
    return buffer.toString();
  }

  /// §11.1 : demande réelle de droit à l'oubli (export/suppression), distincte d'un ticket support
  /// générique — voir migration 41. Le traitement effectif reste une décision admin manuelle.
  Future<String?> createDataRequest(String accountId, String requestType) async {
    if (!_isValidUuid(accountId)) return 'Compte invalide';
    try {
      await client.from('data_requests').insert({'account_id': accountId, 'request_type': requestType});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// §2.5 du cahier des charges : profils archivés, consultables séparément (jamais mêlés à la
  /// liste active utilisée par le sélecteur de profils/la barre latérale).
  Future<List<StudentProfile>> fetchArchivedProfiles(String accountId) async {
    if (!_isValidUuid(accountId)) return [];
    final rows = await client
        .from('profiles')
        .select('*, academic_nodes(name)')
        .eq('account_id', accountId)
        .eq('status', 'archive')
        .order('created_at')
        .then((r) => r as List);
    return rows.map((r) => StudentProfile.fromJson(Map<String, dynamic>.from(r))).toList();
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
  // Le forum réel (`forum_threads`/`forum_posts`) prend en charge plusieurs fils par classe, mais
  // cet écran (une classe = un seul flux) reste volontairement simple : on utilise le fil le plus
  // ancien de la classe comme unique conversation, créé à la volée au premier message si besoin.

  Future<String?> _classThreadId(String classNodeId, String authorAccountId) async {
    final existing = await client
        .from('forum_threads')
        .select('id')
        .eq('class_node_id', classNodeId)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await client
        .from('forum_threads')
        .insert({
          'class_node_id': classNodeId,
          'author_id': authorAccountId,
          'title': 'Discussion de classe',
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  /// Aucune donnée de secours ici : une erreur (RLS, réseau...) doit remonter telle quelle à
  /// l'écran (voir `postsAsync.error` dans class_forum_screen.dart), jamais être masquée par un
  /// faux message codé en dur — c'était le bug précédent (colonnes inexistantes avalées en silence).
  Future<List<ForumPost>> fetchForumPosts(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return [];

    final thread = await client
        .from('forum_threads')
        .select('id')
        .eq('class_node_id', classNodeId)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (thread == null) return [];

    final rows = await client
        .from('forum_posts')
        .select('*, accounts(first_name, last_name)')
        .eq('thread_id', thread['id'] as String)
        .order('created_at', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => ForumPost.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> createForumPost({
    required String classNodeId,
    required String authorAccountId,
    required String content,
  }) async {
    if (!_isValidUuid(classNodeId)) return;
    final threadId = await _classThreadId(classNodeId, authorAccountId);
    if (threadId == null) return;
    await client.from('forum_posts').insert({
      'thread_id': threadId,
      'author_id': authorAccountId,
      'content': content,
    });
  }

  // ─── Examens Officiels Nationaux (§4 du CDC) ───────────────────
  // `official_exams.class_node_id` porte le cloisonnement réel : une classe qui n'a pas de ligne
  // ici (ex: 2nde, qui ne compose aucun examen national) n'a tout simplement rien à afficher — ni
  // fausse donnée de secours, ni examen d'un autre niveau. `maybeSingle` reflète qu'une classe a au
  // plus UN examen national (BEPC, Probatoire ou Bac, jamais plusieurs).
  Future<OfficialExam?> fetchOfficialExamForClass(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return null;
    final row = await client
        .from('official_exams')
        .select()
        .eq('class_node_id', classNodeId)
        .maybeSingle();
    return row == null ? null : OfficialExam.fromJson(Map<String, dynamic>.from(row));
  }

  // RLS `exam_papers_select` gate déjà par palier d'abonnement (`current_user_has_feature_access`)
  // — une liste vide reflète soit l'absence de sujet archivé, soit un palier insuffisant.
  Future<List<ExamPaper>> fetchExamPapers(String examId) async {
    if (!_isValidUuid(examId)) return [];
    final rows = await client
        .from('exam_papers')
        .select('*, subjects(name)')
        .eq('exam_id', examId)
        .order('year', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => ExamPaper.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  // ─── Concours Blancs & Olympiades (§14 du CDC) ─────────────────
  // `events` ne contient aucun lien vers un contenu d'épreuve (pas de question/exercice associé) —
  // la correction se fait hors-ligne, ces méthodes servent donc à informer et afficher des résultats
  // déjà saisis par un admin, jamais à faire passer l'épreuve dans l'app (décision explicite).

  Future<List<MockEvent>> fetchEventsForClass(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return [];
    final rows = await client
        .from('events')
        .select()
        .eq('class_node_id', classNodeId)
        .order('start_date', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => MockEvent.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// `maybeSingle` : au plus un résultat par élève et par événement (contrainte implicite du modèle,
  /// pas de doublon possible côté admin en pratique).
  Future<MyEventResult?> fetchMyEventResult(String eventId, String profileId) async {
    if (!_isValidUuid(eventId) || !_isValidUuid(profileId)) return null;
    final row = await client
        .from('event_results')
        .select()
        .eq('event_id', eventId)
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null ? null : MyEventResult.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<LeaderboardEntry>> fetchEventLeaderboard(String eventId) async {
    if (!_isValidUuid(eventId)) return [];
    final rows = await client
        .rpc('get_event_leaderboard', params: {'p_event_id': eventId})
        .then((r) => r as List);
    return rows.map((r) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// §11 du CDC (2e Correcteur) : réclamation réelle liée à un résultat précis, jamais un ticket
  /// support générique — RLS `grade_disputes_insert` vérifie déjà que ce résultat appartient bien à
  /// l'appelant.
  Future<String?> submitGradeDispute({
    required String eventResultId,
    required String reason,
    required double originalScore,
  }) async {
    try {
      await client.from('grade_disputes').insert({
        'event_result_id': eventResultId,
        'reason': reason,
        'status': 'ouvert',
        'original_score': originalScore,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
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
