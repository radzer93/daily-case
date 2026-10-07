import 'dart:convert';
import 'dart:io';

import 'package:daily_case/models/case_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = jsonDecode(File('assets/cases.json').readAsStringSync()) as List;
  final cases = raw.map((e) => CaseFile.fromJson(e as Map<String, dynamic>)).toList();

  test('has at least one case with unique ids', () {
    expect(cases, isNotEmpty);
    final ids = cases.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final c in cases) {
    group(c.id, () {
      test('has a solution and text for every piece of evidence', () {
        expect(c.solution, isNotNull);
        for (final e in c.evidence) {
          expect(e.text, isNotNull, reason: 'Evidence ${e.id} has no text.');
        }
      });

      test('solution references existing elements', () {
        final sol = c.solution!;
        expect(c.suspects.map((s) => s.id), contains(sol.culprit));
        expect(c.motives.map((m) => m.id), contains(sol.motive));
        expect(sol.evidence, isNotEmpty);
        for (final e in sol.evidence) {
          expect(c.evidence.map((x) => x.id), contains(e));
        }
      });

      test('is solvable without hints', () {
        final open = c.evidence.where((e) => !e.hint).map((e) => e.id).toSet();
        expect(c.solution!.evidence.any(open.contains), isTrue,
            reason: 'At least one key piece of evidence must be public.');
      });

      test('offers enough choices', () {
        expect(c.suspects.length, greaterThanOrEqualTo(3));
        expect(c.motives.length, greaterThanOrEqualTo(3));
        expect(c.solution!.explain, isNotEmpty);
      });

      test('ids are unique within the case', () {
        final s = c.suspects.map((x) => x.id).toList();
        final e = c.evidence.map((x) => x.id).toList();
        final m = c.motives.map((x) => x.id).toList();
        expect(s.toSet().length, s.length);
        expect(e.toSet().length, e.length);
        expect(m.toSet().length, m.length);
      });

      test('inspired case has a source note', () {
        if (c.isInspired) expect(c.note, isNotNull);
      });

      test('public view hides the solution and hint texts', () {
        final pub = c.publicView(id: 'x');
        expect(pub.solution, isNull);
        for (final e in pub.evidence.where((e) => e.hint)) {
          expect(e.text, isNull);
        }
      });
    });
  }
}
