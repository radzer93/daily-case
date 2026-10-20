import 'dart:convert';
import 'dart:io';

import 'package:daily_case/data/game_backend.dart';
import 'package:daily_case/data/local_backend.dart';
import 'package:daily_case/l10n/app_localizations_pl.dart';
import 'package:daily_case/l10n/labels.dart';
import 'package:daily_case/models/case_file.dart';
import 'package:daily_case/models/feedback.dart';
import 'package:daily_case/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = (jsonDecode(File('assets/cases.json').readAsStringSync()) as List)
      .map((e) => CaseFile.fromJson(e as Map<String, dynamic>))
      .toList();

  final l = AppLocalizationsPl();
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

  CaseFile fullFor(GameController g) =>
      cases[(g.current.dayNumber! - 1 + g.current.difficulty.index) % cases.length];

  Future<void> useLevel(Difficulty d) async {
    SharedPreferences.setMockInitialValues({'daily-case:difficulty': d.wire});
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    await useLevel(Difficulty.easy);
    now = DateTime(2026, 10, 7, 12);
  });

  group('difficulty choice', () {
    test('first launch asks for a level, choice is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final g = await loaded();
      expect(g.needsDifficultyChoice, isTrue);
      await g.setDifficulty(Difficulty.hard);
      expect(g.needsDifficultyChoice, isFalse);
      expect(g.current.difficulty, Difficulty.hard);
      expect((await loaded()).difficulty, Difficulty.hard);
    });

    test('each level has a different case on the same day', () async {
      final g = await loaded();
      final titles = <String>{};
      for (final d in Difficulty.values) {
        await g.setDifficulty(d);
        expect(g.current.difficulty, d);
        titles.add(g.current.title);
      }
      expect(titles.length, 3);
      expect(g.levels.keys.toSet(), Difficulty.values.toSet());
    });

    test('levels keep separate progress and a win shows in the switcher', () async {
      final g = await loaded();
      final s = fullFor(g).solution!;
      await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
      expect(g.levels[Difficulty.easy]?.won, isTrue);

      await g.setDifficulty(Difficulty.hard);
      expect(g.progress.attempts, isEmpty);
      expect(g.levels[Difficulty.easy]?.won, isTrue);
      expect(g.levels[Difficulty.hard]?.won, isFalse);
    });

    test('score multiplier: medium x1.5, hard x2', () async {
      for (final (level, expected) in [(Difficulty.medium, 150), (Difficulty.hard, 200)]) {
        await useLevel(level);
        final g = await loaded();
        final s = fullFor(g).solution!;
        await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
        expect(g.progress.score, expected);
        expect(g.shareText(l), contains(l.levelName(level).toUpperCase()));
      }
    });
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
    expect(g.shareText(l), contains('🟩🟥🟩\n🟩🟩🟩'));

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
    final err = await next.openArchive(LocalGameBackend.refFor(1, Difficulty.easy));
    expect(err, isNull);
    expect(next.isDaily, isFalse);
    expect(next.progress.solution?.culprit, sol.culprit);
  });

  test('after midnight the case lapses and accusations are rejected', () async {
    final g = await loaded();
    final sol = fullFor(g).solution!;
    now = DateTime(2026, 10, 8, 0, 5);
    await expectLater(
      backend().accuse(LocalGameBackend.refFor(1, Difficulty.easy),
          culprit: sol.culprit, motive: sol.motive, evidence: sol.evidence.first),
      throwsA(isA<BackendException>()),
    );
    final view = await backend().caseById(LocalGameBackend.refFor(1, Difficulty.easy));
    expect(view.progress.lapsed, isTrue);
    expect(view.progress.solution, isNotNull);
  });

  test('streak grows day by day on any level and resets after a gap', () async {
    Future<void> winToday(Difficulty d) async {
      await useLevel(d);
      final g = await loaded();
      final s = fullFor(g).solution!;
      await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    }

    await winToday(Difficulty.easy);
    now = DateTime(2026, 10, 8, 9);
    final prev = prefs.getString(LocalGameBackend.storageKey);
    await useLevel(Difficulty.hard);
    await prefs.setString(LocalGameBackend.storageKey, prev!);
    final g = await loaded();
    final s = fullFor(g).solution!;
    await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    expect(g.stats.streak, 2);

    now = DateTime(2026, 10, 10, 9);
    final later = await loaded();
    expect(later.stats.streak, 0);
    expect(later.stats.best, 2);
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
    expect(g.shareText(l), contains('Ekspertyzy: 1 · 90 pkt'));
  });

  test('locked hint evidence cannot be used in an accusation', () async {
    final g = await loaded();
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    final s = fullFor(g).solution!;
    final err = await g.accuse(culprit: s.culprit, motive: s.motive, evidence: hint.id);
    expect(err, isNotNull);
    expect(g.progress.attempts, isEmpty);
  });

  test('archive lists previous days on every level', () async {
    now = DateTime(2026, 10, 10, 9);
    final g = await loaded();
    final list = await g.archive();
    expect(list.length, 9);
    expect(list.map((e) => e.dayNumber).toSet(), {1, 2, 3});
    expect(list.first.dayNumber, 3);
    expect(list.take(3).map((e) => e.difficulty), Difficulty.values);
    expect(list.every((e) => !e.won && e.attempts == 0), isTrue);
  });

  test('excluded suspects are remembered per case', () async {
    final g = await loaded();
    final id = g.current.suspects.first.id;
    g.toggleExcluded(id);
    expect(g.isExcluded(id), isTrue);
    expect((await loaded()).isExcluded(id), isTrue);
  });

  group('feedback', () {
    test('rating is only possible after the case is finished', () async {
      final g = await loaded();
      expect(g.canGiveFeedback, isFalse);
      expect(await g.rateCase(5), isNull);
      expect(g.progress.myRating, isNull);

      final s = fullFor(g).solution!;
      await g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
      expect(g.canGiveFeedback, isTrue);
      expect(await g.rateCase(4), isNull);
      expect(g.progress.myRating, 4);
      expect(g.progress.won, isTrue);

      expect(await g.reportCase(FeedbackReason.contradiction), isNull);
      expect(g.progress.reported, isTrue);
      expect(g.progress.myRating, 4);

      final again = await loaded();
      expect(again.progress.myRating, 4);
      expect(again.progress.reported, isTrue);
      expect(again.progress.attempts.length, 1);
    });

    test('backend rejects feedback for an unfinished case', () async {
      final b = backend();
      final t = await b.today(Difficulty.easy);
      expect(() => b.submitFeedback(t.caseFile!.id, rating: 5), throwsA(isA<BackendException>()));
    });

    test('archived cases can be rated only after playing them', () async {
      final first = await loaded();
      final sol = fullFor(first).solution!;
      final wrong = first.current.suspects.firstWhere((s) => s.id != sol.culprit).id;
      await first.accuse(culprit: wrong, motive: sol.motive, evidence: sol.evidence.first);

      now = DateTime(2026, 10, 8, 9);
      final g = await loaded();
      expect(await g.openArchive(LocalGameBackend.refFor(1, Difficulty.medium)), isNull);
      expect(g.canGiveFeedback, isFalse);
      g.openDaily();
      expect(await g.openArchive(LocalGameBackend.refFor(1, Difficulty.easy)), isNull);
      expect(g.canGiveFeedback, isTrue);
      expect(await g.rateCase(2), isNull);
      expect(g.progress.myRating, 2);
      expect(g.isDaily, isFalse);
    });
  });

  group('age gate', () {
    test('starts unknown, an adult is allowed and remembered', () async {
      final g = await loaded();
      expect(g.ageGate, AgeGate.unknown);
      expect(await g.submitBirthDate(DateTime(1990, 3, 3)), isTrue);
      expect(g.ageGate, AgeGate.allowed);
      expect((await loaded()).ageGate, AgeGate.allowed);
    });

    test('a 15-year-old is denied', () async {
      final g = await loaded();
      expect(await g.submitBirthDate(DateTime(2011, 1, 1)), isFalse);
      expect(g.ageGate, AgeGate.denied);
    });
  });

  test('backend errors are codes, not texts', () async {
    final g = await loaded();
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    final s = fullFor(g).solution!;
    expect(await g.accuse(culprit: s.culprit, motive: s.motive, evidence: hint.id), BackendError.invalidChoice);
    expect(l.errorText(BackendError.invalidChoice), isNotEmpty);
  });
}
