import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/supabase_provider.dart';
import '../models/academic_node.dart';
import '../models/content_models.dart';
import '../models/subscription_models.dart';
import '../models/admin_models.dart';
import '../models/community_models.dart';
import '../models/system_models.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

// Onglet actif de la navigation principale — partagé via provider (pas un simple State local à
// MainAdminLayout) pour que d'autres écrans (ex: le tableau de bord) puissent déclencher une
// navigation, comme cliquer sur un élément "en attente de validation" pour aller à cet onglet.
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

// Contexte pays global (navbar) : null = "Tous les pays" (aucun filtre), sinon uniquement ces
// pays. Les providers ci-dessous le lisent en interne (via ref.watch) pour que TOUT écran qui lit
// nodesByTypeProvider/termsProvider/subjectsProvider respecte automatiquement ce filtre sans avoir
// à changer sa propre signature — un seul point de vérité plutôt que de recâbler ~15 écrans.
final selectedCountryIdsProvider = StateProvider<Set<String>?>((ref) => null);

// ─── Academic Tree ──────────────────────────────────────────────

final academicTreeProvider = FutureProvider<List<AcademicNode>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAcademicTree();
});

final academicTreeStreamProvider =
    StreamProvider.family<List<AcademicNode>, bool>((ref, includeInactive) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchAcademicTree(includeInactive: includeInactive);
});

// ─── Content ──────────────────────────────────────────────────

final subjectsProvider = FutureProvider.family<List<Subject>,
    ({String? countryId, bool includeInactive})>((ref, params) async {
  final service = ref.watch(supabaseServiceProvider);
  // Un countryId explicite (ex: modale de création, un seul pays possible par matière) prime
  // toujours sur le contexte global ; sans lui, on retombe sur la sélection pays de la navbar.
  final countryIds = params.countryId != null
      ? {params.countryId!}
      : ref.watch(selectedCountryIdsProvider);
  return service.fetchSubjects(countryIds: countryIds, includeInactive: params.includeInactive);
});

final lessonsProvider =
    FutureProvider.family<List<Lesson>, String?>((ref, chapterId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchLessons(chapterId: chapterId);
});

final chaptersProvider =
    FutureProvider.family<List<Chapter>, String>((ref, subjectId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchChapters(subjectId);
});

// Chapitres + leçons imbriquées pour l'écran Leçons & Cours (remplace le FutureBuilder ad-hoc qui
// ne se réactualisait jamais après une création/édition faute d'être un vrai provider watché).
final chaptersWithLessonsProvider = FutureProvider.family<List<Chapter>,
    ({String subjectId, String? classNodeId, bool includeInactive})>((ref, params) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchChaptersWithLessons(
    params.subjectId,
    classNodeId: params.classNodeId,
    includeInactive: params.includeInactive,
  );
});

// Matières réellement enseignées dans une classe (jointure subject_class_links) — rend le filtre
// "Classe" de l'écran Leçons & Cours réel au lieu de purement décoratif.
final subjectsForClassProvider =
    FutureProvider.family<List<Subject>, String>((ref, classNodeId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchSubjectsForClass(classNodeId);
});

// Classes/Séries où une matière est enseignée (voir fetchClassesForSubject) — n'implique aucun
// partage de contenu, seulement une utilité de navigation/filtrage.
final classesForSubjectProvider =
    FutureProvider.family<List<AcademicNode>, String>((ref, subjectId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchClassesForSubject(subjectId);
});

// ─── Classes Jumelées (migration 19) ───────────────────────────

final twinGroupsProvider = FutureProvider<List<TwinGroup>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchTwinGroups();
});

// Une classe peut désormais appartenir à plusieurs groupes jumelés (un par matière) — la clé
// inclut donc subjectId pour résoudre le bon groupe, pas juste "le" groupe de la classe.
final twinGroupForClassProvider = FutureProvider.family<TwinGroup?,
    ({String? classNodeId, String? subjectId})>((ref, params) async {
  if (params.classNodeId == null) return null;
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchTwinGroupForClass(params.classNodeId!, params.subjectId);
});

