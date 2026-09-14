import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// Données d'un tableau de variations
class VariationTableData {
  final List<String> xValues; // ex: ['-\\infty', '0', '2', '+\\infty']
  final List<String?> derivativeSigns; // ex: ['+', '0', '-', '0', '+']
  final List<String?> variationArrows; // ex: ['up', 'down', 'up']
  final List<String?> fValues; // ex: ['-\\infty', '1', '-3', '+\\infty']

  const VariationTableData({
    required this.xValues,
    required this.derivativeSigns,
    required this.variationArrows,
    required this.fValues,
  });

  /// Modèle standard dérivé de f(x) = x^3 - 3x^2 + 1
  static VariationTableData get defaultCubicCorrection => const VariationTableData(
        xValues: ['-∞', '0', '2', '+∞'],
        derivativeSigns: ['+', '0', '-', '0', '+'],
        variationArrows: ['up', 'down', 'up'],
        fValues: ['-∞', '1', '-3', '+∞'],
      );
}

/// Widget interactif de Tableau de Variations avec Drag & Drop ou Tap-to-Place
class VariationTableInteractive extends StatefulWidget {
  final bool isInteractive;
  final VariationTableData? initialData;
  final ValueChanged<Map<String, String?>>? onStateChanged;

  const VariationTableInteractive({
    super.key,
    this.isInteractive = true,
    this.initialData,
    this.onStateChanged,
  });

  @override
  State<VariationTableInteractive> createState() =>
      _VariationTableInteractiveState();
}

class _VariationTableInteractiveState extends State<VariationTableInteractive> {
  // Réponses placées par l'élève dans les 3 cases de signe et les 3 cases de variation
  final Map<String, String?> _placedElements = {
    'sign_1': null, // entre -inf et 0
    'sign_2': null, // entre 0 et 2
    'sign_3': null, // entre 2 et +inf
    'var_1': null, // flèche 1
    'var_2': null, // flèche 2
    'var_3': null, // flèche 3
  };

  String? _selectedToken;

  @override
  void initState() {
    super.initState();
    if (!widget.isInteractive && widget.initialData != null) {
      final data = widget.initialData!;
      if (data.derivativeSigns.length >= 5) {
        _placedElements['sign_1'] = data.derivativeSigns[0];
        _placedElements['sign_2'] = data.derivativeSigns[2];
        _placedElements['sign_3'] = data.derivativeSigns[4];
      }
      if (data.variationArrows.length >= 3) {
        _placedElements['var_1'] = data.variationArrows[0];
        _placedElements['var_2'] = data.variationArrows[1];
        _placedElements['var_3'] = data.variationArrows[2];
      }
    }
  }

  void _handleDrop(String slotId, String value) {
    setState(() {
      _placedElements[slotId] = value;
    });
    widget.onStateChanged?.call(_placedElements);
  }

  void _handleTapSlot(String slotId) {
    if (!widget.isInteractive) return;
    if (_selectedToken != null) {
      _handleDrop(slotId, _selectedToken!);
    } else if (_placedElements[slotId] != null) {
      // Effacer l'élément si on reclique dessus sans jeton sélectionné
      setState(() {
        _placedElements[slotId] = null;
      });
      widget.onStateChanged?.call(_placedElements);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0E1726) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final rowAltBg = isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC);

    final tableWidget = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // LIGNE 1 : Valeurs de x
          _buildRow(
            height: 46,
            headerWidget: Math.tex(
              'x',
              mathStyle: MathStyle.display,
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Math.tex(r'-\infty', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                Math.tex('0', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                Math.tex('2', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                Math.tex(r'+\infty', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            backgroundColor: rowAltBg,
            borderColor: borderColor,
          ),
          Divider(height: 1, color: borderColor, thickness: 1.2),

          // LIGNE 2 : Signe de f'(x)
          _buildRow(
            height: 60,
            headerWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Signe de', style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Math.tex("f'(x)", mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDropSlot(
                  slotId: 'sign_1',
                  width: 64,
                  height: 42,
                  hint: 'Signe',
                  isSign: true,
                  isDark: isDark,
                ),
                Math.tex('0', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor)),
                _buildDropSlot(
                  slotId: 'sign_2',
                  width: 64,
                  height: 42,
                  hint: 'Signe',
                  isSign: true,
                  isDark: isDark,
                ),
                Math.tex('0', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor)),
                _buildDropSlot(
                  slotId: 'sign_3',
                  width: 64,
                  height: 42,
                  hint: 'Signe',
                  isSign: true,
                  isDark: isDark,
                ),
              ],
            ),
            borderColor: borderColor,
          ),
          Divider(height: 1, color: borderColor, thickness: 1.2),

