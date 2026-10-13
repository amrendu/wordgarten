import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';
import 'paywall_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _view = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final words = _view == 3 ? c.difficultWords : c.savedWords;
    final bookmarked = c.catalog.lessons
        .where((l) => c.bookmarks.contains(l.id))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      children: [
        const PageHeader(
          'Keep them close.',
          'Your words, collected your way.',
          compact: true,
        ),
        GardenCard(
          color: Garden.lavender,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Your personal collection'),
                    const SizedBox(height: 6),
                    Text(
                      '${c.saved.length} favourite words',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Your personal word garden.',
                      style: TextStyle(fontSize: 11, color: Garden.muted),
                    ),
                  ],
                ),
              ),
              const GardenIllustration(
                'garden-achievement',
                width: 64,
                height: 68,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            for (final (i, label) in [
              (0, 'Saved'),
              (1, 'My lists'),
              (2, 'Topics'),
              (3, 'Tricky words'),
            ])
              ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
                selected: _view == i,
                selectedColor: Garden.mint,
                showCheckmark: false,
                onSelected: (_) => setState(() => _view = i),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_view == 0 || _view == 3) ...[
          if (words.isEmpty)
            EmptyGarden(
              _view == 0
                  ? 'Your next favourites are out there.'
                  : 'Nothing tricky here yet.',
              _view == 0 ? 'Tap the bookmark beside a word to keep it here.' : 'Words you find difficult will appear here for another try.',
              artwork: _view == 0 ? 'letter' : 'idea',
            )
          else ...[
            FilledButton.icon(
              onPressed: () {
                if (_view == 3 && !c.premium) {
                  showPaywall(
                    context,
                    c,
                    reason: 'Give your difficult words another chance.',
                  );
                  return;
                }
                showModePicker(
                  context,
                  c,
                  words,
                  _view == 0 ? 'Saved words' : 'Tricky words',
                );
              },
              icon: const Icon(Icons.style_outlined, size: 18),
              label: Text('Practise ${words.length} words'),
            ),
            const SizedBox(height: 18),
            for (final word in words)
              WordTile(
                word: word,
                controller: c,
                onTap: () => showWordDetails(context, c, word),
              ),
          ],
        ],
        if (_view == 1) ...[
          SectionHeading(
            'Your collections',
            action: '+ New list',
            onAction: () => showCreateList(context, c),
          ),
          const SizedBox(height: 12),
          if (c.lists.isEmpty)
            EmptyGarden(
              'Make room for your words.',
              'Create a list for your next trip, your work, or the words you always forget.',
              artwork: 'checklist',
              action: FilledButton.icon(
                onPressed: () => showCreateList(context, c),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create my first list'),
              ),
            ),
          for (final entry in c.lists.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GardenCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WordListScreen(controller: c, name: entry.key),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      color: Garden.green,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${entry.value.length} words',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Garden.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ),
        ],
        if (_view == 2) ...[
          if (bookmarked.isEmpty)
            const EmptyGarden(
              'A place for your favourite topics.',
              'Bookmark a topic to find it here next time.',
              artwork: 'school',
            ),
          for (final lesson in bookmarked)
            LessonTile(
              lesson: lesson,
              controller: c,
              onTap: () => openLesson(context, c, lesson),
            ),
        ],
      ],
    );
  }
}

class WordListScreen extends StatelessWidget {
  const WordListScreen({
    super.key,
    required this.controller,
    required this.name,
  });
  final AppController controller;
  final String name;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final words = <Word>[
        for (final id in controller.lists[name] ?? <String>{})
          if (controller.catalog.words[id] != null)
            controller.catalog.words[id]!,
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Delete list',
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete this list?'),
                    content: const Text(
                      'Your word progress and saved words will be kept.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep list'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  controller.deleteList(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (words.isEmpty)
              const EmptyGarden(
                'This collection is ready to grow.',
                'Open any word and tap “Add to list” to put it here.',
                artwork: 'letter',
              ),
            for (final word in words)
              Column(
                children: [
                  WordTile(
                    word: word,
                    controller: controller,
                    onTap: () => showWordDetails(context, controller, word),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => controller.toggleListWord(name, word.id),
                      child: const Text(
                        'Remove from list',
                        style: TextStyle(fontSize: 11, color: Garden.muted),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: words.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed: () =>
                        showModePicker(context, controller, words, name),
                    child: const Text('Practise this list'),
                  ),
                ),
              ),
      );
    },
  );
}
