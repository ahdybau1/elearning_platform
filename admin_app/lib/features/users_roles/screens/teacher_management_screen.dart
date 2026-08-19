import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends ConsumerState<TeacherManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Gestion des Enseignants & Rattachements Multi-Établissements',
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Un compte enseignant peut être rattaché à plusieurs établissements simultanément sans recréer de compte',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: () => _showCreateTeacherModal(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Créer un Enseignant'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou email...',
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
            child: adminsAsync.when(
              data: (admins) {
                final teachers = admins.where((a) {
                  if (a.role != 'enseignant') return false;
                  if (_search.isEmpty) return true;
                  final haystack = '${a.firstName} ${a.lastName} ${a.email}'.toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                if (teachers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_rounded, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text('Aucun enseignant trouvé', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textMuted)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: teachers.length,
                  itemBuilder: (context, idx) => _buildTeacherCard(teachers[idx]),
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

  Widget _buildTeacherCard(AdminUser teacher) {
    final isPending = !teacher.isActive;
    return Opacity(
      opacity: teacher.isActive ? 1.0 : 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPending ? AppTheme.accentAmber : AppTheme.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.15),
                  child: const Icon(Icons.badge_rounded, color: AppTheme.accentBlue),
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
                              '${teacher.firstName} ${teacher.lastName}',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                  : AppTheme.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPending ? 'En attente / Inactif' : 'Actif',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPending ? AppTheme.accentAmber : AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(teacher.email, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      onPressed: () => _showEditTeacherModal(context, teacher),
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.accentBlue, size: 20),
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      onPressed: () => teacher.isActive
                          ? _showArchiveConfirmation(context, teacher)
                          : _toggleActive(teacher, true),
                      icon: Icon(
                        teacher.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                        color: AppTheme.accentAmber,
                        size: 20,
                      ),
                      tooltip: teacher.isActive ? 'Archiver' : 'Approuver / Désarchiver',
                    ),
                    if (!teacher.isActive)
                      IconButton(
                        onPressed: () => _showDeleteConfirmation(context, teacher),
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRose, size: 20),
                        tooltip: 'Supprimer définitivement',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.primaryBorder, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Périmètre général (hors établissement)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      _buildGeneralScopeRow(context, teacher),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                  onPressed: () => _showEditGeneralScopeModal(context, teacher),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Périmètre'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.primaryBorder, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final linksAsync = ref.watch(teacherEstablishmentsProvider(teacher.id));
                      return linksAsync.when(
                        data: (links) {
                          if (links.isEmpty) {
                            return Text(
                              'Aucun établissement rattaché — normal pour un enseignant qui contribue au '
                              'contenu général sans être lié à un établissement précis.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: links.map((l) {
                              final scopeLabel = [
                                if (l.subjectsScope.isNotEmpty) l.subjectsScope.join(', '),
                                if (l.classesScope.isNotEmpty) l.classesScope.join(', '),
                              ].join(' • ');
                              return Tooltip(
                                message: scopeLabel.isEmpty ? 'Périmètre non précisé' : scopeLabel,
                                child: Container(
                                  padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.domain_rounded, size: 14, color: AppTheme.accentCyan),
                                      const SizedBox(width: 6),
                                      Text('${l.establishmentName} (${l.establishmentCity})',
                                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accentCyan),
                                        tooltip: 'Retirer ce rattachement',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => _showDetachConfirmation(context, teacher, l),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) =>
                            Text('Erreur: $err', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentRose)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                  onPressed: () => _showAttachEstablishmentModal(context, teacher),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('Rattacher un Établissement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralScopeRow(BuildContext context, AdminUser teacher) {
    final subjects = (teacher.scopeJson['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final classes = (teacher.scopeJson['classes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (subjects.isEmpty && classes.isEmpty) {
      return Text(
        'Aucun — cet enseignant ne contribue qu\'au contenu d\'un ou plusieurs établissements rattachés '
        'ci-dessous.',
        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (subjects.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.35)),
            ),
            child: Text('Matières : ${subjects.join(', ')}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.w600)),
          ),
        if (classes.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.35)),
            ),
            child: Text('Classes : ${classes.join(', ')}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  void _showEditGeneralScopeModal(BuildContext context, AdminUser teacher) {
    final subjects = (teacher.scopeJson['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final classes = (teacher.scopeJson['classes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final subjectsCtrl = TextEditingController(text: subjects.join(', '));
    final classesCtrl = TextEditingController(text: classes.join(', '));
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.tune_rounded,
            text: 'Périmètre Général de ${teacher.firstName} ${teacher.lastName}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pour un enseignant qui contribue au contenu pédagogique (leçons, exercices) sans être '
                  'rattaché à un établissement précis — ce périmètre est totalement indépendant des '
                  'rattachements ci-dessous.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectsCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Matières (séparées par des virgules)',
                    hintText: 'ex : Mathématiques, Physique-Chimie',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Classes (séparées par des virgules)',
                    hintText: 'ex : 3e, Tle C',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        final newScope = Map<String, dynamic>.from(teacher.scopeJson);
                        newScope['subjects'] = subjectsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        newScope['classes'] = classesCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        await service.updateAdminUser(teacher.id, scopeJson: newScope);
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        messenger.showSnackBar(
                          SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                        );
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

  Future<void> _toggleActive(AdminUser teacher, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateAdminUser(teacher.id, isActive: isActive);
      ref.invalidate(adminUsersProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(isActive ? 'Enseignant activé.' : 'Enseignant archivé.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
  }

  void _showArchiveConfirmation(BuildContext context, AdminUser teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.archive_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Archiver "${teacher.firstName} ${teacher.lastName}" ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'L\'enseignant ne pourra plus publier ni se connecter à l\'espace administration, mais rien '
          'n\'est supprimé — vous pourrez le désarchiver ou le supprimer définitivement plus tard. Ses '
          'rattachements aux établissements sont conservés.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleActive(teacher, false);
            },
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AdminUser teacher) {
    final confirmController = TextEditingController();
    final fullName = '${teacher.firstName} ${teacher.lastName}';
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
                    'IRRÉVERSIBLE : le compte enseignant et tous ses rattachements aux établissements '
                    'seront définitivement supprimés. Le contenu déjà publié par cet enseignant n\'est pas '
                    'supprimé, mais n\'a plus d\'auteur rattaché.',
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
                        await service.deleteAdminUser(teacher.id);
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Enseignant "$fullName" supprimé définitivement.'),
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

  void _showEditTeacherModal(BuildContext context, AdminUser teacher) {
    final firstNameCtrl = TextEditingController(text: teacher.firstName);
    final lastNameCtrl = TextEditingController(text: teacher.lastName);
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
            text: 'Modifier l\'Enseignant',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email (non modifiable) : ${teacher.email}',
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
                          teacher.id,
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
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

  void _showDetachConfirmation(BuildContext context, AdminUser teacher, TeacherEstablishmentLink link) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.link_off_rounded,
          iconColor: AppTheme.accentAmber,
          text: 'Retirer ce rattachement ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          '${teacher.firstName} ${teacher.lastName} ne pourra plus publier de contenu sous le label de '
          '${link.establishmentName}.',
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
                await service.detachTeacherFromEstablishment(
                  teacherId: teacher.id,
                  establishmentId: link.establishmentId,
                );
                ref.invalidate(teacherEstablishmentsProvider(teacher.id));
                messenger.showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Rattachement retiré.')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
              }
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  void _showAttachEstablishmentModal(BuildContext context, AdminUser teacher) {
    String? selectedEstablishmentId;
    final subjectsCtrl = TextEditingController();
    final classesCtrl = TextEditingController();
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.add_location_alt_rounded,
            text: 'Rattacher un Établissement à ${teacher.firstName} ${teacher.lastName}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final establishmentsAsync = ref.watch(establishmentsProvider);
                    return establishmentsAsync.when(
                      data: (establishments) {
                        if (establishments.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Aucun établissement pour le pays sélectionné dans la barre de navigation. '
                              'Créez-en un depuis la page "Épreuves Établissements" avant de rattacher un '
                              'enseignant.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber, height: 1.4),
                            ),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: selectedEstablishmentId,
                          dropdownColor: AppTheme.primaryDark,
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Établissement'),
                          items: establishments
                              .map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.city})')))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedEstablishmentId = v),
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
                  controller: subjectsCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Matières enseignées (séparées par des virgules)',
                    hintText: 'ex : Mathématiques, Physique-Chimie',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Classes concernées (séparées par des virgules)',
                    hintText: 'ex : 3e, Tle C',
                  ),
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
                      if (selectedEstablishmentId == null) {
                        setModalState(() => formError = 'Sélectionnez un établissement.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.attachTeacherToEstablishment(
                          teacherId: teacher.id,
                          establishmentId: selectedEstablishmentId!,
                          subjectsScope: subjectsCtrl.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList(),
                          classesScope: classesCtrl.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList(),
                        );
                        ref.invalidate(teacherEstablishmentsProvider(teacher.id));
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
                  : const Text('Ajouter le Rattachement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTeacherModal(BuildContext context) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool createActive = true;
    String? formError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.person_add_rounded,
            text: 'Nouveau Compte Enseignant',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  autofocus: true,
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
                  decoration: const InputDecoration(labelText: 'Email institutionnel'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Mot de passe initial', helperText: 'Au moins 6 caractères'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: createActive,
                  onChanged: (v) => setModalState(() => createActive = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.accentBlue,
                  title: Text('Activer immédiatement', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                  subtitle: Text(
                    'Décochez si la demande doit d\'abord être examinée (elle apparaîtra "En attente / Inactif").',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 10),
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
                      if (emailCtrl.text.trim().isEmpty) {
                        setModalState(() => formError = 'L\'email est obligatoire.');
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
                        await service.createTeacherAccount(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          isActive: createActive,
                        );
                        ref.invalidate(adminUsersProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compte enseignant créé.')),
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
                  : const Text('Créer l\'Enseignant'),
            ),
          ],
        ),
      ),
    );
  }
}
