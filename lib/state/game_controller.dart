import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/case_repository.dart';
import '../logic/rules.dart';
import '../models/case_file.dart';
import '../models/progress.dart';

/// Cały stan gry: która sprawa jest otwarta, postęp, statystyki.
/// Zapisywany lokalnie w SharedPreferences.
class GameController extends ChangeNotifier {
  GameController._(this.cases, this._prefs, this._clock);

  static const storageKey = 'daily-case:v1';

  final List<CaseFile> cases;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  late int today;
  late int dailyIndex;
  int currentIndex = 0;
  bool isDaily = true;

  final Map<String, CaseProgress> _progress = {};
  Stats stats = Stats();

  static Future<GameController> create({
    required CaseRepository repository,
    required SharedPreferences prefs,
    DateTime Function()? clock,
  }) async {
    final cases = await repository.loadCases();
    if (cases.isEmpty) {
      throw StateError('Brak spraw w repozytorium.');
    }
    final c = GameController._(cases, prefs, clock ?? DateTime.now);
    c._restore();
    c._computeDay();
    c.currentIndex = c.dailyIndex;
    return c;
  }

  // ---------- odczyt ----------

  CaseFile get current => cases[currentIndex];

  /// Klucz postępu: sprawa dnia jest przypisana do numeru dnia,
  /// sprawa z archiwum do swojego id.
  String get progressKey => isDaily ? 'd$today' : 'a-${current.id}';

  CaseProgress get progress =>
      _progress.putIfAbsent(progressKey, () => CaseProgress());

  CaseProgress? archiveProgress(CaseFile c) => _progress['a-${c.id}'];

  int get streakNow => stats.lastWin >= today - 1 ? stats.streak : 0;

  bool isEvidenceVisible(Evidence e) =>
      !e.hint || progress.hints.contains(e.id) || progress.done;

  int get visibleEvidenceCount =>
      current.evidence.where(isEvidenceVisible).length;

  String get shareText => buildShareText(
        title: current.title,
        isDaily: isDaily,
        day: today,
        progress: progress,
        streak: streakNow,
      );

  // ---------- akcje ----------

  void openDaily() {
    isDaily = true;
    currentIndex = dailyIndex;
    notifyListeners();
  }

  void openArchive(int index) {
    isDaily = false;
    currentIndex = index;
    notifyListeners();
  }

  /// Sprawdza, czy zmienił się dzień (np. po powrocie aplikacji z tła).
  bool refreshDay() {
    final d = dayNumber(_clock());
    if (d == today) return false;
    _computeDay();
    if (isDaily) currentIndex = dailyIndex;
    notifyListeners();
    return true;
  }

  void unlockHint(String evidenceId) {
    final p = progress;
    if (p.done || p.hints.contains(evidenceId)) return;
    p.hints.add(evidenceId);
    _save();
    notifyListeners();
  }

  void toggleExcluded(String suspectId) {
    final p = progress;
    if (!p.excluded.remove(suspectId)) p.excluded.add(suspectId);
    _save();
    notifyListeners();
  }

  Attempt accuse({
    required String culprit,
    required String motive,
    required String evidence,
  }) {
    final p = progress;
    if (p.done) throw StateError('Sprawa jest już zamknięta.');
    final sol = current.solution;
    final attempt = Attempt(
      culprit: culprit,
      motive: motive,
      evidence: evidence,
      result: [
        culprit == sol.culprit,
        motive == sol.motive,
        sol.evidence.contains(evidence),
      ],
    );
    p.attempts.add(attempt);

    if (attempt.correct || p.attempts.length >= maxAttempts) {
      p.done = true;
      p.won = attempt.correct;
      if (isDaily) _recordDailyResult(attempt.correct);
    }
    _save();
    notifyListeners();
    return attempt;
  }

  // ---------- wewnętrzne ----------

  void _computeDay() {
    today = dayNumber(_clock());
    dailyIndex = dailyCaseIndex(today, cases.length);
  }

  void _recordDailyResult(bool won) {
    stats.played++;
    if (won) {
      stats.won++;
      stats.streak = stats.lastWin == today - 1 ? stats.streak + 1 : 1;
      stats.lastWin = today;
      if (stats.streak > stats.best) stats.best = stats.streak;
    } else {
      stats.streak = 0;
    }
  }

  void _restore() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final cs = (j['cases'] as Map?) ?? const {};
      cs.forEach((k, v) {
        _progress[k as String] =
            CaseProgress.fromJson(Map<String, dynamic>.from(v as Map));
      });
      if (j['stats'] is Map) {
        stats = Stats.fromJson(Map<String, dynamic>.from(j['stats'] as Map));
      }
    } catch (e) {
      debugPrint('Nie udało się odczytać zapisu gry: $e');
    }
  }

  void _save() {
    final data = {
      'cases': _progress.map((k, v) => MapEntry(k, v.toJson())),
      'stats': stats.toJson(),
    };
    unawaited(_prefs.setString(storageKey, jsonEncode(data)));
  }
}
