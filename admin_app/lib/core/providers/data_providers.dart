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

// ─── Academic Tree ──────────────────────────────────────────────

final academicTreeProvider = FutureProvider<List<AcademicNode>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAcademicTree();
});

final academicTreeStreamProvider = StreamProvider<List<AcademicNode>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchAcademicTree();
});

// ─── Content ──────────────────────────────────────────────────

final subjectsProvider = FutureProvider.family<List<Subject>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchSubjects(countryId: countryId);
});

final lessonsProvider = FutureProvider.family<List<Lesson>, String?>((ref, chapterId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchLessons(chapterId: chapterId);
});

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAllExercises();
});

final validationQueueProvider = FutureProvider<List<ValidationQueueItem>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchValidationQueue(status: 'en_attente');
});

final validationQueueStreamProvider = StreamProvider<List<ValidationQueueItem>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchValidationQueue();
});

// ─── Subscriptions ─────────────────────────────────────────────

final subscriptionTiersProvider = FutureProvider.family<List<SubscriptionTier>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchTiers(countryId: countryId);
});

final accessMatrixProvider = FutureProvider.family<List<AccessMatrixEntry>, String>((ref, tierId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAccessMatrix(tierId);
});

final ambiguousTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
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

final transactionsStreamProvider = StreamProviderFamily<List<Transaction>, String>((ref, status) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchTransactions(status);
});

// ─── Users & Admin ────────────────────────────────────────────

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAdminUsers();
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

final supportTicketsStreamProvider = StreamProvider<List<SupportTicket>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchSupportTickets(status: 'ouvert');
});

final whatsappCommunitiesProvider = FutureProvider.family<List<WhatsappCommunity>, String?>((ref, countryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchWhatsappCommunities(countryId: countryId);
});

// ─── System ───────────────────────────────────────────────────

final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.watchEvents();
});

final officialExamsProvider = FutureProvider.family<List<OfficialExam>, Map<String, String>>((ref, filters) async {
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

final aiAgentCallsProvider = FutureProvider.family<List<AiAgentCall>, int>((ref, days) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchAiAgentCalls(days: days);
});
