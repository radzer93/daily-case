import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/case_file.dart';
import '../state/game_controller.dart';
import '../theme.dart';

class DifficultyScreen extends StatelessWidget {
  const DifficultyScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
          children: [
            Text(l.appBarTitle, style: displayStyle(size: 30, color: c.ink)),
            const SizedBox(height: 24),
            Text(l.chooseLevelTitle, style: displayStyle(size: 40, color: c.ink)),
            const SizedBox(height: 10),
            Text(l.chooseLevelBody, style: bodyStyle(color: c.muted)),
            const SizedBox(height: 24),
            for (final d in Difficulty.values) ...[
              _LevelCard(difficulty: d, onTap: () => controller.setDifficulty(d)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.difficulty, required this.onTap});
  final Difficulty difficulty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: c.line, width: 1.5),
    );
    return Material(
      color: c.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.levelName(difficulty).toUpperCase(),
                        style: displayStyle(size: 26, weight: FontWeight.w800, color: c.ink)),
                    const SizedBox(height: 6),
                    Text(l.levelDescription(difficulty), style: bodyStyle(size: 15, color: c.muted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(l.levelPoints(difficulty), style: monoStyle(size: 12, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
