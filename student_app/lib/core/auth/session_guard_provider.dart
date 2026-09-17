import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_guard_service.dart';
import 'student_auth_provider.dart';

/// §7.4 du cahier des charges.
class SessionGuardState {
  final String? sessionId;
  final bool isEvicted;

  const SessionGuardState({this.sessionId, this.isEvicted = false});

  SessionGuardState copyWith({
    String? sessionId,
    bool clearSessionId = false,
    bool? isEvicted,
  }) {
    return SessionGuardState(
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      isEvicted: isEvicted ?? this.isEvicted,
    );
  }
}

/// Écoute `studentAuthProvider` plutôt que d'être appelé depuis `StudentAuthNotifier` lui-même
/// (qui n'a pas de `Ref`, et dont le contrat déjà testé ne doit pas changer pour cette seule
/// fonctionnalité) : dès qu'un compte réellement déverrouillé cette ouverture apparaît, ce
/// notifieur enregistre une session pour CET appareil ; toute autre session active du même compte
/// est alors désactivée côté serveur (`enforce_single_session`, migration 31), et si c'est CETTE
/// session-ci qui est désactivée par un login ailleurs, `isEvicted` bascule à `true`.
class SessionGuardNotifier extends StateNotifier<SessionGuardState> {
  SessionGuardNotifier(this._ref) : super(const SessionGuardState()) {
    _ref.listen<StudentAuthState>(
      studentAuthProvider,
      _onAuthStateChanged,
      fireImmediately: true,
    );
    _lifecycleListener = AppLifecycleListener(onResume: _recheckOnResume);
  }

  final Ref _ref;
  String? _registeredForAccountId;
  StreamSubscription<bool>? _realtimeSubscription;
  AppLifecycleListener? _lifecycleListener;

  void _onAuthStateChanged(StudentAuthState? previous, StudentAuthState next) {
    final accountId = next.account?.id;
    if (accountId == null || !next.hasUnlockedThisBoot) {
      if (_registeredForAccountId != null) _reset();
      return;
    }
    if (_registeredForAccountId == accountId) return;
    _registeredForAccountId = accountId;
    unawaited(_register(accountId));
  }

  Future<void> _register(String accountId) async {
    final sessionId = await sessionGuardService.registerSession(accountId);
    if (sessionId == null) return;
    // Le compte a pu changer (déconnexion) pendant l'attente réseau — n'installe pas un état
    // périmé sur un compte qui n'est déjà plus actif.
    if (_registeredForAccountId != accountId) return;
    state = SessionGuardState(sessionId: sessionId, isEvicted: false);
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = sessionGuardService.watchSession(sessionId).listen((isActive) {
      if (!isActive) state = state.copyWith(isEvicted: true);
    });
  }

  Future<void> _recheckOnResume() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isEvicted) return;
    final stillActive = await sessionGuardService.isStillActive(sessionId);
    if (!stillActive) state = state.copyWith(isEvicted: true);
  }

  void _reset() {
    _registeredForAccountId = null;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    state = const SessionGuardState();
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.cancel());
    _lifecycleListener?.dispose();
    super.dispose();
  }
}

final sessionGuardProvider = StateNotifierProvider<SessionGuardNotifier, SessionGuardState>(
  (ref) => SessionGuardNotifier(ref),
);
