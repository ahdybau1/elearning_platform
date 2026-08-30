import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

const String _allFilter = '__all__';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _adminFilter = _allFilter;
  String _actionFilter = _allFilter;
  String _entityFilter = _allFilter;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final adminsAsync = ref.watch(adminUsersProvider);
    final adminNames = <String, String>{
      for (final admin in adminsAsync.valueOrNull ?? <AdminUser>[])
        admin.id: '${admin.firstName} ${admin.lastName}',
    };

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
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                onPressed: logsAsync.valueOrNull == null
                    ? null
                    : () => _exportCsv(
                          context,
                          _applyFilters(logsAsync.valueOrNull!),
                          adminNames,
                        ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Exporter la Vue (CSV)'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          logsAsync.when(
            data: (logs) => _buildFilterRow(logs, adminNames),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: logsAsync.when(
              data: (allLogs) {
                final logs = _applyFilters(allLogs);
                if (allLogs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune action journalisée pour le moment.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted),
                    ),
                  );
                }
                if (logs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune entrée ne correspond aux filtres sélectionnés.',
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
                              label: Text('Horodatage',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(
                              label: Text('Administrateur',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(
                              label: Text('Action',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(
                              label: Text('Table / Entité',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(
                              label: Text('Diff JSON',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                        rows: logs.map((log) {
                          final adminName = log.adminUserId != null
                              ? (adminNames[log.adminUserId] ?? 'Admin inconnu')
                              : 'Système';
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                log.createdAt.toLocal().toString().split('.').first,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                              )),
                              DataCell(Text(adminName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white))),
                              DataCell(_buildActionBadge(log.actionType)),
                              DataCell(Text(log.entityType,
                                  style: GoogleFonts.inter(color: AppTheme.accentCyan))),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.code_rounded, size: 18, color: AppTheme.accentBlue),
                                  onPressed: () => _showJsonDiffModal(context, log),
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

  List<AuditLog> _applyFilters(List<AuditLog> logs) {
    return logs.where((log) {
      if (_adminFilter != _allFilter) {
        if (_adminFilter == 'system') {
          if (log.adminUserId != null) return false;
        } else if (log.adminUserId != _adminFilter) {
          return false;
        }
      }
      if (_actionFilter != _allFilter && log.actionType != _actionFilter) return false;
      if (_entityFilter != _allFilter && log.entityType != _entityFilter) return false;
      return true;
    }).toList();
  }

  Widget _buildFilterRow(List<AuditLog> logs, Map<String, String> adminNames) {
    final adminIds = logs.map((l) => l.adminUserId).whereType<String>().toSet().toList()..sort();
    final actions = logs.map((l) => l.actionType).toSet().toList()..sort();
    final entities = logs.map((l) => l.entityType).toSet().toList()..sort();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.textMuted),
        _buildFilterDropdown(
          label: 'Administrateur',
          value: _adminFilter,
          items: [
            const DropdownMenuItem(value: _allFilter, child: Text('Tous les administrateurs')),
            const DropdownMenuItem(value: 'system', child: Text('Système (auto)')),
            ...adminIds.map((id) => DropdownMenuItem(value: id, child: Text(adminNames[id] ?? 'Admin inconnu'))),
          ],
          onChanged: (v) => setState(() => _adminFilter = v ?? _allFilter),
        ),
        _buildFilterDropdown(
          label: 'Action',
          value: _actionFilter,
          items: [
            const DropdownMenuItem(value: _allFilter, child: Text('Toutes les actions')),
            ...actions.map((a) => DropdownMenuItem(value: a, child: Text(a))),
          ],
          onChanged: (v) => setState(() => _actionFilter = v ?? _allFilter),
        ),
        _buildFilterDropdown(
          label: 'Entité',
          value: _entityFilter,
          items: [
            const DropdownMenuItem(value: _allFilter, child: Text('Toutes les entités')),
            ...entities.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (v) => setState(() => _entityFilter = v ?? _allFilter),
        ),
        if (_adminFilter != _allFilter || _actionFilter != _allFilter || _entityFilter != _allFilter)
          TextButton.icon(
            onPressed: () => setState(() {
              _adminFilter = _allFilter;
              _actionFilter = _allFilter;
              _entityFilter = _allFilter;
            }),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Réinitialiser'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: value,
        isExpanded: true,
        dropdownColor: AppTheme.primaryDark,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg;
    Color fg;
    switch (action) {
      case 'INSERT':
        fg = AppTheme.accentEmerald;
        break;
      case 'UPDATE':
        fg = AppTheme.accentBlue;
        break;
      case 'merge':
        fg = AppTheme.accentIndigo;
        break;
      case 'duplicate_to_class':
        fg = AppTheme.accentCyan;
        break;
      case 'twin_declare':
      case 'twin_add_member':
        fg = AppTheme.accentAmber;
        break;
      case 'twin_remove_member':
      case 'twin_dissolve':
        fg = AppTheme.accentRose;
        break;
      default:
        fg = AppTheme.accentRose;
    }
    bg = fg.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        action,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showJsonDiffModal(BuildContext context, AuditLog log) {
    const encoder = JsonEncoder.withIndent('  ');
    final before = log.beforeJson != null ? encoder.convert(log.beforeJson) : '(aucun)';
    final after = log.afterJson != null ? encoder.convert(log.afterJson) : '(aucun)';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.code_rounded,
          text: 'Diff JSON — ${log.actionType} sur ${log.entityType}',
          onClose: () => Navigator.pop(context),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avant (Before) :',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.accentRose)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.primaryDark,
                  child: Text(before, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                Text('Après (After) :',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.primaryDark,
                  child: Text(after, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
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

  // Export web uniquement (dart:html) — l'app admin est une cible Flutter Web (CDC section 1.3).
  void _exportCsv(BuildContext context, List<AuditLog> logs, Map<String, String> adminNames) {
    final buffer = StringBuffer('Horodatage,Administrateur,Action,Entité,ID Entité\n');
    for (final log in logs) {
      final adminName = log.adminUserId != null
          ? (adminNames[log.adminUserId] ?? 'Admin inconnu')
          : 'Système';
      buffer.writeln(
        [
          log.createdAt.toIso8601String(),
          adminName,
          log.actionType,
          log.entityType,
          log.entityId ?? '',
        ].map((f) => '"${f.replaceAll('"', '""')}"').join(','),
      );
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'audit_log_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentEmerald,
        content: Text('${logs.length} entrées exportées.', style: GoogleFonts.inter(color: Colors.white)),
      ),
    );
  }
}
