import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'latex_to_unicode_converter.dart';

/// Widget MathJax de secours pour exécution hors Web (Flutter VM, tests unitaires, mobile)
class MathJaxSvgView extends StatelessWidget {
  final String latex;
  final bool isDisplay;
  final Color? color;
  final double fontSize;

  const MathJaxSvgView({
    super.key,
    required this.latex,
    this.isDisplay = true,
    this.color,
    this.fontSize = 17.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFE2E8F0);
    return Math.tex(
      latex,
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      textStyle: TextStyle(
        fontSize: fontSize,
        color: effectiveColor,
      ),
      onErrorFallback: (_) => SelectableText(
        LatexToUnicodeConverter.convert(latex),
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
      ),
    );
  }
}
