import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/core/models/academic_node.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/features/content_management/screens/lessons_manager_screen.dart';

// Message affiché par `_buildNoSubjectState` (lessons_manager_screen.dart) quand l'Arbre
// Académique ne contient aucune classe : depuis l'AcademicPathSelector, cet état ne passe plus par
// un dropdown "Aucune classe configurée" mais par l'état vide de la zone de contenu.
const kNoClassesConfiguredMessage =
    'Configurez d\'abord l\'Arbre Académique (au moins une Classe).';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('Loading classes is not presented as an empty academic tree', (
    tester,
  ) async {
    final pending = Completer<List<AcademicNode>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nodesByTypeProvider('class').overrideWith((ref) => pending.future),
          nodesByTypeProvider('series').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: LessonsManagerScreen())),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(kNoClassesConfiguredMessage), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text(kNoClassesConfiguredMessage), findsOneWidget);
  });
  testWidgets('Class query failure can retry instead of claiming no classes', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nodesByTypeProvider('class').overrideWith((ref) async {
            if (++attempts == 1) throw StateError('offline');
            return [];
          }),
          nodesByTypeProvider('series').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: LessonsManagerScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les classes.'), findsOneWidget);
    expect(find.text(kNoClassesConfiguredMessage), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text(kNoClassesConfiguredMessage), findsOneWidget);
  });
}
