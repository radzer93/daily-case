import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_backend.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../logic/rules.dart';
import '../models/case_file.dart';
import '../models/feedback.dart';
import '../models/progress.dart';

enum LoadState { loading, ready, noCase, error }

enum AgeGate {
  unknown(null),
  allowed('allowed'),
  denied('denied');

  const AgeGate(this.wire);
  final String? wire;

  static AgeGate fromWire(String? value) {
    for (final g in values) {
      if (g.wire != null && g.wire == value) return g;
    }
    return unknown;
  }
}

class GameController extends ChangeNotifier {
  GameController({
    required this.backend,
    required SharedPreferences prefs,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now;

  final GameBackend backend;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  LoadState state = LoadState.loading;
  BackendError? error;
  Stats stats = const Stats();

  bool busy = false;

  CaseView? _daily;
  CaseView? _archived;
  DateTime? _closesAt;
  Map<Difficulty, LevelStatus> levels = const {};

  static const _difficultyKey = 'daily-case:difficulty';
  static const _ageGateKey = 'daily-case:age-gate';

  AgeGate get ageGate => AgeGate.fromWire(_prefs.getString(_ageGateKey));

  Future<bool> submitBirthDate(DateTime birthDate) async {
    final allowed = isOldEnough(birthDate, _clock());
    final gate = allowed ? AgeGate.allowed : AgeGate.denied;
    await _prefs.setString(_ageGateKey, gate.wire!);
    notifyListeners();
    return allowed;
  }

  Difficulty? get chosenDifficulty => Difficulty.tryFromWire(_prefs.getString(_difficultyKey));

  bool get needsDifficultyChoice => chosenDifficulty == null;

  Difficulty get difficulty => chosenDifficulty ?? Difficulty.medium;

  Future<void> setDifficulty(Difficulty d) async {
    await _prefs.setString(_difficultyKey, d.wire);
    _archived = null;
    await load();
  }

  bool get isDaily => _archived == null;

  bool get hasCase => _archived != null || (state == LoadState.ready && _daily != null);

  CaseView get _view => _archived ?? _daily!;
  CaseFile get current => _view.caseFile;
  CaseProgress get progress => _view.progress;

  String get viewKey => hasCase ? current.id : state.name;

  DateTime? get closesAt => _closesAt;

  bool isEvidenceVisible(Evidence e) => !e.hint || progress.hintTexts.containsKey(e.id);

  String? evidenceText(Evidence e) => e.text ?? progress.hintTexts[e.id];

  int get visibleEvidenceCount => current.evidence.where(isEvidenceVisible).length;

  bool get canShare => isDaily && progress.attempts.isNotEmpty && progress.done;

  String shareText(AppLocalizations l) => buildShareText(
        l,
        title: current.title,
        day: current.dayNumber ?? 0,
        rows: [for (final a in progress.attempts) a.result],
        hints: progress.unlocked.length,
        won: progress.won,
        score: progress.score,
        streak: stats.streak,
        level: l.levelName(current.difficulty),
      );

  String get _excludedKey => 'daily-case:excluded:${current.id}';

  Set<String> get excluded => (_prefs.getStringList(_excludedKey) ?? const <String>[]).toSet();

  bool isExcluded(String suspectId) => excluded.contains(suspectId);

  void toggleExcluded(String suspectId) {
    final set = excluded;
    if (!set.remove(suspectId)) set.add(suspectId);
    unawaited(_prefs.setStringList(_excludedKey, set.toList()));
    notifyListeners();
  }

  int _loadSeq = 0;

  Future<void> load() async {
    final token = ++_loadSeq;
    state = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      final t = await backend.today(difficulty);
      final s = await backend.stats();
      if (token != _loadSeq) return;
      _closesAt = t.closesAt;
      levels = t.levels;
      _daily = t.caseFile == null ? null : CaseView(t.caseFile!, t.progress);
      _archived = null;
      stats = s;
      state = _daily == null ? LoadState.noCase : LoadState.ready;
    } on BackendException catch (e) {
      if (token != _loadSeq) return;
      error = e.error;
      state = LoadState.error;
    } catch (e) {
      if (token != _loadSeq) return;
      error = BackendError.unknown;
      debugPrint('GameController.load: $e');
      state = LoadState.error;
    }
    notifyListeners();
  }

  DateTime? _lastDayRefresh;

  Future<void> refreshIfDayChanged() async {
    final c = _closesAt;
    final now = _clock();
    if (c == null || now.isBefore(c) || state == LoadState.loading) return;
    final last = _lastDayRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) return;
    _lastDayRefresh = now;
    await load();
  }

  Future<BackendError?> accuse({
    required String culprit,
    required String motive,
    required String evidence,
  }) =>
      _mutate(
        () => backend.accuse(current.id, culprit: culprit, motive: motive, evidence: evidence),
        refreshStats: true,
      );

  Future<BackendError?> unlockHint(String evidenceId) =>
      _mutate(() => backend.unlockHint(current.id, evidenceId));

  Future<BackendError?> _mutate(Future<CaseProgress> Function() call, {bool refreshStats = false}) async {
    if (busy || !isDaily || _daily == null) return null;
    busy = true;
    notifyListeners();
    try {
      final p = await call();
      _daily = CaseView(_daily!.caseFile, p);
      levels = {...levels, _daily!.caseFile.difficulty: LevelStatus(won: p.won, done: p.done)};
      if (refreshStats && p.done) {
        stats = await backend.stats().catchError((_) => stats);
      }
      return null;
    } on BackendException catch (e) {
      return e.error;
    } catch (e) {
      debugPrint('GameController._mutate: $e');
      return BackendError.unknown;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool get canGiveFeedback => hasCase && progress.done && progress.attempts.isNotEmpty;

  Future<BackendError?> rateCase(int rating) => _feedback(rating: rating);

  Future<BackendError?> reportCase(FeedbackReason reason, {String? comment}) =>
      _feedback(reason: reason, comment: comment);

  Future<BackendError?> _feedback({int? rating, FeedbackReason? reason, String? comment}) async {
    if (busy || !canGiveFeedback) return null;
    final view = _view;
    final wasDaily = isDaily;
    busy = true;
    notifyListeners();
    try {
      final p = await backend.submitFeedback(view.caseFile.id, rating: rating, reason: reason, comment: comment);
      final updated = CaseView(view.caseFile, p);
      if (wasDaily) {
        if (identical(_daily, view)) _daily = updated;
      } else if (identical(_archived, view)) {
        _archived = updated;
      }
      return null;
    } on BackendException catch (e) {
      return e.error;
    } catch (e) {
      debugPrint('GameController._feedback: $e');
      return BackendError.unknown;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<ArchiveEntry>> archive() => backend.archive();

  Future<BackendError?> openArchive(String ref) async {
    try {
      _archived = await backend.caseById(ref);
      notifyListeners();
      return null;
    } on BackendException catch (e) {
      return e.error;
    } catch (_) {
      return BackendError.openFailed;
    }
  }

  void openDaily() {
    if (_archived == null) return;
    _archived = null;
    notifyListeners();
  }
}
