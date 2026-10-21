import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../data/game_backend.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../logic/rules.dart';
import '../models/feedback.dart';
import '../models/global_stats.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import 'buttons.dart';

List<InlineSpan> _emphasize(String text, String part, TextStyle style) {
  final i = part.isEmpty ? -1 : text.indexOf(part);
  if (i < 0) return [TextSpan(text: text)];
  return [
    TextSpan(text: text.substring(0, i)),
    TextSpan(text: part, style: style),
    TextSpan(text: text.substring(i + part.length)),
  ];
}

class VerdictView extends StatelessWidget {
  const VerdictView({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final p = controller.progress;
    final cf = controller.current;
    final stats = controller.stats;
    final solution = p.solution;
    final bold = const TextStyle(fontWeight: FontWeight.w600);

    final String stamp;
    final List<InlineSpan> lead;
    final culprit = solution == null ? '' : cf.suspectName(solution.culprit);
    if (p.won) {
      stamp = l.stampClosed;
      final score = l.points(p.score);
      lead = _emphasize(l.verdictWon(score), score, bold);
    } else if (p.dismissed) {
      stamp = l.stampDismissed;
      lead = solution == null
          ? [TextSpan(text: l.verdictDismissedPending)]
          : _emphasize(l.verdictDismissed(culprit), culprit, bold);
    } else if (p.lapsed) {
      stamp = l.stampLapsed;
      lead = [
        TextSpan(text: p.attempts.isEmpty ? l.verdictLapsedUntouched : l.verdictLapsedLate),
        if (solution != null) ...[
          const TextSpan(text: ' '),
          ..._emphasize(l.verdictCulprit(culprit), culprit, bold),
        ],
      ];
    } else {
      stamp = l.stampOpen;
      lead = [TextSpan(text: l.verdictOpen)];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Stamp(text: stamp),
          const SizedBox(height: 18),
          Text.rich(TextSpan(style: bodyStyle(color: c.ink), children: lead)),
          if (controller.isDaily) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                _Stat(value: '${stats.played}', label: l.statPlayed),
                _Stat(value: '${stats.winRate}%', label: l.statWinRate),
                _Stat(value: '${stats.streak}', label: l.statStreak),
                _Stat(value: '${stats.best}', label: l.statBest),
              ],
            ),
          ],
          if (controller.globalStats != null) ...[
            const SizedBox(height: 18),
            _GlobalStatsBox(stats: controller.globalStats!, suspectName: cf.suspectName),
          ],
          if (controller.canShare) ...[
            const SizedBox(height: 18),
            _ShareBox(text: controller.shareText(l)),
          ],
          if (controller.isDaily) ...[
            const SizedBox(height: 14),
            _Countdown(controller: controller),
          ],
          if (controller.isDaily && controller.teaser != null) ...[
            const SizedBox(height: 6),
            Text(
              l.tomorrowTeaser(controller.teaser!.title, controller.teaser!.place, controller.teaser!.date),
              style: monoStyle(size: 12, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.4, height: 1.5),
            ),
          ],
          const SizedBox(height: 22),
          Text(l.tabSolution, style: displayStyle(size: 24, weight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 10),
          if (solution == null)
            Text(l.solutionPending, style: bodyStyle(color: c.muted))
          else ...[
            for (final para in solution.explain)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(para, style: bodyStyle(color: c.ink)),
              ),
          ],
          if (controller.canGiveFeedback) ...[
            const SizedBox(height: 10),
            Divider(color: c.line, height: 1),
            const SizedBox(height: 16),
            _FeedbackBox(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _GlobalStatsBox extends StatelessWidget {
  const _GlobalStatsBox({required this.stats, required this.suspectName});
  final GlobalStats stats;
  final String Function(String id) suspectName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final style = bodyStyle(size: 15, color: c.ink, height: 1.45);
    final lines = <String>[
      if (!stats.enough) l.globalTooFew(globalStatsMinPlayers),
      if (stats.enough && stats.solvedPct != null) l.globalSolved(stats.solvedPct!, stats.players),
      if (stats.enough && stats.avgAttempts != null)
        l.globalAvgAttempts(intl.NumberFormat('0.0', l.localeName).format(stats.avgAttempts)),
      if (stats.enough && stats.topCulpritId != null && stats.topCulpritPct != null)
        l.globalTopCulprit(suspectName(stats.topCulpritId!), stats.topCulpritPct!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.globalTitle, style: monoStyle(size: 11, weight: FontWeight.w600, color: c.muted, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        for (final line in lines) Text(line, style: style),
      ],
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({required this.controller});
  final GameController controller;

  void _show(BuildContext context, BackendError? error, String success) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error == null ? success : l.errorText(error))));
  }

  Future<void> _rate(BuildContext context, int rating) async {
    final error = await controller.rateCase(rating);
    if (!context.mounted) return;
    _show(context, error, AppLocalizations.of(context).feedbackThanksRating);
  }

  Future<void> _report(BuildContext context) async {
    final reason = await showModalBottomSheet<FeedbackReason>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(AppLocalizations.of(ctx).feedbackSheetTitle, style: bodyStyle(color: ctx.colors.ink)),
            ),
            for (final r in FeedbackReason.values)
              ListTile(
                title: Text(AppLocalizations.of(ctx).reasonLabel(r)),
                onTap: () => Navigator.of(ctx).pop(r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    final error = await controller.reportCase(reason);
    if (!context.mounted) return;
    _show(context, error, AppLocalizations.of(context).feedbackThanksReport);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final p = controller.progress;
    final rating = p.myRating ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.feedbackQuestion,
          style: monoStyle(size: 11, weight: FontWeight.w600, color: c.muted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = minRating; i <= maxRating; i++)
              IconButton(
                tooltip: l.ratingTooltip(i, maxRating),
                visualDensity: VisualDensity.compact,
                onPressed: controller.busy ? null : () => _rate(context, i),
                icon: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i <= rating ? c.stamp : c.muted,
                  size: 30,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (p.reported)
          Text(l.feedbackReported, style: bodyStyle(color: c.muted))
        else
          OutlineAction(
            label: l.reportProblem,
            dense: true,
            onPressed: controller.busy ? null : () => _report(context),
          ),
      ],
    );
  }
}

class _ShareBox extends StatelessWidget {
  const _ShareBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            text,
            style: monoStyle(size: 13, weight: FontWeight.w500, color: c.ink, letterSpacing: 0.2, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Builder(
              builder: (bctx) => PrimaryButton(
                label: l.shareResult,
                onPressed: () {
                  final box = bctx.findRenderObject() as RenderBox?;
                  Share.share(
                    text,
                    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
              ),
            ),
            OutlineAction(
              label: l.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.copied)));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final stamp = Transform.rotate(
      angle: -0.07,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        decoration: BoxDecoration(border: Border.all(color: c.stamp, width: 4)),
        child: Text(text.toUpperCase(), style: displayStyle(size: 34, color: c.stamp, height: 1)),
      ),
    );
    if (reduceMotion) return stamp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.8, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Opacity(
        opacity: ((1.8 - s) / 0.8).clamp(0.0, 1.0),
        child: Transform.scale(scale: s, alignment: Alignment.centerLeft, child: child),
      ),
      child: stamp,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.ink, width: 2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: displayStyle(size: 30, color: c.ink, height: 1)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: monoStyle(size: 8.5, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.controller});
  final GameController controller;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration _left = Duration.zero;

  void _tick() {
    final closes = widget.controller.closesAt;
    if (closes == null) return;
    final left = closes.difference(DateTime.now());
    if (left.isNegative) {
      widget.controller.refreshIfDayChanged();
      return;
    }
    setState(() => _left = left);
  }

  @override
  void initState() {
    super.initState();
    final closes = widget.controller.closesAt;
    if (closes != null) _left = closes.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final clock = formatClock(_left);
    return Text.rich(
      TextSpan(
        style: monoStyle(size: 12, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.4),
        children: _emphasize(
          AppLocalizations.of(context).nextCaseIn(clock),
          clock,
          TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}
