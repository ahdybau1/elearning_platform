import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/features/auth/screens/login_screen.dart';
import 'package:admin_app/features/academic_tree/screens/curriculum_autopilot_screen.dart';
import 'package:admin_app/core/theme/app_theme.dart';

void main() {
  testWidgets('LoginScreen renders elements correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(child: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('E-LEARNING Admin HQ'), findsOneWidget);
    expect(find.text('Connexion administrateur'), findsOneWidget);
    expect(find.text('Se Connecter'), findsOneWidget);
  });

  testWidgets(
    'Curriculum preview preserves its sample without claiming collection',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: Scaffold(body: CurriculumAutopilotScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Curriculum Autopilot'), findsOneWidget);
      expect(
        find.text('Collecte automatique non raccordée à cet écran.'),
        findsOneWidget,
      );
      expect(find.text('Ouvrir l’arbre académique'), findsOneWidget);
      await tester.tap(find.text('Cameroun — Sous-système Francophone'));
      await tester.pumpAndSettle();
      expect(find.text('Second Cycle (Lycée)'), findsOneWidget);
      expect(find.textContaining('Confirmer l'), findsNothing);
      expect(find.textContaining('100%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
