import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_app/core/rendering/ai_message_bubble_renderer.dart';
import 'package:student_app/core/rendering/math_formula_view.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('InlineLatexText Markdown & Emojis Tests', () {
    test('parseMarkdownSpans formats bold without literal asterisks', () {
      final spans = InlineLatexText.parseMarkdownSpans(
        'Voici **du texte en gras** et normal.',
        const TextStyle(fontSize: 14),
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Voici ');
      expect((spans[1] as TextSpan).text, 'du texte en gras');
      expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.w700);
      expect((spans[2] as TextSpan).text, ' et normal.');
    });

    test('parseMarkdownSpans formats italic and emojis', () {
      final spans = InlineLatexText.parseMarkdownSpans(
        '💡 Indice : *pense au signe* 🎯',
        const TextStyle(fontSize: 14),
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, '💡 Indice : ');
      expect((spans[1] as TextSpan).text, 'pense au signe');
      expect((spans[1] as TextSpan).style?.fontStyle, FontStyle.italic);
      expect((spans[2] as TextSpan).text, ' 🎯');
    });

    test('parseMarkdownSpans formats inline code and strikethrough', () {
      final spans = InlineLatexText.parseMarkdownSpans(
        'Tape `print(x)` ou ~~faux~~',
        const TextStyle(fontSize: 14),
      );

      expect(spans.length, 4);
      expect((spans[0] as TextSpan).text, 'Tape ');
      expect(spans[1] is WidgetSpan, isTrue); // Code widget pill
      expect((spans[2] as TextSpan).text, ' ou ');
      expect((spans[3] as TextSpan).text, 'faux');
      expect((spans[3] as TextSpan).style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('InlineLatexText renders mixed markdown and math', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineLatexText(
              r'**Étape 1** : Calculer $\Delta = b^2 - 4ac$ avec soin.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No raw asterisks rendered
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('Étape 1'), findsOneWidget);
    });
  });

  group('AiMessageBubbleRenderer Block Parsing Tests', () {
    testWidgets('Renders headings, numbered lists, bullet lists and blockquotes', (tester) async {
      const message = r'''### Démarche à suivre
1. **Identifier** les coefficients $a$, $b$, $c$.
2. **Calculer** le discriminant.
- Remarque importante : $a \neq 0$.
> 💡 Conseil : vérifie toujours ton calcul avant de conclure.''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiMessageBubbleRenderer(
                message: message,
                isAssistant: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Démarche à suivre'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('Identifier'), findsOneWidget);
      expect(find.textContaining('Calculer'), findsOneWidget);
      expect(find.textContaining('Remarque importante'), findsOneWidget);
      expect(find.textContaining('Conseil :'), findsOneWidget);
      // No raw **
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('Renders educational image block with zoom button', (tester) async {
      const message = '''Voici la parabole correspondante :
![Graphe de la parabole](https://image.pollinations.ai/prompt/parabola_graph?width=800&height=450&nologo=true)
Que remarques-tu sur le sommet ?''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiMessageBubbleRenderer(
                message: message,
                isAssistant: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Graphe de la parabole'), findsWidgets);
      expect(find.text('Agrandir'), findsOneWidget);
      expect(find.textContaining('Que remarques-tu'), findsOneWidget);
    });

    testWidgets('Detects quadratic polynomial and shows interactive actions', (tester) async {
      const message = 'Pour la fonction P(x) = 2x^2 - 4x - 6, trouve les racines.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiMessageBubbleRenderer(
                message: message,
                isAssistant: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracer la courbe'), findsOneWidget);
      expect(find.text('Étude de la fonction'), findsOneWidget);
      expect(find.text('Calcul formel exact'), findsOneWidget);
    });
  });
}
