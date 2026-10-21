import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/language.dart';
import '../models/case_file.dart';
import '../models/feedback.dart';
import '../models/global_stats.dart';
import '../models/progress.dart';
import 'game_backend.dart';

class SupabaseGameBackend implements GameBackend {
  SupabaseGameBackend(this._client, {String language = defaultLanguage}) : _language = language;

  final SupabaseClient _client;
  String _language;

  @override
  void setLanguage(String language) => _language = language;

  void _applyLanguage() {
    try {
      _client.rest.headers[languageHeader] = _language;
    } catch (e) {
      debugPrint('SupabaseGameBackend.setLanguage: $e');
    }
  }

  Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) async {
    try {
      if (_client.auth.currentSession == null) {
        await _client.auth.signInAnonymously();
      }
      _applyLanguage();
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw BackendException(_error(e.message), e.message);
    } on AuthException catch (e) {
      throw BackendException(BackendError.accountLink, e.message);
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(BackendError.offline, e.toString());
    }
  }

  static const _serverErrors = <String, BackendError>{
    'case_closed': BackendError.caseClosed,
    'case_not_finished': BackendError.notFinished,
    'case_finished': BackendError.caseFinished,
    'invalid_choice': BackendError.invalidChoice,
    'case_not_found': BackendError.notFound,
    'not_authenticated': BackendError.sessionExpired,
  };

  static BackendError _error(String raw) {
    for (final entry in _serverErrors.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    return BackendError.server;
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
  Future<GlobalStats?> caseStats(String caseRef) async {
    final res = await _rpc('get_case_stats', {'p_case_id': caseRef});
    return res == null ? null : GlobalStats.fromJson(_map(res));
  }

  @override
  Future<Teaser?> tomorrowTeaser(Difficulty difficulty) async {
    final res = await _rpc('get_tomorrow_teaser', {'p_difficulty': difficulty.wire});
    return res == null ? null : Teaser.fromJson(_map(res));
  }

  @override
  Future<Stats> stats() async => Stats.fromJson(_map(await _rpc('get_my_stats')));

  @override
  Future<List<ArchiveEntry>> archive() async {
    final list = await _rpc('get_archive', {'p_limit': 60}) as List;
    return list.map((e) => ArchiveEntry.fromJson(_map(e))).toList();
  }
}
