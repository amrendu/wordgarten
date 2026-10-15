import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import '../infographics.dart';
import '../app_review_link.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onExplore,
    required this.onExam,
  });
  final AppController controller;
  final VoidCallback onExplore;
  final ValueChanged<String> onExam;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final lessons = c.catalog.collections(c.level);
    final goalDone = c.todayCount >= c.goal;
    final resume = c.session;
    final media = MediaQuery.of(context);
    final tablet =
        media.size.shortestSide >= 700 &&
        media.size.width >= 768 &&
        media.textScaler.scale(12) <= 18;
    final dailyPractice = GardenCard(
      color: Garden.mint,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: c.level,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ' · DAILY PRACTICE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(color: Garden.green),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      goalDone
                          ? 'A good day\nfor your German.'
                          : '${c.goal} words.\nFresh start.',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      goalDone
                          ? 'Your daily goal is complete. Keep exploring at your own pace.'
                          : 'A few minutes today.\nA little more confidence.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Garden.green,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                flex: 2,
                child: GardenIllustration(
                  'garden-hero',
                  width: 138,
                  height: 142,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: goalDone
                  ? onExplore
                  : () => startPractice(
                      context,
                      c,
                      c.dailyWords,
                      PracticeMode.flashcards,
                      'Daily practice',
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      goalDone
                          ? 'Explore more words'
                          : 'Start my daily practice',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final examSection = <Widget>[
      const SectionHeading('Prepare for your exam'),
      const SizedBox(height: 6),
      const Text(
        'Exam vocabulary for A1–C1',
        style: TextStyle(fontSize: 11, color: Garden.muted),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            for (final (exam, name, color, art) in [
              ('goethe', 'Goethe', Garden.lavender, 'school'),
              ('telc', 'telc', Garden.peach, 'checklist'),
            ])
              _ExamCard(
                key: ValueKey('home-exam-$exam'),
                controller: c,
                exam: exam,
                name: name,
                color: color,
                art: art,
                onTap: () => onExam(exam),
              ),
          ];
          if (constraints.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(14) > 18.2) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards.first, const SizedBox(height: 12), cards.last],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: 12),
              Expanded(child: cards.last),
            ],
          );
        },
      ),
    ];
    final dailyProgress = <Widget>[
      GardenCard(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            SizedBox(
              width: 43,
              height: 43,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (c.todayCount / c.goal).clamp(0, 1),
                    strokeWidth: 4,
                    backgroundColor: Garden.mint,
                    color: Garden.green,
                  ),
                  Text(
                    '${c.todayCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Every word is a small win',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.todayCount} of ${c.goal} words practised today',
                    style: const TextStyle(fontSize: 10, color: Garden.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.wb_sunny_outlined,
              size: 24,
              color: Color(0xFFD6AD64),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _Metric(
              icon: Icons.local_fire_department_outlined,
              value: '${c.streak}',
              label: 'day streak',
              color: Garden.peach,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Metric(
              icon: Icons.spa_outlined,
              value: '${c.learned}',
              label: 'words recalled',
              color: Garden.lavender,
            ),
          ),
        ],
      ),
    ];
    return ListView(
      key: const ValueKey('home-discovery-scroll'),
      padding: const EdgeInsets.all(24),
      children: [
        const Eyebrow('Guten Tag, word explorer'),
        const SizedBox(height: 9),
        Text(
          'Let your German\ngrow a little.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 18),

        LayoutBuilder(
          builder: (context, bounds) {
            if (!tablet || bounds.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dailyPractice,
                  const SizedBox(height: 22),
                  ...examSection,
                  const SizedBox(height: 16),
                  ...dailyProgress,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dailyPractice,
                      const SizedBox(height: 16),
                      LearningPath(controller: c, onExplore: onExplore),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...examSection,
                      const SizedBox(height: 16),
                      ...dailyProgress,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (resume != null && !resume.complete) ...[
          const SizedBox(height: 22),
          GardenCard(
            onTap: () => openPractice(context, c),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Garden.green,
                  size: 29,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pick up where you left off',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${resume.title} · ${resume.mode.label}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Garden.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
          ),
        ],
        if (!tablet) ...[
          const SizedBox(height: 22),
          LearningPath(controller: c, onExplore: onExplore),
        ],
        const SizedBox(height: 24),
        const SectionHeading('Find your rhythm'),
        const SizedBox(height: 6),
        const Text(
          'Five little ways to make your words stick.',
          style: TextStyle(fontSize: 11, color: Garden.muted),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 131,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PracticeMode.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (context, index) {
              final mode = PracticeMode.values[index];
              return SizedBox(
                width: 132,
                child: GardenCard(
                  color: [
                    Garden.mint,
                    Garden.lavender,
                    Garden.peach,
                  ][index % 3],
                  padding: const EdgeInsets.all(15),
                  onTap: () => startPractice(
                    context,
                    c,
                    c.catalog
                        .levelWords(c.level)
                        .where(
                          (w) =>
                              c.canAccessWord(w.id) &&
                              (mode != PracticeMode.forms || w.hasForms),
                        )
                        .take(10)
                        .toList(),
                    mode,
                    '${c.level} quick practice',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        modeIcon(mode),
                        color: Colors.white.withValues(alpha: .7),
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mode.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Read & listen',
                          'Flip & recall',
                          'Type it out',
                          'Make connections',
                          'Notice patterns',
                        ][index],
                        style: const TextStyle(
                          fontSize: 9,
                          color: Garden.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 26),
        SectionHeading(
          'Words for your world',
          action: 'Explore all',
          onAction: onExplore,
        ),
        const SizedBox(height: 14),
        for (final lesson in lessons.take(3))
          LessonTile(
            lesson: lesson,
            controller: c,
            onTap: () => openLesson(context, c, lesson),
          ),
        if (c.dueWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          GardenCard(
            color: Garden.lavender,
            onTap: () => startPractice(
              context,
              c,
              c.dueWords,
              PracticeMode.flashcards,
              'Due for review',
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: Garden.green),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.dueWords.length} words are ready for a revisit',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Give your memory a little love.',
                        style: TextStyle(color: Garden.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        AppReviewLink(key: const ValueKey('home-rate-app'), controller: c),
        const LearningCycle(),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Little by little becomes a lot. 🌱',
            style: TextStyle(fontSize: 11, color: Garden.muted),
          ),
        ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    super.key,
    required this.controller,
    required this.exam,
    required this.name,
    required this.color,
    required this.art,
    required this.onTap,
  });
  final AppController controller;
  final String exam, name, art;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lessons = controller.catalog.collections(
      controller.level,
      exam: exam,
    );
    final words = {
      for (final lesson in lessons)
        for (final word in controller.catalog.lessonWords(lesson)) word.id,
    }.length;
    return Semantics(
      button: true,
      label: '$name exam vocabulary',
      child: GardenCard(
        color: color,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Artwork(
                  art,
                  size: 50,
                  height: 50,
                  framed: true,
                  assetPath: controller.catalog.topicImages[art],
                ),
                const Spacer(),
                Tag(
                  controller.level,
                  color: Colors.white.withValues(alpha: .7),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${lessons.length} topics · $words words',
              style: const TextStyle(
                fontSize: 10,
                color: Garden.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => GardenCard(
    color: color,
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(
              icon,
              color: Colors.white.withValues(alpha: .6),
              size: 32,
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Garden.muted)),
      ],
    ),
  );
}
