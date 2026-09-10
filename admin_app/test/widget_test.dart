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
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Connexion administrateur'), findsOneWidget);
    expect(find.text('Se Connecter'), findsOneWidget);
  });

  testWidgets(
    'Curriculum Autopilot preserves its sample without claiming collection or auto-writes',
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
      // Cadrage honnête : assistance, aucune écriture automatique. Plus de disclaimer
      // « collecte non raccordée » contradictoire (le panneau d'analyse EST raccordé).
      expect(
        find.textContaining('Aucune écriture automatique'),
        findsWidgets,
      );
      expect(
        find.text('Collecte automatique non raccordée à cet écran.'),
        findsNothing,
      );
      // L'exemple non normatif reste consultable et dépliable.
      expect(find.text('Exemple de structure — non normatif'), findsOneWidget);
      await tester.tap(find.text('Cameroun — Sous-système Francophone'));
      await tester.pumpAndSettle();
      expect(find.text('Second Cycle (Lycée)'), findsOneWidget);
      // Aucun faux succès ni pourcentage de confiance sans analyse réelle.
      expect(find.textContaining('Confirmer l'), findsNothing);
      expect(find.textContaining('100%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
