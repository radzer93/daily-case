import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_case/data/case_repository.dart';
import 'package:daily_case/models/case_file.dart';
import 'package:daily_case/state/game_controller.dart';

class _FileRepo implements CaseRepository {
  @override
  Future<List<CaseFile>> loadCases() async {
    final raw = jsonDecode(File('assets/cases.json').readAsStringSync()) as List;
    return raw.map((e) => CaseFile.fromJson(e as Map<String, dynamic>)).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  Future<GameController> make() async => GameController.create(
        repository: _FileRepo(),
        prefs: await SharedPreferences.getInstance(),
        clock: () => now,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 7, 12);
  });

  test('pierwszego dnia otwiera się pierwsza sprawa', () async {
    final g = await make();
    expect(g.today, 1);
    expect(g.current.id, g.cases.first.id);
    expect(g.isDaily, isTrue);
  });

  test('wygrana w drugiej próbie: seria 1, zapis przetrwa restart', () async {
    final g = await make();
    final sol = g.current.solution;
    final wrongMotive = g.current.motives.firstWhere((m) => m.id != sol.motive).id;

    final first = g.accuse(culprit: sol.culprit, motive: wrongMotive, evidence: sol.evidence.first);
    expect(first.result, [true, false, true]);
    expect(g.progress.done, isFalse);

    final second = g.accuse(culprit: sol.culprit, motive: sol.motive, evidence: sol.evidence.first);
    expect(second.correct, isTrue);
    expect(g.progress.won, isTrue);
    expect(g.stats.played, 1);
    expect(g.streakNow, 1);

    final restored = await make();
    expect(restored.progress.done, isTrue);
    expect(restored.progress.attempts.length, 2);
    expect(restored.streakNow, 1);
  });

  test('trzy chybione próby zamykają sprawę i zerują serię', () async {
    final g = await make();
    final sol = g.current.solution;
    final wrong = g.current.suspects.firstWhere((s) => s.id != sol.culprit).id;
    for (var i = 0; i < 3; i++) {
      g.accuse(culprit: wrong, motive: sol.motive, evidence: sol.evidence.first);
    }
    expect(g.progress.done, isTrue);
    expect(g.progress.won, isFalse);
    expect(g.streakNow, 0);
    expect(() => g.accuse(culprit: sol.culprit, motive: sol.motive, evidence: sol.evidence.first),
        throwsStateError);
  });

  test('seria rośnie dzień po dniu i przepada po przerwie', () async {
    Future<void> winToday() async {
      final g = await make();
      final s = g.current.solution;
      g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    }

    await winToday();
    now = DateTime(2026, 10, 8, 9);
    await winToday();
    expect((await make()).streakNow, 2);

    now = DateTime(2026, 10, 10, 9); // jeden dzień przerwy
    expect((await make()).streakNow, 0);
  });

  test('archiwum nie wpływa na statystyki', () async {
    final g = await make();
    g.openArchive(2);
    final s = g.current.solution;
    g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    expect(g.progress.won, isTrue);
    expect(g.stats.played, 0);
    g.openDaily();
    expect(g.progress.attempts, isEmpty);
  });

  test('ekspertyza odsłania dowód i obniża wynik', () async {
    final g = await make();
    final hint = g.current.evidence.firstWhere((e) => e.hint);
    expect(g.isEvidenceVisible(hint), isFalse);
    g.unlockHint(hint.id);
    expect(g.isEvidenceVisible(hint), isTrue);
    final s = g.current.solution;
    g.accuse(culprit: s.culprit, motive: s.motive, evidence: s.evidence.first);
    expect(g.shareText, contains('Ekspertyzy: 1 · 90 pkt'));
  });
}
