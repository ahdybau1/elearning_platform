import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jeu de couleurs sémantique, dépendant du thème actif (CDC §11.1 Apparence, §11.2 Contraste élevé).
/// Remplace les anciennes `static const Color ...Dark` référencées en dur dans les écrans — celles-ci
/// restent définies dans [StudentTheme] pour compatibilité de valeurs, mais l'accès dynamique passe
/// désormais par `context.colors.xxx` (voir [StudentColorsX]) pour que Clair/Sombre/Automatique et
/// Contraste élevé (deux axes indépendants, §11.2 : « distinct du mode sombre ») aient un effet réel.
class StudentColors extends ThemeExtension<StudentColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentPrimary;
  final Color accentCyan;
  final Color accentIndigo;
  final Color accentEmerald;
  final Color accentAmber;
  final Color accentRose;
  final Color accentPurple;

  const StudentColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.accentCyan,
    required this.accentIndigo,
    required this.accentEmerald,
    required this.accentAmber,
    required this.accentRose,
    required this.accentPurple,
  });

  factory StudentColors.dark() => const StudentColors(
        background: StudentTheme.backgroundDark,
        surface: StudentTheme.surfaceDark,
        card: StudentTheme.cardDark,
        border: StudentTheme.borderDark,
        textPrimary: Colors.white,
        textSecondary: StudentTheme.textSecondary,
        textMuted: StudentTheme.textMuted,
        accentPrimary: StudentTheme.accentPrimary,
        accentCyan: StudentTheme.accentCyan,
        accentIndigo: StudentTheme.accentIndigo,
        accentEmerald: StudentTheme.accentEmerald,
        accentAmber: StudentTheme.accentAmber,
        accentRose: StudentTheme.accentRose,
        accentPurple: StudentTheme.accentPurple,
      );

  factory StudentColors.darkHighContrast() => const StudentColors(
        background: Color(0xFF000000),
        surface: Color(0xFF0A0A0A),
        card: Color(0xFF141414),
        border: Color(0xFFE5E7EB),
        textPrimary: Colors.white,
        textSecondary: Color(0xFFE5E7EB),
        textMuted: Color(0xFFCBD5E1),
        accentPrimary: Color(0xFF7DD3FC),
        accentCyan: Color(0xFF22D3EE),
        accentIndigo: Color(0xFF818CF8),
        accentEmerald: Color(0xFF34D399),
        accentAmber: Color(0xFFFBBF24),
        accentRose: Color(0xFFFB7185),
        accentPurple: Color(0xFFC084FC),
      );

  factory StudentColors.light() => const StudentColors(
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        card: Color(0xFFFFFFFF),
        border: Color(0xFFE2E8F0),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF475569),
        textMuted: Color(0xFF94A3B8),
        accentPrimary: Color(0xFF0284C7),
        accentCyan: Color(0xFF0E7490),
        accentIndigo: Color(0xFF4F46E5),
        accentEmerald: Color(0xFF059669),
        accentAmber: Color(0xFFD97706),
        accentRose: Color(0xFFE11D48),
        accentPurple: Color(0xFF9333EA),
      );

  factory StudentColors.lightHighContrast() => const StudentColors(
        background: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        card: Color(0xFFFFFFFF),
        border: Color(0xFF000000),
        textPrimary: Color(0xFF000000),
        textSecondary: Color(0xFF1F2937),
        textMuted: Color(0xFF374151),
        accentPrimary: Color(0xFF075985),
        accentCyan: Color(0xFF155E75),
        accentIndigo: Color(0xFF3730A3),
        accentEmerald: Color(0xFF047857),
        accentAmber: Color(0xFFB45309),
        accentRose: Color(0xFFBE123C),
        accentPurple: Color(0xFF7E22CE),
      );

  @override
  StudentColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPrimary,
    Color? accentCyan,
    Color? accentIndigo,
    Color? accentEmerald,
    Color? accentAmber,
    Color? accentRose,
    Color? accentPurple,
  }) {
    return StudentColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentCyan: accentCyan ?? this.accentCyan,
      accentIndigo: accentIndigo ?? this.accentIndigo,
      accentEmerald: accentEmerald ?? this.accentEmerald,
      accentAmber: accentAmber ?? this.accentAmber,
      accentRose: accentRose ?? this.accentRose,
      accentPurple: accentPurple ?? this.accentPurple,
    );
  }

  @override
  StudentColors lerp(ThemeExtension<StudentColors>? other, double t) {
    if (other is! StudentColors) return this;
    return StudentColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentIndigo: Color.lerp(accentIndigo, other.accentIndigo, t)!,
      accentEmerald: Color.lerp(accentEmerald, other.accentEmerald, t)!,
      accentAmber: Color.lerp(accentAmber, other.accentAmber, t)!,
      accentRose: Color.lerp(accentRose, other.accentRose, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
    );
  }
}

/// Accès court : `context.colors.card` au lieu de `Theme.of(context).extension<StudentColors>()!.card`.
extension StudentColorsX on BuildContext {
  StudentColors get colors => Theme.of(this).extension<StudentColors>() ?? StudentColors.dark();
}

class StudentTheme {
  // Anciennes constantes : conservées comme valeurs sources de StudentColors.dark() (voir ci-dessus) et
  // pour tout code encore en cours de bascule. Le rendu réel passe désormais par context.colors.
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color cardDark = Color(0xFF1B243B);
  static const Color borderDark = Color(0xFF2B3754);

  // Accents Colorés
  static const Color accentPrimary = Color(0xFF38BDF8); // Cyan Lumineux
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo
  static const Color accentEmerald = Color(0xFF10B981); // Émeraude Succès
  static const Color accentAmber = Color(0xFFF59E0B); // Ambre Avertissement
  static const Color accentRose = Color(0xFFF43F5E); // Rose
  static const Color accentPurple = Color(0xFFA855F7); // Violet

  // Typographie & Textes
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients Signature — identiques dans tous les thèmes (accents de marque ponctuels, toujours posés
  // sur une carte/fond dont le contraste est lui géré par StudentColors).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Résout le thème réel à appliquer à partir des préférences du compte (§11.1 Apparence, §11.2
  /// Contraste élevé — deux axes indépendants, d'où 4 variantes possibles). `mode: 'system'` suit
  /// [platformBrightness] comme le ferait `ThemeMode.system` natif de Flutter.
  static ThemeData resolve({
    required String mode,
    required bool highContrast,
    required Brightness platformBrightness,
  }) {
    final isDark = mode == 'system' ? platformBrightness == Brightness.dark : mode != 'light';
    final colors = isDark
        ? (highContrast ? StudentColors.darkHighContrast() : StudentColors.dark())
        : (highContrast ? StudentColors.lightHighContrast() : StudentColors.light());
    return _themeFrom(colors, isDark);
  }

  static ThemeData get darkTheme => _themeFrom(StudentColors.dark(), true);

  static ThemeData _themeFrom(StudentColors colors, bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accentPrimary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: colors.accentEmerald,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.accentRose,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 30,
          color: colors.textPrimary,
        ),
        displayMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: colors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: colors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: colors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
