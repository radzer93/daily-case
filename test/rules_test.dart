import 'package:daily_case/logic/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayNumber', () {
    test('launch day is day 1, the next day is day 2', () {
      expect(dayNumber(DateTime(2026, 10, 7, 0, 1)), 1);
      expect(dayNumber(DateTime(2026, 10, 7, 23, 59)), 1);
      expect(dayNumber(DateTime(2026, 10, 8, 0, 1)), 2);
    });

    test('DST change (25 October) does not break numbering', () {
      expect(dayNumber(DateTime(2026, 10, 25, 12)), 19);
      expect(dayNumber(DateTime(2026, 10, 26, 0, 30)), 20);
    });

    test('dateOfDay is the inverse of dayNumber', () {
      expect(dateOfDay(1), '2026-10-07');
      expect(dateOfDay(26), '2026-11-01');
    });
  });

  test('cases rotate in a cycle', () {
    expect(dailyCaseIndex(1, 5), 0);
    expect(dailyCaseIndex(5, 5), 4);
    expect(dailyCaseIndex(6, 5), 0);
    expect(dailyCaseIndex(0, 5), 4);
  });

  group('computeScore', () {
    test('first attempt without hints = 100', () {
      expect(computeScore(won: true, attempts: 1, hints: 0), 100);
    });
    test('second attempt with one hint = 70', () {
      expect(computeScore(won: true, attempts: 2, hints: 1), 70);
    });
    test('third attempt with two hints = 40', () {
      expect(computeScore(won: true, attempts: 3, hints: 2), 40);
    });
    test('never below minimum, loss = 0', () {
      expect(computeScore(won: true, attempts: 3, hints: 9), minScore);
      expect(computeScore(won: false, attempts: 3, hints: 0), 0);
    });
  });

  test('scaleScore applies the difficulty multiplier', () {
    expect(scaleScore(80, 1.0), 80);
    expect(scaleScore(70, 1.5), 105);
    expect(scaleScore(10, 2.0), 20);
  });

  test('share text names the level when given', () {
    final text = buildShareText(
      title: 'Lep na muchy',
      day: 3,
      rows: const [
        [true, true, true],
      ],
      hints: 1,
      won: true,
      score: 180,
      streak: 0,
      level: 'Trudna',
    );
    expect(text, 'Sprawa Dnia #3 · TRUDNA · Lep na muchy\n🟩🟩🟩\nEkspertyzy: 1 · 180 pkt');
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

  test('share text does not reveal the solution', () {
    final text = buildShareText(
      title: 'Lep na muchy',
      day: 3,
      rows: const [
        [true, false, true],
        [true, true, true],
      ],
      hints: 0,
      won: true,
      score: 80,
      streak: 4,
    );
    expect(text, 'Sprawa Dnia #3 · Lep na muchy\n🟩🟥🟩\n🟩🟩🟩\nEkspertyzy: 0 · 80 pkt · seria 4');
  });
}
