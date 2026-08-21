import 'dart:async';
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

  bool get isAuthenticated => account != null;

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

/// Renvoyé par [StudentAuthNotifier.signUp] quand Supabase Auth exige une confirmation par email
/// avant d'ouvrir une session — dans ce cas la ligne `accounts` ne peut pas encore être créée
/// (la policy RLS `accounts_insert` exige une session active dont `auth.uid()` correspond).
const String kSignUpNeedsEmailConfirmation = 'CONFIRM_EMAIL';

class StudentAuthNotifier extends StateNotifier<StudentAuthState> {
  StudentAuthNotifier() : super(const StudentAuthState(isLoading: true)) {
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user == null) {
        state = const StudentAuthState(isLoading: false);
        return;
      }
      _loadAccountAndProfiles();
    }, onError: (_) {
      state = const StudentAuthState(isLoading: false);
    });
  }

  static const String _activeProfilePrefKey = 'selected_student_profile_id';

  SupabaseClient get _client => Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Le compte affiché vient toujours d'une lecture réelle de `accounts` filtrée par
  // auth_user_id = auth.uid() (RLS), jamais d'un état codé en dur côté client — même logique que
  // admin_app (voir 03_auth_flow.md côté admin).
  Future<void> _loadAccountAndProfiles() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        state = const StudentAuthState(isLoading: false);
        return;
      }

      final accountRow = await _client
          .from('accounts')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (accountRow == null) {
        // Session Supabase Auth valide mais aucune ligne `accounts` correspondante : inscription
        // interrompue avant sa fin (ex. l'utilisateur a fermé l'app juste après signUp). Impossible
        // de deviner prénom/nom/téléphone à sa place — l'inscription doit être reprise.
        await _client.auth.signOut();
        state = const StudentAuthState(
          isLoading: false,
          errorMessage: 'Inscription incomplète — veuillez recommencer votre inscription.',
        );
        return;
      }

      final account = StudentAccount.fromJson(Map<String, dynamic>.from(accountRow));
      final profiles = await _fetchProfiles(account.id);

      final prefs = await SharedPreferences.getInstance();
      final savedProfileId = prefs.getString(_activeProfilePrefKey);
      StudentProfile? active = profiles.isEmpty ? null : profiles.first;
      if (savedProfileId != null) {
        final match = profiles.where((p) => p.id == savedProfileId).firstOrNull;
        if (match != null) active = match;
      }

      state = StudentAuthState(
        account: account,
        profiles: profiles,
        activeProfile: active,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<List<StudentProfile>> _fetchProfiles(String accountId) async {
    final rows = await _client
        .from('profiles')
        .select('*, academic_nodes(name)')
        .eq('account_id', accountId)
        .eq('status', 'actif')
        .order('created_at')
        .then((r) => r as List);
    return rows
        .map((r) => StudentProfile.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Retourne un message d'erreur lisible en cas d'échec, ou `null` en cas de succès (l'écoute des
  /// changements de session déclenche alors automatiquement le chargement du compte/des profils).
  Future<String?> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return e.toString();
    }
  }

  /// Retourne [kSignUpNeedsEmailConfirmation] si une confirmation par email est requise, un message
  /// d'erreur lisible en cas d'échec, ou `null` en cas de succès complet (compte + session créés).
  Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _client.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) {
        const msg = 'Inscription impossible.';
        state = state.copyWith(isLoading: false, errorMessage: msg);
        return msg;
      }

      if (response.session == null) {
        // Le projet Supabase exige une confirmation par email avant d'ouvrir une session — la ligne
        // `accounts` sera créée au premier signIn réussi via une reprise d'inscription, pas ici.
        state = const StudentAuthState(isLoading: false);
        return kSignUpNeedsEmailConfirmation;
      }

      await _client.from('accounts').insert({
        'auth_user_id': user.id,
        'email': email,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
      });

      await _loadAccountAndProfiles();
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfilePrefKey);
    await _client.auth.signOut();
    state = const StudentAuthState(isLoading: false);
  }

  Future<void> selectProfile(StudentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfilePrefKey, profile.id);
    state = state.copyWith(activeProfile: profile);
  }

  /// Ajoute un nouveau profil (= une classe suivie de plus, voir §2.3 du cahier des charges) au
  /// compte actuellement connecté. Retourne un message d'erreur en cas d'échec, sinon `null`.
  Future<String?> addProfile({
    required String classNodeId,
    required String schoolYear,
  }) async {
    final account = state.account;
    if (account == null) return 'Aucun compte connecté.';
    try {
      final row = await _client
          .from('profiles')
          .insert({
            'account_id': account.id,
            'class_node_id': classNodeId,
            'school_year': schoolYear,
          })
          .select('*, academic_nodes(name)')
          .single();
      final newProfile = StudentProfile.fromJson(Map<String, dynamic>.from(row));
      state = state.copyWith(
        profiles: [...state.profiles, newProfile],
        activeProfile: newProfile,
      );
      await selectProfile(newProfile);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final studentAuthProvider =
    StateNotifierProvider<StudentAuthNotifier, StudentAuthState>((ref) {
  return StudentAuthNotifier();
});
