import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';

class ProfileSwitcherScreen extends ConsumerWidget {
  const ProfileSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'E-Learning National',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showParentPinDialog(context, ref),
            icon: const Icon(Icons.lock_outline_rounded, color: StudentTheme.accentAmber, size: 18),
            label: Text(
              'Espace Parent',
              style: GoogleFonts.inter(color: StudentTheme.accentAmber, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded, color: StudentTheme.textSecondary, size: 20),
            onPressed: () => ref.read(studentAuthProvider.notifier).signOut(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Qui apprend aujourd\'hui ?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Modèle 1 Profil = 1 Classe pour un suivi individuel sans confusion.',
                style: GoogleFonts.inter(fontSize: 14, color: StudentTheme.textSecondary),
              ),
              const SizedBox(height: 40),

              // Profiles Grid
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  ...authState.profiles.map((profile) {
                    final isActive = profile.id == authState.activeProfile?.id;
                    return InkWell(
                      onTap: () async {
                        await ref.read(studentAuthProvider.notifier).selectProfile(profile);
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 170,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: StudentTheme.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? StudentTheme.accentPrimary : StudentTheme.borderDark,
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: StudentTheme.accentPrimary.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: StudentTheme.primaryGradient,
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'E',
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
                              profile.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: StudentTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile.className,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: StudentTheme.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Add Profile Card
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/onboarding'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 170,
                      height: 195,
                      decoration: BoxDecoration(
                        color: StudentTheme.surfaceDark.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: StudentTheme.borderDark, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: StudentTheme.cardDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: StudentTheme.borderDark),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ajouter un profil',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: StudentTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showParentPinDialog(BuildContext context, WidgetRef ref) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudentTheme.cardDark,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: StudentTheme.accentAmber),
            const SizedBox(width: 10),
            Text(
              'Code PIN Parent',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez votre code confidentiel à 4 chiffres (défaut: 1234) :',
              style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.firaCode(fontSize: 22, color: Colors.white, letterSpacing: 8),
              decoration: InputDecoration(
                filled: true,
                fillColor: StudentTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: StudentTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentTheme.accentAmber),
            onPressed: () {
              // TODO(Espace Parent réel) : ce PIN codé en dur est un jalon temporaire. Le vrai
              // rattachement parent passe par `parent_accounts` (voir docs/cahier_des_charges.md
              // §17), pas par un simple code sur le compte élève — à refaire dans une passe dédiée.
              if (pinCtrl.text == '1234') {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/parent-portal');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code PIN incorrect (Code par défaut: 1234)')),
                );
              }
            },
            child: const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
