import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/models/summary_sheet_registry.dart';

void main() {
  test('Every reference resolves by title, tag and identifier', () {
    for (final sheet in SummarySheetRegistry.sheets) {
      for (final query in [sheet.title, sheet.chapterTag, sheet.id]) {
        expect(
          SummarySheetRegistry.findSheetFor(query)?.id,
          sheet.id,
          reason: query,
        );
      }
    }
  });

  test('Normalizes accents, case and separators in precise chapter names', () {
    for (final query in [
      'Le PENDULE ÉLASTIQUE',
      'pendule-elastique',
      'Pendule_e\u0301lastique',
      'Les pendules élastiques',
    ]) {
      expect(
        SummarySheetRegistry.findSheetFor(query)?.id,
        'physique-pendule-elastique-dynamique',
        reason: query,
      );
    }
    expect(
      SummarySheetRegistry.findSheetFor('Chapitre 4 : suite géométrique')?.id,
      'math-suites-reelles',
    );
    expect(
      SummarySheetRegistry.findSheetFor('Oscillateur mécanique')?.id,
      'physique-oscillateurs-classification',
    );
  });

  test('Unknown, empty, generic and partial names have no reference', () {
    for (final query in [
      '',
      '  ',
      'SVT',
      'Mathématiques',
      'Physique-Chimie',
      'La photosynthèse',
      'Poursuites judiciaires',
      'oscillateursXYZ',
      'pendule',
      'réelles',
      's',
      'synthèse',
    ]) {
      expect(SummarySheetRegistry.findSheetFor(query), isNull, reason: query);
    }
  });

  test(
    'Ambiguous topics do not choose the first entry; specific topics prevail',
    () {
      expect(
        SummarySheetRegistry.findSheetFor('Suites et oscillateurs'),
        isNull,
      );
      expect(
        SummarySheetRegistry.findSheetFor(
          'Oscillateurs : pendule élastique',
        )?.id,
        'physique-pendule-elastique-dynamique',
      );
    },
  );
}
