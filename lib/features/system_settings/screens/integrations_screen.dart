import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// WP4 — Administration des intégrations (consigne #5).
///
/// Inventaire + pilotage des fournisseurs/API/services réellement présents : rôle, config
/// autorisée (non secrète), activation, **test de connexion réel**, état de santé, limites
/// connues, erreurs, dernière vérification, licence et coût. **Aucun secret n'est affiché** :
/// seul le *nom* du function-secret requis est visible.
class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  final _testing = <String>{};

  static const _statusColor = <String, Color>{
    'ok': AppTheme.accentEmerald,
    'error': AppTheme.accentRose,
    'not_configured': AppTheme.accentAmber,
    'never': AppTheme.textMuted,
  };
  static const _statusLabel = <String, String>{
    'ok': 'Connecté',
    'error': 'Erreur',
    'not_configured': 'Non configuré',
    'never': 'Jamais testé',
  };
  static const _catLabel = <String, String>{
    'ai': 'Intelligence artificielle',
    'storage': 'Stockage',
    'payment': 'Paiement',
    'messaging': 'Messagerie',
    'other': 'Autre',
  };

  Future<void> _test(String key) async {
    setState(() => _testing.add(key));
    try {
      final res = await ref.read(supabaseServiceProvider).testIntegration(key);
      if (!mounted) return;
      ref.invalidate(integrationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['error'] != null
            ? 'Test : ${res['error']}'
            : '${res['status']} — ${res['detail']}'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _testing.remove(key));
    }
  }

  Future<void> _toggle(String key, bool value) async {
    try {
      await ref.read(supabaseServiceProvider).setIntegrationEnabled(key, value);
      ref.invalidate(integrationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(integrationsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Intégrations',
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Fournisseurs et services connectés au projet. Les secrets restent côté serveur '
            '(function-secrets Supabase) — seul le nom du secret requis est indiqué ici.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Erreur : $e',
                      style: GoogleFonts.inter(color: AppTheme.accentRose)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: () => ref.invalidate(integrationsProvider),
                      child: const Text('Réessayer')),
                ]),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                      child: Text('Aucune intégration enregistrée.',
                          style:
                              GoogleFonts.inter(color: AppTheme.textMuted)));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Integration it) {
    final sc = _statusColor[it.lastStatus] ?? AppTheme.textMuted;
    final busy = _testing.contains(it.key);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(it.name,
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        _pill(_catLabel[it.category] ?? it.category,
                            AppTheme.accentIndigo),
                        _pill(_statusLabel[it.lastStatus] ?? it.lastStatus, sc),
                        if (!it.enabled) _pill('DÉSACTIVÉE', AppTheme.textMuted),
                      ],
                    ),
                    if (it.description != null) ...[
                      const SizedBox(height: 4),
                      Text(it.description!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Switch(
                    value: it.enabled,
                    activeThumbColor: AppTheme.accentEmerald,
                    onChanged: (v) => _toggle(it.key, v),
                  ),
                  Text('Activée',
                      style: GoogleFonts.inter(
                          fontSize: 9, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.primaryBorder, height: 1),
          const SizedBox(height: 10),
          _kv('Fournisseur', it.provider ?? '—'),
          _kv('Secret requis (nom seul)', it.secretRef ?? 'aucun'),
          if (it.config.isNotEmpty)
            _kv('Configuration', it.config.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(' · ')),
          if (it.knownLimits.isNotEmpty)
            _kv('Limites connues', it.knownLimits.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(' · ')),
          if (it.licenseNote != null) _kv('Licence', it.licenseNote!),
          if (it.costNote != null) _kv('Coût', it.costNote!),
          _kv(
              'Dernière vérification',
              it.lastCheckAt == null
                  ? 'jamais'
                  : '${DateFormat('dd/MM/yyyy HH:mm').format(it.lastCheckAt!.toLocal())}'
                      '${it.lastLatencyMs != null ? " · ${it.lastLatencyMs} ms" : ""}'),
          if (it.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Dernière erreur : ${it.lastError}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.accentRose)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: busy ? null : () => _test(it.key),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(busy ? 'Test…' : 'Tester la connexion'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan),
              ),
              if (it.docsUrl != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(it.docsUrl!),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Documentation'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4)),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.bold, color: c)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$k : ',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentIndigo)),
            TextSpan(
                text: v,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white70, height: 1.4)),
          ]),
        ),
      );
}
