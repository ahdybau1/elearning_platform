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
  /// Email de la session Supabase Auth active, même si aucune ligne `accounts` n'existe encore pour
  /// elle (ex. un admin qui se connecte pour la première fois côté élève, ou une inscription
  /// reprise après confirmation email). Distinct de `account` : une session peut être réelle et
  /// valide AVANT que le profil élève soit complété — voir [hasSession].
  final String? sessionEmail;
  /// §11.1 : préférences réelles du compte (thème, notifications, accessibilité...). `null` tant
  /// que non chargées — voir [StudentAuthNotifier._loadAccountAndProfiles].
  final AccountSettings? settings;

  const StudentAuthState({
    this.account,
    this.profiles = const [],
    this.activeProfile,
    this.isLoading = false,
    this.errorMessage,
    this.sessionEmail,
    this.settings,
  });

  /// Un compte élève (`accounts`) existe pour cette session.
  bool get isAuthenticated => account != null;

  /// Une session Supabase Auth réelle est active, que le profil élève soit complété ou non — c'est
  /// ce qui doit décider si on montre l'écran de connexion, pas [isAuthenticated] (voir
  /// [StudentAuthNotifier._loadAccountAndProfiles]).
  bool get hasSession => sessionEmail != null;

  StudentAuthState copyWith({
    StudentAccount? account,
    List<StudentProfile>? profiles,
    StudentProfile? activeProfile,
    bool? isLoading,
    String? errorMessage,
    String? sessionEmail,
    AccountSettings? settings,
  }) {
    return StudentAuthState(
      account: account ?? this.account,
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      sessionEmail: sessionEmail ?? this.sessionEmail,
      settings: settings ?? this.settings,
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
      final user = _client.auth.currentUser;
      if (user == null) {
        state = const StudentAuthState(isLoading: false);
        return;
      }

      final accountRow = await _client
          .from('accounts')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (accountRow == null) {
        // Session Supabase Auth réelle et valide, mais aucune ligne `accounts` correspondante —
        // ex. un admin (identité dans `admin_users`, pas `accounts`) qui teste l'app élève, ou une
        // inscription reprise après confirmation email. On NE déconnecte PLUS ici : l'assistant
        // d'inscription (voir onboarding_wizard_screen.dart) termine le profil sur cette MÊME
        // session au lieu de faire tout recommencer — l'ancien comportement (signOut immédiat)
        // faisait croire à un "identifiants invalides" alors que la connexion avait réussi.
        state = StudentAuthState(isLoading: false, sessionEmail: user.email);
        return;
      }

      final account = StudentAccount.fromJson(Map<String, dynamic>.from(accountRow));
      final profiles = await _fetchProfiles(account.id);
      final settings = await _fetchSettings(account.id);

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
        sessionEmail: user.email,
        settings: settings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<AccountSettings> _fetchSettings(String accountId) async {
    final row = await _client.from('account_settings').select().eq('account_id', accountId).maybeSingle();
    if (row == null) {
      // Compte créé avant l'existence de cette table (migration 40) — ligne par défaut créée à la
      // volée plutôt que de forcer une migration de données rétroactive.
      await _client.from('account_settings').upsert({'account_id': accountId});
      return const AccountSettings();
    }
    return AccountSettings.fromJson(Map<String, dynamic>.from(row));
  }

  /// Mise à jour optimiste : écrit en base puis reflète localement sans recharger tout le compte.
  Future<String?> updateSettings(Map<String, dynamic> partial) async {
    final account = state.account;
    if (account == null) return 'Aucun compte connecté.';
    final previous = state.settings ?? const AccountSettings();
    try {
      await _client.from('account_settings').upsert({
        'account_id': account.id,
        ...partial,
        'updated_at': DateTime.now().toIso8601String(),
      });
      state = state.copyWith(
        settings: AccountSettings(
          notifSubscription: partial['notif_subscription'] as bool? ?? previous.notifSubscription,
          notifForum: partial['notif_forum'] as bool? ?? previous.notifForum,
          notifRevision: partial['notif_revision'] as bool? ?? previous.notifRevision,
          themeMode: partial['theme_mode'] as String? ?? previous.themeMode,
          highContrast: partial['high_contrast'] as bool? ?? previous.highContrast,
          fontScale: (partial['font_scale'] as num?)?.toDouble() ?? previous.fontScale,
          subtitlesEnabled: partial['subtitles_enabled'] as bool? ?? previous.subtitlesEnabled,
          forumProfileVisible: partial['forum_profile_visible'] as bool? ?? previous.forumProfileVisible,
        ),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updatePhone(String phone) async {
    final account = state.account;
    if (account == null) return 'Aucun compte connecté.';
    try {
      await _client.from('accounts').update({'phone': phone}).eq('id', account.id);
      await _loadAccountAndProfiles();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// §11.1 : demande réelle de droit à l'oubli (export/suppression) — voir migration 41. Le
  /// traitement effectif reste une décision admin manuelle (comme refund_requests).
  Future<String?> createDataRequest(String requestType) async {
    final account = state.account;
    if (account == null) return 'Aucun compte connecté.';
    try {
      await _client.from('data_requests').insert({'account_id': account.id, 'request_type': requestType});
      return null;
    } catch (e) {
      return e.toString();
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
    DateTime? birthDate,
    String? schoolName,
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
        if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
        if (schoolName != null && schoolName.trim().isNotEmpty) 'school_name': schoolName.trim(),
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

  /// Crée la ligne `accounts` manquante pour une session Supabase Auth déjà active (voir
  /// [StudentAuthState.hasSession]) — utilisé quand quelqu'un se connecte avec des identifiants
  /// réels qui ne sont liés à aucun compte élève (typiquement un admin qui teste l'app), ou pour
  /// reprendre une inscription interrompue après confirmation email. Pas de mot de passe à
  /// redemander : la session prouve déjà l'identité.
  Future<String?> completeProfile({
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? birthDate,
    String? schoolName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return 'Aucune session active.';
    try {
      await _client.from('accounts').insert({
        'auth_user_id': user.id,
        'email': user.email,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
        if (schoolName != null && schoolName.trim().isNotEmpty) 'school_name': schoolName.trim(),
      });
      await _loadAccountAndProfiles();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Met à jour la photo de profil (§ Photo de profil réelle) — appelée après un upload réussi vers
  /// le bucket `avatars`. Recharge le compte pour que l'URL soit immédiatement visible partout où
  /// l'avatar est affiché (barre du haut, Mon Profil, sélecteur de profils).
  Future<String?> updatePhotoUrl(String photoUrl) async {
    final account = state.account;
    if (account == null) return 'Aucun compte connecté.';
    try {
      await _client.from('accounts').update({'photo_url': photoUrl}).eq('id', account.id);
      await _loadAccountAndProfiles();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// §2.5 du cahier des charges : « Suppression côté utilisateur = archivage... Réactivation
  /// possible. » Jamais une vraie suppression de données déclenchée par l'élève lui-même.
  Future<String?> archiveProfile(String profileId) async {
    try {
      await _client.from('profiles').update({'status': 'archive'}).eq('id', profileId);
      if (state.activeProfile?.id == profileId) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_activeProfilePrefKey);
      }
      await _loadAccountAndProfiles();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> reactivateProfile(String profileId) async {
    try {
      await _client.from('profiles').update({'status': 'actif'}).eq('id', profileId);
      await _loadAccountAndProfiles();
      return null;
    } catch (e) {
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
