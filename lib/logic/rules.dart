import '../l10n/app_localizations.dart';

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

const int minimumAge = 16;

bool isOldEnough(DateTime birthDate, DateTime now, {int age = minimumAge}) {
  final threshold = DateTime(birthDate.year + age, birthDate.month, birthDate.day);
  return !DateTime(now.year, now.month, now.day).isBefore(threshold);
}

String buildShareText(
  AppLocalizations l, {
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
  final result = won ? l.points(score) : l.shareDismissed;
  final tail = won && streak > 1 ? ' · ${l.shareStreak(streak)}' : '';
  final head = level == null ? l.shareHeader(day, title) : l.shareHeaderLevel(day, level.toUpperCase(), title);
  return '$head\n$grid\n${l.shareSummary(hints, result)}$tail';
}
