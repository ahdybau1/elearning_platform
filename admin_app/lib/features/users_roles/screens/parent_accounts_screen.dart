import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class ParentAccountsScreen extends StatelessWidget {
  const ParentAccountsScreen({super.key});

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
                    'Gestion des Comptes Parents',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compte distinct lié à un ou plusieurs profils élèves (Payeur principal & Suivi)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Lier Parent ↔ Élève'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: ListView(
                children: [
                  _buildParentCard(
                    'M. Dieudonné Atangana',
                    'dieudonne.a@gmail.com',
                    '+237 699 11 22 33',
                    ['Junior Atangana (3e)'],
                  ),
                  const SizedBox(height: 12),
                  _buildParentCard(
                    'Mme. Florence Ngo',
                    'florence.ngo@yahoo.fr',
                    '+237 677 55 44 33',
                    ['Marie Ngo (Tle C)', 'Paul Ngo (6e)'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard(
    String name,
    String email,
    String phone,
    List<String> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$email • $phone',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: children.map((c) {
              return Chip(
                backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.15),
                label: Text(
                  c,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
