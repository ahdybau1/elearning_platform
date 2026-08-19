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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
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
                Text('${parent.firstName} ${parent.lastName}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Profil ${p.schoolYear} (${p.status})',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentBlue, fontWeight: FontWeight.w600),
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
          IconButton(
            onPressed: () => _showLinkStudentModal(context, parent),
            icon: const Icon(Icons.add_link_rounded, color: AppTheme.accentCyan),
            tooltip: 'Rattacher un élève (par email du compte élève)',
          ),
        ],
      ),
    );
  }

  void _showLinkStudentModal(BuildContext context, ParentAccount parent) {
    final emailCtrl = TextEditingController();
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
          content: TextField(
            controller: emailCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Email du compte élève déjà existant'),
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
                      if (emailCtrl.text.trim().isEmpty) return;
                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.linkParentToStudentByEmail(
                          parentAccountId: parent.id,
                          studentEmail: emailCtrl.text.trim(),
                        );
                        ref.invalidate(profilesForParentProvider(parent.id));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur: $e')),
                          );
                        }
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
                  decoration: const InputDecoration(labelText: 'Mot de passe initial', prefixIcon: Icon(Icons.lock)),
                ),
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
                      if (firstNameCtrl.text.trim().isEmpty ||
                          lastNameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty ||
                          passwordCtrl.text.trim().isEmpty) {
                        return;
                      }
                      setModalState(() => isLoading = true);
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
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur: $e')),
                          );
                        }
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
