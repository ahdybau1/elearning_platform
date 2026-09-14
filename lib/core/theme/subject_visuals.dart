import 'package:flutter/material.dart';

/// Identité visuelle par matière (icône + dégradé) — remplace les cartes plates identiques pour
/// toutes les matières. Pas d'images/illustrations externes (aucun pipeline d'assets vérifié,
/// aucune image dont les droits sont garantis) : le relief vient d'un dégradé propre à la matière
/// + une grande icône flottante animée en filigrane (voir [SubjectMotif]), une approche utilisée
/// par de nombreuses apps sérieuses (Notion, Linear...) quand l'illustration sur mesure n'est pas
/// disponible.
class SubjectVisual {
  final IconData icon;
  final List<Color> gradient;

  const SubjectVisual({required this.icon, required this.gradient});
}

class SubjectVisuals {
  SubjectVisuals._();

  static const _byKeyword = <String, SubjectVisual>{
    'math': SubjectVisual(icon: Icons.functions_rounded, gradient: [Color(0xFF0EA5E9), Color(0xFF4F46E5)]),
    'phys': SubjectVisual(icon: Icons.science_rounded, gradient: [Color(0xFFF59E0B), Color(0xFFDC2626)]),
    'chim': SubjectVisual(icon: Icons.biotech_rounded, gradient: [Color(0xFFF59E0B), Color(0xFFDC2626)]),
    'svt': SubjectVisual(icon: Icons.eco_rounded, gradient: [Color(0xFF10B981), Color(0xFF047857)]),
    'bio': SubjectVisual(icon: Icons.eco_rounded, gradient: [Color(0xFF10B981), Color(0xFF047857)]),
    'franc': SubjectVisual(icon: Icons.menu_book_rounded, gradient: [Color(0xFFEC4899), Color(0xFF9333EA)]),
    'litt': SubjectVisual(icon: Icons.menu_book_rounded, gradient: [Color(0xFFEC4899), Color(0xFF9333EA)]),
    'angl': SubjectVisual(icon: Icons.translate_rounded, gradient: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
    'english': SubjectVisual(icon: Icons.translate_rounded, gradient: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
    'hist': SubjectVisual(icon: Icons.public_rounded, gradient: [Color(0xFFD97706), Color(0xFF78350F)]),
    'geo': SubjectVisual(icon: Icons.public_rounded, gradient: [Color(0xFFD97706), Color(0xFF78350F)]),
    'philo': SubjectVisual(icon: Icons.psychology_rounded, gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
    'info': SubjectVisual(icon: Icons.terminal_rounded, gradient: [Color(0xFF334155), Color(0xFF0EA5E9)]),
    'sport': SubjectVisual(icon: Icons.sports_soccer_rounded, gradient: [Color(0xFF16A34A), Color(0xFF15803D)]),
    'musiq': SubjectVisual(icon: Icons.music_note_rounded, gradient: [Color(0xFFDB2777), Color(0xFF7C3AED)]),
    'art': SubjectVisual(icon: Icons.palette_rounded, gradient: [Color(0xFFEF4444), Color(0xFFF59E0B)]),
  };

  static const _fallback = SubjectVisual(icon: Icons.auto_stories_rounded, gradient: [Color(0xFF0284C7), Color(0xFF6366F1)]);

  static SubjectVisual forSubject({String? code, String? name}) {
    final needle = '${code ?? ''} ${name ?? ''}'.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (needle.contains(entry.key)) return entry.value;
    }
    return _fallback;
  }
}

/// Grande icône flottante en filigrane, animation douce et continue (léger flottement vertical +
/// rotation) — le "peut-être animée" demandé, sans dépendance externe ni asset image.
class SubjectMotif extends StatefulWidget {
  final IconData icon;
  final double size;
  final double opacity;

  const SubjectMotif({super.key, required this.icon, this.size = 96, this.opacity = 0.16});

  @override
  State<SubjectMotif> createState() => _SubjectMotifState();
}

class _SubjectMotifState extends State<SubjectMotif> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Transform.translate(
          offset: Offset(0, -6 + 10 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.12, child: child),
        );
      },
      child: Icon(widget.icon, size: widget.size, color: Colors.white.withValues(alpha: widget.opacity)),
    );
  }
}
