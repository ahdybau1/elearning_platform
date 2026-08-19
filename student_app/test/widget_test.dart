import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/features/onboarding/screens/profile_switcher_screen.dart';

void main() {
  testWidgets('ProfileSwitcherScreen renders correctly with Netflix-like UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfileSwitcherScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key titles and profiles
    expect(find.text('Qui apprend aujourd\'hui ?'), findsOneWidget);
    expect(find.text('Espace Parent'), findsOneWidget);
    expect(find.text('Ajouter un profil'), findsOneWidget);
  });
}
