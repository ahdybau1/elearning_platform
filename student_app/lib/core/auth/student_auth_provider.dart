import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_models.dart';

class StudentAuthState {
  final StudentAccount? account;
  final List<StudentProfile> profiles;
  final StudentProfile? activeProfile;
  final bool isLoading;
  final String? errorMessage;

  const StudentAuthState({
    this.account,
    this.profiles = const [],
    this.activeProfile,
    this.isLoading = false,
    this.errorMessage,
  });

  StudentAuthState copyWith({
    StudentAccount? account,
    List<StudentProfile>? profiles,
    StudentProfile? activeProfile,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StudentAuthState(
      account: account ?? this.account,
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class StudentAuthNotifier extends StateNotifier<StudentAuthState> {
  StudentAuthNotifier() : super(const StudentAuthState()) {
    _initializeSession();
  }

  static const String _activeProfilePrefKey = 'selected_student_profile_id';

  Future<void> _initializeSession() async {
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProfileId = prefs.getString(_activeProfilePrefKey);

      // Default demo profiles (style Netflix : 1 Profil = 1 Classe)
      final demoProfiles = [
        StudentProfile(
          id: '00000000-0000-0000-0000-000000000010',
          accountId: '00000000-0000-0000-0000-000000000001',
          name: 'Junior (Terminale C)',
          avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=Junior',
          classNodeId: '00000000-0000-0000-0000-000000000004',
          className: 'Terminale C',
          schoolName: 'Lycée Général Leclerc',
          countryId: '00000000-0000-0000-0000-000000000001',
          activeTier: 'mensuel',
          tierExpiresAt: DateTime.now().add(const Duration(days: 25)),
          totalPoints: 340,
          streakDays: 5,
        ),
        StudentProfile(
          id: '00000000-0000-0000-0000-000000000011',
          accountId: '00000000-0000-0000-0000-000000000001',
          name: 'Sandrine (Classe de 3ème)',
          avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=Sandrine',
          classNodeId: '00000000-0000-0000-0000-000000000005',
          className: 'Classe de 3ème',
          schoolName: 'Collège Libermann',
          countryId: '00000000-0000-0000-0000-000000000001',
          activeTier: 'gratuit',
          totalPoints: 120,
          streakDays: 2,
        ),
      ];

      final defaultAccount = StudentAccount(
        id: '00000000-0000-0000-0000-000000000001',
        phoneNumber: '+237 699 12 34 56',
        email: 'famille.kamga@gmail.com',
        isParentAccount: true,
        parentPin: '1234',
      );

      StudentProfile active = demoProfiles.first;
      if (savedProfileId != null) {
        final match = demoProfiles.where((p) => p.id == savedProfileId).firstOrNull;
        if (match != null) active = match;
      }

      state = StudentAuthState(
        account: defaultAccount,
        profiles: demoProfiles,
        activeProfile: active,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectProfile(StudentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfilePrefKey, profile.id);
    state = state.copyWith(activeProfile: profile);
  }

  Future<void> addProfile({
    required String name,
    required String classNodeId,
    required String className,
    String? schoolName,
  }) async {
    final newProfile = StudentProfile(
      id: '00000000-0000-0000-0000-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}',
      accountId: state.account?.id ?? '00000000-0000-0000-0000-000000000001',
      name: name,
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=$name',
      classNodeId: classNodeId,
      className: className,
      schoolName: schoolName,
      countryId: '00000000-0000-0000-0000-000000000001',
      activeTier: 'gratuit',
    );

    final updated = [...state.profiles, newProfile];
    state = state.copyWith(profiles: updated, activeProfile: newProfile);
    await selectProfile(newProfile);
  }

  void upgradeActiveSubscription(String tierName, int days) {
    if (state.activeProfile != null) {
      final upgraded = state.activeProfile!.copyWith(
        activeTier: tierName,
        tierExpiresAt: DateTime.now().add(Duration(days: days)),
      );
      final updatedList = state.profiles
          .map((p) => p.id == upgraded.id ? upgraded : p)
          .toList();
      state = state.copyWith(activeProfile: upgraded, profiles: updatedList);
    }
  }
}

final studentAuthProvider =
    StateNotifierProvider<StudentAuthNotifier, StudentAuthState>((ref) {
  return StudentAuthNotifier();
});
