import '../logic/rules.dart';
import 'case_file.dart';

class Attempt {
  const Attempt({
    required this.culprit,
    required this.motive,
    required this.evidence,
    required this.result,
  });

  final String culprit;
  final String motive;
  final String evidence;
  final List<bool> result;

  bool get correct => result.every((b) => b);

  Map<String, dynamic> toJson() =>
      {'c': culprit, 'm': motive, 'e': evidence, 'r': result};

  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
        culprit: j['c'] as String,
        motive: j['m'] as String,
        evidence: j['e'] as String,
        result: List<bool>.from(j['r'] as List),
      );
}

class CaseProgress {
  const CaseProgress({
    this.attempts = const [],
    this.unlocked = const {},
    this.hintTexts = const {},
    this.done = false,
    this.won = false,
    this.expired = false,
    this.score = 0,
    this.solution,
  });

  static const empty = CaseProgress();
  final List<Attempt> attempts;
  final Set<String> unlocked;
  final Map<String, String> hintTexts;
  final bool done;
  final bool won;
  final bool expired;
  final int score;
  final Solution? solution;

  int get attemptsLeft => maxAttempts - attempts.length;

  bool get dismissed => !won && attempts.length >= maxAttempts;

  bool get lapsed => done && !won && !dismissed;

  factory CaseProgress.fromJson(Map<String, dynamic> j) => CaseProgress(
        attempts: (j['attempts'] as List? ?? const [])
            .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
        unlocked: Set<String>.from(j['unlocked'] as List? ?? const []),
        hintTexts: Map<String, String>.from(j['hints'] as Map? ?? const {}),
        done: j['done'] as bool? ?? false,
        won: j['won'] as bool? ?? false,
        expired: j['expired'] as bool? ?? false,
        score: (j['score'] as num?)?.toInt() ?? 0,
        solution: j['solution'] == null
            ? null
            : Solution.fromJson(Map<String, dynamic>.from(j['solution'] as Map)),
      );
}

class Stats {
  const Stats({this.streak = 0, this.best = 0, this.played = 0, this.won = 0});
  final int streak;
  final int best;
  final int played;
  final int won;

  int get winRate => played == 0 ? 0 : (100 * won / played).round();

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        best: (j['best'] as num?)?.toInt() ?? 0,
        played: (j['played'] as num?)?.toInt() ?? 0,
        won: (j['won'] as num?)?.toInt() ?? 0,
      );
}
