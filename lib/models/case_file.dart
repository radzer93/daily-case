import 'case_kind.dart';
import 'difficulty.dart';

export 'case_kind.dart';
export 'difficulty.dart';

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
    this.text,
    this.hint = false,
  });

  final String id;
  final String title;
  final String? text;
  final bool hint;

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'] as String,
        title: j['title'] as String,
        text: j['text'] as String?,
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
    required this.docket,
    required this.place,
    required this.date,
    required this.brief,
    required this.suspects,
    required this.evidence,
    required this.motives,
    this.solution,
    this.note,
    this.caseDate,
    this.dayNumber,
    this.difficulty = Difficulty.medium,
  });

  final String id;
  final String title;
  final CaseKind kind;
  final String? note;
  final String docket;
  final String place;
  final String date;
  final List<String> brief;
  final List<Suspect> suspects;
  final List<Evidence> evidence;
  final List<Motive> motives;
  final Solution? solution;
  final String? caseDate;
  final int? dayNumber;
  final Difficulty difficulty;

  bool get isInspired => kind == CaseKind.inspired;

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

  CaseFile publicView({required String id, int? dayNumber, String? caseDate, Difficulty? difficulty}) => CaseFile(
        id: id,
        title: title,
        kind: kind,
        note: note,
        docket: docket,
        place: place,
        date: date,
        brief: brief,
        suspects: suspects,
        evidence: [
          for (final e in evidence)
            e.hint ? Evidence(id: e.id, title: e.title, hint: true) : e,
        ],
        motives: motives,
        caseDate: caseDate,
        dayNumber: dayNumber,
        difficulty: difficulty ?? this.difficulty,
      );

  factory CaseFile.fromJson(Map<String, dynamic> j) => CaseFile(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: CaseKind.fromWire(j['kind'] as String?),
        note: j['note'] as String?,
        docket: j['docket'] as String,
        place: j['place'] as String,
        date: j['date'] as String,
        brief: List<String>.from(j['brief'] as List),
        suspects: (j['suspects'] as List)
            .map((e) => Suspect.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        evidence: (j['evidence'] as List)
            .map((e) => Evidence.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        motives: (j['motives'] as List)
            .map((e) => Motive.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        solution: j['solution'] == null
            ? null
            : Solution.fromJson(Map<String, dynamic>.from(j['solution'] as Map)),
        caseDate: j['case_date'] as String?,
        dayNumber: (j['day_number'] as num?)?.toInt(),
        difficulty: Difficulty.fromWire(j['difficulty'] as String?),
      );
}
