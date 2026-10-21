class GlobalStats {
  const GlobalStats({
    required this.players,
    required this.enough,
    this.solvedPct,
    this.avgAttempts,
    this.topCulpritId,
    this.topCulpritPct,
  });

  final int players;
  final bool enough;
  final int? solvedPct;
  final double? avgAttempts;
  final String? topCulpritId;
  final int? topCulpritPct;

  factory GlobalStats.fromJson(Map<String, dynamic> j) {
    final top = j['top_first_culprit'] is Map ? Map<String, dynamic>.from(j['top_first_culprit'] as Map) : null;
    return GlobalStats(
      players: (j['players'] as num?)?.toInt() ?? 0,
      enough: j['enough'] as bool? ?? false,
      solvedPct: (j['solved_pct'] as num?)?.toInt(),
      avgAttempts: (j['avg_attempts'] as num?)?.toDouble(),
      topCulpritId: top?['suspect_id'] as String?,
      topCulpritPct: (top?['pct'] as num?)?.toInt(),
    );
  }
}

class Teaser {
  const Teaser({required this.title, required this.place, required this.date});

  final String title;
  final String place;
  final String date;

  factory Teaser.fromJson(Map<String, dynamic> j) => Teaser(
        title: j['title'] as String? ?? '',
        place: j['place'] as String? ?? '',
        date: j['date'] as String? ?? '',
      );
}
