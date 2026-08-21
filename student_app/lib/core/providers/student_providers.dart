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
    FutureProvider.family<List<Subject>, String?>((ref, countryId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchSubjects(countryId: countryId);
});

final studentChaptersProvider =
    FutureProvider.family<List<Chapter>, String>((ref, subjectId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchChapters(subjectId);
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

final studentOfficialExamsProvider =
    FutureProvider.family<List<OfficialExam>, String>((ref, classNodeId) async {
  final service = ref.watch(studentSupabaseServiceProvider);
  return service.fetchOfficialExams(classNodeId);
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
