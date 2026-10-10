import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/rules.dart';
import '../models/case_file.dart';
import '../models/progress.dart';
import 'game_backend.dart';

typedef _Slot = ({int day, Difficulty difficulty});

class LocalGameBackend implements GameBackend {
  LocalGameBackend({
    required Future<List<CaseFile>> Function() loadCases,
    required SharedPreferences prefs,
    DateTime Function()? clock,
  })  : _loadCases = loadCases,
        _prefs = prefs,
        _clock = clock ?? DateTime.now;

  static const storageKey = 'daily-case:local:v3';
  final Future<List<CaseFile>> Function() _loadCases;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  List<CaseFile>? _cases;

  int get _today => dayNumber(_clock());

  static String refFor(int day, Difficulty difficulty) => 'local-$day-${difficulty.wire}';

  static String _storeKey(_Slot s) => '${s.day}:${s.difficulty.wire}';

  _Slot _slotOf(String ref) {
    final parts = ref.split('-');
    final day = parts.length == 3 && parts[0] == 'local' ? int.tryParse(parts[1]) : null;
    final difficulty = parts.length == 3 ? Difficulty.tryFromWire(parts[2]) : null;
    if (day == null || difficulty == null) throw const BackendException('Nie znaleziono sprawy.');
    return (day: day, difficulty: difficulty);
  }

  Future<CaseFile> _full(_Slot s) async {
    final all = _cases ??= await _loadCases();
    if (all.isEmpty) throw const BackendException('Brak spraw w pliku.');
    return all[dailyCaseIndex(s.day + s.difficulty.index, all.length)];
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

  ({List<Attempt> attempts, List<String> unlocked}) _state(_Slot s) {
    final d = _readStore()[_storeKey(s)];
    if (d is! Map) return (attempts: <Attempt>[], unlocked: <String>[]);
    return (
      attempts: (d['attempts'] as List? ?? const [])
          .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      unlocked: List<String>.from(d['unlocked'] as List? ?? const []),
    );
  }

  void _save(_Slot s, List<Attempt> attempts, List<String> unlocked) {
    final store = _readStore();
    store[_storeKey(s)] = {
      'attempts': attempts.map((a) => a.toJson()).toList(),
      'unlocked': unlocked,
    };
    _writeStore(store);
  }

  CaseProgress _progress(CaseFile full, _Slot slot) {
    final s = _state(slot);
    final won = s.attempts.any((a) => a.correct);
    final expired = slot.day < _today;
    final done = won || s.attempts.length >= maxAttempts || expired;
    final base = computeScore(won: won, attempts: s.attempts.length, hints: s.unlocked.length);
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
      score: scaleScore(base, slot.difficulty.multiplier),
      solution: won || expired ? full.solution : null,
    );
  }

  CaseFile _public(CaseFile full, _Slot s) => full.publicView(
        id: refFor(s.day, s.difficulty),
        dayNumber: s.day,
        caseDate: dateOfDay(s.day),
        difficulty: s.difficulty,
      );

  Future<_Slot> _openToday(String ref) async {
    final slot = _slotOf(ref);
    if (slot.day != _today) throw const BackendException('Ta sprawa jest już zamknięta. Po północy czeka nowa.');
    final p = _progress(await _full(slot), slot);
    if (p.done) throw const BackendException('Ta sprawa jest już zakończona.');
    return slot;
  }

  @override
  Future<TodayResult> today(Difficulty difficulty) async {
    final day = _today;
    final slot = (day: day, difficulty: difficulty);
    final full = await _full(slot);
    final now = _clock();
    final levels = <Difficulty, LevelStatus>{};
    for (final d in Difficulty.values) {
      final s = (day: day, difficulty: d);
      final p = _progress(await _full(s), s);
      levels[d] = LevelStatus(won: p.won, done: p.done);
    }
    return TodayResult(
      caseFile: _public(full, slot),
      progress: _progress(full, slot),
      closesAt: DateTime(now.year, now.month, now.day + 1),
      levels: levels,
    );
  }

  @override
  Future<CaseView> caseById(String ref) async {
    final slot = _slotOf(ref);
    if (slot.day > _today) throw const BackendException('Nie znaleziono sprawy.');
    final full = await _full(slot);
    return CaseView(_public(full, slot), _progress(full, slot));
  }

  @override
  Future<CaseProgress> accuse(
    String caseRef, {
    required String culprit,
    required String motive,
    required String evidence,
  }) async {
    final slot = await _openToday(caseRef);
    final full = await _full(slot);
    final s = _state(slot);

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
    _save(slot, attempts, s.unlocked);
    return _progress(full, slot);
  }

  @override
  Future<CaseProgress> unlockHint(String caseRef, String evidenceId) async {
    final slot = await _openToday(caseRef);
    final full = await _full(slot);
    if (!full.evidence.any((e) => e.id == evidenceId && e.hint)) {
      throw const BackendException('Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.');
    }
    final s = _state(slot);
    if (!s.unlocked.contains(evidenceId)) {
      _save(slot, s.attempts, [...s.unlocked, evidenceId]);
    }
    return _progress(full, slot);
  }

  @override
  Future<Stats> stats() async {
    final today = _today;
    var played = 0, won = 0;
    final winDays = <int>{};
    for (final key in _readStore().keys) {
      final parts = key.split(':');
      final day = int.tryParse(parts.first);
      final difficulty = parts.length == 2 ? Difficulty.tryFromWire(parts.last) : null;
      if (day == null || difficulty == null) continue;
      final s = _state((day: day, difficulty: difficulty));
      if (s.attempts.isEmpty) continue;
      final isWin = s.attempts.any((a) => a.correct);
      if (isWin) {
        won++;
        winDays.add(day);
      }
      if (isWin || s.attempts.length >= maxAttempts || day < today) played++;
    }

    final days = winDays.toList()..sort();
    var best = 0, run = 0, streak = 0;
    for (var i = 0; i < days.length; i++) {
      run = (i > 0 && days[i] == days[i - 1] + 1) ? run + 1 : 1;
      if (run > best) best = run;
    }
    if (days.isNotEmpty && days.last >= today - 1) streak = run;

    return Stats(streak: streak, best: best, played: played, won: won);
  }

  @override
  Future<List<ArchiveEntry>> archive() async {
    final today = _today;
    final out = <ArchiveEntry>[];
    for (var day = today - 1; day >= 1 && day >= today - 60; day--) {
      for (final difficulty in Difficulty.values) {
        final slot = (day: day, difficulty: difficulty);
        final full = await _full(slot);
        final s = _state(slot);
        out.add(ArchiveEntry(
          ref: refFor(day, difficulty),
          title: full.title,
          kind: full.kind,
          difficulty: difficulty,
          docket: full.docket,
          place: full.place,
          caseDate: dateOfDay(day),
          dayNumber: day,
          won: s.attempts.any((a) => a.correct),
          attempts: s.attempts.length,
        ));
      }
    }
    return out;
  }
}
