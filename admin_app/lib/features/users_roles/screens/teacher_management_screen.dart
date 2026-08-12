import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  final List<Map<String, dynamic>> _teachers = [
    {
      'id': 'teach-001',
      'name': 'M. Alain Atangana',
      'email': 'a.atangana@education.cm',
      'phone': '+237 677 11 22 33',
      'establishments': [
        'Lycée Général Leclerc (Yaoundé)',
        'Lycée de Nkolmesseng',
      ],
      'subjects': ['Mathématiques (3e, Tle C)'],
      'status': 'Actif',
    },
    {
      'id': 'teach-002',
      'name': 'Mme. Carine Ngo Ndjo',
      'email': 'c.ngo@education.cm',
      'phone': '+237 699 44 55 66',
      'establishments': ['Collège Vogt (Yaoundé)'],
      'subjects': ['Physique-Chimie (1ère, Tle)'],
      'status': 'En attente d\'approbation',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    'Gestion des Enseignants & Rattachements Multi-Établissements',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un compte enseignant peut être rattaché à plusieurs établissements simultanément sans recréer de compte',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTeacherModal(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Valider un Nouveau Enseignant'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _teachers.length,
              itemBuilder: (context, idx) {
                final teacher = _teachers[idx];
                final isPending =
                    teacher['status'] == 'En attente d\'approbation';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPending
                          ? AppTheme.accentAmber
                          : AppTheme.primaryBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.accentBlue.withValues(
                          alpha: 0.15,
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: AppTheme.accentBlue,
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
                                    teacher['name'],
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? AppTheme.accentAmber.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppTheme.accentEmerald.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    teacher['status'],
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? AppTheme.accentAmber
                                          : AppTheme.accentEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${teacher['email']} • ${teacher['phone']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ...((teacher['establishments'] as List).map(
                                  (e) => Chip(
                                    avatar: const Icon(
                                      Icons.domain_rounded,
                                      size: 14,
                                      color: AppTheme.accentCyan,
                                    ),
                                    backgroundColor: AppTheme.primaryDark,
                                    label: Text(
                                      e,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppTheme.primaryBorder,
                              ),
                            ),
                            onPressed: () => _showRattachementModal(
                              context,
                              teacher['name'],
                            ),
                            icon: const Icon(
                              Icons.add_location_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('Rattacher un Établissement'),
                          ),
                          if (isPending) ...[
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentEmerald,
                              ),
                              onPressed: () {
                                setState(() => teacher['status'] = 'Actif');
                              },
                              child: const Text('Approuver la Demande'),
                            ),
                          ],
                        ],
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

  void _showAddTeacherModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Nouveau Compte Enseignant',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nom et Prénom'),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Email institutionnel',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Téléphone'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Créer l\'Enseignant'),
          ),
        ],
      ),
    );
  }

  void _showRattachementModal(BuildContext context, String teacherName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Rattacher un Établissement à $teacherName',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Sélectionner l\'établissement',
                ),
                items: ['Lycée Bilingue d\'Yaoundé', 'Collège de la Retraite']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Matières enseignées dans cet établissement',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Ajouter le Rattachement'),
          ),
        ],
      ),
    );
  }
}
