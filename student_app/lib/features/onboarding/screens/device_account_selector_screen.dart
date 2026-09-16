import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/device_accounts_service.dart';
import '../../../core/providers/app_root_providers.dart';
import '../../../design_system/components/empty_state_view.dart';
import 'login_code_entry_screen.dart';
import 'student_login_screen.dart';

/// Écran affiché uniquement quand au moins un compte a déjà été réellement authentifié (email +
/// mot de passe) sur CET appareil (voir `DeviceAccountsService`) — sélectionner une tuile ne fait
/// que choisir QUEL compte déverrouiller par code, jamais une connexion en elle-même : l'écran
/// suivant (`LoginCodeEntryScreen`) exige le code personnel de CE compte précis avant tout accès.
class DeviceAccountSelectorScreen extends ConsumerStatefulWidget {
  const DeviceAccountSelectorScreen({super.key});

  @override
  ConsumerState<DeviceAccountSelectorScreen> createState() => _DeviceAccountSelectorScreenState();
}

class _DeviceAccountSelectorScreenState extends ConsumerState<DeviceAccountSelectorScreen> {
  late Future<List<DeviceKnownAccount>> _knownFuture;

  @override
  void initState() {
    super.initState();
    _knownFuture = _loadKnown();
  }

  void _refresh() {
    // Corps bloc requis : un corps flèche (`=> _knownFuture = ...`) renvoie la VALEUR de
    // l'affectation, c'est-à-dire le Future lui-même — `setState` lève alors « callback argument
    // returned a Future », et pire, le nouveau Future assigné n'est jamais reconstruit dans l'arbre
    // (le `markNeedsBuild` n'est jamais atteint), donc son rejet devient une exception non
    // observée. Jamais exercé avant : ce bouton de nouvelle tentative n'existait pas.
    setState(() {
      _knownFuture = _loadKnown();
    });
  }

  /// `deviceAccountsService.listKnown()` directement, plus un observateur d'erreur silencieux posé
  /// IMMÉDIATEMENT sur ce même Future (`.catchError` ci-dessous) — sans lien avec la vraie
  /// consommation par `FutureBuilder` juste en dessous (les Future Dart supportent plusieurs
  /// auditeurs indépendants). Sans lui, un rejet qui survient avant que `FutureBuilder` ne se
  /// réabonne (ex. juste après `setState`, avant le prochain frame) peut être signalé comme une
  /// exception « non observée » par la zone de test, alors que l'UI affiche déjà correctement
  /// l'état d'erreur — repéré uniquement en testant réellement le bouton « Réessayer ».
  Future<List<DeviceKnownAccount>> _loadKnown() {
    final future = deviceAccountsService.listKnown();
    unawaited(future.catchError((_) => const <DeviceKnownAccount>[]));
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
                    tooltip: 'Retour',
                    // Cet écran est toujours la racine directe du parcours élève (jamais empilé) —
                    // rien à dépiler, il faut réinitialiser le choix de rôle pour revenir à
                    // RoleSelectionScreen (voir AppRootGate, main.dart).
                    onPressed: () => ref.read(hasChosenStudentRoleProvider.notifier).state = false,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qui se connecte ?',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez votre compte, puis saisissez votre code personnel.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                FutureBuilder<List<DeviceKnownAccount>>(
                  future: _knownFuture,
                  builder: (context, snapshot) {
                    // Une lecture locale échouée (stockage sécurisé indisponible, ex. profil
                    // système corrompu) ne doit jamais s'afficher comme « aucun compte connu » —
                    // ça inviterait l'élève à ressaisir un mot de passe alors que son compte est
                    // bien enregistré sur l'appareil.
                    if (snapshot.hasError) {
                      return EmptyStateView(
                        icon: Icons.error_outline_rounded,
                        iconColor: context.colors.accentRose,
                        title: 'Comptes enregistrés indisponibles',
                        description:
                            'Impossible de lire les comptes enregistrés sur cet appareil. Réessayez, ou connectez-vous avec votre email.',
                        actionLabel: 'Réessayer',
                        onAction: _refresh,
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(
                          color: context.colors.accentPrimary,
                        ),
                      );
                    }
                    final known = snapshot.data ?? const <DeviceKnownAccount>[];
                    return Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: [
                        ...known.map((account) => _AccountTile(
                              account: account,
                              onTap: () async {
                                final unlocked = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginCodeEntryScreen(account: account),
                                  ),
                                );
                                if (unlocked != true && context.mounted) {
                                  _refresh();
                                }
                              },
                              onForget: () async {
                                await deviceAccountsService.forgetAccount(account.accountId);
                                _refresh();
                              },
                            )),
                        InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                            );
                            _refresh();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 170,
                            height: 195,
                            decoration: BoxDecoration(
                              color: context.colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.colors.border),
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: context.colors.textPrimary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Ajouter un compte',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final DeviceKnownAccount account;
  final VoidCallback onTap;
  final VoidCallback onForget;

  const _AccountTile({required this.account, required this.onTap, required this.onForget});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
      onTap: onTap,
      onLongPress: () => _confirmForget(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: StudentTheme.primaryGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              ),
              child: (account.photoUrl?.isNotEmpty == true)
                  ? Image.network(account.photoUrl!, fit: BoxFit.cover, width: 80, height: 80)
                  : Center(
                      child: Text(
                        account.displayName.isNotEmpty ? account.displayName[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              account.displayName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Icon(Icons.lock_outline_rounded, size: 14, color: context.colors.textSecondary),
          ],
        ),
      ),
        ),
        // Affordance visible d'« oublier ce compte » — l'appui long seul (ci-dessus) n'était
        // jamais découvert par un élève qui n'en connaît pas déjà l'existence.
        Positioned(
          top: -6,
          right: -6,
          child: Tooltip(
            message: 'Oublier ce compte',
            child: InkWell(
              onTap: () => _confirmForget(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmForget(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Oublier ce compte ?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Vous devrez ressaisir votre email et votre mot de passe pour vous reconnecter sur cet appareil.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onForget();
            },
            child: Text('Oublier', style: TextStyle(color: context.colors.accentRose)),
          ),
        ],
      ),
    );
  }
}
