enum Difficulty {
  easy(
    wire: 'easy',
    label: 'Łatwa',
    description: '3 podejrzanych, jeden wyraźny trop.',
    multiplier: 1.0,
  ),
  medium(
    wire: 'medium',
    label: 'Średnia',
    description: '4 podejrzanych, trop ukryty w szczegółach.',
    multiplier: 1.5,
  ),
  hard(
    wire: 'hard',
    label: 'Trudna',
    description: '4 podejrzanych, mylne poszlaki, dwa tropy do połączenia.',
    multiplier: 2.0,
  );

  const Difficulty({
    required this.wire,
    required this.label,
    required this.description,
    required this.multiplier,
  });

  final String wire;
  final String label;
  final String description;
  final double multiplier;

  String get multiplierLabel => '×${multiplier.toStringAsFixed(multiplier % 1 == 0 ? 0 : 1).replaceAll('.', ',')} pkt';

  static Difficulty? tryFromWire(String? value) {
    for (final d in values) {
      if (d.wire == value) return d;
    }
    return null;
  }

  static Difficulty fromWire(String? value) => tryFromWire(value) ?? medium;
}

class LevelStatus {
  const LevelStatus({this.available = true, this.won = false, this.done = false});
  final bool available;
  final bool won;
  final bool done;

  factory LevelStatus.fromJson(Map<String, dynamic> j) => LevelStatus(
        won: j['won'] as bool? ?? false,
        done: j['done'] as bool? ?? false,
      );
}
