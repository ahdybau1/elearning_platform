import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/features/auth/screens/login_screen.dart';
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
}
