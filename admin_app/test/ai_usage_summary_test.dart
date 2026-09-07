import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/models/system_models.dart';
import 'package:admin_app/features/dashboard/widgets/ai_usage_summary.dart';

void main() {
  testWidgets(
    'Usage groups repeated calls and keeps measured sums and failures',
    (tester) async {
      tester.view.physicalSize = const Size(345, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiUsageSummary(
                calls: [
                  AiAgentCall(
                    id: '1',
                    agentType: 'tuteur',
                    provider: 'test',
                    tokensUsed: 11,
                    costEstimate: 0.001,
                    status: 'failed',
                  ),
                  AiAgentCall(
                    id: '2',
                    agentType: 'tuteur',
                    provider: 'test',
                    tokensUsed: 19,
                    costEstimate: 0.002,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('2 appels • 1 agents'), findsOneWidget);
      expect(find.text('tuteur'), findsOneWidget);
      expect(find.textContaining('30 tokens'), findsOneWidget);
      expect(
        find.textContaining('0.0030 USD estimés • 1 échecs'),
        findsOneWidget,
      );
      await tester.tap(find.text('tuteur'));
      await tester.pumpAndSettle();
      expect(find.textContaining('11 tokens'), findsOneWidget);
      expect(find.textContaining('19 tokens'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Long agent lists are bounded and can be expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUsageSummary(
              calls: [
                for (var i = 0; i < 8; i++)
                  AiAgentCall(
                    id: '$i',
                    agentType: 'agent-$i',
                    provider: 'test',
                    tokensUsed: i,
                    costEstimate: 0,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ExpansionTile), findsNWidgets(5));
    await tester.ensureVisible(find.text('Afficher les 8 agents'));
    await tester.tap(find.text('Afficher les 8 agents'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });
}
