import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/features/auth/screens/login_screen.dart';
import 'package:admin_app/features/academic_tree/screens/curriculum_autopilot_screen.dart';
import 'package:admin_app/core/models/curriculum_models.dart';
import 'package:admin_app/core/providers/data_providers.dart';
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
    'Collecte des Programmes : page de suivi, aucun faux succès à vide',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProviderScope(
            overrides: [
              curriculumImportsProvider
                  .overrideWith((ref) => Future.value(<CurriculumImport>[])),
            ],
            child: const Scaffold(body: CurriculumAutopilotScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collecte des Programmes'), findsOneWidget);
      expect(find.text('Nouvelle collecte'), findsOneWidget);
      // À vide : état vide explicite, aucun élément ni pourcentage inventé.
      expect(find.textContaining('Aucune collecte lancée'), findsOneWidget);
      expect(find.textContaining('Aucun programme inventé'), findsWidgets);
      expect(find.textContaining('100%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
