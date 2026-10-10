import '../models/case_file.dart';
import '../models/progress.dart';

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CaseView {
  const CaseView(this.caseFile, this.progress);
  final CaseFile caseFile;
  final CaseProgress progress;
}

class TodayResult {
  const TodayResult({
    required this.caseFile,
    required this.progress,
    required this.closesAt,
    this.levels = const {},
  });
  final CaseFile? caseFile;
  final CaseProgress progress;
  final DateTime closesAt;
  final Map<Difficulty, LevelStatus> levels;
}

class ArchiveEntry {
  const ArchiveEntry({
    required this.ref,
    required this.title,
    required this.kind,
    required this.difficulty,
    required this.docket,
    required this.place,
    required this.caseDate,
    required this.dayNumber,
    required this.won,
    required this.attempts,
  });

  final String ref;
  final String title;
  final CaseKind kind;
  final Difficulty difficulty;
  final String docket;
  final String place;
  final String caseDate;
  final int dayNumber;
  final bool won;
  final int attempts;

  factory ArchiveEntry.fromJson(Map<String, dynamic> j) => ArchiveEntry(
        ref: j['id'] as String,
        title: j['title'] as String,
        kind: CaseKind.fromWire(j['kind'] as String?),
        difficulty: Difficulty.fromWire(j['difficulty'] as String?),
        docket: j['docket'] as String? ?? '',
        place: j['place'] as String? ?? '',
        caseDate: j['case_date'] as String,
        dayNumber: (j['day_number'] as num).toInt(),
        won: j['won'] as bool? ?? false,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

abstract class GameBackend {
  Future<TodayResult> today(Difficulty difficulty);

  Future<CaseView> caseById(String ref);

  Future<CaseProgress> accuse(
    String caseRef, {
    required String culprit,
    required String motive,
    required String evidence,
  });

  Future<CaseProgress> unlockHint(String caseRef, String evidenceId);

  Future<Stats> stats();

  Future<List<ArchiveEntry>> archive();
}
