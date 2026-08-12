import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final List<Map<String, dynamic>> _notificationTemplates = [
    {
      'eventKey': 'expiration_j3',
      'channel': 'Push + In-App',
      'title': 'Votre abonnement se termine dans 3 jours',
      'body':
          'Renouvelez votre accès à [Classe] pour continuer à profiter de toutes les leçons et exercices.',
    },
    {
      'eventKey': 'expiration_j1',
      'channel': 'Push + Bannière Persistante',
      'title': 'Dernier jour d\'abonnement !',
      'body':
          'Votre accès complet se termine ce soir à minuit. Cliquez ici pour vous réabonner immédiatement.',
    },
    {
      'eventKey': 'cumul_mensuel_atteint',
      'channel': 'In-App + Push',
      'title': 'Félicitations ! Accès Mensuel Débloqué',
      'body':
          'Vous avez cumulé assez de paiements ce mois-ci pour débloquer l\'accès complet jusqu\'à la fin du mois.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres Système & Modèles de Notifications',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configuration du catalogue des notifications automatiques (Catalogue Partie 1 Section 6.4) et clés API',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connexion Supabase & Services Tierces',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Supabase Project URL',
                          hintText: 'https://xyz.supabase.co',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Supabase Anon / Service Role Key',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TextField(
                        decoration: InputDecoration(
                          labelText:
                              'Agrégateur Mobile Money (Campay / NotchPay API Key)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connexions enregistrées !'),
                            ),
                          );
                        },
                        child: const Text('Tester & Sauvegarder les Clés API'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Catalogue des Modèles de Notifications (Cycle de vie)',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ..._notificationTemplates.map((tpl) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tpl['eventKey'],
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                            Text(
                              tpl['channel'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Titre : ${tpl['title']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Corps : ${tpl['body']}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
