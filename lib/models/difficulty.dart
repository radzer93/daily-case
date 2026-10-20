enum Difficulty {
  easy(wire: 'easy', multiplier: 1.0),
  medium(wire: 'medium', multiplier: 1.5),
  hard(wire: 'hard', multiplier: 2.0);

  const Difficulty({required this.wire, required this.multiplier});

  final String wire;
  final double multiplier;

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
