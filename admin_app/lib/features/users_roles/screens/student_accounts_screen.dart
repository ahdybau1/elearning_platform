import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class StudentAccountsScreen extends StatefulWidget {
  const StudentAccountsScreen({super.key});

  @override
  State<StudentAccountsScreen> createState() => _StudentAccountsScreenState();
}

class _StudentAccountsScreenState extends State<StudentAccountsScreen> {
  final List<Map<String, dynamic>> _students = [
    {
      'id': 'acc-001',
      'name': 'Junior Atangana',
      'email': 'junior.atangana@gmail.com',
      'phone': '+237 670 12 34 56',
      'activeClass': 'Classe de 3ème (Général)',
      'tier': 'Mensuel',
      'status': 'Actif',
      'sessions': '1 session active (Android)',
    },
    {
      'id': 'acc-002',
      'name': 'Marie Ngo Ndjo',
      'email': 'marie.ngo@yahoo.fr',
      'phone': '+237 699 88 77 66',
      'activeClass': 'Classe de Terminale C',
      'tier': 'Annuel',
      'status': 'Actif',
      'sessions': '1 session active (Web PWA)',
    },
    {
      'id': 'acc-003',
      'name': 'Paul Ebele',
      'email': 'paul.ebele@hotmail.com',
      'phone': '+237 655 44 33 22',
      'activeClass': 'Classe de 2nde',
      'tier': 'Gratuit',
      'status': 'Archivé',
      'sessions': '0 session active',
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
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Créer un Compte Élève'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Students Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppTheme.primaryDark,
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Élève (Identité)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Contact',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Classe Active',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Palier',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Session Unique',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  rows: _students.map((student) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'],
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                student['email'],
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            student['phone'],
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                        ),
                        DataCell(
                          Text(
                            student['activeClass'],
                            style: GoogleFonts.inter(
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student['tier'],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            student['sessions'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.badge_rounded,
                                  size: 18,
                                  color: AppTheme.accentBlue,
                                ),
                                tooltip: 'Voir les Profils du compte',
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.phonelink_erase_rounded,
                                  size: 18,
                                  color: AppTheme.accentAmber,
                                ),
                                tooltip: 'Forcer la Déconnexion (Session)',
                                onPressed: () {},
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
          ),
        ],
      ),
    );
  }
}
