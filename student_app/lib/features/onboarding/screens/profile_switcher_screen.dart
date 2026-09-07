import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../design_system/tokens/app_radius.dart';

class ProfileSwitcherScreen extends ConsumerWidget {
  const ProfileSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'E-Learning National',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Verrouiller',
            icon: Icon(
              Icons.lock_outline_rounded,
              color: context.colors.textSecondary,
              size: 20,
            ),
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
                'Quelle classe ouvrir ?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ce compte suit plusieurs classes — chacune a son propre suivi séparé.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth < 360
                      ? constraints.maxWidth
                      : 180.0;
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      ...authState.profiles.map((profile) {
                        final isActive = profile.id == authState.activeProfile?.id;
                        return InkWell(
                          onTap: () async {
                            await ref
                                .read(studentAuthProvider.notifier)
                                .selectProfile(profile);
                          },
                          borderRadius: AppRadius.radiusLarge,
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.colors.card,
                              borderRadius: AppRadius.radiusLarge,
                              border: Border.all(
                                color: isActive
                                    ? context.colors.accentPrimary
                                    : context.colors.border,
                                width: isActive ? 2 : 1,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: context.colors.accentPrimary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              children: [
                                if (isActive)
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.accentPrimary
                                            .withValues(alpha: 0.15),
                                        borderRadius: AppRadius.radiusSmall,
                                      ),
                                      child: Text(
                                        'Actif',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: context.colors.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: StudentTheme.primaryGradient,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      profile.name.isNotEmpty
                                          ? profile.name[0].toUpperCase()
                                          : 'É',
                                      style: GoogleFonts.outfit(
                                        fontSize: 30,
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
                                    color: context.colors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: AppRadius.radiusSmall,
                                  ),
                                  child: Text(
                                    profile.className,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: context.colors.accentPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/onboarding'),
                        borderRadius: AppRadius.radiusLarge,
                        child: Container(
                          width: cardWidth,
                          height: 195,
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(alpha: 0.5),
                            borderRadius: AppRadius.radiusLarge,
                            border: Border.all(
                              color: context.colors.border,
                              style: BorderStyle.solid,
                            ),
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
                                'Ajouter une classe',
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
    );
  }
}
