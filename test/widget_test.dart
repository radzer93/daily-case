import 'package:flutter_test/flutter_test.dart';
import 'package:daily_case/logic/rules.dart';

void main() {
  test('maximum number of attempts', () => expect(maxAttempts, 3));
}
