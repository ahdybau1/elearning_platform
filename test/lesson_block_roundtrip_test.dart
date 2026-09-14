import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/models/editable_lesson_block.dart';
import 'package:admin_app/core/models/lesson_block_model.dart';

void main() {
  test(
    'Legacy editor preserves Studio metadata, identifiers and media-only blocks',
    () {
      final content =
          jsonDecode(
                File(
                  '../test_fixtures/studio_course_v2.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final raw in content['blocks'] as List) {
        final original = Map<String, dynamic>.from(raw as Map);
        final block = EditableLessonBlock.fromJson(original);
        addTearDown(block.dispose);
        expect(block.isEmpty, isFalse);
        final saved = block.toJson(original['order'] as int);
        expect(saved['metadata'], original['metadata']);
        expect(saved['id'], original['id']);
        expect(LessonBlock.fromJson(saved).metadata, original['metadata']);
      }
    },
  );
  test('Editing text retains renderer metadata', () {
    final block = EditableLessonBlock.fromJson({
      'id': 'a',
      'type': 'custom',
      'body': 'Avant',
      'renderer_key': 'custom_v3',
      'metadata': {'url': 'asset'},
    });
    addTearDown(block.dispose);
    block.bodyCtrl.text = 'Après';
    expect(block.toJson(1), containsPair('renderer_key', 'custom_v3'));
    expect(block.toJson(1), containsPair('body', 'Après'));
  });
}
