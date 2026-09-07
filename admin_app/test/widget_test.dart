import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/features/auth/screens/login_screen.dart';
import 'package:admin_app/features/academic_tree/screens/curriculum_autopilot_screen.dart';
import 'package:admin_app/core/theme/app_theme.dart';

void main() {
  testWidgets('LoginScreen renders elements correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('E-LEARNING Admin HQ'), findsOneWidget);
    expect(find.text('Connexion administrateur'), findsOneWidget);
    expect(find.text('Se Connecter'), findsOneWidget);
  });

  testWidgets('CurriculumAutopilotScreen renders correctly and triggers harvest',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: Scaffold(body: CurriculumAutopilotScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Curriculum Autopilot & Ingestion IA'), findsOneWidget);
    expect(find.text('🚀 Lancer la Collecte & Structuration IA du Programme'), findsOneWidget);
    expect(find.text('Cameroun'), findsOneWidget);

    // Tap the 1-click harvest button
    await tester.tap(find.text('🚀 Lancer la Collecte & Structuration IA du Programme'));
    await tester.pump();

    // Verification that harvesting phase starts
    expect(find.text('Collecte & Structuration en cours...'), findsOneWidget);

    // Fast-forward fake timer to complete all 4 ingestion phases
    await tester.pump(const Duration(seconds: 4));

    // Verify harvest completed and tree is loaded
    expect(find.textContaining('Collecte & Structuration terminées'), findsOneWidget);
    expect(find.text('Injecter dans l\'Arbre Académique'), findsOneWidget);
  });
}
