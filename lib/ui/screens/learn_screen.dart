import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lesson_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.controller, this.initialExam})
    : assert(
        initialExam == null || initialExam == 'goethe' || initialExam == 'telc',
      );
  final AppController controller;
  final String? initialExam;
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _view = 0;
  String? _exam;
  String _search = '';
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _exam = widget.initialExam;
    if (_exam != null) _view = 2;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final lessons = c.catalog.collections(
      c.level,
      exam: _view == 2 ? _exam : null,
      search: _search,
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  'Find your words.',
                  'For your level. For your life. For your exam.',
                  compact: true,
                  trailing: GardenIllustration(
                    'garden-hero',
                    width: 64,
                    height: 48,
                  ),
                ),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search German or English',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Garden.muted,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF0E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      for (final (i, title) in [
                        (0, 'By level'),
                        (1, 'By topic'),
                        (2, 'By exam'),
                      ])
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => setState(() => _view = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _view == i
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _view == i
                                    ? [
                                        const BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _view == i ? Garden.ink : Garden.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 21),
                Row(
                  children: [
                    for (final l in levels) ...[
                      if (l != levels.first) const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          key: ValueKey('learn-level-$l'),
                          onTap: () => c.chooseLevel(l),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: c.level == l ? Garden.green : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: c.level == l
                                    ? Garden.green
                                    : Garden.border,
                              ),
                            ),
                            child: Text(
                              l,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.level == l ? Colors.white : Garden.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_view == 2) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final (id, name, color, art) in [
                        ('goethe', 'Goethe', Garden.lavender, 'school'),
                        ('telc', 'telc', Garden.peach, 'checklist'),
                      ])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: id == 'goethe' ? 10 : 0,
                            ),
                            child: GardenCard(
                              color: _exam == id ? color : Colors.white,
                              padding: const EdgeInsets.all(14),
                              onTap: () => setState(() => _exam = id),
                              child: Column(
                                children: [
                                  Artwork(
                                    art,
                                    size: 108,
                                    height: 108,
                                    framed: true,
                                    assetPath: c.catalog.topicImages[art],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_exam == id) ...[
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Garden.green,
                                          size: 15,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 25),
                SectionHeading(
                  _view == 2
                      ? (_exam == null
                            ? 'Choose your exam'
                            : '${_exam == 'goethe' ? 'Goethe' : 'telc'} · ${c.level}')
                      : '${c.level} · ${switch (c.level) {
                          'A1' => 'Your first conversations',
                          'A2' => 'Everyday confidence',
                          'B1' => 'More to say',
                          'B2' => 'Ideas that connect',
                          _ => 'Express yourself precisely',
                        }}',
                ),
                const SizedBox(height: 8),
                if (_view != 2 || _exam != null)
                  Text(
                    '${lessons.length} topics · ${lessons.expand((l) => l.wordIds).toSet().length} words${lessons.isNotEmpty && lessons.every((l) => l.coverage == 'starter') ? ' · starter collection' : ''}',
                    style: const TextStyle(fontSize: 11, color: Garden.muted),
                  ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        if (_view == 2 && _exam == null)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: EmptyGarden(
                'A path to your exam',
                'Choose Goethe or telc above to find the vocabulary for your preparation.',
                artwork: 'checklist',
              ),
            ),
          )
        else if (lessons.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: EmptyGarden(
                'No words found',
                'Try another word or explore a different level.',
                artwork: 'idea',
              ),
            ),
          )
        else if (_view == 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final lesson = lessons[index];
                  return GardenCard(
                    color: Garden.pastel(lesson.color),
                    padding: const EdgeInsets.all(10),
                    onTap: () => openLesson(context, c, lesson),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, box) => Artwork(
                            lesson.artwork,
                            size: box.maxWidth,
                            height: box.maxWidth,
                            framed: true,
                            assetPath: c.catalog.topicImages[lesson.artwork],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
                            lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${lesson.wordIds.length} words',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Garden.muted,
                                ),
                              ),
                            ),
                            Icon(
                              c.canAccessLesson(lesson)
                                  ? Icons.arrow_forward_rounded
                                  : Icons.lock_outline_rounded,
                              size: 15,
                              color: Garden.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }, childCount: lessons.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent:
                      (constraints.crossAxisExtent - 12) / 2 +
                      83 +
                      (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.builder(
              itemCount: lessons.length,
              itemBuilder: (context, index) => LessonTile(
                lesson: lessons[index],
                controller: c,
                onTap: () => openLesson(context, c, lessons[index]),
              ),
            ),
          ),
      ],
    );
  }
}
