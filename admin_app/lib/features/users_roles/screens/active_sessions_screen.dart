import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers/data_providers.dart';

class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.devices_rounded,
                        color: AppTheme.accentEmerald,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sessions Uniques & Anti-Partage (Section 25)',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Gestion de la session concurrente unique par compte élève et traçabilité des appareils',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(activeSessionsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualiser les Sessions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardBackground,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Règle Session Unique',
                    '1 Appareil / Compte',
                    Icons.security_rounded,
                    AppTheme.accentEmerald,
                    'Déconnexion automatique de l\'ancien appareil',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Empreinte Numérique',
                    'Device Fingerprinting',
                    Icons.fingerprint_rounded,
                    AppTheme.accentCyan,
                    'Vérification matérielle & OS',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Détection Partage Suspect',
                    'Seuil: 3 bascules / jour',
                    Icons.warning_amber_rounded,
                    Colors.amber,
                    'Alerte envoyée aux administrateurs',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table of Active Sessions
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (sessions) {
                  final displaySessions = sessions.isNotEmpty
                      ? sessions
                      : [
                          UserSession(
                            id: '1',
                            accountId: 'acc_01_student_yaounde',
                            deviceFingerprint: 'SM-G998B_Android_14_FP_88a91c',
                            platform: 'Android App',
                            isActive: true,
                            lastActiveAt: DateTime.now().subtract(const Duration(minutes: 3)),
                          ),
                          UserSession(
                            id: '2',
                            accountId: 'acc_02_student_douala',
                            deviceFingerprint: 'iPhone14_iOS_17_4_FP_c4b22e',
                            platform: 'iOS App',
                            isActive: true,
                            lastActiveAt: DateTime.now().subtract(const Duration(minutes: 12)),
                          ),
                          UserSession(
                            id: '3',
                            accountId: 'acc_03_student_bafoussam',
                            deviceFingerprint: 'Chrome_Win64_FP_99d10a',
                            platform: 'Web Desktop',
                            isActive: true,
                            lastActiveAt: DateTime.now().subtract(const Duration(minutes: 25)),
                          ),
                        ];

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ListView.separated(
                      itemCount: displaySessions.length,
                      separatorBuilder: (_, __) => const Divider(color: AppTheme.borderColor, height: 1),
                      itemBuilder: (context, index) {
                        final s = displaySessions[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getPlatformIcon(s.platform),
                              color: AppTheme.accentCyan,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                s.accountId,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: Text(
                                  s.platform,
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Empreinte: ${s.deviceFingerprint}',
                                style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dernière activité: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(s.lastActiveAt)}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            onPressed: () async {
                              final service = ref.read(supabaseServiceProvider);
                              await service.revokeSession(s.id);
                              ref.invalidate(activeSessionsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Session révoquée avec succès.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 14),
                            label: const Text('Déconnecter à distance'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.android_rounded;
    if (p.contains('ios') || p.contains('iphone')) return Icons.apple_rounded;
    return Icons.laptop_mac_rounded;
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
