import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class ParentAccountsScreen extends ConsumerStatefulWidget {
  const ParentAccountsScreen({super.key});

  @override
  ConsumerState<ParentAccountsScreen> createState() => _ParentAccountsScreenState();
}

class _ParentAccountsScreenState extends ConsumerState<ParentAccountsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentAccountsProvider(_search.isEmpty ? null : _search));

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
                      'Gestion des Comptes Parents',
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compte distinct lié à un ou plusieurs profils élèves (Payeur principal & Suivi académique)',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showCreateParentModal(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text('Créer un Compte Parent', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) => setState(() => _search = val.trim()),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un parent par nom, email ou téléphone...',
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
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: parentsAsync.when(
              data: (parents) {
                if (parents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.family_restroom_rounded, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text('Aucun compte parent trouvé', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textMuted)),
                      ],
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: ListView.separated(
                    itemCount: parents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) => _buildParentCard(parents[idx]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard(ParentAccount parent) {
    return Opacity(
      opacity: parent.isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: parent.isActive ? AppTheme.primaryBorder : AppTheme.accentAmber),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.15),
              child: const Icon(Icons.person_outline_rounded, color: AppTheme.accentBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('${parent.firstName} ${parent.lastName}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      if (!parent.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Archivé',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${parent.email} • ${parent.phone} • Inscrit le ${parent.createdAt.toLocal().toString().split(' ').first}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final profilesAsync = ref.watch(profilesForParentProvider(parent.id));
                      return profilesAsync.when(
                        data: (profiles) {
                          if (profiles.isEmpty) {
                            return Text('Aucun élève rattaché.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted));
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: profiles.map((p) {
                              return Container(
                                padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Profil ${p.schoolYear} (${p.status})',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentBlue, fontWeight: FontWeight.w600),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accentBlue),
                                      tooltip: 'Délier cet élève',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onPressed: () => _showUnlinkConfirmation(context, parent, p),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentRose)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 2,
              children: [
                IconButton(
                  onPressed: () => _showEditParentModal(context, parent),
                  icon: const Icon(Icons.edit_rounded, color: AppTheme.accentBlue, size: 20),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  onPressed: () => _showLinkStudentModal(context, parent),
                  icon: const Icon(Icons.add_link_rounded, color: AppTheme.accentCyan, size: 20),
                  tooltip: 'Rattacher un élève (par email du compte élève)',
                ),
                IconButton(
                  onPressed: () => parent.isActive
                      ? _showArchiveConfirmation(context, parent)
                      : _toggleActive(parent, true),
                  icon: Icon(
                    parent.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                    color: AppTheme.accentAmber,
                    size: 20,
                  ),
                  tooltip: parent.isActive ? 'Archiver' : 'Désarchiver',
                ),
                if (!parent.isActive)
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context, parent),
                    icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRose, size: 20),
                    tooltip: 'Supprimer définitivement',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(ParentAccount parent, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateParentAccount(parent.id, isActive: isActive);
      ref.invalidate(parentAccountsProvider(_search.isEmpty ? null : _search));
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Compte parent désarchivé.' : 'Compte parent archivé.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
      );
    }
  }

  void _showUnlinkConfirmation(BuildContext context, ParentAccount parent, StudentProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.link_off_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Délier cet élève ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          '${parent.firstName} ${parent.lastName} n\'aura plus accès à la progression ni aux paiements du '
          'profil ${profile.schoolYear}. Le compte et le profil de l\'élève ne sont pas affectés — seul le '
          'lien parent ↔ élève est retiré.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await service.unlinkParentFromProfile(parentAccountId: parent.id, profileId: profile.id);
                ref.invalidate(profilesForParentProvider(parent.id));
                messenger.showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Élève délié.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Délier'),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, ParentAccount parent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver "${parent.firstName} ${parent.lastName}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'Le compte ne sera plus utilisable pour se connecter côté famille, mais rien n\'est supprimé — '
          'vous pourrez le désarchiver ou le supprimer définitivement plus tard. Les liens avec les élèves '
          'sont conservés.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(parent, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ParentAccount parent) {
    final confirmController = TextEditingController();
    final fullName = '${parent.firstName} ${parent.lastName}';
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
                    'IRRÉVERSIBLE : le compte parent et tous ses liens avec des élèves seront définitivement '
                    'supprimés. Les comptes et profils élèves eux-mêmes ne sont pas affectés.',
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
                        await service.deleteParentAccount(parent.id);
                        ref.invalidate(parentAccountsProvider(_search.isEmpty ? null : _search));
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditParentModal(BuildContext context, ParentAccount parent) {
    final firstNameCtrl = TextEditingController(text: parent.firstName);
    final lastNameCtrl = TextEditingController(text: parent.lastName);
    final phoneCtrl = TextEditingController(text: parent.phone);
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
            text: 'Modifier le Compte Parent',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email (non modifiable) : ${parent.email}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 14),
                TextField(
                  controller: firstNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
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
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le prénom et le nom sont obligatoires.');
                        return;
                      }
                      if (phoneCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le téléphone est obligatoire.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateParentAccount(
                          parent.id,
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        ref.invalidate(parentAccountsProvider(_search.isEmpty ? null : _search));
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

  void _showLinkStudentModal(BuildContext context, ParentAccount parent) {
    final emailCtrl = TextEditingController();
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.add_link_rounded,
            iconColor: AppTheme.accentCyan,
            text: 'Rattacher un élève à ${parent.firstName} ${parent.lastName}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email du compte élève déjà existant'),
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
                      if (emailCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'L\'email de l\'élève est obligatoire.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.linkParentToStudentByEmail(
                          parentAccountId: parent.id,
                          studentEmail: emailCtrl.text.trim(),
                        );
                        ref.invalidate(profilesForParentProvider(parent.id));
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
                  : const Text('Rattacher'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateParentModal(BuildContext context) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.person_add_rounded,
            text: 'Créer un Compte Parent',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Adresse Email', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Téléphone (+237...)', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Mot de passe initial', prefixIcon: Icon(Icons.lock), helperText: 'Au moins 6 caractères'),
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
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
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
                      if (phoneCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'Le téléphone est obligatoire.');
                        return;
                      }
                      if (passwordCtrl.text.trim().length < 6) {
                        setModalState(() => formError = 'Le mot de passe doit contenir au moins 6 caractères.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createParentAccount(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        ref.invalidate(parentAccountsProvider(_search.isEmpty ? null : _search));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compte parent créé avec succès !')),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer et Lier'),
            ),
          ],
        ),
      ),
    );
  }
}
