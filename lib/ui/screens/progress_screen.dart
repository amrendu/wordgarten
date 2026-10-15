import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import '../infographics.dart';
import 'practice_screen.dart';
import 'paywall_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your progress.',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 26),
                  ),
                ),
                IconButton(
                  tooltip: 'More charts & learning tips',
                  icon: const Icon(Icons.info_outline_rounded, size: 21),
                  onPressed: () {
                    if (!c.premium) {
                      showPaywall(
                        context,
                        c,
                        reason: 'Explore your detailed learning insights.',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text(
                              'Your learning journey',
                              style: TextStyle(fontSize: 17),
                            ),
                          ),
                          body: ListenableBuilder(
                            listenable: c,
                            builder: (_, _) =>
                                ProgressDetailsScreen(controller: c),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            GardenCard(
              color: Garden.mint,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: _CompactStat('${c.learned}', 'recalled')),
                  Expanded(child: _CompactStat('${c.streak}', 'day streak')),
                  Expanded(
                    child: _CompactStat(
                      c.attempts == 0
                          ? '—'
                          : '${(100 * c.correct / c.attempts).round()}%',
                      'accuracy',
                    ),
                  ),
                  const GardenIllustration(
                    'garden-achievement',
                    width: 58,
                    height: 62,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const TabBar(
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Activity'),
                Tab(text: 'Memory'),
                Tab(text: 'Levels'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    key: const ValueKey('progress-activity-scroll'),
                    child: Column(
                      children: [
                        WeeklyActivity(
                          controller: c,
                          compact:
                              MediaQuery.sizeOf(context).shortestSide < 700,
                        ),
                        if (MediaQuery.sizeOf(context).shortestSide >= 700) ...[
                          const SizedBox(height: 18),
                          MemoryGarden(controller: c),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: c.dueWords.isEmpty
                                    ? null
                                    : () => startPractice(
                                        context,
                                        c,
                                        c.dueWords,
                                        PracticeMode.flashcards,
                                        'Due for review',
                                      ),
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 17,
                                ),
                                label: Text('Review ${c.dueWords.length}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: c.difficultWords.isEmpty
                                    ? null
                                    : () {
                                        if (!c.premium) {
                                          showPaywall(
                                            context,
                                            c,
                                            reason: 'Give your difficult words another chance.',
                                          );
                                          return;
                                        }
                                        startPractice(
                                          context,
                                          c,
                                          c.difficultWords,
                                          PracticeMode.flashcards,
                                          'Tricky words',
                                        );
                                      },
                                icon: const Icon(
                                  Icons.psychology_outlined,
                                  size: 17,
                                ),
                                label: Text(
                                  'Tricky ${c.difficultWords.length}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const ReviewTimeline(),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    key: const ValueKey('progress-memory-scroll'),
                    child: Column(
                      children: [
                        if (c.premium)
                          MemoryGarden(controller: c, compact: true)
                        else
                          PremiumInvitation(
                            controller: c,
                            title: 'See how your words take root.',
                            description: 'Unlock your memory stages and detailed learning insights.',
                          ),
                        const SizedBox(height: 12),
                        const LearningCycle(),
                        const SizedBox(height: 8),
                        const Text(
                          'Words take root after three successful recalls.',
                          style: TextStyle(fontSize: 12, color: Garden.muted),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    key: const ValueKey('progress-levels-scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your learning paths',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final level in levels)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GardenCard(
                              color: c.level == level
                                  ? Garden.mint
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onTap: () => c.chooseLevel(level),
                              child: Builder(
                                builder: (context) {
                                  final words = c.catalog.levelWords(level);
                                  final count = words
                                      .where(
                                        (w) =>
                                            c.progress[w.id]?.learned == true,
                                      )
                                      .length;
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Tag(level),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              switch (level) {
                                                'A1' => 'First conversations',
                                                'A2' => 'Everyday confidence',
                                                'B1' =>
                                                  'Experiences & opinions',
                                                'B2' => 'Ideas that connect',
                                                _ => 'Nuance & precision',
                                              },
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$count / ${words.length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Garden.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: words.isEmpty
                                              ? 0
                                              : count / words.length,
                                          minHeight: 4,
                                          color: Garden.green,
                                          backgroundColor: Garden.border,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 10, color: Garden.muted)),
    ],
  );
}

class ProgressDetailsScreen extends StatelessWidget {
  const ProgressDetailsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      children: [
        const PageHeader(
          'Look how you’re growing.',
          'Small steps leave a beautiful trail.',
        ),
        GardenCard(
          color: Garden.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Your vocabulary garden'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.learned}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                          ),
                        ),
                        const Text(
                          'words recalled',
                          style: TextStyle(fontSize: 13, color: Garden.green),
                        ),
                      ],
                    ),
                  ),
                  const GardenIllustration(
                    'garden-achievement',
                    width: 130,
                    height: 132,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _Stat(
                      '${c.streak}',
                      'day streak',
                      Icons.local_fire_department_outlined,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      '${c.sessions}',
                      'sessions',
                      Icons.task_alt_rounded,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      c.attempts == 0
                          ? '—'
                          : '${(100 * c.correct / c.attempts).round()}%',
                      'accuracy',
                      Icons.track_changes_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        WeeklyActivity(controller: c),
        const SizedBox(height: 18),
        MemoryGarden(controller: c),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ReviewCard(
                title: 'Ready to revisit',
                count: c.dueWords.length,
                icon: Icons.history_rounded,
                color: Garden.lavender,
                onTap: c.dueWords.isEmpty
                    ? null
                    : () => startPractice(
                        context,
                        c,
                        c.dueWords,
                        PracticeMode.flashcards,
                        'Due for review',
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReviewCard(
                title: 'A little more practice',
                count: c.difficultWords.length,
                icon: Icons.psychology_outlined,
                color: Garden.peach,
                onTap: c.difficultWords.isEmpty
                    ? null
                    : () => startPractice(
                        context,
                        c,
                        c.difficultWords,
                        PracticeMode.flashcards,
                        'Tricky words',
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const ReviewTimeline(),
        const SizedBox(height: 22),
        LearningPath(controller: c),
        const SizedBox(height: 26),
        const SectionHeading('Your learning paths'),
        const SizedBox(height: 14),
        for (final level in levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GardenCard(
              padding: const EdgeInsets.all(17),
              child: Builder(
                builder: (context) {
                  final words = c.catalog.levelWords(level);
                  final count = words
                      .where((w) => c.progress[w.id]?.learned == true)
                      .length;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Tag(level),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              switch (level) {
                                'A1' => 'First conversations',
                                'A2' => 'Everyday confidence',
                                'B1' => 'Experiences & opinions',
                                'B2' => 'Ideas that connect',
                                _ => 'Nuance & precision',
                              },
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '$count / ${words.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Garden.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: words.isEmpty ? 0 : count / words.length,
                          minHeight: 5,
                          backgroundColor: Garden.mint,
                          color: Garden.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 14),
        const Text(
          'Remembering takes revisiting. Words return after 1, 3, 7 and 14 days as you recall them correctly.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Garden.muted, height: 1.6),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.icon);
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      IconBadge(icon, color: Colors.white.withValues(alpha: .7), size: 28),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 9, color: Garden.muted)),
    ],
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GardenCard(
    color: color,
    onTap: onTap,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon, color: Colors.white.withValues(alpha: .7), size: 36),
        const SizedBox(height: 14),
        Text(
          '$count words',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 10, color: Garden.muted)),
      ],
    ),
  );
}
