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
