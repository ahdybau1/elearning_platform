import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/rendering/block_renderer_registry.dart';
import 'package:student_app/core/rendering/math_formula_view.dart';

void main() {
  for (final width in [390.0, 800.0, 1400.0]) {
    testWidgets('Studio summary renders at width $width', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final content = jsonDecode(File('../test_fixtures/studio_course_v2.json').readAsStringSync()) as Map<String, dynamic>;
      final lesson = Lesson.fromJson({'id': 'fixture', 'chapter_id': 'chapter', 'title': 'Suites', 'content_json': content});
      expect(lesson.blocks.length, 2);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Builder(builder: (context) => BlockRendererRegistry.build(context, lesson.blocks.first))))));
      await tester.pumpAndSettle();
      expect(find.text('Suite arithmétique'), findsOneWidget);
      expect(find.text('Suite géométrique'), findsOneWidget);
      expect(find.byType(MathFormulaView), findsNWidgets(2));
      expect(find.text('Identifier la raison avant de choisir la formule.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