          // LIGNE 3 : Variations de f
          _buildRow(
            height: 88,
            headerWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Variations de', style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Math.tex('f', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Math.tex(r'-\infty', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
                _buildDropSlot(
                  slotId: 'var_1',
                  width: 56,
                  height: 52,
                  hint: 'Flèche',
                  isSign: false,
                  isDark: isDark,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Math.tex('1', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                  ],
                ),
                _buildDropSlot(
                  slotId: 'var_2',
                  width: 56,
                  height: 52,
                  hint: 'Flèche',
                  isSign: false,
                  isDark: isDark,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Math.tex('-3', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                _buildDropSlot(
                  slotId: 'var_3',
                  width: 56,
                  height: 52,
                  hint: 'Flèche',
                  isSign: false,
                  isDark: isDark,
                ),
                Math.tex(r'+\infty', mathStyle: MathStyle.text, textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
              ],
            ),
            borderColor: borderColor,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsHorizontalScroll = constraints.maxWidth < 420;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Structure du Tableau (avec scroll horizontal souple sur petit mobile)
            if (needsHorizontalScroll)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 420),
                  child: tableWidget,
                ),
              )
            else
              tableWidget,

            // 2. Palette des éléments à placer (Ruban fluide et épuré)
            if (widget.isInteractive) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF7E22CE).withAlpha(50)
                        : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 15,
                          color: isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'JETONS À DÉPOSER',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildTokenItem('+', isDark),
                        _buildTokenItem('-', isDark),
                        _buildTokenItem('0', isDark),
                        _buildTokenItem('↗', isDark),
                        _buildTokenItem('↘', isDark),
                      ],
                    ),
                    if (_selectedToken != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Jeton "$_selectedToken" sélectionné : touchez une case pour le placer.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow({
    required double height,
    String? headerTitle,
    Widget? headerWidget,
    required Widget content,
    Color? backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      height: height,
      color: backgroundColor,
      child: Row(
        children: [
          // En-tête gauche
          Container(
            width: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor, width: 1.2),
              ),
            ),
            child: headerWidget ??
                Text(
                  headerTitle ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
          ),
          // Contenu étalé
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildDropSlot({
    required String slotId,
    required double width,
    required double height,
    required String hint,
    required bool isSign,
    required bool isDark,
  }) {
    final value = _placedElements[slotId];
    final bool hasValue = value != null;

    final slotBg = hasValue
        ? (isSign
            ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF133E2B) : const Color(0xFFF0FDF4)))
        : (isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC));

    final slotBorder = hasValue
        ? (isSign ? const Color(0xFF3B82F6) : AppColors.tealSuccess)
        : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8));

    return DragTarget<String>(
      onAcceptWithDetails: (details) => _handleDrop(slotId, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _handleTapSlot(slotId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark ? const Color(0xFF3B1D54) : const Color(0xFFF3E8FF))
                  : slotBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered ? const Color(0xFF9333EA) : slotBorder,
                width: hasValue ? 1.5 : 1.1,
              ),
            ),
            child: Center(
              child: hasValue
                  ? _buildPlacedContent(value, isSign, isDark)
                  : Text(
                      widget.isInteractive ? hint : '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlacedContent(String value, bool isSign, bool isDark) {
    if (value == 'up' || value == '↗') {
      return const Icon(
        Icons.trending_up_rounded,
        color: AppColors.tealSuccess,
        size: 24,
      );
    }
    if (value == 'down' || value == '↘') {
      return const Icon(
        Icons.trending_down_rounded,
        color: Color(0xFFEA580C),
        size: 24,
      );
    }
    return Text(
      value,
      style: TextStyle(
        fontSize: isSign ? 17 : 15,
        fontWeight: FontWeight.bold,
        color: isSign
            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
            : (isDark ? Colors.white : const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildTokenItem(String token, bool isDark) {
    final isSelected = _selectedToken == token;

    final tokenWidget = GestureDetector(
      onTap: () {
        setState(() {
          _selectedToken = isSelected ? null : token;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF581C87)
              : (isDark ? const Color(0xFF6B21A8) : const Color(0xFF7E22CE)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E22CE).withAlpha(isSelected ? 90 : 40),
              blurRadius: isSelected ? 6 : 3,
              offset: const Offset(0, 2),
            ),
          ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 1.5)
              : null,
        ),
        child: Text(
          token,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Draggable<String>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21A8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            token,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: tokenWidget,
      ),
      child: tokenWidget,
    );
  }
}
