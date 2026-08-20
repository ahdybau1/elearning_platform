import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_provider.dart';
import '../services/supabase_service.dart';
import '../models/admin_models.dart';
import '../models/enums.dart';

enum AdminRole {
  superAdmin(
    'Super-Administrateur',
    'super_admin',
    'Accès total à toutes les fonctionnalités et données financières.',
  ),
  adminPays(
    'Administrateur Pays',
    'admin_pays',
    'Gestion de l\'arbre académique, des enseignants et des contenus du pays.',
  ),
  adminContenu(
    'Administrateur Contenu',
    'admin_contenu',
    'Gestion et validation des leçons, cours et exercices.',
  ),
  enseignant(
    'Enseignant',
    'enseignant',
    'Création et soumission de cours/exercices rattachés aux établissements.',
  ),
  moderateur(
    'Modérateur',
    'moderateur',
    'Modération des messages du forum et examen des signalements IA.',
  ),
  support(
    'Support Client',
    'support',
    'Traitement des tickets de réclamation des élèves et parents.',
  );

  final String label;
  final String code;
  final String description;

  const AdminRole(this.label, this.code, this.description);

  static AdminRole fromString(String code) {
    return values.firstWhere((r) => r.code == code, orElse: () => superAdmin);
  }
}

class AdminUserState {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final AdminRole role;
  final List<String> permissions;

  AdminUserState({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.permissions = const [],
  });

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  bool hasPermission(String permKey) {
    if (isSuperAdmin) return true;
    return permissions.contains(permKey);
  }

  bool get canViewFinancials => hasPermission(PermissionKey.viewFinancials.name);

  bool get canViewAiCosts => hasPermission(PermissionKey.viewAiCosts.name);

  AdminUserState copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    AdminRole? role,
    List<String>? permissions,
  }) {
    return AdminUserState(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }

  factory AdminUserState.fromAdminUser(
    AdminUser adminUser, {
    List<String> grantedPermissions = const [],
  }) {
    return AdminUserState(
      id: adminUser.id,
      email: adminUser.email,
      firstName: adminUser.firstName,
      lastName: adminUser.lastName,
      role: AdminRole.fromString(adminUser.role),
      permissions: grantedPermissions,
    );
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<AdminUserState?>> {
  AuthNotifier(this._client) : super(const AsyncValue.data(null)) {
    _listenAuthChanges();
    _maybeAutoLogin();
  }

  final SupabaseClient _client;

  // Connexion automatique en développement local UNIQUEMENT, pour éviter d'avoir à ressaisir les
  // identifiants à chaque rechargement pendant les tests. Gardée par DEMO_AUTO_LOGIN dans .env
  // (absent par défaut, jamais commit — voir 03_auth_flow.md). Ne contourne rien : passe par le
  // vrai signInWithPassword ci-dessous, donc RLS et la vérification admin_users restent la seule
  // source de vérité — un mauvais mot de passe ou un compte non lié échoue exactement pareil.
  Future<void> _maybeAutoLogin() async {
    if (dotenv.env['DEMO_AUTO_LOGIN'] != 'true') return;
    if (_client.auth.currentSession != null) return;
    final email = dotenv.env['DEMO_EMAIL'];
    final password = dotenv.env['DEMO_PASSWORD'];
    if (email == null || password == null) return;
    await signInWithPassword(email, password);
  }

  void _listenAuthChanges() {
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }
      await _resolveAdmin(user.id);
    }, onError: (err) {
      state = const AsyncValue.data(null);
    });
  }

  // Le rôle affiché vient toujours d'une requête à admin_users filtrée par auth.uid(), jamais d'un
  // état codé en dur côté client (voir 03_auth_flow.md). Un compte authentifié via Supabase Auth
  // mais absent/inactif dans admin_users n'est pas un admin autorisé : la session est révoquée et
  // l'échec reste visible.
  Future<void> _resolveAdmin(String authUserId) async {
    try {
      final service = SupabaseService(_client);
      final adminUser = await service.getAdminUserByAuthId(authUserId);
      if (adminUser == null || !adminUser.isActive) {
        await _client.auth.signOut();
        state = AsyncValue.error(
          'Compte non autorisé ou inactif.',
          StackTrace.current,
        );
        return;
      }
      // Les droits fins (voir les finances, les coûts IA...) viennent de admin_permissions,
      // seule source de vérité pour ce que le super-admin a explicitement accordé à cet admin —
      // jamais d'un état client codé en dur (voir 03_auth_flow.md).
      final grantedPermissions = await service.fetchPermissions(adminUser.id);
      final permissionKeys = grantedPermissions
          .where((p) => p.granted)
          .map((p) => p.permissionKey)
          .toList();
      state = AsyncValue.data(
        AdminUserState.fromAdminUser(adminUser, grantedPermissions: permissionKeys),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signInWithPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        state = AsyncValue.error('Authentification échouée.', StackTrace.current);
        return;
      }
      await _resolveAdmin(user.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AdminUserState?>>((ref) {
      return AuthNotifier(ref.watch(supabaseClientProvider));
    });
