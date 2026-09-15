import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/features/courses/screens/subjects_list_screen.dart';

void main() {
  final subjects = [
    Subject(id: '1', name: 'Mathématiques', code: 'MATH'),
    Subject(id: '2', name: 'Physique', code: 'PCT'),
  ];

  test('la recherche de matières ignore la casse et les espaces', () {
    expect(filterSubjects(subjects, '  mathÉ '), [subjects.first]);
  });

  test('la recherche accepte aussi le code matière', () {
    expect(filterSubjects(subjects, 'pct'), [subjects.last]);
  });

  test('une recherche vide conserve toutes les matières', () {
    expect(filterSubjects(subjects, '   '), subjects);
  });
}
