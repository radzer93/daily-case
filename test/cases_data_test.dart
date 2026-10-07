import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_case/models/case_file.dart';

/// Pilnuje poprawności assets/cases.json. Uruchamiaj po każdej nowej sprawie.
void main() {
  final raw = jsonDecode(File('assets/cases.json').readAsStringSync()) as List;
  final cases = raw.map((e) => CaseFile.fromJson(e as Map<String, dynamic>)).toList();

  test('jest co najmniej jedna sprawa, id są unikalne', () {
    expect(cases, isNotEmpty);
    final ids = cases.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final c in cases) {
    group(c.id, () {
      test('rozwiązanie wskazuje istniejące elementy', () {
        expect(c.suspects.map((s) => s.id), contains(c.solution.culprit));
        expect(c.motives.map((m) => m.id), contains(c.solution.motive));
        expect(c.solution.evidence, isNotEmpty);
        for (final e in c.solution.evidence) {
          expect(c.evidence.map((x) => x.id), contains(e));
        }
      });

      test('da się rozwiązać bez ekspertyz', () {
        final open = c.evidence.where((e) => !e.hint).map((e) => e.id).toSet();
        expect(c.solution.evidence.any(open.contains), isTrue,
            reason: 'Przynajmniej jeden rozstrzygający dowód musi być jawny.');
      });

      test('ma wystarczająco opcji do wyboru', () {
        expect(c.suspects.length, greaterThanOrEqualTo(3));
        expect(c.motives.length, greaterThanOrEqualTo(3));
        expect(c.solution.explain, isNotEmpty);
      });

      test('id w obrębie sprawy są unikalne', () {
        final s = c.suspects.map((x) => x.id).toList();
        final e = c.evidence.map((x) => x.id).toList();
        final m = c.motives.map((x) => x.id).toList();
        expect(s.toSet().length, s.length);
        expect(e.toSet().length, e.length);
        expect(m.toSet().length, m.length);
      });

      test('sprawa inspirowana ma adnotację o źródle', () {
        if (c.isInspired) expect(c.note, isNotNull);
      });
    });
  }
}
