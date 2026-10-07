import 'dart:convert';
import 'dart:io';

import 'package:daily_case/data/game_backend.dart';
import 'package:daily_case/data/local_backend.dart';
import 'package:daily_case/models/case_file.dart';
import 'package:daily_case/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = (jsonDecode(File('assets/cases.json').readAsStringSync()) as List)
      .map((e) => CaseFile.fromJson(e as Map<String, dynamic>))
      .toList();

  late DateTime now;
  late SharedPreferences prefs;

  LocalGameBackend backend() => LocalGameBackend(
        loadCases: () async => cases,
        prefs: prefs,
        clock: () => now,
      );

  Future<GameController> loaded() async {
    final g = GameController(backend: backend(), prefs: prefs, clock: () => now);
    await g.load();
    return g;
  }

  CaseFile fullFor(GameController g) => cases[(g.current.dayNumber! - 1) % cases.length];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 7, 12);
  });

  test('day one: case #1 without solution or hint texts', () async {
    final g = await loaded();
    expect(g.state, LoadState.ready);
    expect(g.current.dayNumber, 1);
    expect(g.current.title, cases.first.title);
    expect(g.current.solution, isNull);
    expect(g.progress.solution, isNull);
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    expect(g.isEvidenceVisible(hint), isFalse);
    expect(g.evidenceText(hint), isNull);
  });

  test('win on second attempt: 80 points, streak 1, solution revealed', () async {
    final g = await loaded();
    final sol = fullFor(g).solution!;
    final wrongMotive = g.current.motives.firstWhere((m) => m.id != sol.motive).id;

    expect(await g.accuse(culprit: sol.culprit, motive: wrongMotive, evidence: sol.evidence.first), isNull);
    expect(g.progress.attempts.single.result, [true, false, true]);
    expect(g.progress.done, isFalse);
    expect(g.progress.solution, isNull);

    await g.accuse(culprit: sol.culprit, motive: sol.motive, evidence: sol.evidence.first);
    expect(g.progress.won, isTrue);
    expect(g.progress.score, 80);
    expect(g.progress.solution, isNotNull);
    expect(g.stats.streak, 1);
    expect(g.stats.played, 1);
    expect(g.shareText, contains('🟩🟥🟩\n🟩🟩🟩'));

    final again = await loaded();
    expect(again.progress.won, isTrue);
    expect(again.progress.attempts.length, 2);
  });

  test('three misses: case dismissed, solution only on the next day', () async {
    final g = await loaded();
    final sol = fullFor(g).solution!;
    final wrong = g.current.suspects.firstWhere((s) => s.id != sol.culprit).id;
    for (var i = 0; i < 3; i++) {
      await g.accuse(culprit: wrong, motive: sol.motive, evidence: sol.evidence.first);
    }
    expect(g.progress.done, isTrue);
    expect(g.progress.dismissed, isTrue);
    expect(g.progress.solution, isNull);
    expect(g.current.evidence.where((e) => e.hint).every(g.isEvidenceVisible), isTrue);

    now = DateTime(2026, 10, 8, 9);
    final next = await loaded();
    final err = await next.openArchive(LocalGameBackend.refFor(1));
    expect(err, isNull);
    expect(next.isDaily, isFalse);
    expect(next.progress.solution?.culprit, sol.culprit);
  });

  test('after midnight the case lapses and accusations are rejected', () async {
    final g = await loaded();
    final sol = fullFor(g).solution!;
    now = DateTime(2026, 10, 8, 0, 5);
    await expectLater(
      backend().accuse(LocalGameBackend.refFor(1),
          culprit: sol.culprit, motive: sol.motive, evidence: sol.evidence.first),
      throwsA(isA<BackendException>()),
    );
    final view = await backend().caseById(LocalGameBackend.refFor(1));
    expect(view.progress.lapsed, isTrue);
    expect(view.progress.solution, isNotNull);
  });

  test('streak grows day by day and resets after a gap', () async {
    Future<void> winToday() async {
      final g = await loaded();
      final s = fullFor(g).solution!;
      await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    }

    await winToday();
    now = DateTime(2026, 10, 8, 9);
    await winToday();
    expect((await loaded()).stats.streak, 2);

    now = DateTime(2026, 10, 10, 9);
    final g = await loaded();
    expect(g.stats.streak, 0);
    expect(g.stats.best, 2);
  });

  test('hint reveals its text and lowers the score', () async {
    final g = await loaded();
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    expect(await g.unlockHint(hint.id), isNull);
    expect(g.isEvidenceVisible(hint), isTrue);
    expect(g.evidenceText(hint), isNotEmpty);

    final s = fullFor(g).solution!;
    await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    expect(g.progress.score, 90);
    expect(g.shareText, contains('Ekspertyzy: 1 · 90 pkt'));
  });

  test('locked hint evidence cannot be used in an accusation', () async {
    final g = await loaded();
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    final s = fullFor(g).solution!;
    final err = await g.accuse(culprit: s.culprit, motive: s.motive, evidence: hint.id);
    expect(err, isNotNull);
    expect(g.progress.attempts, isEmpty);
  });

  test('archive lists previous days', () async {
    now = DateTime(2026, 10, 10, 9);
    final g = await loaded();
    final list = await g.archive();
    expect(list.map((e) => e.dayNumber), [3, 2, 1]);
    expect(list.every((e) => !e.won && e.attempts == 0), isTrue);
  });

  test('excluded suspects are remembered per case', () async {
    final g = await loaded();
    final id = g.current.suspects.first.id;
    g.toggleExcluded(id);
    expect(g.isExcluded(id), isTrue);
    expect((await loaded()).isExcluded(id), isTrue);
  });
}
