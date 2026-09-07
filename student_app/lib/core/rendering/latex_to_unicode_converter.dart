/// Convertisseur déterministe LaTeX -> Notation Mathématique Unicode humaine.
///
/// Garantit qu'aucun élève ne voit jamais d'antislashs `\`, de balises TeX brutes (`\frac`, `\sqrt`,
/// `\begin{cases}`, `\Delta`, etc.) ou de code informatique non compilé dans les interfaces.
class LatexToUnicodeConverter {
  LatexToUnicodeConverter._();

  static final Map<String, String> _symbolMap = {
    // Opérateurs et relations
    r'\to': '→',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\iff': '⇔',
    r'\implies': '⇒',
    r'\le': '≤',
    r'\leq': '≤',
    r'\ge': '≥',
    r'\geq': '≥',
    r'\neq': '≠',
    r'\approx': '≈',
    r'\times': '×',
    r'\cdot': '·',
    r'\pm': '±',
    r'\mp': '∓',
    r'\infty': '∞',
    r'+\infty': '+∞',
    r'-\infty': '-∞',
    r'\in': '∈',
    r'\notin': '∉',
    r'\subset': '⊂',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\emptyset': '∅',

    // Lettres grecques
    r'\Delta': 'Δ',
    r'\delta': 'δ',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\pi': 'π',
    r'\theta': 'θ',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\sigma': 'σ',
    r'\omega': 'ω',
    r'\Omega': 'Ω',
    r'\phi': 'φ',
    r'\Phi': 'Φ',

    // Espacements et ponctuations TeX
    r'\quad': '  ',
    r'\qquad': '    ',
    r'\,': ' ',
    r'\;': ' ',
    r'\:': ' ',
    r'\!': '',

    // Ensembles mathématiques usuels
    r'\mathbb{R}': 'ℝ',
    r'\mathbb{N}': 'ℕ',
    r'\mathbb{Z}': 'ℤ',
    r'\mathbb{Q}': 'ℚ',
    r'\mathbb{C}': 'ℂ',
  };

  static final Map<String, String> _superscriptMap = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    'n': 'ⁿ',
    'x': 'ˣ',
  };

  static final Map<String, String> _subscriptMap = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    'n': 'ₙ',
    'i': 'ᵢ',
    'j': 'ⱼ',
    'k': 'ₖ',
  };

  /// Convertit une formule ou chaîne LaTeX en texte mathématique lisible et propre.
  static String convert(String latex) {
    if (latex.trim().isEmpty) return '';

    var result = latex;

    // 1. Supprimer les délimiteurs englobants $...$ et $$...$$
    result = result.replaceAll(RegExp(r'^\$\$|\$\$$'), '');
    result = result.replaceAll(RegExp(r'^\$|\$$'), '');

    // 2. Extraire le texte des balises \text{...}, \mathrm{...}, \textbf{...}
    result = result.replaceAllMapped(
      RegExp(r'\\(text|mathrm|textbf|textit|mathbf)\{([^}]*)\}'),
      (m) => m.group(2) ?? '',
    );

    // 3. Remplacer \frac{num}{den} par (num) / (den) si composé, ou num / den si simple
    result = result.replaceAllMapped(
      RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'),
      (m) {
        final num = convert(m.group(1) ?? '');
        final den = convert(m.group(2) ?? '');
        final needNumParen = num.contains(' ') || num.contains('+') || num.contains('-');
        final needDenParen = den.contains(' ') || den.contains('+') || den.contains('-');
        final numPart = needNumParen ? '($num)' : num;
        final denPart = needDenParen ? '($den)' : den;
        return '$numPart / $denPart';
      },
    );

    // 4. Remplacer \sqrt[n]{x} et \sqrt{x}
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\[([^\]]*)\]\{([^}]*)\}'),
      (m) => '${m.group(1)}√(${convert(m.group(2) ?? '')})',
    );
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]*)\}'),
      (m) => '√(${convert(m.group(1) ?? '')})',
    );

    // 5. Remplacer \lim_{...}
    result = result.replaceAllMapped(
      RegExp(r'\\lim_\{([^}]*)\}'),
      (m) => 'lim(${convert(m.group(1) ?? '')})',
    );

    // 6. Nettoyer les environnements de tableaux / systèmes (cases, aligned, matrix)
    result = result.replaceAll(RegExp(r'\\begin\{(cases|aligned|matrix|pmatrix|array)\}'), '');
    result = result.replaceAll(RegExp(r'\\end\{(cases|aligned|matrix|pmatrix|array)\}'), '');
    result = result.replaceAll(r'\\', '\n');
    result = result.replaceAll('&', '   ');

    // 7. Remplacer les symboles standard connus
    _symbolMap.forEach((tex, uni) {
      result = result.replaceAll(tex, uni);
    });

    // 8. Convertir les exposants simples x^2, q^n, ^3
    result = result.replaceAllMapped(RegExp(r'\^([0-9nx+ -])'), (m) {
      final char = m.group(1) ?? '';
      return _superscriptMap[char] ?? '^$char';
    });
    result = result.replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) {
      final inner = m.group(1) ?? '';
      final converted = inner.split('').map((c) => _superscriptMap[c] ?? c).join('');
      return converted;
    });

    // 9. Convertir les indices simples U_n, x_1, _0
    result = result.replaceAllMapped(RegExp(r'_([0-9nijk+ -])'), (m) {
      final char = m.group(1) ?? '';
      return _subscriptMap[char] ?? '_$char';
    });
    result = result.replaceAllMapped(RegExp(r'_\{([^}]*)\}'), (m) {
      final inner = m.group(1) ?? '';
      final converted = inner.split('').map((c) => _subscriptMap[c] ?? c).join('');
      return converted;
    });

    // 10. Supprimer les commandes résiduelles (\left, \right, \Big, \mathcal, etc.)
    result = result.replaceAll(RegExp(r'\\(left|right|Big|big|Bigg|bigg)'), '');
    result = result.replaceAll(RegExp(r'\\mathcal\{([^}]*)\}'), r'$1');
    result = result.replaceAll(RegExp(r'\\vec\{([^}]*)\}'), r'$1');

    // 11. Supprimer tout antislash résiduel orphelin
    result = result.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    result = result.replaceAll(r'\', '');

    // Nettoyer les espaces multiples
    result = result.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    return result;
  }
}
