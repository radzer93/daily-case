// Ten plik istnieje celowo: `flutter create .` nie nadpisuje istniejących plików,
// więc nie doda domyślnego testu z licznikiem (który by się nie skompilował).
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_case/logic/rules.dart';

void main() {
  test('maksymalna liczba prób', () => expect(maxAttempts, 3));
}
