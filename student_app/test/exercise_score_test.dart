import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/features/courses/screens/exercise_runner_screen.dart';

void main() {
  test('un QCM correct attribue les points prévus', () {
    expect(
      confirmedPointsForAnswer(format: 'qcm', points: 3, isQcmCorrect: true),
      3,
    );
  });

  test('un QCM incorrect ne donne aucun point', () {
    expect(
      confirmedPointsForAnswer(format: 'qcm', points: 3, isQcmCorrect: false),
      0,
    );
  });

  test('une réponse libre non évaluée ne donne aucun point automatique', () {
    expect(
      confirmedPointsForAnswer(
        format: 'redaction',
        points: 5,
        isQcmCorrect: false,
      ),
      0,
    );
  });
}
