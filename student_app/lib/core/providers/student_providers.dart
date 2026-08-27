import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/student_supabase_service.dart';
import '../models/student_models.dart';

final studentSupabaseServiceProvider = Provider<StudentSupabaseService>((ref) {
  return StudentSupabaseService.instance;
});

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchAppSettings();
});

final studentSubjectsProvider =
    FutureProvider.family<List<Subject>, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchSubjects(classNodeId: classNodeId);
});

class ChaptersQuery {
  final String subjectId;
  final String classNodeId;
  const ChaptersQuery({required this.subjectId, required this.classNodeId});

  @override
  bool operator ==(Object other) =>
      other is ChaptersQuery && other.subjectId == subjectId && other.classNodeId == classNodeId;

  @override
  int get hashCode => Object.hash(subjectId, classNodeId);
}

final studentChaptersProvider =
    FutureProvider.family<List<Chapter>, ChaptersQuery>((ref, query) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchChapters(subjectId: query.subjectId, classNodeId: query.classNodeId);
});

final studentLessonsProvider =
    FutureProvider.family<List<Lesson>, String>((ref, chapterId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchLessons(chapterId);
});

final studentExercisesProvider =
    FutureProvider.family<List<Exercise>, String>((ref, chapterId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchExercises(chapterId);
});

final studentForumPostsProvider =
    FutureProvider.family<List<ForumPost>, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchForumPosts(classNodeId);
});

final archivedProfilesProvider =
    FutureProvider.family<List<StudentProfile>, String>((ref, accountId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchArchivedProfiles(accountId);
});

final parentLinkCodeProvider =
    FutureProvider.family<String, String>((ref, profileId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchOrCreateParentLinkCode(profileId);
});

final currentTermInfoProvider =
    FutureProvider.family<TermInfo?, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchCurrentTermInfo(classNodeId);
});

final officialExamForClassProvider =
    FutureProvider.family<OfficialExam?, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchOfficialExamForClass(classNodeId);
});

final examPapersProvider =
    FutureProvider.family<List<ExamPaper>, String>((ref, examId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchExamPapers(examId);
});

/// `null` = nœuds racine (pays). Utilisé par le sélecteur de classe à l'inscription — descend
/// l'arbre académique réel (voir docs/cahier_des_charges.md §2.1/§2.2), profondeur variable.
final studentAcademicChildrenProvider =
    FutureProvider.family<List<StudentAcademicNode>, String?>((ref, parentId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchChildAcademicNodes(parentId);
});

final currentSchoolYearProvider =
    FutureProvider.family<String?, String>((ref, countryId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchCurrentSchoolYear(countryId);
});

final establishmentsProvider = FutureProvider<List<Establishment>>((ref) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchEstablishments();
});

class EstablishmentPapersQuery {
  final String classNodeId;
  final String? establishmentId;
  const EstablishmentPapersQuery({required this.classNodeId, this.establishmentId});

  @override
  bool operator ==(Object other) =>
      other is EstablishmentPapersQuery &&
      other.classNodeId == classNodeId &&
      other.establishmentId == establishmentId;

  @override
  int get hashCode => Object.hash(classNodeId, establishmentId);
}

final establishmentPapersProvider =
    FutureProvider.family<List<EstablishmentPaper>, EstablishmentPapersQuery>((ref, query) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchEstablishmentPapers(
    classNodeId: query.classNodeId,
    establishmentId: query.establishmentId,
  );
});

final whatsappCommunityProvider =
    FutureProvider.family<WhatsappCommunity?, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchWhatsappCommunity(classNodeId);
});

final charityCampaignsProvider = FutureProvider<List<CharityCampaign>>((ref) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchCharityCampaigns();
});

final supportTicketsProvider =
    FutureProvider.family<List<SupportTicket>, String>((ref, accountId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchSupportTickets(accountId);
});

final classEventsProvider =
    FutureProvider.family<List<MockEvent>, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchEventsForClass(classNodeId);
});

class MyEventResultQuery {
  final String eventId;
  final String profileId;
  const MyEventResultQuery({required this.eventId, required this.profileId});

  @override
  bool operator ==(Object other) =>
      other is MyEventResultQuery && other.eventId == eventId && other.profileId == profileId;

  @override
  int get hashCode => Object.hash(eventId, profileId);
}

final myEventResultProvider =
    FutureProvider.family<MyEventResult?, MyEventResultQuery>((ref, query) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchMyEventResult(query.eventId, query.profileId);
});

final eventLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, eventId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchEventLeaderboard(eventId);
});
