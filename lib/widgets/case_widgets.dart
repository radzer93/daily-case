import 'package:flutter/material.dart';

import '../models/case_file.dart';
import '../models/progress.dart';
import '../theme.dart';
import 'buttons.dart';

class PoliceTape extends StatelessWidget {
  const PoliceTape({super.key, required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final run = words.map((w) => w.toUpperCase()).join('   •   ');
    final text = List.filled(6, run).join('   •   ');
    return ExcludeSemantics(
      child: ClipRect(
        child: SizedBox(
          height: 40,
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: -0.018,
              child: Container(
                color: c.tag,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: monoStyle(size: 10.5, color: c.tagInk, letterSpacing: 2.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Seria rozwiązanych spraw dnia: $streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('SERIA $streak', style: monoStyle(size: 11.5, color: c.ink)),
      ),
    );
  }
}

class CaseHeader extends StatelessWidget {
  const CaseHeader({
    super.key,
    required this.caseFile,
    required this.isDaily,
    required this.onBackToDaily,
  });

  final CaseFile caseFile;
  final bool isDaily;
  final VoidCallback onBackToDaily;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cf = caseFile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: [
              Text('SYGN. AKT ${cf.docket}',
                  style: monoStyle(size: 11, weight: FontWeight.w500, color: c.muted)),
              Text('${cf.place}, ${cf.date}'.toUpperCase(),
                  style: monoStyle(size: 11, weight: FontWeight.w500, color: c.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(cf.title.toUpperCase(), style: displayStyle(size: 38, color: c.ink)),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: c.ink),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  cf.kind.badge.toUpperCase(),
                  style: monoStyle(size: 10, color: c.ink),
                ),
              ),
              if (cf.note != null)
                Text(cf.note!, style: bodyStyle(size: 13, color: c.muted, height: 1.4)),
            ],
          ),
          if (!isDaily) ...[
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Sprawa z archiwum. Rozwiązanie jest jawne.',
                    style: monoStyle(size: 11, weight: FontWeight.w500, color: c.muted)),
                OutlineAction(label: 'Sprawa dnia', onPressed: onBackToDaily, dense: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class EvidenceCard extends StatelessWidget {
  const EvidenceCard({
    super.key,
    required this.number,
    required this.evidence,
    required this.text,
    required this.docket,
    required this.visible,
    required this.onUnlock,
  });

  final int number;
  final Evidence evidence;
  final String? text;
  final String docket;
  final bool visible;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final headBg = visible ? c.tag : c.tagInk;
    final headFg = visible ? c.tagInk : c.tag;
    final right = !visible ? 'ZASTRZEŻONE' : (evidence.hint ? 'EKSPERTYZA' : docket);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headBg,
            padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: headFg.withAlpha(90), width: 2),
                  ),
                ),
                const SizedBox(width: 10),
                Text('DOWÓD NR $number', style: monoStyle(size: 11, color: headFg)),
                const Spacer(),
                Text(right, style: monoStyle(size: 11, color: headFg)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evidence.title.toUpperCase(),
                    style: displayStyle(size: 21, weight: FontWeight.w800, color: c.ink, height: 1.05)),
                const SizedBox(height: 8),
                if (visible)
                  Text(text ?? '', style: bodyStyle(color: c.ink))
                else ...[
                  for (final w in const [0.94, 0.81, 0.58])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: FractionallySizedBox(
                        widthFactor: w,
                        alignment: Alignment.centerLeft,
                        child: Container(height: 12, color: c.ink.withAlpha(215)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlineAction(label: 'Zleć ekspertyzę · −10 pkt', onPressed: onUnlock),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SuspectCard extends StatelessWidget {
  const SuspectCard({
    super.key,
    required this.index,
    required this.total,
    required this.suspect,
    required this.excluded,
    required this.onToggle,
  });

  final int index;
  final int total;
  final Suspect suspect;
  final bool excluded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: excluded ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('PROTOKÓŁ PRZESŁUCHANIA',
                    style: monoStyle(size: 10, weight: FontWeight.w500, color: c.muted, letterSpacing: 2)),
                const Spacer(),
                Text('$index/$total', style: monoStyle(size: 10, weight: FontWeight.w500, color: c.muted)),
              ],
            ),
            Container(height: 1, color: c.line, margin: const EdgeInsets.symmetric(vertical: 10)),
            Text(
              suspect.name.toUpperCase(),
              style: displayStyle(
                size: 27,
                weight: FontWeight.w800,
                color: c.ink,
                decoration: excluded ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),
            Text('${suspect.age} l., ${suspect.role}', style: bodyStyle(size: 14, color: c.muted)),
            const SizedBox(height: 12),
            for (final p in suspect.statement)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('„$p”', style: bodyStyle(color: c.ink)),
              ),
            const SizedBox(height: 4),
            OutlineAction(
              label: excluded ? 'Wykluczony · cofnij' : 'Wyklucz z podejrzeń',
              onPressed: onToggle,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class AttemptRow extends StatelessWidget {
  const AttemptRow({super.key, required this.caseFile, required this.attempt});
  final CaseFile caseFile;
  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('SPRAWCA', caseFile.suspectName(attempt.culprit), attempt.result[0]),
      ('MOTYW', caseFile.motiveLabel(attempt.motive), attempt.result[1]),
      ('DOWÓD', caseFile.evidenceTitle(attempt.evidence), attempt.result[2]),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _Cell(label: cells[i].$1, value: cells[i].$2, ok: cells[i].$3)),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.ok});
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: $value, ${ok ? 'trafione' : 'chybione'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ok ? c.ok : c.bad,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: monoStyle(size: 9, color: c.onSemantic.withAlpha(215), letterSpacing: 1.4)),
            const SizedBox(height: 2),
            Text(value, style: bodyStyle(size: 13, color: c.onSemantic, height: 1.25)),
          ],
        ),
      ),
    );
  }
}
