import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_provider.dart';
import '../services/supabase_service.dart';
import '../models/admin_models.dart';

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
  final String selectedCountry;
  final List<String> permissions;

  AdminUserState({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.selectedCountry = 'Cameroun',
    this.permissions = const [],
  });

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  bool get canViewFinancials => role == AdminRole.superAdmin;

  bool hasPermission(String permKey) {
    if (isSuperAdmin) return true;
    return permissions.contains(permKey);
  }

  AdminUserState copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    AdminRole? role,
    String? selectedCountry,
    List<String>? permissions,
  }) {
    return AdminUserState(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      permissions: permissions ?? this.permissions,
    );
  }

  factory AdminUserState.fromAdminUser(AdminUser adminUser) {
    return AdminUserState(
      id: adminUser.id,
      email: adminUser.email,
      firstName: adminUser.firstName,
      lastName: adminUser.lastName,
      role: AdminRole.fromString(adminUser.role),
      selectedCountry: adminUser.scopeJson['selected_country'] ?? 'Cameroun',
      permissions: List<String>.from(adminUser.scopeJson['permissions'] ?? []),
    );
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<AdminUserState?>> {
  AuthNotifier() : super(const AsyncValue.data(null)) {
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final user = data.session?.user;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }
      state = const AsyncValue.loading();
      SupabaseService(Supabase.instance.client)
          .getAdminUserByEmail(user.email ?? '')
          .then((adminUser) {
            if (adminUser == null) {
              state = const AsyncValue.data(null);
              return;
            }
            state = AsyncValue.data(AdminUserState.fromAdminUser(adminUser));
          })
          .catchError((err) {
            state = AsyncError(err, StackTrace.current);
          });
    });
  }

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void switchRole(AdminRole newRole) {
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(state.value!.copyWith(role: newRole));
    }
  }

  void switchCountry(String countryName) {
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(
        state.value!.copyWith(selectedCountry: countryName),
      );
    }
  }

  Future<void> signInWithPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw Exception(
          'Échec de l’authentification. Vérifiez vos identifiants.',
        );
      }
      final adminUser = await SupabaseService(
        Supabase.instance.client,
      ).getAdminUserByEmail(user.email ?? '');
      if (adminUser == null) {
        throw Exception(
          'Adresse email non associée à un compte administrateur.',
        );
      }
      state = AsyncValue.data(AdminUserState.fromAdminUser(adminUser));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AdminUserState?>>((ref) {
      return AuthNotifier();
    });

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

class AuthRepository {
  final SupabaseClient client;

  AuthRepository(this.client);

  Future<AdminUserState?> signInWithPassword(
    String email,
    String password,
  ) async {
    final res = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) return null;

    final adminUser = await SupabaseService(
      client,
    ).getAdminUserByEmail(user.email ?? '');
    if (adminUser == null) return null;

    return AdminUserState.fromAdminUser(adminUser);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
