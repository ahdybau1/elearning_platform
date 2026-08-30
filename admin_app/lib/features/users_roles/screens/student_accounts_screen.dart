import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class StudentAccountsScreen extends ConsumerStatefulWidget {
  const StudentAccountsScreen({super.key});

  @override
  ConsumerState<StudentAccountsScreen> createState() => _StudentAccountsScreenState();
}

class _StudentAccountsScreenState extends ConsumerState<StudentAccountsScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider(_search.isEmpty ? null : _search));

    return Padding(
      padding: const EdgeInsets.all(16),
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
                      'Gestion des Comptes & Profils Élèves',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Modèle 1 Compte = Plusieurs Profils (1 classe = 1 abonnement = 1 progression)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: () => _showCreateAccountModal(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Créer un Compte Élève'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onSubmitted: (val) => setState(() => _search = val.trim()),
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, prénom ou email...',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _search = '';
                      }),
                    ),
              filled: true,
              fillColor: AppTheme.primarySurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryBorder),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun compte élève pour le moment — l\'application élève n\'a pas encore '
                      'été lancée.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppTheme.primaryDark),
                        columns: [
                          DataColumn(
                            label: Text('Élève (Identité)',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          DataColumn(
                            label: Text('Contact',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          DataColumn(
                            label: Text('Créé le',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          DataColumn(
                            label: Text('Actions',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                        rows: accounts.map((account) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${account.firstName} ${account.lastName}',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text(account.email,
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              DataCell(Text(account.phone ?? '—',
                                  style: GoogleFonts.inter(color: Colors.white70))),
                              DataCell(Text(
                                account.createdAt.toLocal().toString().split(' ').first,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentBlue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Modifier le compte',
                                      onPressed: () => _showEditAccountModal(context, account),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.badge_rounded, size: 18, color: AppTheme.accentBlue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Voir les Profils du compte',
                                      onPressed: () => _showProfilesDialog(context, account),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.phonelink_erase_rounded,
                                          size: 18, color: AppTheme.accentAmber),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Gérer les sessions (déconnexion forcée)',
                                      onPressed: () => _showSessionsDialog(context, account),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAccountModal(BuildContext context, Account account) {
    final firstNameCtrl = TextEditingController(text: account.firstName);
    final lastNameCtrl = TextEditingController(text: account.lastName);
    final phoneCtrl = TextEditingController(text: account.phone ?? '');
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
            text: 'Modifier le Compte',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email (non modifiable) : ${account.email}',
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
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
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
                        await service.updateAccount(
                          account.id,
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        );
                        ref.invalidate(accountsProvider(_search.isEmpty ? null : _search));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilesDialog(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.badge_rounded,
          text: 'Profils de ${account.firstName} ${account.lastName}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 440,
          height: MediaQuery.of(context).size.height * 0.5,
          child: Consumer(
            builder: (context, ref, _) {
              final profilesAsync = ref.watch(profilesForAccountProvider(account.id));
              return profilesAsync.when(
                data: (profiles) {
                  final allActive = profiles.isNotEmpty && profiles.every((p) => p.status == 'actif');
                  final allArchived = profiles.isNotEmpty && profiles.every((p) => p.status == 'archive');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (allActive || allArchived) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final service = ref.read(supabaseServiceProvider);
                                if (allActive) {
                                  await service.suspendAccount(account.id);
                                } else {
                                  await service.unsuspendAccount(account.id);
                                }
                                ref.invalidate(profilesForAccountProvider(account.id));
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.accentEmerald,
                                    content: Text(allActive
                                        ? 'Tous les profils ont été archivés.'
                                        : 'Tous les profils ont été désarchivés.'),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                                );
                              }
                            },
                            icon: Icon(allActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                                size: 16, color: AppTheme.accentAmber),
                            label: Text(
                              allActive ? 'Archiver tous les profils' : 'Désarchiver tous les profils',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber),
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: profiles.isEmpty
                            ? Center(
                                child: Text('Aucun profil — utilisez "Ajouter un profil" ci-dessous.',
                                    style: GoogleFonts.inter(color: AppTheme.textMuted)),
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: profiles
                                    .map((p) => _buildProfileTile(context, ref, account, p))
                                    .toList(),
                              ),
                      ),
                      const Divider(color: AppTheme.primaryBorder),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddProfileDialog(context, account),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter un profil (ré-inscription)'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
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

  Widget _buildProfileTile(BuildContext context, WidgetRef ref, Account account, StudentProfile p) {
    final isActive = p.status == 'actif';
    return ListTile(
      dense: true,
      leading: Icon(
        isActive ? Icons.check_circle_rounded : Icons.archive_rounded,
        color: isActive ? AppTheme.accentEmerald : Colors.white38,
      ),
      title: Text('Année ${p.schoolYear}', style: GoogleFonts.inter(color: Colors.white)),
      subtitle: Text('Palier: ${p.subscriptionTier} · ${p.status}',
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(
          isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
          size: 18,
          color: AppTheme.accentAmber,
        ),
        tooltip: isActive ? 'Archiver ce profil' : 'Désarchiver ce profil',
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final service = ref.read(supabaseServiceProvider);
            await service.setProfileStatus(p.id, isActive ? 'archive' : 'actif');
            ref.invalidate(profilesForAccountProvider(account.id));
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.accentEmerald,
                content: Text(isActive ? 'Profil archivé.' : 'Profil désarchivé.'),
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
            );
          }
        },
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, Account account) {
    final schoolYearCtrl = TextEditingController(text: '2026-2027');
    String? selectedClassId;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.add_rounded,
            text: 'Ajouter un Profil',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final classesAsync = ref.watch(nodesByTypeProvider('class'));
                    return classesAsync.when(
                      data: (classes) {
                        selectedClassId ??= classes.isNotEmpty ? classes.first.id : null;
                        return DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: selectedClassId,
                          dropdownColor: AppTheme.primaryDark,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Classe'),
                          items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setModalState(() => selectedClassId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) =>
                          Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schoolYearCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Année scolaire (ex: 2026-2027)'),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedClassId == null) {
                        setModalState(() => formError = 'Sélectionnez une classe.');
                        return;
                      }
                      if (schoolYearCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'L\'année scolaire est obligatoire.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.addProfileToAccount(
                          accountId: account.id,
                          classNodeId: selectedClassId!,
                          schoolYear: schoolYearCtrl.text.trim(),
                        );
                        ref.invalidate(profilesForAccountProvider(account.id));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionsDialog(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.phonelink_erase_rounded,
            iconColor: AppTheme.accentAmber,
            text: 'Sessions de ${account.firstName} ${account.lastName}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Consumer(
              builder: (context, ref, _) {
                final sessionsAsync = ref.watch(sessionsForAccountProvider(account.id));
                return sessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Text('Aucune session enregistrée.',
                          style: GoogleFonts.inter(color: AppTheme.textMuted));
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: sessions.map((s) {
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            s.isActive ? Icons.smartphone_rounded : Icons.phonelink_off_rounded,
                            color: s.isActive ? AppTheme.accentEmerald : Colors.white38,
                          ),
                          title: Text(s.platform, style: GoogleFonts.inter(color: Colors.white)),
                          subtitle: Text(
                            'Dernière activité : ${s.lastActiveAt.toLocal().toString().split('.').first}',
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          trailing: s.isActive
                              ? TextButton(
                                  onPressed: () async {
                                    final service = ref.read(supabaseServiceProvider);
                                    await service.revokeSession(s.id);
                                    ref.invalidate(sessionsForAccountProvider(account.id));
                                  },
                                  child: Text('Déconnecter',
                                      style: GoogleFonts.inter(color: AppTheme.accentRose)),
                                )
                              : null,
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
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
      ),
    );
  }

  void _showCreateAccountModal(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final schoolYearCtrl = TextEditingController(text: '2026-2027');
    String? selectedClassId;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.person_add_rounded,
            text: 'Créer un Compte Élève',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Mot de passe initial', helperText: 'Au moins 6 caractères'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(nodesByTypeProvider('class'));
                      return classesAsync.when(
                        data: (classes) {
                          selectedClassId ??= classes.isNotEmpty ? classes.first.id : null;
                          return DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: selectedClassId,
                            dropdownColor: AppTheme.primaryDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Classe'),
                            items: classes
                                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: (v) => setModalState(() => selectedClassId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err',
                            style: GoogleFonts.inter(color: AppTheme.accentRose)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: schoolYearCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Année scolaire (ex: 2026-2027)'),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(formError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le prénom et le nom sont obligatoires.');
                        return;
                      }
                      if (emailCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'L\'email est obligatoire.');
                        return;
                      }
                      if (passwordCtrl.text.trim().length < 6) {
                        setModalState(() => formError = 'Le mot de passe doit contenir au moins 6 caractères.');
                        return;
                      }
                      if (selectedClassId == null) {
                        setModalState(() => formError = 'Sélectionnez une classe.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createStudentAccount(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          classNodeId: selectedClassId!,
                          schoolYear: schoolYearCtrl.text.trim(),
                        );
                        ref.invalidate(accountsProvider(_search.isEmpty ? null : _search));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                'Compte créé pour ${firstNameCtrl.text} ${lastNameCtrl.text}.',
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Créer le compte'),
            ),
          ],
        ),
      ),
    );
  }
}
