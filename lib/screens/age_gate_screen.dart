import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/rules.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/buttons.dart';

class AgeGateScreen extends StatelessWidget {
  const AgeGateScreen({super.key, required this.controller});
  final GameController controller;

  static final DateTime _earliest = DateTime(1900);

  Future<void> _ask(BuildContext context) async {
    final today = DateTime.now();
    final birthDate = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 20, 1, 1),
      firstDate: _earliest,
      lastDate: today,
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppLocalizations.of(context).ageGatePickerHelp,
    );
    if (birthDate == null) return;
    await controller.submitBirthDate(birthDate);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final denied = controller.ageGate == AgeGate.denied;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
          children: [
            Text(l.appBarTitle, style: displayStyle(size: 30, color: c.ink)),
            const SizedBox(height: 24),
            Text(
              denied ? l.ageDeniedTitle : l.ageGateTitle(minimumAge),
              style: displayStyle(size: 40, color: denied ? c.stamp : c.ink),
            ),
            const SizedBox(height: 10),
            Text(
              denied ? l.ageDeniedBody(minimumAge) : l.ageGateBody(minimumAge),
              style: bodyStyle(color: c.muted),
            ),
            if (!denied) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: PrimaryButton(label: l.ageGateAsk, onPressed: () => _ask(context)),
              ),
              const SizedBox(height: 14),
              Text(l.ageGatePrivacy, style: bodyStyle(size: 13, color: c.muted, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
