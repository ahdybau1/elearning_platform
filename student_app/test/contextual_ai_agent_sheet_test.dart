import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_app/features/ai_tutor/widgets/contextual_ai_agent_sheet.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final mode in ['exercise', 'diagnostic', 'tutor']) {
    testWidgets(
      'SVT $mode has no unrelated sequence or curve at mobile width',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContextualAiAgentSheet(
                topicTitle: 'BONJOUR',
                subject: 'ECOSYSTEME DE LA TERRE',
                initialMode: mode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('U_10'), findsNothing);
        expect(find.textContaining('Tracer la courbe'), findsNothing);
        if (mode != 'tutor') {
          expect(
            find.textContaining('Aucun entraînement local'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Sequence practice retains local correction without fabricated XP',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContextualAiAgentSheet(
              topicTitle: 'Suites réelles',
              subject: 'Mathématiques',
              initialMode: 'exercise',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '43,0');
      await tester.tap(find.text('Vérifier la réponse'));
      await tester.pumpAndSettle();
      expect(find.text('Réponse correcte !'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
