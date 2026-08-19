import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

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
                              onPressed: () => _showPermissionsModal(context, ref, admin),
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
    String selectedRole = 'admin_contenu';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.admin_panel_settings_rounded,
            text: 'Créer un Compte Administrateur',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email administrateur',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 16),
                // ignore: deprecated_member_use
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedRole,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin_pays',
                      child: Text('Administrateur Pays'),
                    ),
                    DropdownMenuItem(
                      value: 'admin_contenu',
                      child: Text('Administrateur Contenu'),
                    ),
                    DropdownMenuItem(
                      value: 'enseignant',
                      child: Text('Enseignant'),
                    ),
                    DropdownMenuItem(
                      value: 'moderateur',
                      child: Text('Modérateur'),
                    ),
                    DropdownMenuItem(
                      value: 'support',
                      child: Text('Support Client'),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => selectedRole = v ?? selectedRole),
                ),
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final firstName = firstNameController.text.trim();
                      final lastName = lastNameController.text.trim();
                      if (email.isEmpty ||
                          firstName.isEmpty ||
                          lastName.isEmpty) {
                        return;
                      }
                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createAdminUser(
                          email: email,
                          firstName: firstName,
                          lastName: lastName,
                          role: selectedRole,
                        );
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                'Administrateur $email créé avec succès.',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentRose,
                              content: Text('Erreur: $e',
                                  style:
                                      GoogleFonts.inter(color: Colors.white)),
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Créer le Compte'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsModal(BuildContext context, WidgetRef ref, AdminUser admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.tune_rounded,
          text: 'Permissions de ${admin.firstName} ${admin.lastName}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 420,
          child: Consumer(
            builder: (context, ref, _) {
              final permissionsAsync = ref.watch(adminPermissionsProvider(admin.id));
              return permissionsAsync.when(
                data: (granted) {
                  final grantedKeys = granted
                      .where((p) => p.granted)
                      .map((p) => p.permissionKey)
                      .toSet();
                  return SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: PermissionKey.values.map((perm) {
                      final isGranted = grantedKeys.contains(perm.name);
                      return SwitchListTile(
                        dense: true,
                        activeThumbColor: AppTheme.accentEmerald,
                        title: Text(
                          _permissionLabel(perm),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        ),
                        value: isGranted,
                        onChanged: (value) async {
                          final service = ref.read(supabaseServiceProvider);
                          if (value) {
                            await service.grantPermission(admin.id, perm.name);
                          } else {
                            await service.revokePermission(admin.id, perm.name);
                          }
                          ref.invalidate(adminPermissionsProvider(admin.id));
                        },
                      );
                    }).toList(),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text(
                  'Erreur: $err',
                  style: GoogleFonts.inter(color: AppTheme.accentRose),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  String _permissionLabel(PermissionKey perm) {
    switch (perm) {
      case PermissionKey.viewFinancials:
        return 'Voir les données financières';
      case PermissionKey.manageAcademicTree:
        return 'Gérer l\'arbre académique';
      case PermissionKey.publishContent:
        return 'Publier du contenu pédagogique';
      case PermissionKey.moderateForum:
        return 'Modérer le forum';
      case PermissionKey.reconcilePayments:
        return 'Réconcilier les paiements';
      case PermissionKey.viewAiCosts:
        return 'Voir les coûts IA';
    }
  }
}
