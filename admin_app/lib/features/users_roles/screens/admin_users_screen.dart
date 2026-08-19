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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 14),
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

                    return Opacity(
                      opacity: admin.isActive ? 1.0 : 0.55,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !admin.isActive
                                ? AppTheme.accentAmber
                                : isSuper
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${admin.firstName} ${admin.lastName}',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (!admin.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentAmber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Suspendu',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${admin.email} • Rôle: $roleLabel',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSuperAdmin && !isSuper) ...[
                              IconButton(
                                onPressed: () => _showEditAdminModal(context, ref, admin),
                                icon: const Icon(Icons.edit_rounded, color: AppTheme.accentBlue, size: 20),
                                tooltip: 'Modifier',
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: AppTheme.primaryBorder,
                                  ),
                                ),
                                onPressed: () => _showPermissionsModal(context, ref, admin),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Permissions'),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => admin.isActive
                                    ? _showSuspendConfirmation(context, ref, admin)
                                    : _toggleActive(context, ref, admin, true),
                                icon: Icon(
                                  admin.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                  color: AppTheme.accentAmber,
                                  size: 20,
                                ),
                                tooltip: admin.isActive ? 'Suspendre' : 'Réactiver',
                              ),
                              if (!admin.isActive)
                                IconButton(
                                  onPressed: () => _showDeleteConfirmation(context, ref, admin),
                                  icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRose, size: 20),
                                  tooltip: 'Supprimer définitivement',
                                ),
                            ],
                          ],
                        ),
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

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, AdminUser admin, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateAdminUser(admin.id, isActive: isActive);
      ref.invalidate(adminUsersProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Compte réactivé.' : 'Compte suspendu.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
  }

  void _showSuspendConfirmation(BuildContext context, WidgetRef ref, AdminUser admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.block_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Suspendre "${admin.firstName} ${admin.lastName}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'Ce compte ne pourra plus se connecter à l\'espace administration, mais rien n\'est supprimé — '
          'vous pourrez le réactiver ou le supprimer définitivement plus tard.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(context, ref, admin, false);
            },
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AdminUser admin) {
    final confirmController = TextEditingController();
    final fullName = '${admin.firstName} ${admin.lastName}';
    bool nameMatches = false;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer "$fullName" ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'IRRÉVERSIBLE : le compte administrateur sera définitivement supprimé. Les actions '
                    'déjà journalisées à son nom dans l\'audit log sont conservées.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tapez "$fullName" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: fullName),
                  onChanged: (v) => setModalState(() => nameMatches = v.trim() == fullName),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(errorText!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
              onPressed: (isLoading || !nameMatches)
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.deleteAdminUser(admin.id);
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Compte "$fullName" supprimé définitivement.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAdminModal(BuildContext context, WidgetRef ref, AdminUser admin) {
    final firstNameCtrl = TextEditingController(text: admin.firstName);
    final lastNameCtrl = TextEditingController(text: admin.lastName);
    String selectedRole = admin.role;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.edit_rounded,
            text: 'Modifier l\'Administrateur',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email (non modifiable) : ${admin.email}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 14),
                TextField(
                  controller: firstNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedRole,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: 'admin_pays', child: Text('Administrateur Pays')),
                    DropdownMenuItem(value: 'admin_contenu', child: Text('Administrateur Contenu')),
                    DropdownMenuItem(value: 'enseignant', child: Text('Enseignant')),
                    DropdownMenuItem(value: 'moderateur', child: Text('Modérateur')),
                    DropdownMenuItem(value: 'support', child: Text('Support Client')),
                  ],
                  onChanged: (v) => setModalState(() => selectedRole = v ?? selectedRole),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le prénom et le nom sont obligatoires.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateAdminUser(
                          admin.id,
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          role: selectedRole,
                        );
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAdminModal(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    String selectedRole = 'admin_contenu';
    String? formError;
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
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email administrateur',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe initial',
                    helperText: 'Au moins 6 caractères',
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
                if (formError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ),
                ],
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
                      if (email.isEmpty || firstName.isEmpty || lastName.isEmpty) {
                        setModalState(() => formError = 'Email, prénom et nom sont obligatoires.');
                        return;
                      }
                      if (passwordController.text.trim().length < 6) {
                        setModalState(() => formError = 'Le mot de passe doit contenir au moins 6 caractères.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createAdminUser(
                          email: email,
                          password: passwordController.text.trim(),
                          firstName: firstName,
                          lastName: lastName,
                          role: selectedRole,
                        );
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
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
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
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
