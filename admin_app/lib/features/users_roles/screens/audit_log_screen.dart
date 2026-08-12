import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final List<Map<String, dynamic>> _logs = [
    {
      'id': 'log-9901',
      'admin': 'Mme. Béatrice Eboko (Admin Pays)',
      'action': 'UPDATE',
      'entity': 'subscription_tiers',
      'entityId': 'tier-3e-mensuel',
      'details':
          'Modification du prix du palier Mensuel de 2,000 FCFA à 2,500 FCFA',
      'time': '10/10/2026 à 15:45',
      'before': '{"price": 2000}',
      'after': '{"price": 2500}',
    },
    {
      'id': 'log-9902',
      'admin': 'M. Marc Nguema (Admin Contenu)',
      'action': 'PUBLISH',
      'entity': 'lessons',
      'entityId': 'les-001',
      'details': 'Publication de la Leçon 1 : PGCD et nombres premiers',
      'time': '10/10/2026 à 14:22',
      'before': '{"status": "en_attente"}',
      'after': '{"status": "publie"}',
    },
    {
      'id': 'log-9903',
      'admin': 'Super Administrateur HQ',
      'action': 'RECONCILE',
      'entity': 'transactions',
      'entityId': 'tx-88213',
      'details':
          'Réconciliation manuelle de la transaction Mobile Money MTN MoMo',
      'time': '09/10/2026 à 11:10',
      'before': '{"status": "ambiguous"}',
      'after': '{"status": "success"}',
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
                    'Journal d\'Audit & Traçabilité Système',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Historique inaltérable de toutes les modifications, publications, réconciliations et suppressions',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Exporter l\'Audit Log (CSV/JSON)'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Log List Table
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
                        'Horodatage',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Administrateur',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Action',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Table / Entité',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Détails du changement',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Diff JSON',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  rows: _logs.map((log) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            log['time'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            log['admin'],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        DataCell(_buildActionBadge(log['action'])),
                        DataCell(
                          Text(
                            log['entity'],
                            style: GoogleFonts.inter(
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            log['details'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.code_rounded,
                              size: 18,
                              color: AppTheme.accentBlue,
                            ),
                            onPressed: () => _showJsonDiffModal(context, log),
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

  Widget _buildActionBadge(String action) {
    Color bg;
    Color fg;
    if (action == 'CREATE') {
      bg = AppTheme.accentEmerald.withValues(alpha: 0.15);
      fg = AppTheme.accentEmerald;
    } else if (action == 'UPDATE' || action == 'PUBLISH') {
      bg = AppTheme.accentBlue.withValues(alpha: 0.15);
      fg = AppTheme.accentBlue;
    } else if (action == 'RECONCILE') {
      bg = AppTheme.accentIndigo.withValues(alpha: 0.15);
      fg = AppTheme.accentIndigo;
    } else {
      bg = AppTheme.accentRose.withValues(alpha: 0.15);
      fg = AppTheme.accentRose;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showJsonDiffModal(BuildContext context, Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Diff JSON pour l\'action ${log['id']}',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avant (Before) :',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentRose,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.primaryDark,
                child: Text(
                  log['before'],
                  style: GoogleFonts.robotoMono(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Après (After) :',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentEmerald,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.primaryDark,
                child: Text(
                  log['after'],
                  style: GoogleFonts.robotoMono(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
