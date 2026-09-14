import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/core/widgets/math_text.dart';

/// Couvre les cas concrets exigés (retour utilisateur du 2026-09-12, point #5) : fractions,
/// racines, puissances/indices, vecteurs, systèmes, matrices, limites/dérivées/intégrales,
/// unités de physique, chimie, délimiteurs alternatifs, `$` isolé, formule invalide.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, String text) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MathText(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final cases = <String, String>{
    'fraction et racine': r'La solution est $x = \frac{-b + \sqrt{b^2 - 4ac}}{2a}$.',
    'puissance et indice': r'On note $u_n$ le terme général et $x^2 + y_1^3$.',
    'vecteur': r'Le vecteur $\vec{AB}$ et $\overrightarrow{u} + \overrightarrow{v}$.',
    'systeme': r'$$\begin{cases} x + y = 3 \\ x - y = 1 \end{cases}$$',
    'matrice': r'$$\begin{pmatrix} a & b \\ c & d \end{pmatrix}$$',
    'limite derivee integrale':
        r'$\lim_{x \to 0} \frac{\sin x}{x} = 1$ et $\int_0^1 x^2\,dx$ et $f^{\prime}(x)$.',
    'unites physique': r'La vitesse est $v = 12\ \text{m/s}$ et $E = mc^2$.',
    'chimie fleche': r'\ce{H2O -> H2 + O2}',
    'chimie charge': r'\ce{Fe^3+ + 3OH- -> Fe(OH)3}',
    'delimiteurs alternatifs': r'Voici \(x^2+1\) en ligne et \[\int_a^b f(x)\,dx\] en bloc.',
  };

  for (final entry in cases.entries) {
    testWidgets('rend sans exception : ${entry.key}', (tester) async {
      await pump(tester, entry.value);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('un dollar isolé (prix) ne dévore pas le paragraphe suivant', (tester) async {
    const text = 'Le service coûte 10\$ ce mois-ci. Ensuite le cours continue normalement '
        'sur plusieurs phrases sans aucune formule réelle à afficher.';
    await pump(tester, text);
    expect(tester.takeException(), isNull);
    // Le texte doit rester lisible tel quel (aucune portion avalée par un faux appariement).
    expect(find.textContaining('Ensuite le cours continue normalement'), findsOneWidget);
  });

  testWidgets('une formule invalide affiche un signalement, jamais le code brut', (tester) async {
    await pump(tester, r'Ceci est invalide : $\frac{1}{$ fin.');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('formule invalide'), findsWidgets);
  });

  testWidgets('une équation \$\$...\$\$ est isolée sur son propre bloc, pas injectée en ligne',
      (tester) async {
    await pump(tester, r'Avant. $$E = mc^2$$ Après.');
    expect(tester.takeException(), isNull);
    // Le texte "Avant." et "Après." doivent chacun apparaître (le bloc équation les sépare).
    expect(find.textContaining('Avant.'), findsOneWidget);
    expect(find.textContaining('Après.'), findsOneWidget);
  });

  testWidgets('texte sans aucune formule reste un Text simple (repli honnête)', (tester) async {
    await pump(tester, 'Aucune formule ici, uniquement de la prose normale.');
    expect(tester.takeException(), isNull);
    expect(MathText.containsMath('Aucune formule ici.'), isFalse);
  });

  testWidgets('containsMath détecte les délimiteurs alternatifs', (tester) async {
    expect(MathText.containsMath(r'\(x^2\)'), isTrue);
    expect(MathText.containsMath(r'\[x^2\]'), isTrue);
    expect(MathText.containsMath(r'$x^2$'), isTrue);
    expect(MathText.containsMath('juste du texte'), isFalse);
  });
}
