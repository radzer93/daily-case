import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/rules.dart';
import '../models/case_file.dart';
import '../models/progress.dart';
import 'game_backend.dart';

class LocalGameBackend implements GameBackend {
  LocalGameBackend({
    required Future<List<CaseFile>> Function() loadCases,
    required SharedPreferences prefs,
    DateTime Function()? clock,
  })  : _loadCases = loadCases,
        _prefs = prefs,
        _clock = clock ?? DateTime.now;

  static const storageKey = 'daily-case:local:v2';
  final Future<List<CaseFile>> Function() _loadCases;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  List<CaseFile>? _cases;

  int get _today => dayNumber(_clock());

  static String refFor(int day) => 'local-$day';

  int _dayOf(String ref) {
    final d = int.tryParse(ref.replaceFirst('local-', ''));
    if (d == null) throw const BackendException('Nie znaleziono sprawy.');
    return d;
  }

  Future<CaseFile> _full(int day) async {
    final all = _cases ??= await _loadCases();
    if (all.isEmpty) throw const BackendException('Brak spraw w pliku.');
    return all[dailyCaseIndex(day, all.length)];
  }

  Map<String, dynamic> _readStore() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void _writeStore(Map<String, dynamic> store) =>
      unawaited(_prefs.setString(storageKey, jsonEncode(store)));

  ({List<Attempt> attempts, List<String> unlocked}) _dayState(int day) {
    final d = _readStore()['$day'];
    if (d is! Map) return (attempts: <Attempt>[], unlocked: <String>[]);
    return (
      attempts: (d['attempts'] as List? ?? const [])
          .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      unlocked: List<String>.from(d['unlocked'] as List? ?? const []),
    );
  }

  void _saveDay(int day, List<Attempt> attempts, List<String> unlocked) {
    final store = _readStore();
    store['$day'] = {
      'attempts': attempts.map((a) => a.toJson()).toList(),
      'unlocked': unlocked,
    };
    _writeStore(store);
  }

  CaseProgress _progress(CaseFile full, int day) {
    final s = _dayState(day);
    final won = s.attempts.any((a) => a.correct);
    final expired = day < _today;
    final done = won || s.attempts.length >= maxAttempts || expired;
    return CaseProgress(
      attempts: s.attempts,
      unlocked: s.unlocked.toSet(),
      hintTexts: {
        for (final e in full.evidence)
          if (e.hint && e.text != null && (done || s.unlocked.contains(e.id))) e.id: e.text!,
      },
      done: done,
      won: won,
      expired: expired,
      score: computeScore(won: won, attempts: s.attempts.length, hints: s.unlocked.length),
      solution: won || expired ? full.solution : null,
    );
  }

  CaseFile _public(CaseFile full, int day) =>
      full.publicView(id: refFor(day), dayNumber: day, caseDate: dateOfDay(day));

  Future<int> _openToday(String ref) async {
    final day = _dayOf(ref);
    if (day != _today) throw const BackendException('Ta sprawa jest już zamknięta. Po północy czeka nowa.');
    final p = _progress(await _full(day), day);
    if (p.done) throw const BackendException('Ta sprawa jest już zakończona.');
    return day;
  }

  @override
  Future<TodayResult> today() async {
    final day = _today;
    final full = await _full(day);
    final now = _clock();
    return TodayResult(
      caseFile: _public(full, day),
      progress: _progress(full, day),
      closesAt: DateTime(now.year, now.month, now.day + 1),
    );
  }

  @override
  Future<CaseView> caseById(String ref) async {
    final day = _dayOf(ref);
    if (day > _today) throw const BackendException('Nie znaleziono sprawy.');
    final full = await _full(day);
    return CaseView(_public(full, day), _progress(full, day));
  }

  @override
  Future<CaseProgress> accuse(
    String caseRef, {
    required String culprit,
    required String motive,
    required String evidence,
  }) async {
    final day = await _openToday(caseRef);
    final full = await _full(day);
    final s = _dayState(day);

    final ev = full.evidence.where((e) => e.id == evidence).toList();
    final validChoice = full.suspects.any((x) => x.id == culprit) &&
        full.motives.any((m) => m.id == motive) &&
        ev.isNotEmpty &&
        (!ev.first.hint || s.unlocked.contains(evidence));
    if (!validChoice) throw const BackendException('Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.');

    final sol = full.solution!;
    final attempts = [
      ...s.attempts,
      Attempt(
        culprit: culprit,
        motive: motive,
        evidence: evidence,
        result: [culprit == sol.culprit, motive == sol.motive, sol.evidence.contains(evidence)],
      ),
    ];
    _saveDay(day, attempts, s.unlocked);
    return _progress(full, day);
  }

  @override
  Future<CaseProgress> unlockHint(String caseRef, String evidenceId) async {
    final day = await _openToday(caseRef);
    final full = await _full(day);
    if (!full.evidence.any((e) => e.id == evidenceId && e.hint)) {
      throw const BackendException('Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.');
    }
    final s = _dayState(day);
    if (!s.unlocked.contains(evidenceId)) {
      _saveDay(day, s.attempts, [...s.unlocked, evidenceId]);
    }
    return _progress(full, day);
  }

  @override
  Future<Stats> stats() async {
    final today = _today;
    var played = 0, won = 0;
    final winDays = <int>[];
    for (final entry in _readStore().entries) {
      final day = int.tryParse(entry.key);
      if (day == null) continue;
      final s = _dayState(day);
      if (s.attempts.isEmpty) continue;
      final isWin = s.attempts.any((a) => a.correct);
      if (isWin) {
        won++;
        winDays.add(day);
      }
      if (isWin || s.attempts.length >= maxAttempts || day < today) played++;
    }

    winDays.sort();
    var best = 0, run = 0, streak = 0;
    for (var i = 0; i < winDays.length; i++) {
      run = (i > 0 && winDays[i] == winDays[i - 1] + 1) ? run + 1 : 1;
      if (run > best) best = run;
    }
    if (winDays.isNotEmpty && winDays.last >= today - 1) streak = run;

    return Stats(streak: streak, best: best, played: played, won: won);
  }

  @override
  Future<List<ArchiveEntry>> archive() async {
    final today = _today;
    final out = <ArchiveEntry>[];
    for (var day = today - 1; day >= 1 && day >= today - 60; day--) {
      final full = await _full(day);
      final s = _dayState(day);
      out.add(ArchiveEntry(
        ref: refFor(day),
        title: full.title,
        kind: full.kind,
        docket: full.docket,
        place: full.place,
        caseDate: dateOfDay(day),
        dayNumber: day,
        won: s.attempts.any((a) => a.correct),
        attempts: s.attempts.length,
      ));
    }
    return out;
  }
}
