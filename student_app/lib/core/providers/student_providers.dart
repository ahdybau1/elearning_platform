import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/student_supabase_service.dart';
import '../models/student_models.dart';

final studentSupabaseServiceProvider = Provider<StudentSupabaseService>((ref) {
  return StudentSupabaseService.instance;
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
