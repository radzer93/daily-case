import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/case_widgets.dart';
import 'archive_screen.dart';
import 'case_tabs.dart';

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
                Text('SPRAWA DNIA', style: displayStyle(size: 26, color: colors.ink)),
                if (c.hasCase && c.current.dayNumber != null) ...[
                  const SizedBox(width: 8),
                  Text('nr ${c.current.dayNumber}',
                      style: monoStyle(size: 11, weight: FontWeight.w500, color: colors.muted)),
                ],
              ],
            ),
          ),
          actions: [
            Center(child: StreakChip(streak: c.stats.streak)),
            IconButton(
              tooltip: 'Archiwum',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: _openArchive,
            ),
            const SizedBox(width: 4),
          ],
        );

        if (!c.hasCase) {
          return Scaffold(appBar: appBar, body: _StatusView(controller: c, onArchive: _openArchive));
        }

        final cf = c.current;
        final p = c.progress;
        final lastTab = !c.isDaily
            ? 'ROZWIĄZANIE'
            : p.done
                ? 'WERDYKT'
                : 'OSKARŻENIE ${p.attemptsLeft}×';

        return Scaffold(
          appBar: appBar,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PoliceTape(words: ['Miejsce zdarzenia', 'Nie przekraczać', 'Policja', cf.place, 'Sygn. ${cf.docket}']),
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
                  const Tab(text: 'AKTA'),
                  Tab(text: 'DOWODY ${c.visibleEvidenceCount}/${cf.evidence.length}'),
                  Tab(text: 'ZEZNANIA ${cf.suspects.length}'),
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
    if (controller.state == LoadState.loading) {
      return Center(child: CircularProgressIndicator(color: colors.ink));
    }

    final isError = controller.state == LoadState.error;
    final title = isError ? 'Brak połączenia z archiwum' : 'Akta jeszcze nie dotarły';
    final body = isError
        ? (controller.errorMessage ?? 'Spróbuj ponownie za chwilę.')
        : 'Dzisiejsza sprawa jest w drodze. Zajrzyj za chwilę albo przejrzyj zamknięte sprawy.';

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
            PrimaryButton(label: 'Spróbuj ponownie', onPressed: controller.load),
            if (!isError) OutlineAction(label: 'Archiwum', onPressed: onArchive),
          ],
        ),
      ],
    );
  }
}
