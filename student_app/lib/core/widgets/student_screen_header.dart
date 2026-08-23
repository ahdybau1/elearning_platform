import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/student_theme.dart';

/// Titre de page à l'intérieur du contenu scrollable — reprend exactement le motif de
/// admin_app (`DashboardOverviewScreen` : gros titre + sous-titre + action optionnelle), pour que
/// les deux applications "soient faites de la même façon". Remplace l'AppBar individuelle que
/// chaque page élève portait auparavant — la barre du haut est désormais unique et partagée
/// (voir main_navigation_screen.dart), comme côté admin.
class StudentScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const StudentScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}
