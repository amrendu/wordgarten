import 'dart:math';

import 'package:flutter/material.dart';

import '../models/vocabulary.dart';
import '../state/app_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// Native charts keep labels accessible and values tied to real local progress.
class LearningPath extends StatelessWidget {
  const LearningPath({super.key, required this.controller, this.onExplore});
  final AppController controller;
  final VoidCallback? onExplore;
  @override
  Widget build(BuildContext context) => GardenCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.route_outlined, size: 18, color: Garden.green),
            SizedBox(width: 8),
            Expanded(child: Eyebrow('Your learning path')),
          ],
        ),
        const SizedBox(height: 18),
        Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: 23,
              child: Container(height: 2, color: Garden.border),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, level) in levels.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: controller.level == level,
                      label: 'Explore $level vocabulary',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          controller.chooseLevel(level);
                          onExplore?.call();
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: controller.level == level
                                    ? Garden.green
                                    : [
                                        Garden.mint,
                                        Garden.peach,
                                        Garden.lavender,
                                      ][i % 3],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                [
                                  Icons.eco_outlined,
                                  Icons.local_florist_outlined,
                                  Icons.park_outlined,
                                  Icons.workspace_premium_outlined,
                                  Icons.auto_awesome_outlined,
                                ][i],
                                size: 20,
                                color: controller.level == level
                                    ? Colors.white
                                    : Garden.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              level,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: controller.level == level
                                    ? Garden.green
                                    : Garden.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'From your first hello to expressing every nuance.',
          style: TextStyle(fontSize: 10, color: Garden.muted),
        ),
      ],
    ),
  );
}

class LearningCycle extends StatelessWidget {
  const LearningCycle({super.key});
  @override
  Widget build(BuildContext context) => GardenCard(
    color: const Color(0xFFF3F1E7),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('A small habit. A lasting memory.'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => GardenIllustration(
            'garden-cycle',
            width: constraints.maxWidth,
            height: constraints.maxWidth / 3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, title, subtitle) in [
              (0, 'Discover', 'Meet a new word'),
              (1, 'Recall', 'Try it from memory'),
              (2, 'Revisit', 'Let it take root'),
            ]) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Garden.muted,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Garden.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class WeeklyActivity extends StatelessWidget {
  const WeeklyActivity({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final bool compact;
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final now = controller.clock();
    final dates = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];
    final values = [
      for (final date in dates) controller.days[dayKey(date)]?.length ?? 0,
    ];
    final maximum = max(controller.goal, values.reduce(max));
    final total = values.fold(0, (a, b) => a + b);
    return GardenCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                Icons.insights_outlined,
                size: 34,
                color: Garden.lavender,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A week of little wins',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$total words practised in the last 7 days',
                      style: const TextStyle(fontSize: 10, color: Garden.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 22),
          SizedBox(
            height: compact ? 98 : 126,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 25,
                  child: CustomPaint(
                    painter: _GoalLinePainter(
                      controller.goal / maximum,
                      barHeight: compact ? 48 : 72,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, date) in dates.indexed)
                      Expanded(
                        child: Semantics(
                          label:
                              '${date.day}/${date.month}: ${values[i]} words practised',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${values[i]}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: i == 6 ? Garden.green : Garden.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: max(
                                  5,
                                  values[i] / maximum * (compact ? 48 : 72),
                                ),
                                width: 22,
                                decoration: BoxDecoration(
                                  color: values[i] == 0
                                      ? Garden.border
                                      : i == 6
                                      ? Garden.green
                                      : const Color(0xFFA6C1A0),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                [
                                  'M',
                                  'T',
                                  'W',
                                  'T',
                                  'F',
                                  'S',
                                  'S',
                                ][date.weekday - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: i == 6
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == 6 ? Garden.green : Garden.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 2,
                color: Garden.green.withValues(alpha: .4),
              ),
              const SizedBox(width: 7),
              Text(
                'Daily goal · ${controller.goal} words',
                style: const TextStyle(fontSize: 10, color: Garden.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  const _GoalLinePainter(this.fraction, {this.barHeight = 72});
  final double barHeight;
  final double fraction;
  @override
  void paint(Canvas canvas, Size size) {
    // Bars share a 72px scale above their baseline. Leave room for value labels.
    final y = size.height - barHeight * fraction;
    final paint = Paint()
      ..color = Garden.green.withValues(alpha: .22)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(min(x + 4, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) =>
      fraction != old.fraction || barHeight != old.barHeight;
}

class MemoryGarden extends StatelessWidget {
  const MemoryGarden({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final bool compact;
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final records = controller.progress.values
        .where((p) => p.reviewed)
        .toList();
    final seen = records.where((p) => p.attempts == 0).length;
    final practising = records.where((p) => p.attempts > 0 && p.box < 3).length;
    final remembered = records.where((p) => p.box >= 3).length;
    final counts = [seen, practising, remembered];
    const colors = [Color(0xFFCEC3E5), Color(0xFFDEB17D), Garden.green];
    return GardenCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.donut_large_rounded, size: 18, color: Garden.green),
              SizedBox(width: 9),
              Expanded(child: Eyebrow('How your words are growing')),
            ],
          ),
          SizedBox(height: compact ? 12 : 20),
          Row(
            children: [
              Semantics(
                label:
                    '${records.length} words explored: $seen seen, $practising practising, $remembered remembered',
                child: SizedBox(
                  width: compact ? 96 : 112,
                  height: compact ? 96 : 112,
                  child: CustomPaint(
                    painter: _MemoryRingPainter(counts, colors),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${records.length}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const Text(
                            'explored',
                            style: TextStyle(fontSize: 10, color: Garden.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 16 : 22),
              Expanded(
                child: Column(
                  children: [
                    for (final (i, label) in [
                      'Seen',
                      'Practising',
                      'Taking root',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: colors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              '${counts[i]}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
          if (!compact) ...[
            const SizedBox(height: 17),
            const Text(
              'Words take root after three successful recalls. A wrong answer brings them back for practice.',
              style: TextStyle(fontSize: 10, color: Garden.muted, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryRingPainter extends CustomPainter {
  const _MemoryRingPainter(this.counts, this.colors);
  final List<int> counts;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rect = bounds.deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Garden.border;
    canvas.drawOval(rect, paint);
    final total = counts.fold(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -pi / 2;
    for (var i = 0; i < counts.length; i++) {
      final sweep = 2 * pi * counts[i] / total;
      if (counts[i] > 0) {
        paint.color = colors[i];
        canvas.drawArc(rect, start + .03, max(.01, sweep - .06), false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_MemoryRingPainter old) => !_same(old.counts, counts);
  bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
}

class ReviewTimeline extends StatelessWidget {
  const ReviewTimeline({super.key});
  @override
  Widget build(BuildContext context) => GardenCard(
    color: Garden.lavender,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.event_repeat_rounded, size: 18, color: Garden.green),
            SizedBox(width: 8),
            Expanded(child: Eyebrow('The rhythm of remembering')),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final (i, days) in [1, 3, 7, 14].indexed) ...[
              if (i > 0)
                Expanded(
                  child: Container(height: 2, color: const Color(0xFFC9C2DD)),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$days',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Garden.green,
                      ),
                    ),
                    Text(
                      days == 1 ? 'day' : 'days',
                      style: const TextStyle(fontSize: 9, color: Garden.muted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 15),
        const Text(
          'Each correct recall moves your next review further ahead.',
          style: TextStyle(fontSize: 10, color: Garden.muted),
        ),
      ],
    ),
  );
}
