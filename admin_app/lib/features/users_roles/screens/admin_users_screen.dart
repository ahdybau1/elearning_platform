import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/data_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final authState = authAsync.valueOrNull;
    final isSuperAdmin = authState?.isSuperAdmin ?? false;

    final adminsAsync = ref.watch(adminUsersProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comptes Administrateurs & Matrice de Permissions',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attribution des rôles fixes et permissions nommées (Super-admin dispose du contrôle total)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              if (isSuperAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showAddAdminModal(context, ref),
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 18,
                  ),
                  label: const Text('Créer un Compte Administrateur'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: adminsAsync.when(
              data: (admins) {
                if (admins.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun administrateur trouvé.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: admins.length,
                  itemBuilder: (context, idx) {
                    final admin = admins[idx];
                    final roleLabel = AdminRole.fromString(admin.role).label;
                    final isSuper = admin.role == 'super_admin';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSuper
                              ? AppTheme.accentEmerald.withValues(alpha: 0.5)
                              : AppTheme.primaryBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isSuper
                                ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                                : AppTheme.accentBlue.withValues(alpha: 0.15),
                            child: Icon(
                              isSuper
                                  ? Icons.shield_rounded
                                  : Icons.person_rounded,
                              color: isSuper
                                  ? AppTheme.accentEmerald
                                  : AppTheme.accentBlue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${admin.firstName} ${admin.lastName}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${admin.email} • Rôle: $roleLabel',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Statut: ${admin.isActive ? "Actif" : "Inactif"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSuperAdmin && !isSuper)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: AppTheme.primaryBorder,
                                ),
                              ),
                              onPressed: () {},
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('Ajuster Permissions'),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Erreur: $err',
                  style: GoogleFonts.inter(color: AppTheme.accentRose),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAdminModal(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Créer un Compte Administrateur',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email administrateur',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe temporaire',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.refresh(adminUsersProvider);
              Navigator.pop(context);
            },
            child: const Text('Créer le Compte'),
          ),
        ],
      ),
    );
  }
}
