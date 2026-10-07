import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_backend.dart';
import '../logic/rules.dart';
import '../models/case_file.dart';
import '../models/progress.dart';

enum LoadState { loading, ready, noCase, error }

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
  String? errorMessage;
  Stats stats = const Stats();

  bool busy = false;

  CaseView? _daily;
  CaseView? _archived;
  DateTime? _closesAt;

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

  String get shareText => buildShareText(
        title: current.title,
        day: current.dayNumber ?? 0,
        rows: [for (final a in progress.attempts) a.result],
        hints: progress.unlocked.length,
        won: progress.won,
        score: progress.score,
        streak: stats.streak,
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

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final t = await backend.today();
      _closesAt = t.closesAt;
      _daily = t.caseFile == null ? null : CaseView(t.caseFile!, t.progress);
      _archived = null;
      stats = await backend.stats();
      state = _daily == null ? LoadState.noCase : LoadState.ready;
    } on BackendException catch (e) {
      errorMessage = e.message;
      state = LoadState.error;
    } catch (e) {
      errorMessage = 'Coś poszło nie tak. Spróbuj ponownie.';
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

  Future<String?> accuse({
    required String culprit,
    required String motive,
    required String evidence,
  }) =>
      _mutate(
        () => backend.accuse(current.id, culprit: culprit, motive: motive, evidence: evidence),
        refreshStats: true,
      );

  Future<String?> unlockHint(String evidenceId) =>
      _mutate(() => backend.unlockHint(current.id, evidenceId));

  Future<String?> _mutate(Future<CaseProgress> Function() call, {bool refreshStats = false}) async {
    if (busy || !isDaily || _daily == null) return null;
    busy = true;
    notifyListeners();
    try {
      final p = await call();
      _daily = CaseView(_daily!.caseFile, p);
      if (refreshStats && p.done) {
        stats = await backend.stats().catchError((_) => stats);
      }
      return null;
    } on BackendException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('GameController._mutate: $e');
      return 'Coś poszło nie tak. Spróbuj ponownie.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<ArchiveEntry>> archive() => backend.archive();

  Future<String?> openArchive(String ref) async {
    try {
      _archived = await backend.caseById(ref);
      notifyListeners();
      return null;
    } on BackendException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nie udało się otworzyć sprawy.';
    }
  }

  void openDaily() {
    if (_archived == null) return;
    _archived = null;
    notifyListeners();
  }
}
