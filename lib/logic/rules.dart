final DateTime launchDateUtc = DateTime.utc(2026, 10, 7);

const int maxAttempts = 3;
const int hintCost = 10;
const int wrongAttemptCost = 20;
const int minScore = 10;

int dayNumber(DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  return today.difference(launchDateUtc).inDays + 1;
}

String dateOfDay(int day) {
  final d = launchDateUtc.add(Duration(days: day - 1));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

int dailyCaseIndex(int day, int caseCount) => (day - 1) % caseCount;

int computeScore({required bool won, required int attempts, required int hints}) {
  if (!won) return 0;
  final s = 100 - wrongAttemptCost * (attempts - 1) - hintCost * hints;
  return s < minScore ? minScore : s;
}

int scaleScore(int base, double multiplier) => (base * multiplier).round();

String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}

String plural(int n, String one, String few, String many) {
  if (n == 1) return one;
  final d = n % 10, h = n % 100;
  if (d >= 2 && d <= 4 && (h < 12 || h > 14)) return few;
  return many;
}

String buildShareText({
  required String title,
  required int day,
  required List<List<bool>> rows,
  required int hints,
  required bool won,
  required int score,
  required int streak,
  String? level,
}) {
  final grid = rows.map((r) => r.map((b) => b ? '🟩' : '🟥').join()).join('\n');
  final result = won ? '$score pkt' : 'umorzona';
  final tail = won && streak > 1 ? ' · seria $streak' : '';
  final head = level == null ? 'Sprawa Dnia #$day · $title' : 'Sprawa Dnia #$day · ${level.toUpperCase()} · $title';
  return '$head\n$grid\nEkspertyzy: $hints · $result$tail';
}
