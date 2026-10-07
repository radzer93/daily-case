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
    final share = controller.shareText;
    final rate = stats.played == 0 ? 0 : (100 * stats.won / stats.played).round();

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
          _Stamp(text: p.won ? 'Sprawa zamknięta' : 'Sprawa umorzona'),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              style: bodyStyle(color: c.ink),
              children: p.won
                  ? [
                      const TextSpan(text: 'Prokurator przyjmuje akt oskarżenia. Wynik: '),
                      TextSpan(text: '${score(p)} pkt', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: '.'),
                    ]
                  : [
                      const TextSpan(text: 'Trzy chybione oskarżenia. Sprawcą był(a) '),
                      TextSpan(
                        text: cf.suspectName(cf.solution.culprit),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '.'),
                    ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(value: '${stats.played}', label: 'Spraw dnia'),
              _Stat(value: '$rate%', label: 'Rozwiązanych'),
              _Stat(value: '${controller.streakNow}', label: 'Seria'),
              _Stat(value: '${stats.best}', label: 'Najdłuższa'),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              share,
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
                    // iPad wymaga punktu zaczepienia dla okna udostępniania.
                    final box = bctx.findRenderObject() as RenderBox?;
                    Share.share(
                      share,
                      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                    );
                  },
                ),
              ),
              OutlineAction(
                label: 'Kopiuj',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: share));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Wynik skopiowany')));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Countdown(controller: controller),
          const SizedBox(height: 22),
          Text('ROZWIĄZANIE', style: displayStyle(size: 24, weight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 10),
          for (final para in cf.solution.explain)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(para, style: bodyStyle(color: c.ink)),
            ),
        ],
      ),
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
  Duration _left = untilNextDay(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.controller.refreshDay()) return; // nowy dzień: ekran się przebuduje
      setState(() => _left = untilNextDay(DateTime.now()));
    });
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
