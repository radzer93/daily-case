/// Postęp gracza w jednej sprawie i statystyki ogólne.
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

  /// [sprawca, motyw, dowód] – czy trafiony.
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
  CaseProgress({
    List<Attempt>? attempts,
    Set<String>? hints,
    Set<String>? excluded,
    this.done = false,
    this.won = false,
  })  : attempts = attempts ?? <Attempt>[],
        hints = hints ?? <String>{},
        excluded = excluded ?? <String>{};

  final List<Attempt> attempts;

  /// Odsłonięte ekspertyzy (id dowodów).
  final Set<String> hints;

  /// Podejrzani wykluczeni przez gracza (tylko pomoc w notatkach).
  final Set<String> excluded;
  bool done;
  bool won;

  Map<String, dynamic> toJson() => {
        'attempts': attempts.map((a) => a.toJson()).toList(),
        'hints': hints.toList(),
        'excluded': excluded.toList(),
        'done': done,
        'won': won,
      };

  factory CaseProgress.fromJson(Map<String, dynamic> j) => CaseProgress(
        attempts: (j['attempts'] as List? ?? const [])
            .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
        hints: Set<String>.from(j['hints'] as List? ?? const []),
        excluded: Set<String>.from(j['excluded'] as List? ?? const []),
        done: j['done'] as bool? ?? false,
        won: j['won'] as bool? ?? false,
      );
}

class Stats {
  Stats({
    this.streak = 0,
    this.lastWin = 0,
    this.best = 0,
    this.played = 0,
    this.won = 0,
  });

  /// Seria rozwiązanych spraw dnia z rzędu.
  int streak;

  /// Numer dnia ostatniej wygranej.
  int lastWin;
  int best;
  int played;
  int won;

  Map<String, dynamic> toJson() => {
        'streak': streak,
        'lastWin': lastWin,
        'best': best,
        'played': played,
        'won': won,
      };

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        lastWin: (j['lastWin'] as num?)?.toInt() ?? 0,
        best: (j['best'] as num?)?.toInt() ?? 0,
        played: (j['played'] as num?)?.toInt() ?? 0,
        won: (j['won'] as num?)?.toInt() ?? 0,
      );
}
