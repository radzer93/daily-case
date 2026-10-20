import 'package:flutter/material.dart';

import '../data/game_backend.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/case_widgets.dart';
import 'age_gate_screen.dart';
import 'archive_screen.dart';
import 'case_tabs.dart';
import 'difficulty_screen.dart';

class CaseScreen extends StatefulWidget {
  const CaseScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<CaseScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  late String _shownKey;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shownKey = c.viewKey;
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChange);
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.refreshIfDayChanged();
  }

  void _onControllerChange() {
    if (c.viewKey != _shownKey) {
      _shownKey = c.viewKey;
      _tabs.index = 0;
    }
  }

  void _goTo(int i) => _tabs.animateTo(i);

  void _openArchive() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArchiveScreen(controller: c)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final colors = context.colors;
        final l = AppLocalizations.of(context);
        if (c.ageGate != AgeGate.allowed) return AgeGateScreen(controller: c);
        if (c.needsDifficultyChoice) return DifficultyScreen(controller: c);

        final switcher = DifficultySwitcher(
          selected: c.difficulty,
          levels: c.levels,
          onSelect: c.setDifficulty,
          enabled: !c.busy && c.state != LoadState.loading,
        );

        final appBar = AppBar(
          titleSpacing: 16,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(l.appBarTitle, style: displayStyle(size: 26, color: colors.ink)),
                if (c.hasCase && c.current.dayNumber != null) ...[
                  const SizedBox(width: 8),
                  Text(l.caseNumber(c.current.dayNumber!),
                      style: monoStyle(size: 11, weight: FontWeight.w500, color: colors.muted)),
                ],
              ],
            ),
          ),
          actions: [
            Center(child: StreakChip(streak: c.stats.streak)),
            IconButton(
              tooltip: l.archive,
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: _openArchive,
            ),
            const SizedBox(width: 4),
          ],
        );

        if (!c.hasCase) {
          return Scaffold(
            appBar: appBar,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                switcher,
                Expanded(child: _StatusView(controller: c, onArchive: _openArchive)),
              ],
            ),
          );
        }

        final cf = c.current;
        final p = c.progress;
        final lastTab = !c.isDaily
            ? l.tabSolution
            : p.done
                ? l.tabVerdict
                : l.tabAccusation(p.attemptsLeft);

        return Scaffold(
          appBar: appBar,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.isDaily) switcher,
              PoliceTape(words: [l.tapeScene, l.tapeDoNotCross, l.tapePolice, cf.place, l.tapeDocket(cf.docket)]),
              CaseHeader(caseFile: cf, isDaily: c.isDaily, onBackToDaily: c.openDaily),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: colors.ink,
                unselectedLabelColor: colors.muted,
                labelStyle: monoStyle(size: 12, letterSpacing: 1),
                unselectedLabelStyle: monoStyle(size: 12, letterSpacing: 1),
                indicatorColor: colors.ink,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: colors.line,
                tabs: [
                  Tab(text: l.tabBrief),
                  Tab(text: l.tabEvidence(c.visibleEvidenceCount, cf.evidence.length)),
                  Tab(text: l.tabStatements(cf.suspects.length)),
                  Tab(text: lastTab),
                ],
              ),
              SizedBox(
                height: 2,
                child: c.busy
                    ? LinearProgressIndicator(color: colors.ink, backgroundColor: colors.line)
                    : null,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    BriefTab(caseFile: cf, onNext: () => _goTo(1)),
                    EvidenceTab(controller: c, onNext: () => _goTo(2)),
                    SuspectsTab(controller: c, onNext: () => _goTo(3)),
                    AccusationTab(key: ValueKey(c.viewKey), controller: c),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.controller, required this.onArchive});
  final GameController controller;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = AppLocalizations.of(context);
    if (controller.state == LoadState.loading) {
      return Center(child: CircularProgressIndicator(color: colors.ink));
    }

    final isError = controller.state == LoadState.error;
    final title = isError ? l.statusErrorTitle : l.statusEmptyTitle;
    final error = controller.error;
    final body = isError
        ? l.errorText(error ?? BackendError.unknown)
        : l.statusEmptyBody(l.levelName(controller.difficulty).toLowerCase());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
      children: [
        Text(title.toUpperCase(), style: displayStyle(size: 34, color: colors.ink)),
        const SizedBox(height: 12),
        Text(body, style: bodyStyle(color: colors.muted)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrimaryButton(label: l.retry, onPressed: controller.load),
            if (!isError) OutlineAction(label: l.archive, onPressed: onArchive),
          ],
        ),
      ],
    );
  }
}
