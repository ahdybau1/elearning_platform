import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/theme/student_theme.dart';

/// §7.4 du cahier des charges : « Nouvelle connexion détectée → déconnexion immédiate et
/// automatique de l'ancienne session, avec message explicite ». Rendue directement par
/// `StudentAuthGate` (jamais poussée) — un accès évincé ne doit jamais rester atteignable en
/// revenant en arrière dans la pile de navigation.
class SessionEvictedScreen extends ConsumerWidget {
  const SessionEvictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.accentRose.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phonelink_erase_rounded,
                    size: 48,
                    color: context.colors.accentRose,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Compte utilisé sur un autre appareil — reconnectez-vous pour reprendre l\'accès',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Par sécurité, un seul appareil peut être connecté à la fois sur ce compte.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ref.read(studentAuthProvider.notifier).signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Se reconnecter',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
