import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class WhatsappGroupsScreen extends StatefulWidget {
  const WhatsappGroupsScreen({super.key});

  @override
  State<WhatsappGroupsScreen> createState() => _WhatsappGroupsScreenState();
}

class _WhatsappGroupsScreenState extends State<WhatsappGroupsScreen> {
  String _selectedStatusFilter = 'Tous';

  final List<Map<String, dynamic>> _groups = [
    {
      'id': 'grp_1',
      'class': 'Classe de 3ème (Général)',
      'inviteLink': 'https://chat.whatsapp.com/Km89Xz901AB',
      'membersCount': 850,
      'maxMembers': 1024,
      'status': 'Actif',
    },
    {
      'id': 'grp_2',
      'class': 'Classe de Terminale C (Maths & Physiques)',
      'inviteLink': 'https://chat.whatsapp.com/TleC2026TleC',
      'membersCount': 1024,
      'maxMembers': 1024,
      'status': 'Complet',
    },
    {
      'id': 'grp_3',
      'class': 'Classe de 1ère D (Sciences)',
      'inviteLink': 'https://chat.whatsapp.com/1ereD2026Sci',
      'membersCount': 640,
      'maxMembers': 1024,
      'status': 'Actif',
    },
    {
      'id': 'grp_4',
      'class': 'Préparation BEPC (Entraînement Intensif)',
      'inviteLink': 'https://chat.whatsapp.com/BEPCPrep2027',
      'membersCount': 310,
      'maxMembers': 1024,
      'status': 'Maintenance',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _groups.where((grp) {
      if (_selectedStatusFilter == 'Tous') return true;
      return grp['status'] == _selectedStatusFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Communautés d\'Étude WhatsApp Officielles',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestion des liens d\'invitation des groupes WhatsApp officiels par classe (Cloisonnement strict)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showGroupModal(context),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(
                  'Ajouter un Groupe WhatsApp',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Filtrer par Statut : ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: ['Tous', 'Actif', 'Complet', 'Maintenance']
                      .map((st) {
                    final isSel = _selectedStatusFilter == st;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(st),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : AppTheme.textMuted,
                      ),
                      selectedColor: AppTheme.accentEmerald,
                      backgroundColor: AppTheme.primaryDark,
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = st),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Groups List
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Text(
                      'Aucun groupe WhatsApp avec ce statut.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, idx) {
                      final grp = filteredGroups[idx];
                      final status = grp['status'] as String;

                      Color statusBg = status == 'Actif'
                          ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                          : status == 'Complet'
                              ? AppTheme.accentRose.withValues(alpha: 0.15)
                              : AppTheme.accentAmber.withValues(alpha: 0.15);

                      Color statusFg = status == 'Actif'
                          ? AppTheme.accentEmerald
                          : status == 'Complet'
                              ? AppTheme.accentRose
                              : AppTheme.accentAmber;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  AppTheme.accentEmerald.withValues(alpha: 0.15),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppTheme.accentEmerald,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        grp['class'],
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusFg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lien d\'invitation : ${grp['inviteLink']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Membres actuels : ${grp['membersCount']} / ${grp['maxMembers']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentCyan,
                                side: BorderSide(
                                    color: AppTheme.accentCyan
                                        .withValues(alpha: 0.5)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Lien copié : ${grp['inviteLink']}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copier Lien'),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  _showGroupModal(context, group: grp),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showGroupModal(BuildContext context, {Map<String, dynamic>? group}) {
    final nameCtrl = TextEditingController(text: group?['class'] ?? '');
    final linkCtrl = TextEditingController(text: group?['inviteLink'] ?? '');
    final countCtrl =
        TextEditingController(text: group?['membersCount']?.toString() ?? '100');
    String selectedStatus = group?['status'] ?? 'Actif';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.groups_rounded,
          text: group == null
              ? 'Ajouter un Groupe WhatsApp'
              : 'Éditer ${group['class']}',
          onClose: () => Navigator.pop(context),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nom du Groupe (ex: Classe de 3ème Général)',
                  prefixIcon: Icon(Icons.groups),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Lien d\'invitation WhatsApp (https://chat...)',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Membres',
                        prefixIcon: Icon(Icons.people),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      dropdownColor: AppTheme.primarySurface,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: ['Actif', 'Complet', 'Maintenance']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) selectedStatus = val;
                      },
                    ),
                  ),
                ],
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && linkCtrl.text.isNotEmpty) {
                setState(() {
                  if (group == null) {
                    _groups.add({
                      'id': 'grp_${DateTime.now().millisecondsSinceEpoch}',
                      'class': nameCtrl.text,
                      'inviteLink': linkCtrl.text,
                      'membersCount': int.tryParse(countCtrl.text) ?? 0,
                      'maxMembers': 1024,
                      'status': selectedStatus,
                    });
                  } else {
                    group['class'] = nameCtrl.text;
                    group['inviteLink'] = linkCtrl.text;
                    group['membersCount'] = int.tryParse(countCtrl.text) ?? 0;
                    group['status'] = selectedStatus;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(group == null
                        ? 'Nouveau groupe WhatsApp enregistré !'
                        : 'Groupe mis à jour.'),
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
