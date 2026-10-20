import 'package:flutter/material.dart';

import '../data/game_backend.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../logic/rules.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/buttons.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  late Future<List<ArchiveEntry>> _future = widget.controller.archive();
  bool _opening = false;

  Future<void> _open(ArchiveEntry e) async {
    if (_opening) return;
    setState(() => _opening = true);
    final err = await widget.controller.openArchive(e.ref);
    if (!mounted) return;
    setState(() => _opening = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorText(err))));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(l.archiveTitle, style: displayStyle(size: 26, color: c.ink)),
        bottom: _opening
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(color: c.ink, backgroundColor: c.line),
              )
            : null,
      ),
      body: FutureBuilder<List<ArchiveEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: c.ink));
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  snap.error is BackendException
                      ? l.errorText((snap.error as BackendException).error)
                      : l.archiveLoadFailed,
                  style: bodyStyle(color: c.muted),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryButton(
                    label: l.retry,
                    onPressed: () => setState(() => _future = widget.controller.archive()),
                  ),
                ),
              ],
            );
          }

          final items = snap.data ?? const <ArchiveEntry>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                items.isEmpty ? l.archiveEmpty : l.archiveIntro,
                style: monoStyle(size: 11.5, weight: FontWeight.w500, color: c.muted, letterSpacing: 0.3, height: 1.5),
              ),
              const SizedBox(height: 14),
              for (final e in items) ...[
                _ArchiveTile(entry: e, onTap: () => _open(e)),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.entry, required this.onTap});
  final ArchiveEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final e = entry;

    final (String status, Color statusColor) = e.won
        ? (l.archiveClosed, c.ok)
        : e.attempts >= maxAttempts
            ? (l.archiveDismissed, c.bad)
            : e.attempts > 0
                ? (l.archiveLapsed, c.bad)
                : (l.archiveUntouched, c.muted);

    final sub = [
      '#${e.dayNumber}',
      l.levelName(e.difficulty),
      e.place,
      l.kindName(e.kind),
    ].where((s) => s.isNotEmpty).join(' · ').toUpperCase();

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: BorderSide(color: c.line),
    );

    return Material(
      color: c.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(e.caseDate, style: monoStyle(size: 11, weight: FontWeight.w500, color: c.muted)),
                  const Spacer(),
                  Text(status, style: monoStyle(size: 11, color: statusColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(e.title.toUpperCase(),
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
