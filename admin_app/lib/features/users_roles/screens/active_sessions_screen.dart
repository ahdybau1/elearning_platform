import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

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
    final suspiciousAsync = ref.watch(suspiciousSessionAccountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    color: AppTheme.accentEmerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessions Uniques & Anti-Partage',
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
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(activeSessionsProvider);
                    ref.invalidate(suspiciousSessionAccountsProvider);
                  },
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
                  child: suspiciousAsync.when(
                    data: (flagged) => _buildStatCard(
                      'Partage Suspect Aujourd\'hui',
                      flagged.isEmpty ? 'Aucun compte' : '${flagged.length} compte(s)',
                      Icons.warning_amber_rounded,
                      flagged.isEmpty ? AppTheme.accentEmerald : Colors.amber,
                      flagged.isEmpty
                          ? 'Aucune bascule d\'appareil suspecte (seuil : 3 / jour)'
                          : '≥ 3 bascules d\'appareil — à vérifier ci-dessous',
                    ),
                    loading: () => _buildStatCard('Partage Suspect Aujourd\'hui', '...', Icons.warning_amber_rounded,
                        Colors.amber, 'Calcul en cours...'),
                    error: (err, _) => _buildStatCard('Partage Suspect Aujourd\'hui', 'Erreur',
                        Icons.warning_amber_rounded, AppTheme.accentRose, '$err'),
                  ),
                ),
              ],
            ),

            suspiciousAsync.maybeWhen(
              data: (flagged) => flagged.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text('Comptes à investiguer (bascules d\'appareil aujourd\'hui)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: flagged.map((f) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Text(
                                    '${f.firstName} ${f.lastName} (${f.email}) — ${f.switchCount} bascules',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
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
                  if (sessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.devices_other_rounded, size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text('Aucune session active pour le moment',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            'Les connexions élèves apparaîtront ici dès que l\'application élève écrira dans la\ntable des sessions.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
                      itemBuilder: (context, index) {
                        final s = sessions[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
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
                              Flexible(
                                child: Text(
                                  s.accountDisplayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
                              if (s.accountEmail != null)
                                Text(s.accountEmail!,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
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
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            onPressed: () => _showRevokeConfirmation(context, s),
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

  void _showRevokeConfirmation(BuildContext context, UserSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.logout_rounded,
          iconColor: Colors.redAccent,
          text: 'Déconnecter cet appareil ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          '${session.accountDisplayName} sera immédiatement déconnecté de ${session.platform}. '
          'L\'élève devra se reconnecter pour reprendre l\'accès.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await service.revokeSession(session.id);
                ref.invalidate(activeSessionsProvider);
                messenger.showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Session révoquée avec succès.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Déconnecter'),
          ),
        ],
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
              color: color.withValues(alpha: 0.15),
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
