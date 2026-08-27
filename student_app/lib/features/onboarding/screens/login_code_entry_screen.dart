import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/device_accounts_service.dart';
import '../../../core/auth/student_auth_provider.dart';
import 'student_login_screen.dart';

/// Déverrouillage rapide par code personnel — RÈGLE DE SÉCURITÉ NON NÉGOCIABLE : ce code ne fait
/// que confirmer qu'il appartient exactement au compte déjà sélectionné (`account`), restauré côté
/// serveur via `verifyCodeForAccount` qui ne prend aucun identifiant de compte en paramètre (voir
/// migration 45, `verify_login_code`). Le code d'un autre compte est refusé exactement comme un
/// code incorrect — jamais de bascule automatique, jamais d'indice sur le vrai propriétaire.
class LoginCodeEntryScreen extends ConsumerStatefulWidget {
  final DeviceKnownAccount account;

  const LoginCodeEntryScreen({super.key, required this.account});

  @override
  ConsumerState<LoginCodeEntryScreen> createState() => _LoginCodeEntryScreenState();
}

class _LoginCodeEntryScreenState extends ConsumerState<LoginCodeEntryScreen> {
  final _codeCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Saisissez les 6 chiffres de votre code personnel.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final ok = await deviceAccountsService.verifyCodeForAccount(widget.account.accountId, code);

    if (!mounted) return;

    if (ok) {
      await ref.read(studentAuthProvider.notifier).unlockDeviceAccount(widget.account.accountId);
      if (!mounted) return;
      // Succès : StudentAuthGate (main.dart) réagit automatiquement au changement de session et
      // remplace toute cette pile de navigation — pas de navigation manuelle vers l'accueil ici.
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _codeCtrl.clear();
      // Message générique volontairement identique, que le code soit simplement faux OU qu'il
      // appartienne réellement à un autre compte connu sur cet appareil — ne jamais révéler lequel.
      _errorMessage = 'Code incorrect. Veuillez saisir votre code personnel.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: StudentTheme.primaryGradient,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                      ),
                      child: (widget.account.photoUrl?.isNotEmpty == true)
                          ? Image.network(
                              widget.account.photoUrl!,
                              fit: BoxFit.cover,
                              width: 72,
                              height: 72,
                            )
                          : Center(
                              child: Text(
                                widget.account.displayName.isNotEmpty
                                    ? widget.account.displayName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bonjour ${widget.account.displayName}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saisissez votre code personnel à 6 chiffres.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeCtrl,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: context.colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.accentRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.accentRose.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: context.colors.accentRose, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(fontSize: 12, color: context.colors.accentRose),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            'Déverrouiller',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Ce n\'est pas moi',
                          style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                        ),
                      ),
                      Text('·', style: TextStyle(color: context.colors.textSecondary)),
                      TextButton(
                        onPressed: () {
                          // `push` (pas `pushReplacement`) : garde cet écran de code dans la pile
                          // pour que le bouton retour de StudentLoginScreen y ramène directement —
                          // en cas de succès, StudentLoginScreen se charge lui-même de tout retirer
                          // d'un coup jusqu'à la racine (voir son `popUntil`), donc aucun écran de
                          // code périmé ne reste affiché.
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                          );
                        },
                        child: Text(
                          'Code oublié ?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.colors.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
