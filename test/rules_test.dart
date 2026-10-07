import 'package:flutter_test/flutter_test.dart';
import 'package:daily_case/logic/rules.dart';
import 'package:daily_case/models/progress.dart';

Attempt _a(List<bool> r) => Attempt(culprit: 'x', motive: 'y', evidence: 'z', result: r);

void main() {
  group('dayNumber', () {
    test('dzień startu ma numer 1, kolejny dzień 2', () {
      expect(dayNumber(DateTime(2026, 10, 7, 0, 1)), 1);
      expect(dayNumber(DateTime(2026, 10, 7, 23, 59)), 1);
      expect(dayNumber(DateTime(2026, 10, 8, 0, 1)), 2);
    });

    test('zmiana czasu (25 października) nie psuje numeracji', () {
      expect(dayNumber(DateTime(2026, 10, 25, 12)), 19);
      expect(dayNumber(DateTime(2026, 10, 26, 0, 30)), 20);
    });
  });

  test('sprawy krążą w kółko', () {
    expect(dailyCaseIndex(1, 5), 0);
    expect(dailyCaseIndex(5, 5), 4);
    expect(dailyCaseIndex(6, 5), 0);
    expect(dailyCaseIndex(0, 5), 4);
  });

  group('score', () {
    test('trafienie za pierwszym razem bez ekspertyz = 100', () {
      final p = CaseProgress(attempts: [_a([true, true, true])], won: true, done: true);
      expect(score(p), 100);
    });

    test('druga próba i jedna ekspertyza = 70', () {
      final p = CaseProgress(
        attempts: [_a([true, false, true]), _a([true, true, true])],
        hints: {'e5'},
        won: true,
        done: true,
      );
      expect(score(p), 70);
    });

    test('trzecia próba i dwie ekspertyzy = 40', () {
      final won = CaseProgress(
        attempts: [_a([false, false, false]), _a([false, false, false]), _a([true, true, true])],
        hints: {'e5', 'e6'},
        won: true,
        done: true,
      );
      expect(score(won), 40);
    });

    test('nigdy poniżej minimum, porażka = 0', () {
      final won = CaseProgress(
        attempts: [_a([false, false, false]), _a([false, false, false]), _a([true, true, true])],
        hints: {'e1', 'e2', 'e3', 'e4', 'e5', 'e6'},
        won: true,
        done: true,
      );
      expect(score(won), minScore);
      expect(score(CaseProgress(done: true)), 0);
    });
  });

  test('plural', () {
    expect(plural(1, 'próba', 'próby', 'prób'), 'próba');
    expect(plural(2, 'próba', 'próby', 'prób'), 'próby');
    expect(plural(5, 'próba', 'próby', 'prób'), 'prób');
    expect(plural(12, 'próba', 'próby', 'prób'), 'prób');
    expect(plural(22, 'próba', 'próby', 'prób'), 'próby');
  });

  test('formatClock', () {
    expect(formatClock(const Duration(hours: 5, minutes: 3, seconds: 9)), '05:03:09');
    expect(formatClock(const Duration(seconds: -4)), '00:00:00');
  });

  test('tekst do udostępnienia nie zdradza rozwiązania', () {
    final p = CaseProgress(
      attempts: [_a([true, false, true]), _a([true, true, true])],
      won: true,
      done: true,
    );
    final text = buildShareText(title: 'Lep na muchy', isDaily: true, day: 3, progress: p, streak: 4);
    expect(text, 'Sprawa Dnia #3 · Lep na muchy\n🟩🟥🟩\n🟩🟩🟩\nEkspertyzy: 0 · 80 pkt · seria 4');
  });
}
