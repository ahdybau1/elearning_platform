import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/student_providers.dart';
import '../theme/student_theme.dart';

/// Bloque l'accès à toute l'application quand un super-admin active le mode maintenance depuis
/// Paramètres Système (admin_app) — vérifié avant même le routage vers l'écran de démarrage, donc
/// aucune route de l'app élève n'est jamais atteignable pendant la maintenance.
class MaintenanceGate extends ConsumerWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return settingsAsync.when(
      data: (settings) => settings.maintenanceMode
          ? _MaintenanceScreen(message: settings.maintenanceMessage)
          : child,
      loading: () => child,
      error: (_, _) => child,
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_circle_rounded, size: 72, color: context.colors.accentAmber),
              const SizedBox(height: 24),
              Text(
                'Application en Maintenance',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                (message == null || message!.trim().isEmpty)
                    ? 'L\'application est momentanément indisponible. Merci de réessayer un peu plus tard.'
                    : message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
