import '../models/progress.dart';

/// Dzień nr 1 gry. Wszyscy gracze dostają tę samą sprawę danego dnia.
final DateTime launchDateUtc = DateTime.utc(2026, 10, 7);

const int maxAttempts = 3;
const int hintCost = 10;
const int wrongAttemptCost = 20;
const int minScore = 10;

/// Numer dnia liczony od startu, wg lokalnej daty gracza.
/// Liczone na datach UTC, żeby zmiana czasu (23/25 h) nie przesuwała numeracji.
int dayNumber(DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  return today.difference(launchDateUtc).inDays + 1;
}

/// Indeks sprawy dnia w puli. Sprawy krążą w kółko.
int dailyCaseIndex(int day, int caseCount) => (day - 1) % caseCount;

Duration untilNextDay(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

int attemptsLeft(CaseProgress p) => maxAttempts - p.attempts.length;

int score(CaseProgress p) {
  if (!p.won) return 0;
  final s = 100 -
      wrongAttemptCost * (p.attempts.length - 1) -
      hintCost * p.hints.length;
  return s < minScore ? minScore : s;
}

String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}

/// Polska odmiana: 1 próba, 2 próby, 5 prób, 22 próby, 12 prób.
String plural(int n, String one, String few, String many) {
  if (n == 1) return one;
  final d = n % 10, h = n % 100;
  if (d >= 2 && d <= 4 && (h < 12 || h > 14)) return few;
  return many;
}

/// Wynik do udostępnienia, bez spoilerów.
String buildShareText({
  required String title,
  required bool isDaily,
  required int day,
  required CaseProgress progress,
  required int streak,
}) {
  final head = isDaily
      ? 'Sprawa Dnia #$day · $title'
      : 'Sprawa Dnia, archiwum · $title';
  final rows = progress.attempts
      .map((a) => a.result.map((b) => b ? '🟩' : '🟥').join())
      .join('\n');
  final result = progress.won ? '${score(progress)} pkt' : 'umorzona';
  final tail = isDaily && progress.won && streak > 1 ? ' · seria $streak' : '';
  return '$head\n$rows\nEkspertyzy: ${progress.hints.length} · $result$tail';
}
