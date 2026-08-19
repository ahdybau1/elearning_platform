import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// En-tête standard pour tout `AlertDialog`/modal fermable de l'app : icône, titre, et un bouton
/// de fermeture en haut à droite façon barre de titre Windows. Le bouton appelle [onClose] — pour
/// une confirmation qui doit renvoyer une valeur (ex: `Navigator.pop(ctx, false)`), passez cette
/// valeur explicitement plutôt que de laisser [onClose] à `null`.
class AppDialogTitle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback onClose;

  const AppDialogTitle({
    super.key,
    required this.icon,
    required this.text,
    required this.onClose,
    this.iconColor = AppTheme.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _DialogCloseButton(onPressed: onClose),
      ],
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DialogCloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Fermer',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}
