import 'package:flutter/material.dart';

import '../logic/rules.dart';
import '../state/game_controller.dart';
import '../theme.dart';

/// Lista wszystkich spraw. Zwraca indeks wybranej sprawy przez Navigator.pop.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('ARCHIWUM', style: displayStyle(size: 26, color: c.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Podgląd prototypu: wszystkie sprawy są dostępne od razu. '
            'Sprawy z archiwum nie liczą się do serii.',
            style: monoStyle(size: 11.5, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.3, height: 1.5),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < controller.cases.length; i++) ...[
            _ArchiveTile(controller: controller, index: i),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.controller, required this.index});

  final GameController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cf = controller.cases[index];
    final p = controller.archiveProgress(cf);

    final (String status, Color statusColor) = switch (p) {
      final q? when q.done && q.won => ('ZAMKNIĘTA · ${score(q)} PKT', c.ok),
      final q? when q.done => ('UMORZONA', c.bad),
      _ => ('OTWARTA', c.muted),
    };

    final sub = [
      cf.place,
      cf.isInspired ? 'inspirowana' : 'fikcyjna',
      if (index == controller.dailyIndex) 'dziś sprawa dnia',
    ].join(' · ').toUpperCase();

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: BorderSide(color: c.line),
    );

    return Material(
      color: c.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => Navigator.of(context).pop(index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(cf.sygn, style: monoStyle(size: 11, weight: FontWeight.w500, color: c.muted)),
                  const Spacer(),
                  Text(status, style: monoStyle(size: 11, color: statusColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(cf.title.toUpperCase(),
                  style: displayStyle(size: 22, weight: FontWeight.w800, color: c.ink, height: 1.05)),
              const SizedBox(height: 4),
              Text(sub, style: monoStyle(size: 10, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
