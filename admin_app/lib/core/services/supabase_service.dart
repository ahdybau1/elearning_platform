import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_node.dart';
import '../models/content_models.dart';
import '../models/subscription_models.dart';
import '../models/admin_models.dart';
import '../models/community_models.dart';
import '../models/system_models.dart';

class SupabaseService {
  final SupabaseClient client;

  SupabaseService(this.client);

  static final SupabaseService instance = SupabaseService(
    Supabase.instance.client,
  );

  // ─── Academic Nodes ───────────────────────────────────────────

  Future<List<AcademicNode>> fetchAcademicTree() async {
    final rootNodes = await client
        .from('academic_nodes')
        .select()
        .isFilter('parent_id', null)
        .eq('is_active', true)
        .order('display_order')
        .then((rows) => rows as List);

    return Future.wait(
      rootNodes.map(
        (r) => _buildNodeWithChildren(Map<String, dynamic>.from(r)),
      ),
    );
  }

  Future<AcademicNode> _buildNodeWithChildren(Map<String, dynamic> data) async {
    final node = AcademicNode.fromJson(data);
    final childrenRows = await client
        .from('academic_nodes')
        .select()
        .eq('parent_id', node.id)
        .eq('is_active', true)
        .order('display_order')
        .then((rows) => rows as List);

    final children = await Future.wait(
      childrenRows.map(
        (c) => _buildNodeWithChildren(Map<String, dynamic>.from(c)),
      ),
    );

    return AcademicNode(
      id: node.id,
      parentId: node.parentId,
      nodeType: node.nodeType,
      name: node.name,
      code: node.code,
      countryId: node.countryId,
      displayOrder: node.displayOrder,
      isActive: node.isActive,
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      children: children,
    );
  }

