import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/case_file.dart';
import '../models/feedback.dart';
import '../models/progress.dart';
import 'game_backend.dart';

class SupabaseGameBackend implements GameBackend {
  SupabaseGameBackend(this._client);

  final SupabaseClient _client;

  Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) async {
    try {
      if (_client.auth.currentSession == null) {
        await _client.auth.signInAnonymously();
      }
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw BackendException(_message(e.message));
    } on AuthException catch (e) {
      throw BackendException('Nie udało się połączyć konta gracza: ${e.message}');
    } on BackendException {
      rethrow;
    } catch (_) {
      throw const BackendException('Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.');
    }
  }

  static String _message(String raw) {
    if (raw.contains('case_closed')) return 'Ta sprawa jest już zamknięta. Po północy czeka nowa.';
    if (raw.contains('case_finished')) return 'Ta sprawa jest już zakończona.';
    if (raw.contains('invalid_choice')) return 'Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.';
    if (raw.contains('case_not_finished')) return 'Ocenić można tylko sprawę, którą prowadziłeś do końca.';
    if (raw.contains('case_not_found')) return 'Nie znaleziono sprawy.';
    if (raw.contains('not_authenticated')) return 'Sesja wygasła. Uruchom aplikację ponownie.';
    return 'Błąd serwera: $raw';
  }

  static Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

  static CaseProgress _progress(dynamic v) =>
      v == null ? CaseProgress.empty : CaseProgress.fromJson(_map(v));

  @override
  Future<TodayResult> today(Difficulty difficulty) async {
    final res = _map(await _rpc('get_today_case', {'p_difficulty': difficulty.wire}));
    final levels = res['levels'] == null ? const <String, dynamic>{} : _map(res['levels']);
    return TodayResult(
      caseFile: res['case'] == null ? null : CaseFile.fromJson(_map(res['case'])),
      progress: _progress(res['progress']),
      closesAt: DateTime.parse(res['closes_at'] as String).toLocal(),
      levels: {
        for (final d in Difficulty.values)
          d: levels[d.wire] == null ? const LevelStatus(available: false) : LevelStatus.fromJson(_map(levels[d.wire])),
      },
    );
  }

  @override
  Future<CaseView> caseById(String ref) async {
    final res = _map(await _rpc('get_case', {'p_case_id': ref}));
    return CaseView(CaseFile.fromJson(_map(res['case'])), _progress(res['progress']));
  }

  @override
  Future<CaseProgress> accuse(
    String caseRef, {
    required String culprit,
    required String motive,
    required String evidence,
  }) async =>
      _progress(await _rpc('submit_accusation', {
        'p_case_id': caseRef,
        'p_culprit': culprit,
        'p_motive': motive,
        'p_evidence': evidence,
      }));

  @override
  Future<CaseProgress> unlockHint(String caseRef, String evidenceId) async =>
      _progress(await _rpc('unlock_hint', {'p_case_id': caseRef, 'p_evidence_id': evidenceId}));

  @override
  Future<CaseProgress> submitFeedback(
    String caseRef, {
    int? rating,
    FeedbackReason? reason,
    String? comment,
  }) async =>
      _progress(await _rpc('submit_case_feedback', {
        'p_case_id': caseRef,
        'p_rating': rating,
        'p_reason': reason?.wire,
        'p_comment': comment,
      }));

  @override
  Future<Stats> stats() async => Stats.fromJson(_map(await _rpc('get_my_stats')));

  @override
  Future<List<ArchiveEntry>> archive() async {
    final list = await _rpc('get_archive', {'p_limit': 60}) as List;
    return list.map((e) => ArchiveEntry.fromJson(_map(e))).toList();
  }
}
