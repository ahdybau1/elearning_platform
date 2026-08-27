import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/device_accounts_service.dart';
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
    _knownFuture = deviceAccountsService.listKnown();
  }

  void _refresh() {
    setState(() => _knownFuture = deviceAccountsService.listKnown());
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
    return InkWell(
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
