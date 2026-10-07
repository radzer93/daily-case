import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/rules.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import 'buttons.dart';

class VerdictView extends StatelessWidget {
  const VerdictView({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = controller.progress;
    final cf = controller.current;
    final stats = controller.stats;
    final solution = p.solution;
    final bold = const TextStyle(fontWeight: FontWeight.w600);

    final String stamp;
    final List<InlineSpan> lead;
    if (p.won) {
      stamp = 'Sprawa zamknięta';
      lead = [
        const TextSpan(text: 'Prokurator przyjmuje akt oskarżenia. Wynik: '),
        TextSpan(text: '${p.score} pkt', style: bold),
        const TextSpan(text: '.'),
      ];
    } else if (p.dismissed) {
      stamp = 'Sprawa umorzona';
      lead = solution == null
          ? [const TextSpan(text: 'Trzy chybione oskarżenia. Rozwiązanie odtajnimy jutro po północy.')]
          : [
              const TextSpan(text: 'Trzy chybione oskarżenia. Sprawcą był(a) '),
              TextSpan(text: cf.suspectName(solution.culprit), style: bold),
              const TextSpan(text: '.'),
            ];
    } else if (p.lapsed) {
      stamp = 'Sprawa przepadła';
      lead = [
        TextSpan(
          text: p.attempts.isEmpty
              ? 'Ta sprawa minęła bez Twojego śledztwa.'
              : 'Północ minęła przed rozwiązaniem.',
        ),
        if (solution != null) ...[
          const TextSpan(text: ' Sprawcą był(a) '),
          TextSpan(text: cf.suspectName(solution.culprit), style: bold),
          const TextSpan(text: '.'),
        ],
      ];
    } else {
      stamp = 'Sprawa w toku';
      lead = const [TextSpan(text: 'Wróć do sprawy dnia, żeby ją rozwiązać.')];
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
                _Stat(value: '${stats.played}', label: 'Spraw dnia'),
                _Stat(value: '${stats.winRate}%', label: 'Rozwiązanych'),
                _Stat(value: '${stats.streak}', label: 'Seria'),
                _Stat(value: '${stats.best}', label: 'Najdłuższa'),
              ],
            ),
          ],
          if (controller.canShare) ...[
            const SizedBox(height: 18),
            _ShareBox(text: controller.shareText),
          ],
          if (controller.isDaily) ...[
            const SizedBox(height: 14),
            _Countdown(controller: controller),
          ],
          const SizedBox(height: 22),
          Text('ROZWIĄZANIE', style: displayStyle(size: 24, weight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 10),
          if (solution == null)
            Text(
              'Akta z rozwiązaniem odtajnimy po północy. Wróć jutro: w archiwum zobaczysz, kto to zrobił i dlaczego.',
              style: bodyStyle(color: c.muted),
            )
          else ...[
            for (final para in solution.explain)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(para, style: bodyStyle(color: c.ink)),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShareBox extends StatelessWidget {
  const _ShareBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                label: 'Udostępnij wynik',
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
              label: 'Kopiuj',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Wynik skopiowany')));
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
    return Text.rich(
      TextSpan(
        style: monoStyle(size: 12, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.4),
        children: [
          const TextSpan(text: 'Następna sprawa za '),
          TextSpan(
            text: formatClock(_left),
            style: TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