final classNodeMergeImpactProvider =
    FutureProvider.family<List<MergeImpactRow>, String>((ref, classNodeId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getClassNodeMergeImpact(classNodeId);
});

final chapterDuplicationImpactProvider =
    FutureProvider.family<ChapterDuplicationImpact, String>((ref, chapterId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getChapterDuplicationImpact(chapterId);
});

final termsProvider =
    FutureProvider.family<List<Term>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  final countryIds = countryId != null ? {countryId} : ref.watch(selectedCountryIdsProvider);
  return service.fetchTerms(countryIds: countryIds);
});

final lessonVersionsProvider =
    FutureProvider.family<List<LessonVersion>, String>((ref, lessonId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchLessonVersions(lessonId);
});

final exercisesProvider =
    FutureProvider.family<List<Exercise>, bool>((ref, includeInactive) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAllExercises(includeInactive: includeInactive);
});

final exerciseVersionsProvider =
    FutureProvider.family<List<ExerciseVersion>, String>((ref, exerciseId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchExerciseVersions(exerciseId);
});

final validationQueueProvider =
    FutureProvider<List<ValidationQueueItem>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchValidationQueue(status: 'en_attente');
});

final validationQueueStreamProvider =
    StreamProvider<List<ValidationQueueItem>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchValidationQueue();
});

// ─── Subscriptions ─────────────────────────────────────────────

final subscriptionTiersProvider =
    FutureProvider.family<List<SubscriptionTier>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchTiers(countryId: countryId);
});

final accessMatrixProvider =
    FutureProvider.family<List<AccessMatrixEntry>, String>((ref, tierId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAccessMatrix(tierId);
});

final matrixFeaturesProvider = FutureProvider<List<MatrixFeature>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchMatrixFeatures();
});

final ambiguousTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAmbiguousTransactions();
});

final refundRequestsProvider = FutureProvider<List<RefundRequest>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchRefundRequests(status: 'en_attente');
});

final refundRequestsStreamProvider = StreamProvider<List<RefundRequest>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchRefundRequests();
});

final transactionsStreamProvider =
    StreamProviderFamily<List<Transaction>, String>((ref, status) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchTransactions(status);
});

final pendingReconciliationsProvider =
    FutureProvider<List<PaymentReconciliation>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchPendingReconciliations();
});

// ─── Users & Admin ────────────────────────────────────────────

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAdminUsers();
});

final adminPermissionsProvider =
    FutureProvider.family<List<AdminPermission>, String>((ref, adminId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchPermissions(adminId);
});

final establishmentsProvider = FutureProvider<List<Establishment>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final countryIds = ref.watch(selectedCountryIdsProvider);
  final all = await service.fetchEstablishments();
  if (countryIds == null || countryIds.isEmpty) return all;
  return all.where((e) => countryIds.contains(e.countryId)).toList();
});

final establishmentPapersProvider =
    FutureProvider.family<List<EstablishmentPaper>, String>((ref, establishmentId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchEstablishmentPapers(establishmentId);
});

final establishmentTeacherCountProvider =
    FutureProvider.family<int, String>((ref, establishmentId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countTeachersForEstablishment(establishmentId);
});

final teacherEstablishmentsProvider =
    FutureProvider.family<List<TeacherEstablishmentLink>, String>((ref, teacherId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchTeacherEstablishments(teacherId);
});

// ─── Community ────────────────────────────────────────────────

final forumThreadsStreamProvider = StreamProvider<List<ForumThread>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchForumThreads();
});

final flaggedPostsProvider = FutureProvider<List<ForumPost>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchFlaggedPosts();
});

final supportTicketsStreamProvider =
    StreamProvider.family<List<SupportTicket>, String?>((ref, status) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchSupportTickets(status: status);
});

final whatsappCommunitiesProvider =
    FutureProvider.family<List<WhatsappCommunity>, String?>((ref, classNodeId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchWhatsappCommunities(classNodeId: classNodeId);
});

