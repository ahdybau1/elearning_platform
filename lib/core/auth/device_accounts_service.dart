import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Un compte élève déjà réellement authentifié (email + mot de passe) au moins une fois sur CET
/// appareil précis — jamais un compte connu uniquement via un identifiant/code découvert ailleurs.
class DeviceKnownAccount {
  final String accountId;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;

  DeviceKnownAccount({
    required this.accountId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
  });

  String get displayName => firstName.isNotEmpty ? firstName : email;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'photoUrl': photoUrl,
      };

  factory DeviceKnownAccount.fromJson(Map<String, dynamic> json) => DeviceKnownAccount(
        accountId: json['accountId'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
      );
}

/// Registre LOCAL (cet appareil uniquement) des comptes élève déjà réellement authentifiés ici, avec
/// leur session Supabase persistée séparément — c'est ce qui permet le déverrouillage rapide par code
/// personnel (§7.3/§7.4) : le code ne fait que redéverrouiller une session déjà réelle et déjà
/// enregistrée sur CET appareil, il ne crée jamais de session à lui seul et ne permet jamais de
/// retrouver ou choisir un compte à partir du seul code (voir migration 45,
/// `verify_login_code`, qui ne vérifie que la session déjà restaurée — jamais un compte au choix).
class DeviceAccountsService {
  static const _registryKey = 'student_device_accounts_v1';
  static const _sessionKeyPrefix = 'student_device_session_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<DeviceKnownAccount>> listKnown() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_registryKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => DeviceKnownAccount.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Enregistre/actualise ce compte comme connu sur cet appareil, avec sa session Supabase actuelle
  /// (déjà réellement établie par email + mot de passe) — appelé après toute connexion/inscription
  /// réussie, jamais à partir d'un simple code.
  Future<void> registerCurrentAccount({
    required String accountId,
    required String firstName,
    required String lastName,
    required String email,
    String? photoUrl,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final prefs = await _prefs;
    final known = await listKnown();
    final updated = [
      ...known.where((a) => a.accountId != accountId),
      DeviceKnownAccount(
        accountId: accountId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        photoUrl: photoUrl,
      ),
    ];
    await prefs.setString(_registryKey, jsonEncode(updated.map((a) => a.toJson()).toList()));
    await prefs.setString('$_sessionKeyPrefix$accountId', jsonEncode(session.toJson()));
  }

  Future<void> forgetAccount(String accountId) async {
    final prefs = await _prefs;
    final known = await listKnown();
    await prefs.setString(
      _registryKey,
      jsonEncode(known.where((a) => a.accountId != accountId).map((a) => a.toJson()).toList()),
    );
    await prefs.remove('$_sessionKeyPrefix$accountId');
  }

  /// Cœur de la vérification : restaure la session déjà enregistrée pour CE compte précis dans un
  /// client Supabase TEMPORAIRE et isolé (jamais le client global de l'app), puis vérifie le code
  /// dessus. En cas d'échec, le client temporaire est jeté sans que la session réelle de l'app n'ait
  /// jamais été touchée — aucune donnée du compte n'est donc jamais exposée sur un code invalide.
  /// Ne renvoie `true` que si le code correspond exactement au compte déjà sélectionné.
  Future<bool> verifyCodeForAccount(String accountId, String code) async {
    final prefs = await _prefs;
    final sessionJson = prefs.getString('$_sessionKeyPrefix$accountId');
    if (sessionJson == null) return false;

    final tempClient = SupabaseClient(resolvedSupabaseUrl(), resolvedSupabaseAnonKey());
    try {
      await tempClient.auth.setInitialSession(sessionJson);
      final result = await tempClient.rpc('verify_login_code', params: {'p_code': code});
      final success = result is Map && result['success'] == true;
      if (success) {
        // Les jetons peuvent avoir été renouvelés pendant la restauration — on garde la version la
        // plus fraîche pour la prochaine fois.
        final refreshed = tempClient.auth.currentSession;
        if (refreshed != null) {
          await prefs.setString('$_sessionKeyPrefix$accountId', jsonEncode(refreshed.toJson()));
        }
      }
      return success;
    } catch (_) {
      return false;
    } finally {
      await tempClient.dispose();
    }
  }

  /// N'appeler qu'après [verifyCodeForAccount] == true : installe pour de vrai la session de ce
  /// compte sur le client global de l'app (déclenche StudentAuthNotifier normalement).
  Future<void> activateOnPrimaryClient(String accountId) async {
    final prefs = await _prefs;
    final sessionJson = prefs.getString('$_sessionKeyPrefix$accountId');
    if (sessionJson == null) return;
    await Supabase.instance.client.auth.setInitialSession(sessionJson);
  }
}

final deviceAccountsService = DeviceAccountsService();
