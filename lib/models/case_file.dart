/// Model jednej sprawy. Dane pochodzą z assets/cases.json
/// (później można je pobierać z serwera, format zostaje ten sam).
class Suspect {
  const Suspect({
    required this.id,
    required this.name,
    required this.age,
    required this.role,
    required this.statement,
  });

  final String id;
  final String name;
  final int age;
  final String role;
  final List<String> statement;

  factory Suspect.fromJson(Map<String, dynamic> j) => Suspect(
        id: j['id'] as String,
        name: j['name'] as String,
        age: (j['age'] as num).toInt(),
        role: j['role'] as String,
        statement: List<String>.from(j['statement'] as List),
      );
}

class Evidence {
  const Evidence({
    required this.id,
    required this.title,
    required this.text,
    this.hint = false,
  });

  final String id;
  final String title;
  final String text;

  /// Dowód zastrzeżony: odsłaniany przez ekspertyzę, która kosztuje punkty.
  final bool hint;

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'] as String,
        title: j['title'] as String,
        text: j['text'] as String,
        hint: j['hint'] as bool? ?? false,
      );
}

class Motive {
  const Motive({required this.id, required this.label});

  final String id;
  final String label;

  factory Motive.fromJson(Map<String, dynamic> j) =>
      Motive(id: j['id'] as String, label: j['label'] as String);
}

class Solution {
  const Solution({
    required this.culprit,
    required this.motive,
    required this.evidence,
    required this.explain,
  });

  final String culprit;
  final String motive;

  /// Dowody uznawane za rozstrzygające (wystarczy wskazać jeden z nich).
  final List<String> evidence;
  final List<String> explain;

  factory Solution.fromJson(Map<String, dynamic> j) => Solution(
        culprit: j['culprit'] as String,
        motive: j['motive'] as String,
        evidence: List<String>.from(j['evidence'] as List),
        explain: List<String>.from(j['explain'] as List),
      );
}

class CaseFile {
  const CaseFile({
    required this.id,
    required this.title,
    required this.kind,
    required this.sygn,
    required this.place,
    required this.date,
    required this.brief,
    required this.suspects,
    required this.evidence,
    required this.motives,
    required this.solution,
    this.note,
  });

  final String id;
  final String title;

  /// 'fikcyjna' albo 'inspirowana'.
  final String kind;

  /// Dla spraw inspirowanych: skąd pochodzi motyw i co zmieniono.
  final String? note;
  final String sygn;
  final String place;
  final String date;
  final List<String> brief;
  final List<Suspect> suspects;
  final List<Evidence> evidence;
  final List<Motive> motives;
  final Solution solution;

  bool get isInspired => kind == 'inspirowana';

  String suspectName(String id) {
    for (final s in suspects) {
      if (s.id == id) return s.name;
    }
    return '?';
  }

  String motiveLabel(String id) {
    for (final m in motives) {
      if (m.id == id) return m.label;
    }
    return '?';
  }

  String evidenceTitle(String id) {
    for (final e in evidence) {
      if (e.id == id) return e.title;
    }
    return '?';
  }

  factory CaseFile.fromJson(Map<String, dynamic> j) => CaseFile(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: j['kind'] as String,
        note: j['note'] as String?,
        sygn: j['sygn'] as String,
        place: j['place'] as String,
        date: j['date'] as String,
        brief: List<String>.from(j['brief'] as List),
        suspects: (j['suspects'] as List)
            .map((e) => Suspect.fromJson(e as Map<String, dynamic>))
            .toList(),
        evidence: (j['evidence'] as List)
            .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
            .toList(),
        motives: (j['motives'] as List)
            .map((e) => Motive.fromJson(e as Map<String, dynamic>))
            .toList(),
        solution: Solution.fromJson(j['solution'] as Map<String, dynamic>),
      );
}
