import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_accounts_service.dart';

/// §7.4 du cahier des charges : un seul accès actif par compte, toutes plateformes confondues.
/// `enforce_single_session()` (migration 31) + sa politique INSERT (migration 86) font tout le
/// travail de désactivation côté serveur dès qu'une ligne est insérée ; ce service ne fait
/// qu'insérer cette ligne pour CET appareil et surveiller si elle a été désactivée par un autre.
class SessionGuardService {
  const SessionGuardService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Insère une nouvelle session active pour ce compte — désactive automatiquement (trigger
  /// serveur) toute autre session active du même compte. Retourne l'id de la ligne créée, ou
  /// `null` en cas d'échec réseau (l'appelant doit alors réessayer plus tard, jamais bloquer
  /// l'accès élève pour un souci de traçabilité de session).
  Future<String?> registerSession(String accountId) async {
    try {
      final fingerprint = await deviceAccountsService.deviceFingerprint();
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final row = await _client
          .from('sessions')
          .insert({
            'account_id': accountId,
            'device_fingerprint': fingerprint,
            'platform': platform,
            'is_active': true,
          })
          .select('id')
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Contrôle ponctuel (repli) — le flux Realtime peut se couper en arrière-plan (onglet web en
  /// veille, app mobile suspendue) : à rappeler quand l'app revient au premier plan.
  Future<bool> isStillActive(String sessionId) async {
    try {
      final row = await _client
          .from('sessions')
          .select('is_active')
          .eq('id', sessionId)
          .maybeSingle();
      return row?['is_active'] as bool? ?? false;
    } catch (_) {
      // Réseau indisponible : on ne peut pas confirmer l'éviction, donc on ne la déclenche pas
      // non plus — mieux vaut un faux négatif temporaire qu'expulser un élève hors-ligne par erreur.
      return true;
    }
  }

  /// Flux temps réel de l'état `is_active` de CETTE session précise.
  Stream<bool> watchSession(String sessionId) {
    return _client
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isNotEmpty ? (rows.first['is_active'] as bool? ?? false) : true);
  }
}

const sessionGuardService = SessionGuardService();
