import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game_backend.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../logic/rules.dart';
import '../models/case_file.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/case_widgets.dart';
import '../widgets/verdict_view.dart';

const _pagePadding = EdgeInsets.fromLTRB(16, 20, 16, 48);

void _showError(BuildContext context, BackendError error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorText(error))));
}

class BriefTab extends StatelessWidget {
  const BriefTab({super.key, required this.caseFile, required this.onNext});
  final CaseFile caseFile;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return ListView(
      padding: _pagePadding,
      children: [
        for (final p in caseFile.brief)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(p, style: bodyStyle(size: 17, color: c.ink)),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.howToTitle, style: monoStyle(size: 11, color: c.ink, letterSpacing: 1.6)),
              const SizedBox(height: 6),
              Text(l.howToBody(maxAttempts), style: bodyStyle(size: 15, color: c.muted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(alignment: Alignment.centerLeft, child: PrimaryButton(label: l.openEvidence, onPressed: onNext)),
      ],
    );
  }
}

class EvidenceTab extends StatelessWidget {
  const EvidenceTab({super.key, required this.controller, required this.onNext});
  final GameController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cf = controller.current;
    final canUnlock = controller.isDaily && !controller.progress.done && !controller.busy;
    return ListView(
      padding: _pagePadding,
      children: [
        for (var i = 0; i < cf.evidence.length; i++) ...[
          EvidenceCard(
            number: i + 1,
            evidence: cf.evidence[i],
            text: controller.evidenceText(cf.evidence[i]),
            docket: cf.docket,
            visible: controller.isEvidenceVisible(cf.evidence[i]),
            onUnlock: canUnlock
                ? () async {
                    HapticFeedback.selectionClick();
                    final err = await controller.unlockHint(cf.evidence[i].id);
                    if (err != null && context.mounted) _showError(context, err);
                  }
                : null,
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: OutlineAction(label: l.goToStatements, onPressed: onNext)),
      ],
    );
  }
}

class SuspectsTab extends StatelessWidget {
  const SuspectsTab({super.key, required this.controller, required this.onNext});
  final GameController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cf = controller.current;
    final p = controller.progress;
    final excluded = controller.excluded;
    return ListView(
      padding: _pagePadding,
      children: [
        for (var i = 0; i < cf.suspects.length; i++) ...[
          SuspectCard(
            index: i + 1,
            total: cf.suspects.length,
            suspect: cf.suspects[i],
            excluded: excluded.contains(cf.suspects[i].id),
            onToggle: () => controller.toggleExcluded(cf.suspects[i].id),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryButton(
            label: !controller.isDaily
                ? l.seeSolution
                : p.done
                    ? l.seeVerdict
                    : l.makeAccusation,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class AccusationTab extends StatefulWidget {
  const AccusationTab({super.key, required this.controller});
  final GameController controller;

  @override
  State<AccusationTab> createState() => _AccusationTabState();
}

class _AccusationTabState extends State<AccusationTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _culprit;
  String? _motive;
  String? _evidence;
  String? _error;

  AppLocalizations get _l => AppLocalizations.of(context);

  GameController get c => widget.controller;

  Future<void> _submit(String? culprit) async {
    if (culprit == null || _motive == null || _evidence == null) {
      setState(() => _error = _l.accusationIncomplete);
      return;
    }
    setState(() => _error = null);
    final before = c.progress.attempts.length;
    final err = await c.accuse(culprit: culprit, motive: _motive!, evidence: _evidence!);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = _l.errorText(err));
      return;
    }
    if (c.progress.attempts.length > before) {
      if (c.progress.won) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;
    final l = AppLocalizations.of(context);
    final cf = c.current;
    final p = c.progress;

    final children = <Widget>[];
    for (final a in p.attempts) {
      children
        ..add(AttemptRow(caseFile: cf, attempt: a))
        ..add(const SizedBox(height: 8));
    }

    if (p.done || !c.isDaily) {
      children
        ..add(const SizedBox(height: 8))
        ..add(VerdictView(controller: c));
      return ListView(padding: _pagePadding, children: children);
    }

    final excluded = c.excluded;
    final culprit = (_culprit != null && !excluded.contains(_culprit)) ? _culprit : null;
    final evidence = cf.evidence.any((e) => e.id == _evidence && c.isEvidenceVisible(e)) ? _evidence : null;
    final left = p.attemptsLeft;

    if (p.attempts.isNotEmpty) children.add(const SizedBox(height: 14));
    children.addAll([
      _Group(
        label: l.groupCulprit,
        options: [
          for (final s in cf.suspects)
            if (!excluded.contains(s.id)) (s.id, s.name),
        ],
        selected: culprit,
        onSelect: (v) => setState(() => _culprit = v),
      ),
      _Group(
        label: l.groupMotive,
        options: [for (final m in cf.motives) (m.id, m.label)],
        selected: _motive,
        onSelect: (v) => setState(() => _motive = v),
      ),
      _Group(
        label: l.groupEvidence,
        options: [
          for (final e in cf.evidence)
            if (c.isEvidenceVisible(e)) (e.id, e.title),
        ],
        selected: evidence,
        onSelect: (v) => setState(() => _evidence = v),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: monoStyle(size: 12, color: colors.bad, letterSpacing: 0.3)),
        ),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          PrimaryButton(
            label: c.busy ? l.sending : l.submitAccusation,
            onPressed: c.busy ? null : () => _submit(culprit),
          ),
          Text(
            l.attemptsLeft(left, p.unlocked.length),
            style: monoStyle(size: 11.5, weight: FontWeight.w500, color: colors.muted, letterSpacing: 0.3),
          ),
        ],
      ),
    ]);

    return ListView(padding: _pagePadding, children: children);
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: monoStyle(size: 11.5, color: c.ink, letterSpacing: 1.6)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                _Choice(label: o.$2, selected: o.$1 == selected, onTap: () => onSelect(o.$1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: selected ? c.ink : c.line, width: 1.5),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.ink : c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(label, style: bodyStyle(size: 15, height: 1.3, color: selected ? c.bg : c.ink)),
          ),
        ),
      ),
    );
  }
}
