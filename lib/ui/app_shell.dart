import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../services/reminder_service.dart';
import '../services/progress_storage.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/library_screen.dart';
import 'screens/progress_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  int _learnEntry = 0;
  String? _examSelection;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refreshForClock();
    widget.controller.purchases.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.onboarded) return OnboardingScreen(controller: c);
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 18, 4),
                child: Row(
                  children: [
                    const BrandMark(),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'wortgarten',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.8,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('current-level-selector'),
                      style: TextButton.styleFrom(
                        backgroundColor: Garden.mint,
                        foregroundColor: Garden.green,
                        minimumSize: const Size(72, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Garden.border),
                        ),
                      ),
                      onPressed: () => showLevelPicker(context, c),
                      child: Semantics(
                        label: 'Current level ${c.level}. Change level',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.level,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.expand_more_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => showSettings(context, c),
                      icon: const Icon(Icons.tune_rounded, size: 21),
                    ),
                  ],
                ),
              ),
              if (c.storageError != null)
                Container(
                  color: Garden.peach,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.storageError!,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: c.retryStorage,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    HomeScreen(
                      controller: c,
                      onExplore: () => setState(() => _tab = 1),
                      onExam: (exam) => setState(() {
                        _examSelection = exam;
                        _learnEntry++;
                        _tab = 1;
                      }),
                    ),
                    LearnScreen(
                      key: ValueKey(_learnEntry),
                      controller: c,
                      initialExam: _examSelection,
                    ),
                    LibraryScreen(controller: c),
                    ProgressScreen(controller: c),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Garden.background,
            border: Border(top: BorderSide(color: Garden.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  for (final (i, label, icon) in [
                    (0, 'Home', Icons.home_outlined),
                    (1, 'Learn', Icons.auto_stories_outlined),
                    (2, 'Library', Icons.bookmarks_outlined),
                    (3, 'Progress', Icons.bar_chart_rounded),
                  ])
                    Expanded(
                      child: Semantics(
                        selected: _tab == i,
                        button: true,
                        label: label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _tab = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 48,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _tab == i
                                        ? Garden.mint
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 21,
                                    color: _tab == i
                                        ? Garden.green
                                        : Garden.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: _tab == i
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _tab == i
                                        ? Garden.green
                                        : Garden.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void showLevelPicker(
  BuildContext context,
  AppController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your level',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'You can change this whenever you like.',
            style: TextStyle(color: Garden.muted),
          ),
          const SizedBox(height: 18),
          for (final (level, description) in [
            ('A1', 'First words & everyday essentials'),
            ('A2', 'Routines, travel & working life'),
            ('B1', 'Experiences, decisions & opinions'),
            ('B2', 'Arguments, society & the environment'),
            ('C1', 'Nuance, academic & professional German'),
          ])
            ListTile(
              key: ValueKey('level-choice-$level'),
              selected: controller.level == level,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: controller.level == level ? Garden.mint : null,
              leading: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: controller.level == level ? Garden.green : Garden.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: controller.level == level
                        ? Colors.white
                        : Garden.green,
                  ),
                ),
              ),
              title: Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: controller.level == level
                  ? const Icon(Icons.check_circle_rounded, color: Garden.green)
                  : null,
              onTap: () {
                controller.chooseLevel(level);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  ),
);

void showSettings(BuildContext context, AppController c) {
  final reminders = ReminderService();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make it your own',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              PremiumInvitation(
                controller: c,
                title: c.premium
                    ? 'Your whole garden is unlocked.'
                    : 'Discover Wortgarten Premium',
                description: c.premium
                    ? 'View your access and manage your purchase.'
                    : 'All levels, exam collections and your own word lists.',
              ),
              const SizedBox(height: 24),
              const Eyebrow('Daily word goal'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 9,
                children: [
                  for (final goal in [5, 10, 15, 20])
                    ChoiceChip(
                      label: Text('$goal words'),
                      selected: c.goal == goal,
                      showCheckmark: false,
                      selectedColor: Garden.mint,
                      onSelected: (_) {
                        c.setGoal(goal);
                        refresh(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Eyebrow('Pronunciation speed'),
              Slider(
                value: c.speechRate,
                min: .25,
                max: .65,
                divisions: 4,
                label: c.speechRate < .4 ? 'Slower' : 'Natural',
                onChanged: (v) {
                  c.speechRate = v;
                  c.changed();
                  refresh(() {});
                },
              ),
              Row(
                children: [
                  const Text(
                    'Slower',
                    style: TextStyle(color: Garden.muted, fontSize: 11),
                  ),
                  const Spacer(),
                  const Text(
                    'Natural',
                    style: TextStyle(color: Garden.muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'A gentle daily reminder',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  c.reminder
                      ? 'Every day at ${TimeOfDay(hour: c.reminderHour, minute: c.reminderMinute).format(context)}'
                      : 'A small nudge to keep growing',
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
                value: c.reminder,
                onChanged: (enabled) async {
                  if (enabled) {
                    final ok = await reminders.schedule(
                      c.reminderHour,
                      c.reminderMinute,
                    );
                    if (!context.mounted) return;
                    if (!ok) {
                      toast(
                        context,
                        'Enable notifications in your device settings. Reminders are available in the mobile app.',
                      );
                      return;
                    }
                  } else {
                    await reminders.cancel();
                  }
                  c.reminder = enabled;
                  c.changed();
                  if (context.mounted) refresh(() {});
                },
              ),
              if (c.reminder)
                TextButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('Change reminder time'),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: c.reminderHour,
                        minute: c.reminderMinute,
                      ),
                    );
                    if (time == null) return;
                    final ok = await reminders.schedule(time.hour, time.minute);
                    if (!context.mounted) return;
                    if (ok) {
                      c.reminderHour = time.hour;
                      c.reminderMinute = time.minute;
                      c.changed();
                      refresh(() {});
                    } else {
                      toast(
                        context,
                        'The reminder could not be changed. Your previous time is kept.',
                      );
                    }
                  },
                ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(
                    Icons.offline_bolt_outlined,
                    size: 18,
                    color: Garden.green,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Your vocabulary and progress stay on this device.',
                      style: TextStyle(fontSize: 12, color: Garden.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _IntroductionPreview(controller: c),
                    ),
                  );
                },
                icon: const Icon(Icons.spa_outlined, size: 18),
                label: const Text('See the introduction again'),
              ),
              TextButton(
                onPressed: () => showSources(context, c),
                child: const Text('About the vocabulary & sources'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IntroductionPreview extends StatefulWidget {
  const _IntroductionPreview({required this.controller});
  final AppController controller;
  @override
  State<_IntroductionPreview> createState() => _IntroductionPreviewState();
}

class _IntroductionPreviewState extends State<_IntroductionPreview> {
  late final AppController _preview =
      AppController(
          catalog: widget.controller.catalog,
          storage: MemoryProgressStorage(),
          purchases: widget.controller.purchases,
          disposePurchases: false,
        )
        ..level = widget.controller.level
        ..goal = widget.controller.goal;
  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingScreen(
    controller: _preview,
    onFinished: () => Navigator.pop(context),
  );
}

void showSources(
  BuildContext context,
  AppController c,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Words with context',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          Text(
            '${c.catalog.words.length} unique words and expressions, with original definitions, examples and illustrations.',
          ),
          const SizedBox(height: 18),
          const Text(
            'A1–B1 reference collections',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'General A1 is checked against Goethe Start Deutsch 1. A2 and B1 add cumulative topic collections with earlier-level revision. Goethe and telc keep their individual reference selections; some earlier mobile practice packs are also retained. The telc collections use published textbook lists, not an exhaustive exam syllabus. These selections do not claim complete coverage of the published word lists.',
          ),
          const SizedBox(height: 18),
          const Text(
            'B2–C1 exam themes & additional practice',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'B2 contains curated exam themes, vocational vocabulary and earlier-level revision. C1 adds words found in selected official exam materials, including archived Goethe vocabulary references and telc general, Hochschule and Beruf sources. Earlier mobile practice packs remain available. These selections are not exhaustive official exam word lists.',
          ),
          const SizedBox(height: 18),
          const SelectableText(
            'goethe.de/en/spr/prf.html\n\ntelc.net/lehrmaterialien/downloadbereich/',
            style: TextStyle(color: Garden.green, fontSize: 12),
          ),
        ],
      ),
    ),
  ),
);
