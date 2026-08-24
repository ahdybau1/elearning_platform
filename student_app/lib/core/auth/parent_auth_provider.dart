import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/student_models.dart';

/// §17 du cahier des charges : « Compte parent (identité propre, créé séparément du compte
/// élève) ». Utilise un [SupabaseClient] DÉDIÉ, distinct de `Supabase.instance.client` (session
/// élève), avec sa propre persistance locale (voir [ParentAuthNotifier._persistSession]) — c'est ce
/// qui permet à un parent et à l'élève d'être connectés SIMULTANÉMENT sur le même appareil, sans
/// jamais se couper l'un l'autre, et donc de basculer entre les deux vues « sans réauthentification
/// constante » comme l'exige le CDC. Toucher `Supabase.instance.client` depuis ce fichier serait un
/// bug : cela couperait la session élève de `student_auth_provider.dart`.
final SupabaseClient parentSupabaseClient = SupabaseClient(
  resolvedSupabaseUrl(),
  resolvedSupabaseAnonKey(),
);

const String _parentSessionPrefKey = 'parent_auth_session_v1';

class ParentAuthState {
  final ParentAccount? account;
  final List<LinkedChildProfile> children;
  final bool isLoading;
  final String? errorMessage;
  final String? sessionEmail;

  const ParentAuthState({
    this.account,
    this.children = const [],
    this.isLoading = false,
    this.errorMessage,
    this.sessionEmail,
  });

  bool get hasSession => sessionEmail != null;
  bool get isAuthenticated => account != null;

  ParentAuthState copyWith({
    ParentAccount? account,
    List<LinkedChildProfile>? children,
    bool? isLoading,
    String? errorMessage,
    String? sessionEmail,
  }) {
    return ParentAuthState(
      account: account ?? this.account,
      children: children ?? this.children,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      sessionEmail: sessionEmail ?? this.sessionEmail,
    );
  }
}

class ParentAuthNotifier extends StateNotifier<ParentAuthState> {
  ParentAuthNotifier() : super(const ParentAuthState(isLoading: true)) {
    _init();
  }

  SupabaseClient get _client => parentSupabaseClient;
  StreamSubscription<AuthState>? _authSubscription;
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      unawaited(_persistSession(session));
      if (session?.user == null) {
        state = const ParentAuthState(isLoading: false);
        return;
      }
      _loadParentAndChildren();
    }, onError: (_) {
      state = const ParentAuthState(isLoading: false);
    });

    // Restauration de session persistée (même mécanisme que SupabaseAuth._onAuthStateChange côté
    // supabase_flutter, reconstruit manuellement ici car ce client ne passe pas par Supabase.initialize).
    final persisted = _prefs?.getString(_parentSessionPrefKey);
    if (persisted != null) {
      try {
        await _client.auth.setInitialSession(persisted);
        return; // onAuthStateChange se déclenche et charge le compte.
      } catch (_) {
        await _prefs?.remove(_parentSessionPrefKey);
      }
    }
    state = const ParentAuthState(isLoading: false);
  }

  Future<void> _persistSession(Session? session) async {
    if (session != null) {
      await _prefs?.setString(_parentSessionPrefKey, jsonEncode(session.toJson()));
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadParentAndChildren() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        state = const ParentAuthState(isLoading: false);
        return;
      }

      final parentRow = await _client
          .from('parent_accounts')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (parentRow == null) {
        // Session réelle mais aucun compte parent actif visible (RLS filtre déjà is_active — voir
        // migration 42) : compte suspendu ou lien pas encore établi par l'administration.
        state = ParentAuthState(isLoading: false, sessionEmail: user.email, errorMessage: 'Aucun compte parent actif trouvé pour cette session.');
        return;
      }

      final parent = ParentAccount.fromJson(Map<String, dynamic>.from(parentRow));

      final linkRows = await _client
          .from('parent_profile_links')
          .select('profiles(id, school_year, subscription_tier, status, accounts(first_name, last_name), academic_nodes(name))')
          .eq('parent_account_id', parent.id)
          .then((r) => r as List);

      final children = linkRows
          .where((r) => (r as Map<String, dynamic>)['profiles'] != null)
          .map((r) => LinkedChildProfile.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      state = ParentAuthState(
        account: parent,
        children: children,
        isLoading: false,
        sessionEmail: user.email,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      return e.message;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _prefs?.remove(_parentSessionPrefKey);
    await _client.auth.signOut();
    state = const ParentAuthState(isLoading: false);
  }

  /// §9 du cahier des charges : tickets identifiés séparément élève/parent — voir migration 43
  /// (support_tickets.parent_account_id, policy owns_parent_account). Doit passer par CE client
  /// (session parent), jamais _client de student_auth_provider, pour que auth.uid() corresponde au
  /// parent et non à l'élève.
  Future<String?> createSupportTicket({required String category, required String subject, required String description}) async {
    final parentId = state.account?.id;
    if (parentId == null) return 'Aucun compte parent connecté.';
    try {
      await _client.from('support_tickets').insert({
        'parent_account_id': parentId,
        'category': category,
        'subject': subject,
        'description': description,
        'requester_type': 'parent',
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<ParentTransaction>> fetchTransactions() async {
    final profileIds = state.children.map((c) => c.profileId).toList();
    if (profileIds.isEmpty) return [];
    final rows = await _client
        .from('transactions')
        .select()
        .inFilter('profile_id', profileIds)
        .eq('status', 'success')
        .order('created_at', ascending: false)
        .limit(20)
        .then((r) => r as List);
    return rows.map((r) => ParentTransaction.fromJson(Map<String, dynamic>.from(r))).toList();
  }
}

final parentAuthProvider = StateNotifierProvider<ParentAuthNotifier, ParentAuthState>((ref) {
  return ParentAuthNotifier();
});

final parentTransactionsProvider = FutureProvider.autoDispose<List<ParentTransaction>>((ref) async {
  final notifier = ref.watch(parentAuthProvider.notifier);
  ref.watch(parentAuthProvider); // recharge si le compte/les enfants changent
  return notifier.fetchTransactions();
});
