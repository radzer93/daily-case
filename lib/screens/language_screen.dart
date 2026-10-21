import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import '../state/game_controller.dart';
import '../theme.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.controller});
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
            Text(l.chooseLanguageTitle, style: displayStyle(size: 40, color: c.ink)),
            const SizedBox(height: 10),
            Text(l.chooseLanguageBody, style: bodyStyle(color: c.muted)),
            const SizedBox(height: 24),
            for (final code in controller.languages) ...[
              LanguageTile(
                code: code,
                selected: code == controller.language.value,
                onTap: () => controller.setLanguage(code),
              ),
              const SizedBox(height: 12),
            ],
            if (controller.languages.any((code) => code != defaultLanguage)) ...[
              const SizedBox(height: 4),
              Text(l.untranslatedNote, style: bodyStyle(size: 13, color: c.muted, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key, required this.code, required this.selected, required this.onTap});
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: selected ? c.ink : c.line, width: 1.5),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
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
                  child: Text(
                    languageName(code).toUpperCase(),
                    style: displayStyle(size: 26, weight: FontWeight.w800, color: c.ink),
                  ),
                ),
                Text(code.toUpperCase(), style: monoStyle(size: 12, color: c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context, GameController controller) async {
  final code = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.chooseLanguageTitle, style: displayStyle(size: 26, color: ctx.colors.ink)),
            const SizedBox(height: 14),
            for (final code in controller.languages) ...[
              LanguageTile(
                code: code,
                selected: code == controller.language.value,
                onTap: () => Navigator.of(ctx).pop(code),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );
  if (code != null) await controller.setLanguage(code);
}
