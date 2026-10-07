import 'package:flutter/material.dart';

import '../logic/rules.dart';
import '../state/game_controller.dart';
import '../theme.dart';
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
    _shownKey = c.progressKey;
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
    if (state == AppLifecycleState.resumed) c.refreshDay();
  }

  /// Po zmianie sprawy (archiwum, nowy dzień) wracamy na zakładkę Akta.
  void _onControllerChange() {
    if (c.progressKey != _shownKey) {
      _shownKey = c.progressKey;
      _tabs.index = 0;
    }
  }

  void _goTo(int i) => _tabs.animateTo(i);

  Future<void> _openArchive() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ArchiveScreen(controller: c)),
    );
    if (picked != null) c.openArchive(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final colors = context.colors;
        final cf = c.current;
        final p = c.progress;

        return Scaffold(
          appBar: AppBar(
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
                  const SizedBox(width: 8),
                  Text('nr ${c.today}', style: monoStyle(size: 11, weight: FontWeight.w500, color: colors.muted)),
                ],
              ),
            ),
            actions: [
              Center(child: StreakChip(streak: c.streakNow)),
              IconButton(
                tooltip: 'Archiwum',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: _openArchive,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PoliceTape(words: ['Miejsce zdarzenia', 'Nie przekraczać', 'Policja', cf.place, 'Sygn. ${cf.sygn}']),
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
                  Tab(text: p.done ? 'WERDYKT' : 'OSKARŻENIE ${attemptsLeft(p)}×'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    BriefTab(caseFile: cf, onNext: () => _goTo(1)),
                    EvidenceTab(controller: c, onNext: () => _goTo(2)),
                    SuspectsTab(controller: c, onNext: () => _goTo(3)),
                    AccusationTab(key: ValueKey(c.progressKey), controller: c),
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
