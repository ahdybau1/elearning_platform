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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Structure du Tableau (Border bleue/grise élégante)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
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
                height: 48,
                headerWidget: Math.tex(
                  'x',
                  mathStyle: MathStyle.display,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Math.tex(r'-\infty', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Math.tex('0', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Math.tex('2', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Math.tex(r'+\infty', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
              const Divider(height: 1, color: Color(0xFFCBD5E1), thickness: 1.5),

              // LIGNE 2 : Signe de f'(x)
              _buildRow(
                height: 64,
                headerWidget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Signe de', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Math.tex("f'(x)", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDropSlot(
                      slotId: 'sign_1',
                      width: 70,
                      height: 44,
                      hint: 'Signe',
                      isSign: true,
                    ),
                    Math.tex('0', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    _buildDropSlot(
                      slotId: 'sign_2',
                      width: 70,
                      height: 44,
                      hint: 'Signe',
                      isSign: true,
                    ),
                    Math.tex('0', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    _buildDropSlot(
                      slotId: 'sign_3',
                      width: 70,
                      height: 44,
                      hint: 'Signe',
                      isSign: true,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFCBD5E1), thickness: 1.5),

              // LIGNE 3 : Variations de f
              _buildRow(
                height: 96,
                headerWidget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Variations de', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Math.tex('f', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Math.tex(r'-\infty', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    _buildDropSlot(
                      slotId: 'var_1',
                      width: 60,
                      height: 58,
                      hint: 'Flèche',
                      isSign: false,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Math.tex('1', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 14),
                      ],
                    ),
                    _buildDropSlot(
                      slotId: 'var_2',
                      width: 60,
                      height: 58,
                      hint: 'Flèche',
                      isSign: false,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 14),
                        Math.tex('-3', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    _buildDropSlot(
                      slotId: 'var_3',
                      width: 60,
                      height: 58,
                      hint: 'Flèche',
                      isSign: false,
                    ),
                    Math.tex(r'+\infty', mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Palette des éléments à placer (si mode interactif)
        if (widget.isInteractive) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÉLÉMENTS À PLACER',
                  style: TextStyle(
                    color: Color(0xFF7E22CE),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildTokenItem('+'),
                    _buildTokenItem('-'),
                    _buildTokenItem('0'),
                    _buildTokenItem('↗'),
                    _buildTokenItem('↘'),
                  ],
                ),
                if (_selectedToken != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Jeton "$_selectedToken" sélectionné : cliquez sur une case pointillée pour le déposer.',
                    style: const TextStyle(
                      color: Color(0xFF6B21A8),
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
  }

  Widget _buildRow({
    required double height,
    String? headerTitle,
    Widget? headerWidget,
    required Widget content,
    Color? backgroundColor,
  }) {
    return Container(
      height: height,
      color: backgroundColor,
      child: Row(
        children: [
          // En-tête gauche
          Container(
            width: 90,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              ),
            ),
            child: headerWidget ??
                Text(
                  headerTitle ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
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
  }) {
    final value = _placedElements[slotId];
    final bool hasValue = value != null;

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
              color: hasValue
                  ? (isSign ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4))
                  : (isHovered ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasValue
                    ? (isSign ? const Color(0xFF3B82F6) : AppColors.tealSuccess)
                    : (isHovered
                        ? const Color(0xFF9333EA)
                        : const Color(0xFF94A3B8)),
                width: hasValue ? 1.5 : 1.2,
                style: hasValue ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: Center(
              child: hasValue
                  ? _buildPlacedContent(value, isSign)
                  : Text(
                      widget.isInteractive ? hint : '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlacedContent(String value, bool isSign) {
    if (value == 'up' || value == '↗') {
      return const Icon(
        Icons.trending_up_rounded,
        color: AppColors.tealSuccess,
        size: 26,
      );
    }
    if (value == 'down' || value == '↘') {
      return const Icon(
        Icons.trending_down_rounded,
        color: Color(0xFFEA580C),
        size: 26,
      );
    }
    return Text(
      value,
      style: TextStyle(
        fontSize: isSign ? 18 : 16,
        fontWeight: FontWeight.bold,
        color: isSign ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTokenItem(String token) {
    final isSelected = _selectedToken == token;

    final tokenWidget = GestureDetector(
      onTap: () {
        setState(() {
          _selectedToken = isSelected ? null : token;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF581C87)
              : const Color(0xFF7E22CE), // Violet riche maquette
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E22CE).withAlpha(isSelected ? 100 : 50),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
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
    );

    return Draggable<String>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21A8),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            token,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
