import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final List<Map<String, dynamic>> _tickets = [
    {
      'id': 'tick-1001',
      'requester': 'M. Dieudonné Atangana (Parent d\'élève)',
      'requesterType': 'Parent',
      'category': 'Paiement',
      'subject': 'Prélèvement effectué mais cours non débloqués',
      'description':
          'J\'ai payé le Pass Mensuel pour mon fils Junior en 3e via Orange Money, le solde a été débité mais l\'application affiche toujours en gratuit.',
      'status': 'Ouvert',
      'time': 'Il y a 30 min',
    },
    {
      'id': 'tick-1002',
      'requester': 'Marie Ngo (Élève Tle C)',
      'requesterType': 'Élève',
      'category': 'Technique',
      'subject': 'Problème d\'affichage des graphiques de physique',
      'description':
          'Sur la leçon 2 d\'optique, les schémas ne se chargent pas quand je suis en réseau faible.',
      'status': 'En cours',
      'time': 'Il y a 2 heures',
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
                    'Centre de Traitement des Tickets Support',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distinction explicite des requêtes venant des élèves vs des parents payeurs',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_tickets.length} tickets en attente',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _tickets.length,
              itemBuilder: (context, idx) {
                final tick = _tickets[idx];
                final isParent = tick['requesterType'] == 'Parent';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isParent
                                      ? AppTheme.accentAmber.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.accentBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TICKET ${tick['requesterType'].toString().toUpperCase()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isParent
                                        ? AppTheme.accentAmber
                                        : AppTheme.accentBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                tick['requester'],
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            tick['time'],
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sujet : ${tick['subject']}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tick['description'],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                            ),
                            onPressed: () =>
                                _showReplyModal(context, tick['subject']),
                            icon: const Icon(Icons.reply_rounded, size: 16),
                            label: const Text('Répondre au Ticket'),
                          ),
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

  void _showReplyModal(BuildContext context, String subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Répondre : $subject',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Saisissez votre réponse au client...',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Réponse envoyée au client par email/notification.',
                  ),
                ),
              );
            },
            child: const Text('Envoyer la Réponse'),
          ),
        ],
      ),
    );
  }
}