  Future<List<AcademicNode>> fetchChildren(String parentId) async {
    final rows = await client
        .from('academic_nodes')
        .select()
        .eq('parent_id', parentId)
        .eq('is_active', true)
        .order('display_order')
        .then((rows) => rows as List);
    return (rows)
        .map((r) => AcademicNode.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<AcademicNode?> createNode({
    String? parentId,
    required String nodeType,
    required String name,
    String? code,
    String? countryId,
    required int displayOrder,
  }) async {
    final insertData = <String, dynamic>{
      'node_type': nodeType,
      'name': name,
      'is_active': true,
      'display_order': displayOrder,
    };
    if (parentId != null) insertData['parent_id'] = parentId;
    if (code != null) insertData['code'] = code;
    if (countryId != null) insertData['country_id'] = countryId;

    final rows = await client
        .from('academic_nodes')
        .insert(insertData)
        .select()
        .then((rows) => rows as List);

    if (rows.isNotEmpty) {
      return AcademicNode.fromJson(Map<String, dynamic>.from(rows.first));
    }
    return null;
  }

  Future<void> updateNode(
    String id, {
    String? name,
    String? code,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (code != null) updates['code'] = code;
    if (isActive != null) updates['is_active'] = isActive;
    await client.from('academic_nodes').update(updates).eq('id', id);
  }

  Future<void> deleteNode(String id) async {
    await client
        .from('academic_nodes')
        .update({'is_active': false})
        .eq('id', id);
  }

  Stream<List<AcademicNode>> watchAcademicTree() {
    return client
        .from('academic_nodes')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('display_order')
        .map((snapshot) {
          final allNodes = snapshot
              .map((s) => AcademicNode.fromJson(s))
              .toList();
          final rootNodes = allNodes.where((n) => n.parentId == null).toList();
          for (final root in rootNodes) {
            _attachChildren(root, allNodes);
          }
          return rootNodes;
        });
  }

  void _attachChildren(AcademicNode node, List<AcademicNode> allNodes) {
    final children = allNodes.where((n) => n.parentId == node.id).toList();
    for (final child in children) {
      _attachChildren(child, allNodes);
    }
    // We can't mutate immutable list, so we set it via copyWith-like approach
  }

  // ─── Subjects ─────────────────────────────────────────────────

  Future<List<Subject>> fetchSubjects({String? countryId}) async {
    var query = client.from('subjects').select();
    if (countryId != null) query = query.eq('country_id', countryId);
    final rows = await query.order('name').then((rows) => rows as List);
    return (rows)
        .map((r) => Subject.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Subject?> getSubject(String id) async {
    final rows = await client
        .from('subjects')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Subject.fromJson(Map<String, dynamic>.from(rows.first));
  }

  // ─── Chapters ─────────────────────────────────────────────────

  Future<List<Chapter>> fetchChapters(
    String subjectId, {
    String? termId,
  }) async {
    var query = client.from('chapters').select().eq('subject_id', subjectId);
    if (termId != null) query = query.eq('term_id', termId);
    final rows = await query
        .order('display_order')
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Chapter.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Chapter?> getChapter(String id) async {
    final rows = await client
        .from('chapters')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Chapter.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<Chapter>> fetchChaptersWithLessons(String subjectId) async {
    final rows = await client
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('display_order')
        .then((rows) => rows as List);

    return Future.wait(
      (rows).map((r) async {
        final chapter = Chapter.fromJson(Map<String, dynamic>.from(r));
        final lessons = await fetchLessonsForChapter(chapter.id);
        return Chapter(
          id: chapter.id,
          subjectId: chapter.subjectId,
          termId: chapter.termId,
          title: chapter.title,
          introduction: chapter.introduction,
          displayOrder: chapter.displayOrder,
          isActive: chapter.isActive,
          createdAt: chapter.createdAt,
          updatedAt: chapter.updatedAt,
          lessons: lessons,
        );
      }),
    );
  }

  // ─── Lessons ──────────────────────────────────────────────────

  Future<List<Lesson>> fetchLessonsForChapter(String chapterId) async {
    final rows = await client
        .from('lessons')
        .select()
        .eq('chapter_id', chapterId)
        .order('display_order')
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Lesson.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Lesson>> fetchLessons({
    String? subjectId,
    String? chapterId,
  }) async {
    var query = client.from('lessons').select();
    if (chapterId != null) query = query.eq('chapter_id', chapterId);
    if (subjectId != null) query = query.eq('subject_id', subjectId);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Lesson.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Lesson?> getLesson(String id) async {
    final rows = await client
        .from('lessons')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Lesson.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<Lesson?> createLesson(Lesson lesson) async {
    final rows = await client
        .from('lessons')
        .insert(lesson.toJson())
        .select()
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Lesson.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateLesson(String id, Lesson lesson) async {
    final updates = lesson.toJson()
      ..remove('id')
      ..remove('created_at');
    updates['updated_at'] = DateTime.now().toIso8601String();
    await client.from('lessons').update(updates).eq('id', id);
  }

  Future<void> publishLesson(String id, bool isPublished) async {
    await client
        .from('lessons')
        .update({
          'is_published': isPublished,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  // ─── Exercises ───────────────────────────────────────────────

  Future<List<Exercise>> fetchExercises({
    String? lessonId,
    String? chapterId,
  }) async {
    var query = client.from('exercises').select();
    if (lessonId != null) query = query.eq('lesson_id', lessonId);
    if (chapterId != null) query = query.eq('chapter_id', chapterId);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Exercise>> fetchAllExercises() async {
    final rows = await client
        .from('exercises')
        .select()
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Validation Queue ─────────────────────────────────────────

  Future<List<ValidationQueueItem>> fetchValidationQueue({
    String? status,
  }) async {
    var query = client.from('validation_queue').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ValidationQueueItem.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<ValidationQueueItem>> watchValidationQueue() {
    return client
        .from('validation_queue')
        .stream(primaryKey: ['id'])
        .eq('status', 'en_attente')
        .order('created_at', ascending: false)
        .map(
          (snapshot) =>
              snapshot.map((s) => ValidationQueueItem.fromJson(s)).toList(),
        );
  }

  Future<void> updateValidationStatus(
    String id,
    String status, {
    String? reviewerId,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (reviewerId != null) updates['reviewer_id'] = reviewerId;
    if (notes != null) updates['review_notes'] = notes;
    await client.from('validation_queue').update(updates).eq('id', id);
  }

  // ─── Subscription Tiers ───────────────────────────────────────

  Future<List<SubscriptionTier>> fetchTiers({String? countryId}) async {
    var query = client.from('subscription_tiers').select();
    if (countryId != null) query = query.eq('country_id', countryId);
    final rows = await query.order('name').then((rows) => rows as List);
    return (rows)
        .map((r) => SubscriptionTier.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<SubscriptionTier?> createTier({
    required String name,
    required String countryId,
    required String classNodeId,
    required double price,
    required int durationDays,
  }) async {
    final rows = await client
        .from('subscription_tiers')
        .insert({
          'name': name,
          'country_id': countryId,
          'class_node_id': classNodeId,
          'price': price,
          'duration_days': durationDays,
        })
        .select()
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return SubscriptionTier.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateTier(String id, {double? price, int? durationDays}) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (price != null) updates['price'] = price;
    if (durationDays != null) updates['duration_days'] = durationDays;
    await client.from('subscription_tiers').update(updates).eq('id', id);
  }

  // ─── Access Matrix ───────────────────────────────────────────

  Future<List<AccessMatrixEntry>> fetchAccessMatrix(String tierId) async {
    final rows = await client
        .from('access_matrix')
        .select()
        .eq('tier_id', tierId)
        .order('feature_key')
        .then((rows) => rows as List);
    return (rows)
        .map((r) => AccessMatrixEntry.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> updateAccessEntry(
    String entryId, {
    String? accessLevel,
    Map<String, dynamic>? limitParameter,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (accessLevel != null) updates['access_level'] = accessLevel;
    if (limitParameter != null) updates['limit_parameter'] = limitParameter;
    await client.from('access_matrix').update(updates).eq('id', entryId);
  }

  Future<void> updateAccessEntries(
    String tierId,
    Map<String, String> featureMap,
  ) async {
    final existing = await fetchAccessMatrix(tierId);
    for (final entry in existing) {
      final featureKey = entry.featureKey;
      if (featureMap.containsKey(featureKey)) {
        await updateAccessEntry(
          entry.id,
          accessLevel: featureMap[featureKey],
          limitParameter:
              featureMap[featureKey] != null &&
                  featureMap[featureKey]!.startsWith('Limité')
              ? {'daily_limit': 3}
              : null,
        );
      }
    }
  }

  // ─── Transactions & Payments ──────────────────────────────────

  Future<List<Transaction>> fetchAmbiguousTransactions() async {
    final rows = await client
        .from('transactions')
        .select()
        .eq('status', 'ambiguous')
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Transaction.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Transaction>> fetchTransactionsByStatus(String status) async {
    final rows = await client
        .from('transactions')
        .select()
        .eq('status', status)
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Transaction.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<Transaction>> watchTransactions(String status) {
    return client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('status', status)
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => Transaction.fromJson(s)).toList(),
        );
  }

  Future<void> reconcileTransaction(String transactionId, String status) async {
    await client
        .from('transactions')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', transactionId);
  }

  // ─── Refund Requests ──────────────────────────────────────────

  Future<List<RefundRequest>> fetchRefundRequests({String? status}) async {
    var query = client.from('refund_requests').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => RefundRequest.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<RefundRequest>> watchRefundRequests() {
    return client
        .from('refund_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'en_attente')
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => RefundRequest.fromJson(s)).toList(),
        );
  }

  Future<void> decideRefund(
    String refundId,
    String status, {
    required String decidedBy,
    String? reason,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'decided_by': decidedBy,
      'decided_at': DateTime.now().toIso8601String(),
    };
    if (reason != null) updates['decision_reason'] = reason;
    await client.from('refund_requests').update(updates).eq('id', refundId);
  }

  // ─── Admin Users & Auth ──────────────────────────────────────

  Future<List<AdminUser>> fetchAdminUsers() async {
    final rows = await client
        .from('admin_users')
        .select()
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => AdminUser.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<AdminUser?> getAdminUserByEmail(String email) async {
    final rows = await client
        .from('admin_users')
        .select()
        .eq('email', email)
        .limit(1)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return AdminUser.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> setAdminUserActive(String id, bool isActive) async {
    await client
        .from('admin_users')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  // ─── Forum Moderation ─────────────────────────────────────────

  Future<List<ForumThread>> fetchFlaggedThreads() async {
    final rows = await client
        .from('forum_threads')
        .select()
        .eq('is_locked', false)
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ForumThread.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<ForumThread>> watchForumThreads() {
    return client
        .from('forum_threads')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => ForumThread.fromJson(s)).toList(),
        );
  }

  Future<void> lockThread(String threadId, bool locked) async {
    await client
        .from('forum_threads')
        .update({'is_locked': locked})
        .eq('id', threadId);
  }

  Future<List<ForumPost>> fetchFlaggedPosts() async {
    final rows = await client
        .from('forum_posts')
        .select()
        .eq('flagged', true)
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ForumPost.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> moderatePost(
    String postId,
    String status, {
    String? reason,
  }) async {
    final updates = <String, dynamic>{'moderation_status': status};
    if (reason != null) updates['flag_reason'] = reason;
    await client.from('forum_posts').update(updates).eq('id', postId);
  }

  // ─── Support Tickets ──────────────────────────────────────────

  Stream<List<SupportTicket>> watchSupportTickets({String? status}) {
    var stream = client.from('support_tickets').stream(primaryKey: ['id']);
    if (status != null) stream = stream.eq('status', status);
    return stream
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => SupportTicket.fromJson(s)).toList(),
        );
  }

  Future<void> assignTicket(String ticketId, String adminId) async {
    await client
        .from('support_tickets')
        .update({'assigned_to': adminId, 'status': 'en_cours'})
        .eq('id', ticketId);
  }

  Future<void> closeTicket(String ticketId, String resolutionNotes) async {
    await client
        .from('support_tickets')
        .update({'status': 'ferme', 'resolution_notes': resolutionNotes})
        .eq('id', ticketId);
  }

  // ─── Events & Official Exams ──────────────────────────────────

  Stream<List<Event>> watchEvents() {
    return client
        .from('events')
        .stream(primaryKey: ['id'])
        .order('start_date', ascending: false)
        .map((snapshot) => snapshot.map((s) => Event.fromJson(s)).toList());
  }

  Future<List<OfficialExam>> fetchOfficialExams({
    String? countryId,
    String? classNodeId,
  }) async {
    var query = client.from('official_exams').select();
    if (countryId != null) query = query.eq('country_id', countryId);
    if (classNodeId != null) query = query.eq('class_node_id', classNodeId);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => OfficialExam.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<ExamPaper>> fetchExamPapers(String examId) async {
    final rows = await client
        .from('exam_papers')
        .select()
        .eq('exam_id', examId)
        .order('year', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ExamPaper.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Announcements ────────────────────────────────────────────

  Stream<List<Announcement>> watchAnnouncements() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => Announcement.fromJson(s)).toList(),
        );
  }

  // ─── Audit Logs ───────────────────────────────────────────────

  Future<List<AuditLog>> fetchAuditLogs({
    String? entityType,
    String? userId,
  }) async {
    var query = client.from('audit_logs').select();
    if (entityType != null) query = query.eq('entity_type', entityType);
    if (userId != null) query = query.eq('admin_user_id', userId);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => AuditLog.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── AI Agents ────────────────────────────────────────────────

  Future<List<AiAgentCall>> fetchAiAgentCalls({int? days}) async {
    var query = client.from('ai_agent_calls').select();
    if (days != null) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      query = query.gte('created_at', cutoff.toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => AiAgentCall.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── WhatsApp Communities ────────────────────────────────────

  Future<List<WhatsappCommunity>> fetchWhatsappCommunities({
    String? countryId,
  }) async {
    var query = client.from('whatsapp_communities').select();
    if (countryId != null) query = query.eq('country_id', countryId);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => WhatsappCommunity.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
}