// ─── System ───────────────────────────────────────────────────

final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchEvents();
});

final eventResultsProvider = FutureProvider.family<List<EventResult>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchEventResults(eventId);
});

final gradeDisputesProvider = FutureProvider<List<GradeDispute>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchGradeDisputes();
});

final examPapersProvider =
    FutureProvider.family<List<ExamPaper>, String>((ref, examId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchExamPapers(examId);
});

final officialExamsProvider =
    FutureProvider.family<List<OfficialExam>, Map<String, String>>((ref, filters) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchOfficialExams(
    countryId: filters['countryId'],
    classNodeId: filters['classNodeId'],
  );
});

final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchAnnouncements();
});

final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAuditLogs();
});

final aiAgentCallsProvider =
    FutureProvider.family<List<AiAgentCall>, int>((ref, days) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAiAgentCalls(days: days);
});

// ─── Dashboard KPI Counts ─────────────────────────────────────

final activeProfilesCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countActiveProfiles();
});

final publishedLessonsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countPublishedLessons();
});

final exercisesCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countExercises();
});

final pendingValidationCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countPendingValidation();
});

final openTicketsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.countOpenTickets();
});

// ─── CDC Additional Modules Providers ─────────────────────────

final contentCatalogProvider =
    FutureProvider.family<List<ContentCatalogItem>, String>((ref, subjectId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchContentCatalog(subjectId);
});

final shopDocumentsProvider =
    FutureProvider.family<List<ShopDocument>, String?>((ref, classNodeId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchShopDocuments(classNodeId: classNodeId);
});

final charityCampaignsProvider = FutureProvider<List<CharityCampaign>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchCharityCampaigns();
});

final donationsProvider =
    FutureProvider.family<List<Donation>, String?>((ref, campaignId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchDonations(campaignId: campaignId);
});

final schoolYearsProvider =
    FutureProvider.family<List<SchoolYear>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchSchoolYears(countryId: countryId);
});

final promotionRecordsProvider =
    FutureProvider.family<List<PromotionRecord>, String?>((ref, schoolYear) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchPromotionRecords(schoolYear: schoolYear);
});

final activeSessionsProvider = FutureProvider<List<UserSession>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchActiveSessions();
});

final suspiciousSessionAccountsProvider = FutureProvider<List<SuspiciousSessionAccount>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchSuspiciousSessionAccounts();
});

final nodesByTypeProvider =
    FutureProvider.family<List<AcademicNode>, String>((ref, nodeType) async {
  final service = ref.watch(supabaseServiceProvider);
  // 'country' n'est jamais filtré par lui-même — sinon impossible de voir les pays à sélectionner.
  final countryIds = nodeType == 'country' ? null : ref.watch(selectedCountryIdsProvider);
  return service.fetchNodesByType(nodeType, countryIds: countryIds);
});

final nodeByIdProvider = FutureProvider.family<AcademicNode?, String?>((ref, nodeId) async {
  if (nodeId == null) return null;
  final service = ref.watch(supabaseServiceProvider);
  return service.getNode(nodeId);
});

final accountsProvider =
    FutureProvider.family<List<Account>, String?>((ref, search) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAccounts(search: search);
});

final profilesForAccountProvider =
    FutureProvider.family<List<StudentProfile>, String>((ref, accountId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchProfilesForAccount(accountId);
});

final sessionsForAccountProvider =
    FutureProvider.family<List<UserSession>, String>((ref, accountId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchSessionsForAccount(accountId);
});

final notificationTemplatesProvider =
    FutureProvider<List<NotificationTemplate>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchNotificationTemplates();
});

final parentAccountsProvider =
    FutureProvider.family<List<ParentAccount>, String?>((ref, search) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchParentAccounts(search: search);
});

final profilesForParentProvider =
    FutureProvider.family<List<StudentProfile>, String>((ref, parentAccountId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchProfilesForParent(parentAccountId);
});

final mediaLibraryProvider =
    FutureProvider.family<List<MediaAsset>, String?>((ref, type) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchMediaLibrary(type: type);
});
