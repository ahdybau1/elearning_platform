import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/enums.dart';
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

  static bool _isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value.trim());
  }

  // ─── Academic Nodes ───────────────────────────────────────────

  Future<List<AcademicNode>> fetchAcademicTree({bool includeInactive = false}) async {
    var query = client.from('academic_nodes').select().isFilter('parent_id', null);
    if (!includeInactive) query = query.eq('is_active', true);
    final rootNodes = await query.order('display_order').then((rows) => rows as List);

    return Future.wait(
      rootNodes.map(
        (r) => _buildNodeWithChildren(Map<String, dynamic>.from(r), includeInactive),
      ),
    );
  }

  Future<AcademicNode> _buildNodeWithChildren(
    Map<String, dynamic> data,
    bool includeInactive,
  ) async {
    final node = AcademicNode.fromJson(data);
    var childrenQuery = client.from('academic_nodes').select().eq('parent_id', node.id);
    if (!includeInactive) childrenQuery = childrenQuery.eq('is_active', true);
    final childrenRows =
        await childrenQuery.order('display_order').then((rows) => rows as List);

    final children = await Future.wait(
      childrenRows.map(
        (c) => _buildNodeWithChildren(Map<String, dynamic>.from(c), includeInactive),
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

  Future<AcademicNode?> getNode(String? id) async {
    if (!_isValidUuid(id)) return null;
    final rows = await client
        .from('academic_nodes')
        .select()
        .eq('id', id!)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return AcademicNode.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<AcademicNode>> fetchNodesByType(String nodeType, {Set<String>? countryIds}) async {
    var query = client
        .from('academic_nodes')
        .select()
        .eq('node_type', nodeType)
        .eq('is_active', true);
    if (countryIds != null && countryIds.isNotEmpty) {
      query = query.inFilter('country_id', countryIds.toList());
    }
    final rows = await query.order('display_order').then((rows) => rows as List);
    return (rows)
        .map((r) => AcademicNode.fromJson(Map<String, dynamic>.from(r)))
        .toList();
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

  /// Désactive le nœud ET tous ses descendants (migration 20) — un simple `.update()` sur la seule
  /// ligne ciblée laissait les enfants actifs, visibles et incohérents dès que "Afficher les
  /// nœuds inactifs" était coché, alors que la boîte de confirmation affirme (à raison désormais)
  /// que les enfants sont eux aussi désactivés.
  Future<void> deactivateNode(String id, String adminId) async {
    await client.rpc('deactivate_academic_node_cascade', params: {
      'p_node_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Symétrique de [deactivateNode] (migration 21) — réactive le nœud ET tous ses descendants,
  /// pour éviter qu'une réactivation "un par un" via "Modifier" laisse des descendants inactifs.
  Future<void> reactivateNode(String id, String adminId) async {
    await client.rpc('reactivate_academic_node_cascade', params: {
      'p_node_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Suppression PHYSIQUE réelle (migration 21) — contrairement à l'ancien bouton "Supprimer
  /// Définitivement" qui n'était qu'un alias de la désactivation. Réservée aux nœuds déjà
  /// désactivés côté base ; échoue avec un message clair si des élèves ou d'autres données sont
  /// encore rattachés au sous-arbre.
  Future<void> permanentlyDeleteNode(String id, String adminId) async {
    await client.rpc('permanently_delete_academic_node', params: {
      'p_node_id': id,
      'p_admin_id': adminId,
    });
  }

  Stream<List<AcademicNode>> watchAcademicTree({bool includeInactive = false}) async* {
    yield await fetchAcademicTree(includeInactive: includeInactive);
    yield* client
        .from('academic_nodes')
        .stream(primaryKey: ['id'])
        .order('display_order')
        .map((snapshot) {
          final flat = snapshot
              .where((s) => includeInactive || s['is_active'] != false)
              .map((s) => AcademicNode.fromJson(Map<String, dynamic>.from(s)))
              .toList();
          return _buildTreeFromFlatList(flat, null);
        });
  }

  // AcademicNode.children est final : impossible de la peupler après coup sur une instance déjà
  // construite. On reconstruit donc l'arbre depuis la liste plate en reconstruisant chaque nœud
  // avec sa liste d'enfants déjà résolue (récursif, feuilles d'abord).
  List<AcademicNode> _buildTreeFromFlatList(
    List<AcademicNode> flat,
    String? parentId,
  ) {
    return flat.where((n) => n.parentId == parentId).map((n) {
      final children = _buildTreeFromFlatList(flat, n.id);
      return AcademicNode(
        id: n.id,
        parentId: n.parentId,
        nodeType: n.nodeType,
        name: n.name,
        code: n.code,
        countryId: n.countryId,
        displayOrder: n.displayOrder,
        isActive: n.isActive,
        createdAt: n.createdAt,
        updatedAt: n.updatedAt,
        children: children,
      );
    }).toList();
  }

  Future<void> updateNodeOrder(String id, int displayOrder) async {
    await client
        .from('academic_nodes')
        .update({
          'display_order': displayOrder,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Nombre de profils élèves réellement rattachés à ce nœud — utilisé pour afficher un
  /// impact réel (pas une estimation générique) avant suppression.
  Future<int> countProfilesForNode(String nodeId) async {
    final rows = await client
        .from('profiles')
        .select('id')
        .eq('class_node_id', nodeId)
        .then((r) => r as List);
    return rows.length;
  }

  /// Fusionne deux Classes ou deux Séries (Section 3.2 du CDC) : réattribue élèves, rattachements
  /// matière↔classe, paliers, examens, communautés et boutique du nœud source vers le nœud cible,
  /// puis désactive le nœud source. Opération atomique côté serveur (voir migration
  /// 12_merge_class_nodes.sql) — trop de tables impactées pour rester sûr avec des appels
  /// séquentiels côté client.
  Future<void> mergeClassNodes({
    required String sourceId,
    required String targetId,
    required String adminId,
  }) async {
    await client.rpc('merge_academic_class_nodes', params: {
      'p_source_id': sourceId,
      'p_target_id': targetId,
      'p_admin_id': adminId,
    });
  }

  // ─── Subjects ─────────────────────────────────────────────────

  Future<List<Subject>> fetchSubjects({Set<String>? countryIds, bool includeInactive = false}) async {
    var query = client.from('subjects').select();
    if (countryIds != null && countryIds.isNotEmpty) {
      query = query.inFilter('country_id', countryIds.toList());
    }
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('name').then((rows) => rows as List);
    return (rows)
        .map((r) => Subject.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Subject?> getSubject(String id) async {
    if (!_isValidUuid(id)) return null;
    final rows = await client
        .from('subjects')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Subject.fromJson(Map<String, dynamic>.from(rows.first));
  }

  /// Matières réellement enseignées dans une classe donnée (jointure subject_class_links), pour
  /// que le filtre "Classe" de l'écran Leçons & Cours ait un effet réel au lieu d'être décoratif.
  Future<List<Subject>> fetchSubjectsForClass(String classNodeId) async {
    if (!_isValidUuid(classNodeId)) return [];
    final links = await client
        .from('subject_class_links')
        .select('subject_id')
        .eq('class_node_id', classNodeId)
        .then((r) => r as List);
    if (links.isEmpty) return [];
    final subjectIds = links.map((l) => l['subject_id'] as String).toList();
    final rows = await client
        .from('subjects')
        .select()
        .inFilter('id', subjectIds)
        .order('name')
        .then((r) => r as List);
    return (rows)
        .map((r) => Subject.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Chapters ─────────────────────────────────────────────────

  Future<List<Chapter>> fetchChapters(
    String subjectId, {
    String? termId,
    String? classNodeId,
    bool includeInactive = false,
  }) async {
    if (!_isValidUuid(subjectId)) return [];
    var query = client.from('chapters').select().eq('subject_id', subjectId);
    if (_isValidUuid(termId)) query = query.eq('term_id', termId!);
    // Un chapitre sans class_node_id (créé avant cette colonne, ou pas encore reclassé) reste
    // visible sous chaque classe filtrée plutôt que de disparaître silencieusement — voir
    // migration 15_chapters_class_scoping.sql.
    if (_isValidUuid(classNodeId)) {
      query = query.or('class_node_id.eq.$classNodeId,class_node_id.is.null');
    }
    if (!includeInactive) query = query.eq('is_active', true);
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

  Future<List<Chapter>> fetchChaptersWithLessons(
    String subjectId, {
    String? classNodeId,
    bool includeInactive = false,
  }) async {
    var query = client.from('chapters').select().eq('subject_id', subjectId);
    if (_isValidUuid(classNodeId)) {
      query = query.or('class_node_id.eq.$classNodeId,class_node_id.is.null');
    }
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('display_order').then((rows) => rows as List);

    return Future.wait(
      (rows).map((r) async {
        final chapter = Chapter.fromJson(Map<String, dynamic>.from(r));
        final lessons = await fetchLessonsForChapter(
          chapter.id,
          includeInactive: includeInactive,
        );
        return Chapter(
          id: chapter.id,
          subjectId: chapter.subjectId,
          classNodeId: chapter.classNodeId,
          termId: chapter.termId,
          title: chapter.title,
          introduction: chapter.introduction,
          introMedia: chapter.introMedia,
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

  Future<List<Lesson>> fetchLessonsForChapter(
    String chapterId, {
    bool includeInactive = false,
  }) async {
    var query = client.from('lessons').select().eq('chapter_id', chapterId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('display_order').then((rows) => rows as List);
    return (rows)
        .map((r) => Lesson.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Lesson>> fetchLessons({
    String? chapterId,
  }) async {
    // NB: lessons n'a pas de colonne subject_id (seulement chapter_id) — un filtre par matière
    // doit d'abord résoudre les chapitres de cette matière (voir fetchChaptersWithLessons).
    var query = client.from('lessons').select();
    if (_isValidUuid(chapterId)) query = query.eq('chapter_id', chapterId!);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Lesson.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Lesson?> getLesson(String id) async {
    if (!_isValidUuid(id)) return null;
    final rows = await client
        .from('lessons')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Lesson.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<Exercise>> fetchExercises({
    String? lessonId,
    String? chapterId,
  }) async {
    var query = client.from('exercises').select();
    if (_isValidUuid(lessonId)) query = query.eq('lesson_id', lessonId!);
    if (_isValidUuid(chapterId)) query = query.eq('chapter_id', chapterId!);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Exercise>> fetchAllExercises({bool includeInactive = false}) async {
    var query = client.from('exercises').select();
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('created_at', ascending: false).then((rows) => rows as List);
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

  /// Statut réel de validation (en_attente/approuve/rejete/a_corriger) pour un lot de contenus,
  /// utilisé pour afficher un badge fidèle sur les écrans Leçons & Cours / Exercices au lieu du
  /// seul booléen is_published qui ne distingue pas "jamais soumis" de "rejeté".
  Future<Map<String, String>> fetchValidationStatusForContentIds(List<String> contentIds) async {
    if (contentIds.isEmpty) return {};
    final rows = await client
        .from('validation_queue')
        .select('content_id, status')
        .inFilter('content_id', contentIds)
        .then((r) => r as List);
    final map = <String, String>{};
    for (final row in rows) {
      map[row['content_id'] as String] = row['status'] as String;
    }
    return map;
  }

  /// Diffuse TOUS les statuts (pas seulement en_attente) — l'écran File de Validation filtre
  /// lui-même par statut pour ses onglets Approuvés/Rejetés/À corriger, qui resteraient vides en
  /// permanence si ce flux ne laissait passer que les éléments encore en attente.
  Stream<List<ValidationQueueItem>> watchValidationQueue() async* {
    yield await fetchValidationQueue();
    yield* client
        .from('validation_queue')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot.map((s) => ValidationQueueItem.fromJson(s)).toList(),
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
    if (_isValidUuid(countryId)) query = query.eq('country_id', countryId!);
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

  /// `subscription_tiers` n'a pas de colonne `updated_at` (voir reset_project_schema.sql) — l'ancien
  /// code en envoyait une inconditionnellement à chaque appel, ce qui faisait échouer TOUTE mise à
  /// jour de palier avec une erreur Postgrest "colonne introuvable". `name` a aussi été ajouté :
  /// l'écran d'édition affiche un champ nom modifiable qui n'était jamais réellement sauvegardé.
  Future<void> updateTier(String id, {String? name, double? price, int? durationDays}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (price != null) updates['price'] = price;
    if (durationDays != null) updates['duration_days'] = durationDays;
    if (updates.isEmpty) return;
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

  Stream<List<Transaction>> watchTransactions(String status) async* {
    yield await fetchTransactionsByStatus(status);
    yield* client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot
              .where((s) => s['status'] == status)
              .map((s) => Transaction.fromJson(s))
              .toList(),
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

  /// Jointure sur transactions ajoutée : sans elle, RefundRequest.transaction restait toujours
  /// null et le montant du remboursement s'affichait comme "••••" pour tout le monde, y compris un
  /// Super-Admin habilité à le voir.
  Future<List<RefundRequest>> fetchRefundRequests({String? status}) async {
    var query = client.from('refund_requests').select('*, transaction:transactions(*)');
    if (status != null) query = query.eq('status', status);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => RefundRequest.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<RefundRequest>> watchRefundRequests() async* {
    yield await fetchRefundRequests();
    yield* client
        .from('refund_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot
              .where((s) => s['status'] == 'en_attente')
              .map((s) => RefundRequest.fromJson(s))
              .toList(),
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

  // Résout l'admin par le lien Supabase Auth (auth_user_id = auth.uid()), jamais par un état codé
  // en dur : une erreur ou une absence de résultat doit rester visible à l'appelant (voir
  // 03_auth_flow.md — aucun état "de secours" qui masque un échec d'authentification).
  Future<AdminUser?> getAdminUserByAuthId(String authUserId) async {
    final rows = await client
        .from('admin_users')
        .select()
        .eq('auth_user_id', authUserId)
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

  Future<List<SupportTicket>> fetchSupportTickets({String? status}) async {
    var query = client.from('support_tickets').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => SupportTicket.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<SupportTicket>> watchSupportTickets({String? status}) async* {
    yield await fetchSupportTickets(status: status);
    yield* client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (snapshot) => snapshot
              .where((s) => status == null || s['status'] == status)
              .map((s) => SupportTicket.fromJson(s))
              .toList(),
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
    if (_isValidUuid(countryId)) query = query.eq('country_id', countryId!);
    if (_isValidUuid(classNodeId)) query = query.eq('class_node_id', classNodeId!);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => OfficialExam.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<ExamPaper>> fetchExamPapers(String examId) async {
    if (!_isValidUuid(examId)) return [];
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

  Future<List<Announcement>> fetchAnnouncements({String? countryId}) async {
    var query = client.from('announcements').select();
    if (_isValidUuid(countryId)) query = query.eq('target_country_id', countryId!);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Announcement.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<Announcement>> watchAnnouncements() async* {
    yield await fetchAnnouncements();
    yield* client
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
    var query = client.from('audit_log').select();
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
    String? classNodeId,
  }) async {
    var query = client.from('whatsapp_communities').select();
    if (_isValidUuid(classNodeId)) query = query.eq('class_node_id', classNodeId!);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => WhatsappCommunity.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> upsertWhatsappCommunity({
    String? id,
    required String classNodeId,
    required String inviteLink,
    int memberCountEstimate = 0,
    bool isActive = true,
  }) async {
    final data = <String, dynamic>{
      'class_node_id': classNodeId,
      'invite_link': inviteLink,
      'member_count_estimate': memberCountEstimate,
      'is_active': isActive,
    };
    if (id != null) {
      await client.from('whatsapp_communities').update(data).eq('id', id);
    } else {
      await client.from('whatsapp_communities').insert(data);
    }
  }

  Future<void> deleteWhatsappCommunity(String id) async {
    await client.from('whatsapp_communities').update({'is_active': false}).eq('id', id);
  }

  // ─── KPI Counts (Dashboard) ───────────────────────────────────

  Future<int> countActiveProfiles() async {
    final res = await client
        .from('profiles')
        .select('id')
        .eq('status', 'actif');
    return (res as List).length;
  }

  Future<int> countPublishedLessons() async {
    final res = await client
        .from('lessons')
        .select('id')
        .eq('is_published', true);
    return (res as List).length;
  }

  Future<int> countExercises() async {
    final res = await client.from('exercises').select('id');
    return (res as List).length;
  }

  Future<int> countPendingValidation() async {
    final res = await client
        .from('validation_queue')
        .select('id')
        .eq('status', 'en_attente');
    return (res as List).length;
  }

  Future<int> countOpenTickets() async {
    final res = await client
        .from('support_tickets')
        .select('id')
        .eq('status', 'ouvert');
    return (res as List).length;
  }




  Future<void> upsertAccessMatrixEntry({
    required String tierId,
    required String featureKey,
    required String accessLevel,
    Map<String, dynamic>? limitParameter,
  }) async {
    await client.from('access_matrix').upsert(
      {
        'tier_id': tierId,
        'feature_key': featureKey,
        'access_level': accessLevel,
        'limit_parameter': limitParameter ?? {},
      },
      onConflict: 'tier_id,feature_key',
    );
  }

  Future<void> upsertAccessMatrix(List<Map<String, dynamic>> entries) async {
    await client.from('access_matrix').upsert(
      entries,
      onConflict: 'tier_id,feature_key',
    );
  }

  /// Catalogue des fonctionnalités de la Matrice de Droits (migration 28) — avant, cette liste
  /// était codée en dur côté Dart, sans aucun moyen pour l'admin d'en ajouter/modifier/supprimer.
  Future<List<MatrixFeature>> fetchMatrixFeatures() async {
    final rows = await client
        .from('matrix_features')
        .select()
        .order('display_order')
        .then((r) => r as List);
    return (rows).map((r) => MatrixFeature.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> createMatrixFeature({
    required String featureKey,
    required String label,
    String iconName = 'lock',
    bool isEnforced = false,
    int displayOrder = 0,
  }) async {
    await client.from('matrix_features').insert({
      'feature_key': featureKey,
      'label': label,
      'icon_name': iconName,
      'is_enforced': isEnforced,
      'display_order': displayOrder,
    });
  }

  Future<void> updateMatrixFeature(
    String id, {
    String? label,
    String? iconName,
    int? displayOrder,
  }) async {
    final data = <String, dynamic>{};
    if (label != null) data['label'] = label;
    if (iconName != null) data['icon_name'] = iconName;
    if (displayOrder != null) data['display_order'] = displayOrder;
    if (data.isEmpty) return;
    await client.from('matrix_features').update(data).eq('id', id);
  }

  /// Supprime la définition ET toutes les règles d'accès qui la référencent dans access_matrix
  /// (pas de FK entre les deux tables — feature_key n'est qu'un TEXT partagé — donc le nettoyage
  /// est fait explicitement ici plutôt que de laisser des lignes orphelines invisibles).
  Future<void> deleteMatrixFeature(String id, String featureKey) async {
    await client.from('access_matrix').delete().eq('feature_key', featureKey);
    await client.from('matrix_features').delete().eq('id', id);
  }

  // ─── Validation Queue Actions ─────────────────────────────────

  /// Marque la file de validation "approuve" ET publie le contenu en une seule transaction
  /// (migration 24) — deux écritures séparées laissaient une fenêtre où la queue pouvait être
  /// approuvée sans que le contenu soit jamais réellement publié si la seconde échouait.
  Future<void> approveContent(String validationId, String reviewerId) async {
    await client.rpc('approve_and_publish_content', params: {
      'p_validation_id': validationId,
      'p_reviewer_id': reviewerId,
    });
  }

  Future<void> rejectContent(
    String validationId,
    String reviewerId, {
    required String notes,
  }) async {
    await client
        .from('validation_queue')
        .update({
          'status': 'rejete',
          'reviewer_id': reviewerId,
          'review_notes': notes,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', validationId);
  }

  Future<void> sendBackContent(
    String validationId,
    String reviewerId, {
    required String notes,
  }) async {
    await client
        .from('validation_queue')
        .update({
          'status': 'a_corriger',
          'reviewer_id': reviewerId,
          'review_notes': notes,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', validationId);
  }

  // ─── Payment Reconciliation CRUD ─────────────────────────────

  Future<void> createReconciliation({
    required String transactionId,
    required String issueType,
    String? notes,
  }) async {
    await client.from('payment_reconciliation').insert({
      'transaction_id': transactionId,
      'issue_type': issueType,
      'notes': notes,
      'status': 'pending',
    });
  }

  Future<void> resolveReconciliation(
    String reconciliationId,
    String resolvedBy, {
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'status': 'resolved',
      'resolved_by': resolvedBy,
    };
    if (notes != null) data['notes'] = notes;
    await client
        .from('payment_reconciliation')
        .update(data)
        .eq('id', reconciliationId);
    // Also mark transaction as success
    final row = await client
        .from('payment_reconciliation')
        .select('transaction_id')
        .eq('id', reconciliationId)
        .single();
    await client
        .from('transactions')
        .update({'status': 'success'})
        .eq('id', row['transaction_id']);
  }

  Future<List<PaymentReconciliation>> fetchPendingReconciliations() async {
    final rows = await client
        .from('payment_reconciliation')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .then((r) => r as List);
    return rows
        .map((r) =>
            PaymentReconciliation.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Admin Users CRUD ─────────────────────────────────────────

  /// Avant : simple INSERT dans `admin_users` sans jamais créer de compte Supabase Auth —
  /// l'administrateur créé n'avait aucun moyen de se connecter. Passe désormais par une Edge Function
  /// (comme pour élèves/parents/enseignants) qui crée l'utilisateur Auth ET la ligne `admin_users` de
  /// façon atomique.
  Future<void> createAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final res = await client.functions.invoke(
      'admin-create-admin-account',
      body: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de création du compte administrateur');
    }
  }

  Future<void> updateAdminUser(
    String id, {
    String? firstName,
    String? lastName,
    String? role,
    Map<String, dynamic>? scopeJson,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (role != null) data['role'] = role;
    if (scopeJson != null) data['scope_json'] = scopeJson;
    if (isActive != null) data['is_active'] = isActive;
    await client.from('admin_users').update(data).eq('id', id);
  }

  Future<void> deleteAdminUser(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('admin_users').delete().eq('id', id);
  }

  // ─── Section 5.4 / 22 : Comptes Enseignants & Rattachements Multi-Établissements ─────

  /// Contrairement aux autres rôles admin (créés par simple insertion, sans compte Auth utilisable),
  /// un enseignant doit pouvoir réellement se connecter — passe donc par une Edge Function
  /// `admin-create-teacher-account` qui crée l'utilisateur Supabase Auth ET la ligne `admin_users`
  /// (role='enseignant') de façon atomique, comme pour les élèves et les parents.
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    bool isActive = true,
  }) async {
    final res = await client.functions.invoke(
      'admin-create-teacher-account',
      body: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'is_active': isActive,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de création du compte enseignant');
    }
  }

  Future<List<Establishment>> fetchEstablishments({String? countryId}) async {
    var query = client.from('establishments').select();
    if (_isValidUuid(countryId)) {
      query = query.eq('country_id', countryId!);
    }
    final rows = await query.order('name').then((r) => r as List);
    return rows.map((r) => Establishment.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> createEstablishment({
    required String countryId,
    required String name,
    required String city,
  }) async {
    await client.from('establishments').insert({
      'country_id': countryId,
      'name': name,
      'city': city,
    });
  }

  Future<void> updateEstablishment(
    String id, {
    String? name,
    String? city,
    bool? isActive,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (city != null) data['city'] = city;
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('establishments').update(data).eq('id', id);
  }

  Future<void> deleteEstablishment(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('establishments').delete().eq('id', id);
  }

  Future<int> countTeachersForEstablishment(String establishmentId) async {
    if (!_isValidUuid(establishmentId)) return 0;
    final rows = await client
        .from('teacher_establishments')
        .select('id')
        .eq('establishment_id', establishmentId)
        .then((r) => r as List);
    return rows.length;
  }

  // ─── Section 4.2 : Épreuves d'Établissement ────────────────────

  Future<List<EstablishmentPaper>> fetchEstablishmentPapers(String establishmentId) async {
    if (!_isValidUuid(establishmentId)) return [];
    final rows = await client
        .from('establishment_papers')
        .select()
        .eq('establishment_id', establishmentId)
        .order('year', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => EstablishmentPaper.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> addEstablishmentPaper({
    required String establishmentId,
    required String classNodeId,
    required String subjectId,
    required int year,
    required String documentUrl,
    String? correctionUrl,
  }) async {
    await client.from('establishment_papers').insert({
      'establishment_id': establishmentId,
      'class_node_id': classNodeId,
      'subject_id': subjectId,
      'year': year,
      'document_url': documentUrl,
      'correction_url': correctionUrl,
    });
  }

  Future<void> deleteEstablishmentPaper(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('establishment_papers').delete().eq('id', id);
  }

  Future<List<TeacherEstablishmentLink>> fetchTeacherEstablishments(String teacherId) async {
    if (!_isValidUuid(teacherId)) return [];
    final rows = await client
        .from('teacher_establishments')
        .select('id, establishment_id, subjects_scope, classes_scope, establishments(name, city)')
        .eq('teacher_id', teacherId)
        .then((r) => r as List);
    return rows
        .map((r) => TeacherEstablishmentLink.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> attachTeacherToEstablishment({
    required String teacherId,
    required String establishmentId,
    List<String> subjectsScope = const [],
    List<String> classesScope = const [],
  }) async {
    await client.from('teacher_establishments').upsert(
      {
        'teacher_id': teacherId,
        'establishment_id': establishmentId,
        'subjects_scope': subjectsScope,
        'classes_scope': classesScope,
      },
      onConflict: 'teacher_id,establishment_id',
    );
  }

  Future<void> detachTeacherFromEstablishment({
    required String teacherId,
    required String establishmentId,
  }) async {
    await client
        .from('teacher_establishments')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('establishment_id', establishmentId);
  }

  Future<void> grantPermission(
    String adminId,
    String permissionKey,
  ) async {
    await client.from('admin_permissions').upsert(
      {
        'admin_user_id': adminId,
        'permission_key': permissionKey,
        'granted': true,
      },
      onConflict: 'admin_user_id,permission_key',
    );
  }

  Future<void> revokePermission(
    String adminId,
    String permissionKey,
  ) async {
    await client
        .from('admin_permissions')
        .update({'granted': false})
        .eq('admin_user_id', adminId)
        .eq('permission_key', permissionKey);
  }

  Future<List<AdminPermission>> fetchPermissions(String adminId) async {
    final rows = await client
        .from('admin_permissions')
        .select()
        .eq('admin_user_id', adminId)
        .then((r) => r as List);
    return rows
        .map((r) => AdminPermission.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Academic Node CRUD ───────────────────────────────────────

  Future<AcademicNode?> createAcademicNode({
    String? parentId,
    required String nodeType,
    required String name,
    String? code,
    String? countryId,
    required int displayOrder,
  }) async {
    final data = <String, dynamic>{
      'node_type': nodeType,
      'name': name,
      'is_active': true,
      'display_order': displayOrder,
    };
    if (parentId != null) data['parent_id'] = parentId;
    if (code != null) data['code'] = code;
    if (countryId != null) data['country_id'] = countryId;
    final rows = await client
        .from('academic_nodes')
        .insert(data)
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return AcademicNode.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateAcademicNode(
    String id, {
    String? name,
    String? code,
    bool? isActive,
    int? displayOrder,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) data['name'] = name;
    if (code != null) data['code'] = code;
    if (isActive != null) data['is_active'] = isActive;
    if (displayOrder != null) data['display_order'] = displayOrder;
    await client.from('academic_nodes').update(data).eq('id', id);
  }

  Future<void> archiveAcademicNode(String id) async {
    await client
        .from('academic_nodes')
        .update({'is_active': false})
        .eq('id', id);
  }

  // Duplique un nœud de l'arbre académique et tout son sous-arbre (Section 3.2 du CDC : "dupliquer"
  // fait partie des opérations attendues sur l'arbre académique).
  Future<void> duplicateAcademicNode(String nodeId) async {
    final rows = await client
        .from('academic_nodes')
        .select()
        .eq('id', nodeId)
        .limit(1)
        .then((r) => r as List);
    if (rows.isEmpty) return;
    final original = Map<String, dynamic>.from(rows.first);
    await _duplicateNodeRecursive(
      original,
      original['parent_id'] as String?,
      renameSuffix: ' (copie)',
    );
  }

  Future<String> _duplicateNodeRecursive(
    Map<String, dynamic> node,
    String? newParentId, {
    String renameSuffix = '',
  }) async {
    final insertData = <String, dynamic>{
      'node_type': node['node_type'],
      'name': '${node['name']}$renameSuffix',
      // Copie désactivée par défaut (annoncé explicitement dans la boîte de confirmation de
      // duplication) : évite qu'un doublon de contenu live n'apparaisse immédiatement aux élèves
      // avant relecture par l'admin.
      'is_active': false,
      'display_order': node['display_order'] ?? 0,
    };
    if (newParentId != null) insertData['parent_id'] = newParentId;
    if (node['code'] != null) insertData['code'] = node['code'];
    if (node['country_id'] != null) insertData['country_id'] = node['country_id'];

    final inserted = await client
        .from('academic_nodes')
        .insert(insertData)
        .select()
        .then((r) => (r as List).first as Map<String, dynamic>);
    final newId = inserted['id'] as String;

    final children = await client
        .from('academic_nodes')
        .select()
        .eq('parent_id', node['id'] as String)
        .then((r) => r as List);
    for (final child in children) {
      await _duplicateNodeRecursive(Map<String, dynamic>.from(child), newId);
    }
    return newId;
  }

  // ─── Announcements CRUD ───────────────────────────────────────

  Future<Announcement?> createAnnouncement({
    required String title,
    required String message,
    required String urgency,
    String? targetCountryId,
    String? targetClassId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final rows = await client
        .from('announcements')
        .insert({
          'title': title,
          'message': message,
          'urgency': urgency,
          'target_country_id': targetCountryId,
          'target_class_id': targetClassId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'is_active': true,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Announcement.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? message,
    String? urgency,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (message != null) data['message'] = message;
    if (urgency != null) data['urgency'] = urgency;
    if (isActive != null) data['is_active'] = isActive;
    if (startDate != null) data['start_date'] = startDate.toIso8601String();
    if (endDate != null) data['end_date'] = endDate.toIso8601String();
    await client.from('announcements').update(data).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await client.from('announcements').update({'is_active': false}).eq('id', id);
  }

  // ─── Events CRUD ──────────────────────────────────────────────

  Future<Event?> createEvent({
    required String type,
    required String countryId,
    required String classNodeId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required String pricingMode,
    double price = 0.00,
  }) async {
    final rows = await client
        .from('events')
        .insert({
          'type': type,
          'country_id': countryId,
          'class_node_id': classNodeId,
          'title': title,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'pricing_mode': pricingMode,
          'price': price,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Event.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateEvent(
    String id, {
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? pricingMode,
    double? price,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (startDate != null) data['start_date'] = startDate.toIso8601String();
    if (endDate != null) data['end_date'] = endDate.toIso8601String();
    if (pricingMode != null) data['pricing_mode'] = pricingMode;
    if (price != null) data['price'] = price;
    await client.from('events').update(data).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('events').delete().eq('id', id);
  }

  // ─── Section 11 : Résultats & Section 27 : Contestations de Notes ──────

  Future<List<EventResult>> fetchEventResults(String eventId) async {
    if (!_isValidUuid(eventId)) return [];
    final rows = await client
        .from('event_results')
        .select('*, profiles(school_year, accounts(first_name, last_name))')
        .eq('event_id', eventId)
        .order('score', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => EventResult.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// Saisie manuelle d'une note (interface de correction, §11) — utilisée telle quelle pour les
  /// formats numériques/QCM ; sert aussi de point de saisie final pour l'oral et le manuscrit, dont la
  /// correction elle-même (écoute audio/vidéo, lecture de copie) se fait hors de cette interface tant
  /// que le stockage des soumissions élève n'existe pas côté student_app.
  Future<void> addEventResult({
    required String eventId,
    required String profileId,
    required double score,
  }) async {
    await client.from('event_results').insert({
      'event_id': eventId,
      'profile_id': profileId,
      'score': score,
    });
  }

  Future<void> updateEventResultScore(String id, double score) async {
    if (!_isValidUuid(id)) return;
    await client.from('event_results').update({'score': score}).eq('id', id);
  }

  Future<List<GradeDispute>> fetchGradeDisputes() async {
    final rows = await client
        .from('grade_disputes')
        .select('*, event_results(profiles(accounts(first_name, last_name)), events(title))')
        .order('created_at', ascending: false)
        .then((r) => r as List);
    return rows.map((r) => GradeDispute.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// Décision sur une contestation (§27) : maintenue (statut rejete, note inchangée) ou révisée
  /// (statut resolu, nouvelle note propagée sur event_results.score par le trigger applicatif — ici
  /// fait explicitement pour rester simple, pas de trigger DB dédié).
  Future<void> resolveGradeDispute(
    String disputeId, {
    required bool accepted,
    double? revisedScore,
    required String resolutionNotes,
    required String reviewerId,
  }) async {
    if (!_isValidUuid(disputeId)) return;
    final dispute = await client
        .from('grade_disputes')
        .select('event_result_id')
        .eq('id', disputeId)
        .single();
    await client.from('grade_disputes').update({
      'status': accepted ? 'resolu' : 'rejete',
      'revised_score': accepted ? revisedScore : null,
      'resolution_notes': resolutionNotes,
      'assigned_reviewer_id': reviewerId,
    }).eq('id', disputeId);
    if (accepted && revisedScore != null) {
      await client
          .from('event_results')
          .update({'score': revisedScore}).eq('id', dispute['event_result_id'] as String);
    }
  }

  // ─── Refund Decisions ─────────────────────────────────────────

  Future<void> approveRefund(
    String refundId,
    String adminId, {
    String? reason,
  }) async {
    await client.from('refund_requests').update({
      'status': 'accepte',
      'decided_by': adminId,
      'decision_reason': reason,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', refundId);
  }

  Future<void> rejectRefund(
    String refundId,
    String adminId, {
    required String reason,
  }) async {
    await client.from('refund_requests').update({
      'status': 'refuse',
      'decided_by': adminId,
      'decision_reason': reason,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', refundId);
  }

  // ─── Official Exams CRUD ──────────────────────────────────────

  Future<OfficialExam?> createOfficialExam({
    required String countryId,
    required String classNodeId,
    required String name,
    DateTime? examDate,
  }) async {
    final rows = await client
        .from('official_exams')
        .insert({
          'country_id': countryId,
          'class_node_id': classNodeId,
          'name': name,
          'exam_date': examDate?.toIso8601String(),
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return OfficialExam.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateOfficialExam(
    String id, {
    String? name,
    String? classNodeId,
    DateTime? examDate,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (classNodeId != null) data['class_node_id'] = classNodeId;
    if (examDate != null) data['exam_date'] = examDate.toIso8601String();
    if (data.isEmpty) return;
    await client.from('official_exams').update(data).eq('id', id);
  }

  Future<void> deleteOfficialExam(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('official_exams').delete().eq('id', id);
  }

  Future<ExamPaper?> addExamPaper({
    required String examId,
    required String subjectId,
    required int year,
    required String documentUrl,
    String? correctionUrl,
  }) async {
    final rows = await client
        .from('exam_papers')
        .insert({
          'exam_id': examId,
          'subject_id': subjectId,
          'year': year,
          'document_url': documentUrl,
          'correction_url': correctionUrl,
          'is_correction_unlocked': correctionUrl != null,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return ExamPaper.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> toggleCorrectionUnlock(String paperId, bool unlocked) async {
    await client
        .from('exam_papers')
        .update({'is_correction_unlocked': unlocked})
        .eq('id', paperId);
  }

  Future<void> deleteExamPaper(String paperId) async {
    await client.from('exam_papers').delete().eq('id', paperId);
  }

  // ─── Subjects CRUD ────────────────────────────────────────────

  Future<Subject?> createSubject({
    required String name,
    required String code,
    String? countryId,
  }) async {
    final rows = await client
        .from('subjects')
        .insert({
          'name': name,
          'code': code,
          'country_id': countryId,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Subject.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> linkSubjectToClass(String subjectId, String classNodeId) async {
    await client.from('subject_class_links').upsert(
      {'subject_id': subjectId, 'class_node_id': classNodeId},
      onConflict: 'subject_id,class_node_id',
    );
  }

  /// Rattache une matière à plusieurs classes/séries d'un coup — sans au moins un lien, une
  /// matière nouvellement créée reste invisible dans le sélecteur "Matière" de Chapitres & Leçons
  /// (qui ne liste que les matières jointes via subject_class_links pour la classe choisie).
  Future<void> linkSubjectToClasses(String subjectId, List<String> classNodeIds) async {
    for (final classNodeId in classNodeIds) {
      await linkSubjectToClass(subjectId, classNodeId);
    }
  }

  Future<void> unlinkSubjectFromClass(String subjectId, String classNodeId) async {
    await client
        .from('subject_class_links')
        .delete()
        .eq('subject_id', subjectId)
        .eq('class_node_id', classNodeId);
  }

  Future<void> updateSubject({
    required String id,
    String? name,
    String? code,
    bool updateCountryId = false,
    String? countryId,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (code != null) data['code'] = code;
    if (updateCountryId) data['country_id'] = countryId;
    if (data.isEmpty) return;
    await client.from('subjects').update(data).eq('id', id);
  }

  Future<void> toggleSubjectActive(String id, bool isActive) async {
    await client.from('subjects').update({'is_active': isActive}).eq('id', id);
  }

  /// Suppression PHYSIQUE réelle d'une matière (migration 25) — réservée aux matières déjà
  /// archivées ET sans chapitre rattaché (chapters.subject_id cascade sur leçons/exercices : un
  /// rayon d'action bien plus large qu'un chapitre isolé, donc bloqué côté SQL tant qu'il en reste).
  Future<void> permanentlyDeleteSubject(String id, String adminId) async {
    await client.rpc('permanently_delete_subject', params: {
      'p_subject_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Appelle l'agent IA de génération de types d'éléments du Catalogue Pédagogique (Edge Function
  /// ai-catalog-types-generation, miroir de ai-exercise-generation) — évite d'avoir à taper un par
  /// un les types (Théorème, Définition...) qui seront injectés dans le prompt de structuration de
  /// cours pour cette matière.
  Future<List<Map<String, dynamic>>> generateAiCatalogTypes({
    String? subjectId,
    required String subjectName,
    String? educationLevel,
    String? countryId,
    int count = 8,
    String? rawNotes,
  }) async {
    final res = await client.functions.invoke(
      'ai-catalog-types-generation',
      body: {
        'subject_id': subjectId,
        'subject_name': subjectName,
        'education_level': educationLevel,
        'country_id': countryId,
        'count': count,
        'raw_notes': rawNotes,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de la génération IA');
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    return List<Map<String, dynamic>>.from(
      (data['types'] as List? ?? []).map((t) => Map<String, dynamic>.from(t as Map)),
    );
  }

  /// Classes/Séries où cette matière est enseignée (lecture inverse de subject_class_links) —
  /// n'implique AUCUN partage de contenu entre ces classes : chaque chapitre reste rattaché à une
  /// seule classe via chapters.class_node_id (voir migration 15).
  Future<List<AcademicNode>> fetchClassesForSubject(String subjectId) async {
    if (!_isValidUuid(subjectId)) return [];
    final links = await client
        .from('subject_class_links')
        .select('class_node_id')
        .eq('subject_id', subjectId)
        .then((r) => r as List);
    if (links.isEmpty) return [];
    final classIds = links.map((l) => l['class_node_id'] as String).toList();
    final rows = await client
        .from('academic_nodes')
        .select()
        .inFilter('id', classIds)
        .eq('is_active', true)
        .order('name')
        .then((r) => r as List);
    return (rows)
        .map((r) => AcademicNode.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Appelle l'agent IA de structuration de cours (Edge Function ai-course-structuring, Section
  /// 16.0 du CDC) : transforme des notes brutes en cours structuré (sections, formules LaTeX,
  /// pièges classiques, conseils d'examen, quiz). Retourne le JSON structuré tel quel — l'appelant
  /// décide comment le fusionner dans le contenu de la leçon.
  Future<Map<String, dynamic>> generateAiLessonDraft({
    String? chapterId,
    String? subjectId,
    required String rawNotes,
    String? promptDirectives,
  }) async {
    final res = await client.functions.invoke(
      'ai-course-structuring',
      body: {
        'chapter_id': chapterId,
        'subject_id': subjectId,
        'raw_notes': rawNotes,
        'prompt_directives': promptDirectives,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de la génération IA');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ─── Terms (Trimestres) ───────────────────────────────────────

  Future<List<Term>> fetchTerms({Set<String>? countryIds}) async {
    var query = client.from('terms').select();
    if (countryIds != null && countryIds.isNotEmpty) {
      query = query.inFilter('country_id', countryIds.toList());
    }
    final rows = await query.order('start_date').then((r) => r as List);
    return (rows).map((r) => Term.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  Future<Term?> createTerm({
    required String countryId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String schoolYear,
  }) async {
    final rows = await client
        .from('terms')
        .insert({
          'country_id': countryId,
          'name': name,
          'start_date': startDate.toIso8601String().split('T').first,
          'end_date': endDate.toIso8601String().split('T').first,
          'school_year': schoolYear,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Term.fromJson(Map<String, dynamic>.from(rows.first));
  }

  /// Aucune mise à jour n'était possible sur un trimestre après création (migration 27) — une
  /// erreur de saisie ou un trimestre obsolète ne pouvait jamais être corrigé ni archivé.
  Future<void> updateTerm(
    String id, {
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (startDate != null) data['start_date'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) data['end_date'] = endDate.toIso8601String().split('T').first;
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('terms').update(data).eq('id', id);
  }

  // ─── Chapters CRUD ────────────────────────────────────────────

  Future<Chapter?> createChapter({
    required String subjectId,
    String? classNodeId,
    required String title,
    String? introduction,
    String? termId,
    List<Map<String, dynamic>>? introMedia,
    required int displayOrder,
  }) async {
    final data = <String, dynamic>{
      'subject_id': subjectId,
      'title': title,
      'display_order': displayOrder,
      'is_active': true,
    };
    if (classNodeId != null) data['class_node_id'] = classNodeId;
    if (introduction != null) data['introduction'] = introduction;
    if (termId != null) data['term_id'] = termId;
    if (introMedia != null) data['intro_media_json'] = introMedia;
    final rows = await client
        .from('chapters')
        .insert(data)
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Chapter.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateChapter(
    String id, {
    String? title,
    String? introduction,
    List<Map<String, dynamic>>? introMedia,
    bool? isActive,
    int? displayOrder,
    bool updateTermId = false,
    String? termId,
    bool updateClassNodeId = false,
    String? classNodeId,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) data['title'] = title;
    if (introduction != null) data['introduction'] = introduction;
    if (introMedia != null) data['intro_media_json'] = introMedia;
    if (isActive != null) data['is_active'] = isActive;
    if (displayOrder != null) data['display_order'] = displayOrder;
    if (updateTermId) data['term_id'] = termId;
    if (updateClassNodeId) data['class_node_id'] = classNodeId;
    await client.from('chapters').update(data).eq('id', id);
  }

  /// Archive le chapitre ET ses leçons (migration 22) — un simple `updateChapter(isActive: false)`
  /// laissait les leçons actives, incohérentes avec un chapitre marqué "ARCHIVÉ".
  Future<void> deactivateChapterCascade(String id, String adminId) async {
    await client.rpc('deactivate_chapter_cascade', params: {
      'p_chapter_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Symétrique de [deactivateChapterCascade] : réactive le chapitre ET ses leçons.
  Future<void> reactivateChapterCascade(String id, String adminId) async {
    await client.rpc('reactivate_chapter_cascade', params: {
      'p_chapter_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Suppression PHYSIQUE réelle d'un chapitre (migration 22) — réservée aux chapitres déjà
  /// archivés. Cascade en base sur ses leçons, versions de leçons et exercices rattachés.
  Future<void> permanentlyDeleteChapter(String id, String adminId) async {
    await client.rpc('permanently_delete_chapter', params: {
      'p_chapter_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Suppression PHYSIQUE réelle d'une leçon (migration 22) — réservée aux leçons déjà archivées.
  /// Cascade en base sur ses versions et les exercices qui lui sont rattachés.
  Future<void> permanentlyDeleteLesson(String id, String adminId) async {
    await client.rpc('permanently_delete_lesson', params: {
      'p_lesson_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Duplique un chapitre (et ses leçons) vers une autre classe/série — le vrai mécanisme pour des
  /// programmes identiques entre classes (ex: séries jumelées), en duplication réelle et
  /// indépendante plutôt qu'en partage implicite via subject_id (voir migration
  /// 15_chapters_class_scoping.sql).
  Future<String> duplicateChapterToClass({
    required String chapterId,
    required String targetClassNodeId,
    required String adminId,
  }) async {
    final result = await client.rpc('duplicate_chapter_to_class', params: {
      'p_chapter_id': chapterId,
      'p_target_class_node_id': targetClassNodeId,
      'p_admin_id': adminId,
    });
    return result as String;
  }

  // ─── Classes Jumelées (migration 19) ─────────────────────────

  Future<String> declareClassTwinGroup(
    List<String> classNodeIds,
    String subjectId,
    String? label,
    String adminId,
  ) async {
    final result = await client.rpc('declare_class_twin_group', params: {
      'p_class_node_ids': classNodeIds,
      'p_subject_id': subjectId,
      'p_label': label,
      'p_admin_id': adminId,
    });
    return result as String;
  }

  Future<void> addClassToTwinGroup(String groupId, String classNodeId, String adminId) async {
    await client.rpc('add_class_to_twin_group', params: {
      'p_group_id': groupId,
      'p_class_node_id': classNodeId,
      'p_admin_id': adminId,
    });
  }

  Future<void> removeClassFromTwinGroup(String groupId, String classNodeId, String adminId) async {
    await client.rpc('remove_class_from_twin_group', params: {
      'p_group_id': groupId,
      'p_class_node_id': classNodeId,
      'p_admin_id': adminId,
    });
  }

  Future<void> dissolveClassTwinGroup(String groupId, String adminId) async {
    await client.rpc('dissolve_class_twin_group', params: {'p_group_id': groupId, 'p_admin_id': adminId});
  }

  Future<List<TwinGroup>> fetchTwinGroups() async {
    final groups = await client.from('class_twin_groups').select().order('created_at').then((r) => r as List);
    if (groups.isEmpty) return [];
    final groupIds = groups.map((g) => g['id'] as String).toList();
    final members = await client
        .from('class_twin_group_members')
        .select()
        .inFilter('group_id', groupIds)
        .then((r) => r as List);
    final classIds = members.map((m) => m['class_node_id'] as String).toSet().toList();
    final nodes = classIds.isEmpty
        ? <dynamic>[]
        : await client.from('academic_nodes').select().inFilter('id', classIds).then((r) => r as List);
    final nodeNames = {for (final n in nodes) n['id'] as String: n['name'] as String};
    final subjectIds = groups.map((g) => g['subject_id'] as String?).whereType<String>().toSet().toList();
    final subjectRows = subjectIds.isEmpty
        ? <dynamic>[]
        : await client.from('subjects').select().inFilter('id', subjectIds).then((r) => r as List);
    final subjectNames = {for (final s in subjectRows) s['id'] as String: s['name'] as String};
    return groups.map((g) {
      final groupId = g['id'] as String;
      final subjectId = g['subject_id'] as String?;
      final groupMembers = members.where((m) => m['group_id'] == groupId).map((m) {
        final classId = m['class_node_id'] as String;
        return TwinGroupMember(classNodeId: classId, className: nodeNames[classId] ?? 'Classe inconnue');
      }).toList();
      return TwinGroup(
        id: groupId,
        label: g['label'] as String?,
        subjectId: subjectId,
        subjectName: subjectId == null ? null : (subjectNames[subjectId] ?? 'Matière inconnue'),
        members: groupMembers,
      );
    }).toList();
  }

  /// Groupe jumelé auquel appartient une classe donnée POUR CETTE MATIÈRE précise (ou null si
  /// aucun) — une classe peut désormais appartenir à plusieurs groupes, un par matière, donc le
  /// filtre par `subjectId` est nécessaire pour résoudre le bon groupe. Utilisé pour le badge
  /// "Jumelée avec : X, Y" sur les cartes de chapitre et la duplication en masse.
  Future<TwinGroup?> fetchTwinGroupForClass(String classNodeId, String? subjectId) async {
    if (!_isValidUuid(classNodeId)) return null;
    final memberRows = await client
        .from('class_twin_group_members')
        .select()
        .eq('class_node_id', classNodeId)
        .then((r) => r as List);
    if (memberRows.isEmpty) return null;
    final groupIds = memberRows.map((m) => m['group_id'] as String).toList();
    final groups =
        await client.from('class_twin_groups').select().inFilter('id', groupIds).then((r) => r as List);
    final matches = subjectId == null ? groups : groups.where((g) => g['subject_id'] == subjectId).toList();
    if (matches.isEmpty) return null;
    final group = matches.first;
    final groupId = group['id'] as String;
    final groupSubjectId = group['subject_id'] as String?;
    final members = await client
        .from('class_twin_group_members')
        .select()
        .eq('group_id', groupId)
        .then((r) => r as List);
    final classIds = members.map((m) => m['class_node_id'] as String).toList();
    final nodes = await client.from('academic_nodes').select().inFilter('id', classIds).then((r) => r as List);
    final nodeNames = {for (final n in nodes) n['id'] as String: n['name'] as String};
    final subject = groupSubjectId == null ? null : await getSubject(groupSubjectId);
    return TwinGroup(
      id: groupId,
      label: group['label'] as String?,
      subjectId: groupSubjectId,
      subjectName: subject?.name,
      members: members.map((m) {
        final classId = m['class_node_id'] as String;
        return TwinGroupMember(classNodeId: classId, className: nodeNames[classId] ?? 'Classe inconnue');
      }).toList(),
    );
  }

  /// Aperçu d'impact avant une FUSION (pas un jumelage) : combien d'élèves/chapitres/exercices/...
  /// seraient réassignés si ce nœud était la source d'une fusion.
  Future<List<MergeImpactRow>> getClassNodeMergeImpact(String classNodeId) async {
    final rows = await client
        .rpc('get_class_node_merge_impact', params: {'p_class_node_id': classNodeId}).then((r) => r as List);
    return rows
        .map((r) => MergeImpactRow(
              entityKey: r['entity_key'] as String,
              entityLabel: r['entity_label'] as String,
              rowCount: (r['row_count'] as num).toInt(),
            ))
        .toList();
  }

  Future<List<String>> duplicateChapterToTwinGroup(String chapterId, String adminId) async {
    final result = await client.rpc('duplicate_chapter_to_twin_group', params: {
      'p_chapter_id': chapterId,
      'p_admin_id': adminId,
    });
    return List<String>.from(result as List);
  }

  Future<ChapterDuplicationImpact> getChapterDuplicationImpact(String chapterId) async {
    final rows = await client
        .rpc('get_chapter_duplication_impact', params: {'p_chapter_id': chapterId}).then((r) => r as List);
    if (rows.isEmpty) return ChapterDuplicationImpact(lessonCount: 0, exerciseCount: 0);
    final row = rows.first;
    return ChapterDuplicationImpact(
      lessonCount: (row['lesson_count'] as num).toInt(),
      exerciseCount: (row['exercise_count'] as num).toInt(),
    );
  }

  // ─── Lessons CRUD ─────────────────────────────────────────────

  Future<Lesson?> createLesson({
    required String chapterId,
    required String title,
    required Map<String, dynamic> contentJson,
    required int displayOrder,
    String minSubscriptionTier = 'gratuit',
  }) async {
    final rows = await client
        .from('lessons')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'content_json': contentJson,
          'display_order': displayOrder,
          'is_published': false,
          'min_subscription_tier': minSubscriptionTier,
        })
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Lesson.fromJson(Map<String, dynamic>.from(rows.first));
  }

  /// Modifie une leçon. Si le contenu change, l'ancienne version est d'abord conservée dans
  /// lesson_versions (symétrique de exercise_versions) — c'est ce qui rend réelle la promesse de
  /// "versioning" affichée sur l'écran Leçons & Cours.
  Future<void> updateLesson({
    required String id,
    String? title,
    Map<String, dynamic>? contentJson,
    String? minSubscriptionTier,
    bool? isActive,
    String? editedBy,
  }) async {
    if (contentJson != null) {
      final current = await getLesson(id);
      if (current != null && editedBy != null) {
        final versions = await fetchLessonVersions(id);
        final nextVersion =
            versions.isEmpty ? 1 : versions.map((v) => v.versionNumber).reduce((a, b) => a > b ? a : b) + 1;
        await client.from('lesson_versions').insert({
          'lesson_id': id,
          'version_number': nextVersion,
          'content_json': current.contentJson,
          'published_by': editedBy,
        });
      }
    }
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) data['title'] = title;
    if (contentJson != null) data['content_json'] = contentJson;
    if (minSubscriptionTier != null) {
      data['min_subscription_tier'] = minSubscriptionTier;
    }
    if (isActive != null) data['is_active'] = isActive;
    await client.from('lessons').update(data).eq('id', id);
  }

  Future<List<LessonVersion>> fetchLessonVersions(String lessonId) async {
    final rows = await client
        .from('lesson_versions')
        .select()
        .eq('lesson_id', lessonId)
        .order('version_number', ascending: false)
        .then((r) => r as List);
    return (rows)
        .map((r) => LessonVersion.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> publishLesson(String lessonId, bool published) async {
    await client
        .from('lessons')
        .update({
          'is_published': published,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', lessonId);
  }

  // ─── Exercises CRUD ───────────────────────────────────────────

  /// Crée un exercice. Si `chapterId`/`lessonId` est fourni, `class_node_id`/`term_id` sont
  /// automatiquement dérivés du chapitre par le trigger SQL `trg_sync_exercise_class_scope`
  /// (migration 17) — inutile de les passer dans ce cas. Pour un exercice indépendant (Niveau 3,
  /// type examen, ni chapitre ni leçon), `classNodeId` doit être fourni explicitement par l'appelant
  /// (l'UI l'exige) puisqu'aucun chapitre parent n'existe pour le déduire.
  Future<Exercise?> createExercise({
    String? lessonId,
    String? chapterId,
    String? classNodeId,
    String? termId,
    required ExerciseType type,
    required ExerciseDifficulty difficulty,
    required ExerciseFormat format,
    required String title,
    required Map<String, dynamic> instructionsJson,
    Map<String, dynamic>? solutionJson,
    String minSubscriptionTier = 'gratuit',
  }) async {
    final data = <String, dynamic>{
      'type': exerciseTypeToDb(type),
      'difficulty': exerciseDifficultyToDb(difficulty),
      'format': exerciseFormatToDb(format),
      'title': title,
      'instructions_json': instructionsJson,
      'solution_json': solutionJson ?? {},
      'min_subscription_tier': minSubscriptionTier,
      'is_published': false,
    };
    if (lessonId != null) data['lesson_id'] = lessonId;
    if (chapterId != null) data['chapter_id'] = chapterId;
    if (classNodeId != null) data['class_node_id'] = classNodeId;
    if (termId != null) data['term_id'] = termId;
    final rows = await client
        .from('exercises')
        .insert(data)
        .select()
        .then((r) => r as List);
    if (rows.isEmpty) return null;
    return Exercise.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<Exercise?> getExercise(String id) async {
    final rows = await client
        .from('exercises')
        .select()
        .eq('id', id)
        .then((rows) => rows as List);
    if (rows.isEmpty) return null;
    return Exercise.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<ExerciseVersion>> fetchExerciseVersions(String exerciseId) async {
    final rows = await client
        .from('exercise_versions')
        .select()
        .eq('exercise_id', exerciseId)
        .order('version_number', ascending: false)
        .then((r) => r as List);
    return (rows)
        .map((r) => ExerciseVersion.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Modifie un exercice. Si l'énoncé ou le corrigé change, l'ancienne version est d'abord
  /// conservée dans exercise_versions (jusqu'ici la table existait mais n'était jamais utilisée).
  Future<void> updateExercise({
    required String id,
    String? title,
    ExerciseType? type,
    ExerciseDifficulty? difficulty,
    ExerciseFormat? format,
    Map<String, dynamic>? instructionsJson,
    Map<String, dynamic>? solutionJson,
    String? minSubscriptionTier,
    bool? isActive,
    bool updateChapterId = false,
    String? chapterId,
    bool updateClassNodeId = false,
    String? classNodeId,
    bool updateTermId = false,
    String? termId,
    String? editedBy,
  }) async {
    if ((instructionsJson != null || solutionJson != null) && editedBy != null) {
      final current = await getExercise(id);
      if (current != null) {
        final versions = await fetchExerciseVersions(id);
        final nextVersion =
            versions.isEmpty ? 1 : versions.map((v) => v.versionNumber).reduce((a, b) => a > b ? a : b) + 1;
        await client.from('exercise_versions').insert({
          'exercise_id': id,
          'version_number': nextVersion,
          'content_json': {
            'instructions_json': current.instructionsJson,
            'solution_json': current.solutionJson,
          },
          'published_by': editedBy,
        });
      }
    }
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) data['title'] = title;
    if (type != null) data['type'] = exerciseTypeToDb(type);
    if (difficulty != null) data['difficulty'] = exerciseDifficultyToDb(difficulty);
    if (format != null) data['format'] = exerciseFormatToDb(format);
    if (instructionsJson != null) data['instructions_json'] = instructionsJson;
    if (solutionJson != null) data['solution_json'] = solutionJson;
    if (minSubscriptionTier != null) {
      data['min_subscription_tier'] = minSubscriptionTier;
    }
    if (isActive != null) data['is_active'] = isActive;
    if (updateChapterId) data['chapter_id'] = chapterId;
    if (updateClassNodeId) data['class_node_id'] = classNodeId;
    if (updateTermId) data['term_id'] = termId;
    await client.from('exercises').update(data).eq('id', id);
  }

  /// Suppression PHYSIQUE réelle d'un exercice (migration 23) — réservée aux exercices déjà
  /// archivés. Un exercice est une feuille (aucun enfant) : pas de cascade nécessaire, juste
  /// exercise_versions qui suit via ON DELETE CASCADE.
  Future<void> permanentlyDeleteExercise(String id, String adminId) async {
    await client.rpc('permanently_delete_exercise', params: {
      'p_exercise_id': id,
      'p_admin_id': adminId,
    });
  }

  /// Appelle l'agent IA de génération d'exercices (Edge Function ai-exercise-generation, miroir de
  /// ai-course-structuring pour la banque d'exercices). Retourne la liste brute — l'appelant décide
  /// lesquels créer réellement après relecture.
  Future<List<Map<String, dynamic>>> generateAiExercises({
    String? subjectId,
    String? chapterId,
    required ExerciseType type,
    required ExerciseDifficulty difficulty,
    required ExerciseFormat format,
    required int count,
    String? rawNotes,
    String? promptDirectives,
  }) async {
    final res = await client.functions.invoke(
      'ai-exercise-generation',
      body: {
        'subject_id': subjectId,
        'chapter_id': chapterId,
        'type': exerciseTypeToDb(type),
        'difficulty': exerciseDifficultyToDb(difficulty),
        'format': exerciseFormatToDb(format),
        'count': count,
        'raw_notes': rawNotes,
        'prompt_directives': promptDirectives,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de la génération IA');
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['exercises'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> publishExercise(String exerciseId, bool published) async {
    await client
        .from('exercises')
        .update({
          'is_published': published,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', exerciseId);
  }

  Future<void> submitForValidation({
    required String contentId,
    required String contentType,
    required String authorId,
  }) async {
    await client.from('validation_queue').upsert(
      {
        'content_id': contentId,
        'content_type': contentType,
        'author_id': authorId,
        'status': 'en_attente',
      },
      onConflict: 'content_id',
    );
  }

  /// Point unique de vérité pour "faut-il passer par la file de validation ?" — le super_admin
  /// n'a personne au-dessus de lui pour réviser son propre contenu, donc son travail est
  /// auto-approuvé ET publié immédiatement, tout en restant traçable (une ligne validation_queue
  /// avec status='approuve', reviewer_id=authorId, jamais un silence total). Les autres rôles
  /// suivent le flux normal, inchangé. Remplace les appels directs à submitForValidation dans les
  /// écrans Leçons/Exercices pour ne pas dupliquer cette branche 3 fois.
  Future<void> submitOrAutoApprove({
    required String contentId,
    required String contentType,
    required String authorId,
    required bool isSuperAdmin,
  }) async {
    if (!isSuperAdmin) {
      await submitForValidation(contentId: contentId, contentType: contentType, authorId: authorId);
      return;
    }
    await client.from('validation_queue').upsert(
      {
        'content_id': contentId,
        'content_type': contentType,
        'author_id': authorId,
        'status': 'approuve',
        'reviewer_id': authorId,
        'reviewed_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'content_id',
    );
    if (contentType == 'lesson') {
      await client.from('lessons').update({'is_published': true}).eq('id', contentId);
    } else if (contentType == 'exercise') {
      await client.from('exercises').update({'is_published': true}).eq('id', contentId);
    }
  }

  Future<void> deleteTier(String id) async {
    await client.from('subscription_tiers').delete().eq('id', id);
  }

  Future<void> dismissFlag(String postId) async {
    await client
        .from('forum_posts')
        .update({'flagged': false, 'moderation_status': 'visible'})
        .eq('id', postId);
  }

  Future<void> deleteForumPost(String postId) async {
    await client.from('forum_posts').delete().eq('id', postId);
  }

  Future<void> updateTicketStatus(String ticketId, String status, {String? replyMessage}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (replyMessage != null) {
      updates['reply_message'] = replyMessage;
    }
    await client.from('support_tickets').update(updates).eq('id', ticketId);
  }

  // ─── Section 16.0 : Content Catalog ──────────────────────────

  Future<List<ContentCatalogItem>> fetchContentCatalog(String subjectId) async {
    if (!_isValidUuid(subjectId)) return [];
    final rows = await client
        .from('content_catalog')
        .select()
        .eq('subject_id', subjectId)
        .order('element_type')
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ContentCatalogItem.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createContentCatalogItem({
    required String subjectId,
    required String elementType,
    String? description,
  }) async {
    if (!_isValidUuid(subjectId)) return;
    await client.from('content_catalog').insert({
      'subject_id': subjectId,
      'element_type': elementType,
      'description': description,
    });
  }

  Future<void> updateContentCatalogItem(
    String id, {
    String? elementType,
    String? description,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (elementType != null) data['element_type'] = elementType;
    if (description != null) data['description'] = description;
    if (data.isEmpty) return;
    await client.from('content_catalog').update(data).eq('id', id);
  }

  Future<void> deleteContentCatalogItem(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('content_catalog').delete().eq('id', id);
  }

  // ─── Section 7 : Boutique & Documents Payants ──────────────────

  Future<List<ShopDocument>> fetchShopDocuments({String? classNodeId}) async {
    var query = client.from('shop_documents').select();
    if (_isValidUuid(classNodeId)) {
      query = query.eq('class_node_id', classNodeId!);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ShopDocument.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createShopDocument({
    required String classNodeId,
    String? subjectId,
    required String title,
    String? description,
    required double price,
    required String documentUrl,
    String? previewUrl,
  }) async {
    if (!_isValidUuid(classNodeId)) return;
    await client.from('shop_documents').insert({
      'class_node_id': classNodeId,
      'subject_id': _isValidUuid(subjectId) ? subjectId : null,
      'title': title,
      'description': description,
      'price': price,
      'document_url': documentUrl,
      'preview_url': previewUrl,
      'is_active': true,
    });
  }

  /// Aucune mise à jour n'était possible sur un document boutique après publication (migration —
  /// aucun `updateShopDocument` n'existait, seulement create/delete) — ni pour corriger une erreur,
  /// ni pour archiver/désarchiver (`is_active` existe pourtant en base et était totalement inutilisé
  /// côté UI, alors que la policy RLS shop_documents_select s'appuie dessus).
  Future<void> updateShopDocument(
    String id, {
    String? title,
    String? description,
    double? price,
    String? documentUrl,
    String? previewUrl,
    bool? isActive,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (price != null) data['price'] = price;
    if (documentUrl != null) data['document_url'] = documentUrl;
    if (previewUrl != null) data['preview_url'] = previewUrl;
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('shop_documents').update(data).eq('id', id);
  }

  Future<void> deleteShopDocument(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('shop_documents').delete().eq('id', id);
  }

  // ─── Section 12 : Dons & Œuvres Caritatives ────────────────────

  Future<List<CharityCampaign>> fetchCharityCampaigns() async {
    final rows = await client
        .from('charity_campaigns')
        .select()
        .order('start_date', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => CharityCampaign.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<Donation>> fetchDonations({String? campaignId}) async {
    var query = client.from('donations').select();
    if (_isValidUuid(campaignId)) {
      query = query.eq('charity_campaign_id', campaignId!);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Donation.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createCharityCampaign({
    required String title,
    required String description,
    required double targetAmount,
    String? imageUrl,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    await client.from('charity_campaigns').insert({
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'collected_amount': 0.0,
      'image_url': imageUrl,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'is_active': true,
    });
  }

  Future<void> updateCharityCampaign(
    String id, {
    String? title,
    String? description,
    double? targetAmount,
    String? imageUrl,
    DateTime? endDate,
    bool? isActive,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (targetAmount != null) data['target_amount'] = targetAmount;
    if (imageUrl != null) data['image_url'] = imageUrl;
    if (endDate != null) data['end_date'] = endDate.toIso8601String().split('T')[0];
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('charity_campaigns').update(data).eq('id', id);
  }

  Future<void> deleteCharityCampaign(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('charity_campaigns').delete().eq('id', id);
  }

  /// Enregistrement manuel d'un don reçu hors application (espèces, chèque, virement direct...) —
  /// `collected_amount` de la campagne liée est mis à jour automatiquement par un trigger DB
  /// (voir 29_charity_campaign_collected_sync.sql), pas par ce code.
  Future<void> createDonation({
    required String donorName,
    String? donorEmail,
    String? donorPhone,
    required double amount,
    String operator = 'Espèces',
    String? charityCampaignId,
    String? receiptUrl,
  }) async {
    await client.from('donations').insert({
      'donor_name': donorName,
      'donor_email': donorEmail,
      'donor_phone': donorPhone,
      'amount': amount,
      'operator': operator,
      'charity_campaign_id': _isValidUuid(charityCampaignId) ? charityCampaignId : null,
      'receipt_url': receiptUrl,
    });
  }

  // ─── Section 23 : Année Scolaire & Campagne de Passage ─────────

  Future<List<SchoolYear>> fetchSchoolYears({String? countryId}) async {
    var query = client.from('school_years').select();
    if (_isValidUuid(countryId)) {
      query = query.eq('country_id', countryId!);
    }
    final rows = await query
        .order('start_date', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => SchoolYear.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createSchoolYear({
    required String countryId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = true,
  }) async {
    if (!_isValidUuid(countryId)) return;
    await client.from('school_years').insert({
      'country_id': countryId,
      'name': name,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_current': isCurrent,
      'promotion_campaign_open': false,
    });
  }

  Future<void> togglePromotionCampaign(String schoolYearId, bool isOpen) async {
    if (!_isValidUuid(schoolYearId)) return;
    await client
        .from('school_years')
        .update({'promotion_campaign_open': isOpen})
        .eq('id', schoolYearId);
  }

  /// Aucune mise à jour n'était possible sur une année scolaire après création (migration 27) —
  /// une erreur de saisie (dates, nom) ne pouvait jamais être corrigée, et il n'y avait aucun moyen
  /// d'archiver une année obsolète. Si `isCurrent` passe à true, les autres années du même pays
  /// sont d'abord désactivées comme "en cours" — une seule année en cours à la fois par pays.
  Future<void> updateSchoolYear(
    String id, {
    required String countryId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    bool? isActive,
  }) async {
    if (isCurrent == true) {
      await client
          .from('school_years')
          .update({'is_current': false})
          .eq('country_id', countryId)
          .neq('id', id);
    }
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (startDate != null) data['start_date'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) data['end_date'] = endDate.toIso8601String().split('T').first;
    if (isCurrent != null) data['is_current'] = isCurrent;
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('school_years').update(data).eq('id', id);
  }

  Future<List<PromotionRecord>> fetchPromotionRecords({String? schoolYear}) async {
    var query = client.from('promotion_records').select();
    if (schoolYear != null && schoolYear.isNotEmpty) {
      query = query.eq('school_year', schoolYear);
    }
    final rows = await query
        .order('processed_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => PromotionRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Section 3.5 : Comptes & Profils Élèves ────────────────────

  Future<List<Account>> fetchAccounts({String? search}) async {
    var query = client.from('accounts').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.or(
        'first_name.ilike.%$search%,last_name.ilike.%$search%,email.ilike.%$search%',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => Account.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<StudentProfile>> fetchProfilesForAccount(String accountId) async {
    final rows = await client
        .from('profiles')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => StudentProfile.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createStudentAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    required String classNodeId,
    required String schoolYear,
  }) async {
    final res = await client.functions.invoke(
      'admin-create-student-account',
      body: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'class_node_id': classNodeId,
        'school_year': schoolYear,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de création du compte élève');
    }
  }

  Future<void> suspendAccount(String accountId) async {
    // Correspond à l'archivage décrit en section 2.1 du CDC : suppression côté utilisateur =
    // archivage des profils, jamais une suppression définitive des données.
    final profiles = await fetchProfilesForAccount(accountId);
    for (final profile in profiles) {
      await client
          .from('profiles')
          .update({'status': 'archive'})
          .eq('id', profile.id);
    }
  }

  Future<void> unsuspendAccount(String accountId) async {
    final profiles = await fetchProfilesForAccount(accountId);
    for (final profile in profiles) {
      await client
          .from('profiles')
          .update({'status': 'actif'})
          .eq('id', profile.id);
    }
  }

  Future<void> setProfileStatus(String profileId, String status) async {
    if (!_isValidUuid(profileId)) return;
    await client.from('profiles').update({'status': status}).eq('id', profileId);
  }

  /// Ré-inscription d'un compte élève existant pour une nouvelle classe/année scolaire (le compte
  /// et son historique de profils précédents sont conservés, un nouveau profil est simplement ajouté).
  Future<void> addProfileToAccount({
    required String accountId,
    required String classNodeId,
    required String schoolYear,
  }) async {
    await client.from('profiles').insert({
      'account_id': accountId,
      'class_node_id': classNodeId,
      'school_year': schoolYear,
      'status': 'actif',
    });
  }

  Future<void> updateAccount(
    String id, {
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (phone != null) data['phone'] = phone;
    if (data.isEmpty) return;
    await client.from('accounts').update(data).eq('id', id);
  }

  // ─── Section 3.9 / 6.4 : Modèles de Notifications ──────────────

  Future<List<NotificationTemplate>> fetchNotificationTemplates() async {
    final rows = await client
        .from('notification_templates')
        .select()
        .order('event_key')
        .then((r) => r as List);
    return (rows)
        .map((r) => NotificationTemplate.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> updateNotificationTemplate(
    String id, {
    required String titleTemplate,
    required String bodyTemplate,
  }) async {
    await client
        .from('notification_templates')
        .update({'title_template': titleTemplate, 'body_template': bodyTemplate})
        .eq('id', id);
  }

  // ─── Section 2.16 : Comptes Parents ────────────────────────────

  Future<void> createParentAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final res = await client.functions.invoke(
      'admin-create-parent-account',
      body: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : res.data;
      throw Exception(error ?? 'Échec de création du compte parent');
    }
  }

  Future<List<ParentAccount>> fetchParentAccounts({String? search}) async {
    var query = client.from('parent_accounts').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.or(
        'first_name.ilike.%$search%,last_name.ilike.%$search%,email.ilike.%$search%',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => ParentAccount.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<StudentProfile>> fetchProfilesForParent(String parentAccountId) async {
    final links = await client
        .from('parent_profile_links')
        .select('profile_id')
        .eq('parent_account_id', parentAccountId)
        .then((r) => r as List);
    if (links.isEmpty) return [];
    final profileIds = links.map((l) => l['profile_id'] as String).toList();
    final rows = await client
        .from('profiles')
        .select()
        .inFilter('id', profileIds)
        .then((r) => r as List);
    return (rows)
        .map((r) => StudentProfile.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // Rattache un profil élève existant (recherché par email du compte élève) à un compte parent.
  Future<void> linkParentToStudentByEmail({
    required String parentAccountId,
    required String studentEmail,
  }) async {
    final accountRows = await client
        .from('accounts')
        .select('id')
        .eq('email', studentEmail)
        .limit(1)
        .then((r) => r as List);
    if (accountRows.isEmpty) {
      throw Exception('Aucun compte élève trouvé pour cet email');
    }
    final accountId = accountRows.first['id'] as String;
    final profileRows = await client
        .from('profiles')
        .select('id')
        .eq('account_id', accountId)
        .then((r) => r as List);
    if (profileRows.isEmpty) {
      throw Exception('Ce compte élève n\'a aucun profil actif');
    }
    for (final profile in profileRows) {
      await client.from('parent_profile_links').upsert(
        {
          'parent_account_id': parentAccountId,
          'profile_id': profile['id'],
        },
        onConflict: 'parent_account_id,profile_id',
      );
    }
  }

  Future<void> unlinkParentFromProfile({
    required String parentAccountId,
    required String profileId,
  }) async {
    await client
        .from('parent_profile_links')
        .delete()
        .eq('parent_account_id', parentAccountId)
        .eq('profile_id', profileId);
  }

  Future<void> updateParentAccount(
    String id, {
    String? firstName,
    String? lastName,
    String? phone,
    bool? isActive,
  }) async {
    if (!_isValidUuid(id)) return;
    final data = <String, dynamic>{};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (phone != null) data['phone'] = phone;
    if (isActive != null) data['is_active'] = isActive;
    if (data.isEmpty) return;
    await client.from('parent_accounts').update(data).eq('id', id);
  }

  Future<void> deleteParentAccount(String id) async {
    if (!_isValidUuid(id)) return;
    await client.from('parent_accounts').delete().eq('id', id);
  }

  Future<List<UserSession>> fetchSessionsForAccount(String accountId) async {
    final rows = await client
        .from('sessions')
        .select()
        .eq('account_id', accountId)
        .order('last_active_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => UserSession.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ─── Section 25 : Sessions Uniques & Anti-Partage ──────────────

  Future<List<UserSession>> fetchActiveSessions() async {
    final rows = await client
        .from('sessions')
        .select('*, accounts(first_name, last_name, email)')
        .eq('is_active', true)
        .order('last_active_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => UserSession.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<SuspiciousSessionAccount>> fetchSuspiciousSessionAccounts({int minSwitches = 3}) async {
    final rows = await client
        .rpc('get_suspicious_session_accounts', params: {'p_min_switches': minSwitches})
        .then((r) => r as List);
    return rows
        .map((r) => SuspiciousSessionAccount.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> revokeSession(String sessionId) async {
    if (!_isValidUuid(sessionId)) return;
    await client.from('sessions').update({'is_active': false}).eq('id', sessionId);
  }

  // ─── Médiathèque (Storage bucket "media" — voir 08_media_storage.sql) ─────

  static const _mediaTypeExtensions = {
    'image': ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'],
    'video': ['mp4', 'mov', 'webm', 'avi'],
    'audio': ['mp3', 'wav', 'm4a', 'ogg'],
  };

  static String inferMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    for (final entry in _mediaTypeExtensions.entries) {
      if (entry.value.contains(ext)) return entry.key;
    }
    return 'document';
  }

  Future<MediaAsset> uploadMedia({
    required Uint8List bytes,
    required String filename,
    required String uploadedBy,
  }) async {
    final type = inferMediaType(filename);
    final storagePath =
        '${DateTime.now().millisecondsSinceEpoch}_${filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';

    await client.storage.from('media').uploadBinary(storagePath, bytes);
    final url = client.storage.from('media').getPublicUrl(storagePath);

    final rows = await client
        .from('media_library')
        .insert({
          'filename': filename,
          'type': type,
          'url': url,
          'size_bytes': bytes.length,
          'uploaded_by': uploadedBy,
        })
        .select()
        .then((r) => r as List);

    return MediaAsset.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<MediaAsset>> fetchMediaLibrary({String? type}) async {
    var query = client.from('media_library').select();
    if (type != null) query = query.eq('type', type);
    final rows = await query
        .order('created_at', ascending: false)
        .then((rows) => rows as List);
    return (rows)
        .map((r) => MediaAsset.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
}

