import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../services/speech_service.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import '../word_grammar.dart';
import 'practice_screen.dart';
import 'paywall_screen.dart';

void openLesson(BuildContext context, AppController c, Lesson lesson) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(controller: c, lesson: lesson),
      ),
    );

class LessonScreen extends StatelessWidget {
  const LessonScreen({
    super.key,
    required this.controller,
    required this.lesson,
  });
  final AppController controller;
  final Lesson lesson;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        backgroundColor: Garden.background,
        title: Text(
          lesson.level,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bookmark topic',
            onPressed: () => controller.toggleBookmark(lesson.id),
            icon: Icon(
              controller.bookmarks.contains(lesson.id)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              color: Garden.green,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          GardenCard(
            color: Garden.pastel(lesson.color),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, box) => Center(
                    child: Artwork(
                      lesson.artwork,
                      size: box.maxWidth,
                      height: box.maxWidth.clamp(160, 220),
                      framed: true,
                      assetPath: controller.catalog.topicImages[lesson.artwork],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      lesson.exam == null
                          ? 'Words for your world'
                          : '${lesson.exam} preparation',
                    ),
                    const SizedBox(height: 9),
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 25),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      lesson.germanTitle,
                      style: const TextStyle(fontSize: 12, color: Garden.green),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      '${lesson.wordIds.length} words · ${lesson.level}',
                      style: const TextStyle(fontSize: 11, color: Garden.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(lesson.description, style: const TextStyle(color: Garden.muted)),
          if (lesson.coverage == 'starter') ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 15,
                  color: Garden.green,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'An editorial starter pack to get you going.',
                    style: TextStyle(fontSize: 11, color: Garden.green),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (!controller.canAccessLesson(lesson)) ...[
            PremiumInvitation(
              controller: controller,
              title: 'Grow beyond this preview.',
              description:
                  'Unlock ${lesson.title}, every level and Goethe/telc collections.',
            ),
            const SizedBox(height: 18),
          ],
          SectionHeading(
            'Your words',
            action:
                '${(controller.lessonProgress(lesson) * 100).round()}% recalled',
          ),
          const SizedBox(height: 12),
          for (final word
              in controller.canAccessLesson(lesson)
                  ? controller.catalog.lessonWords(lesson)
                  : controller.catalog.lessonWords(lesson).take(3))
            WordTile(
              word: word,
              controller: controller,
              onTap: () => showWordDetails(context, controller, word),
            ),
          const SizedBox(height: 12),
          Text(
            lesson.source,
            style: const TextStyle(fontSize: 10, color: Garden.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton.icon(
            onPressed: !controller.canAccessLesson(lesson)
                ? () => showPaywall(
                    context,
                    controller,
                    reason: 'Unlock ${lesson.title}.',
                  )
                : () => showModePicker(
                    context,
                    controller,
                    controller.catalog.lessonWords(lesson),
                    lesson.title,
                    lessonId: lesson.id,
                  ),
            icon: const Icon(Icons.style_outlined, size: 20),
            label: Text(
              controller.canAccessLesson(lesson)
                  ? 'Practise this topic'
                  : 'Unlock this topic',
            ),
          ),
        ),
      ),
    ),
  );
}

class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.word,
    required this.controller,
    required this.onTap,
  });
  final Word word;
  final AppController controller;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GardenCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      onTap: onTap,
      child: Row(
        children: [
          WordArtwork(word, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        word.term,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (controller.progress[word.id]?.learned == true) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                        color: Garden.green,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  word.translation,
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: controller.saved.contains(word.id)
                ? 'Unsave word'
                : 'Save word',
            onPressed: () {
              if (!controller.canAccessWord(word.id) &&
                  !controller.saved.contains(word.id)) {
                showPaywall(
                  context,
                  controller,
                  reason: 'Unlock this word and its collection.',
                );
                return;
              }
              controller.toggleSaved(word.id);
            },
            icon: Icon(
              controller.saved.contains(word.id)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 20,
              color: controller.saved.contains(word.id)
                  ? Garden.green
                  : Garden.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

void showWordDetails(BuildContext context, AppController c, Word word) {
  if (!c.canAccessWord(word.id) &&
      !c.saved.contains(word.id) &&
      !c.progress.containsKey(word.id)) {
    showPaywall(context, c, reason: 'Unlock this word and its collection.');
    return;
  }
  final speech = SpeechService();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Tag(word.part),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Listen to pronunciation',
                    onPressed: () async {
                      final result = await speech.playWord(
                        word,
                        rate: c.speechRate,
                      );
                      if (result == PlaybackResult.failed && context.mounted) {
                        toast(
                          context,
                          'A German voice is unavailable. Install a German voice in your device settings.',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.volume_up_outlined,
                      color: Garden.green,
                    ),
                  ),
                ],
              ),
              Center(
                child: WordArtwork(
                  word,
                  size: (MediaQuery.sizeOf(context).width - 96).clamp(180, 260),
                  enlargeable: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                word.term,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                word.translation,
                style: const TextStyle(fontSize: 19, color: Garden.muted),
              ),
              if (word.pronunciation != null) ...[
                const SizedBox(height: 7),
                Text(
                  word.pronunciation!,
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
              ],
              const SizedBox(height: 17),
              Text(word.definition),
              const SizedBox(height: 20),
              GardenCard(
                color: Garden.mint,
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('In a sentence'),
                    const SizedBox(height: 8),
                    Text(
                      word.example,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      word.exampleTranslation,
                      style: const TextStyle(fontSize: 12, color: Garden.muted),
                    ),
                  ],
                ),
              ),
              if (word.hasForms) ...[
                const SizedBox(height: 18),
                WordGrammarDetails(word: word),
              ],
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => c.toggleSaved(word.id),
                      icon: Icon(
                        c.saved.contains(word.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        c.saved.contains(word.id) ? 'Saved' : 'Save word',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showAddToList(context, c, word),
                      icon: const Icon(Icons.playlist_add_rounded, size: 19),
                      label: const Text('Add to list'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(speech.stop);
}

void showAddToList(BuildContext context, AppController c, Word word) {
  if (!c.premium) {
    showPaywall(context, c, reason: 'Make your own word collections.');
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A home for this word',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(word.term, style: const TextStyle(color: Garden.muted)),
              const SizedBox(height: 16),
              for (final name in c.lists.keys)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  value: c.lists[name]!.contains(word.id),
                  onChanged: (_) => c.toggleListWord(name, word.id),
                ),
              TextButton.icon(
                onPressed: () => showCreateList(context, c),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Create a new list'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showCreateList(BuildContext context, AppController c) async {
  if (!await requirePremium(context, c, 'Make your own word collections.') ||
      !context.mounted) {
    return;
  }
  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your own little collection'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        maxLength: 48,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Words for my trip'),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, nameController.text);
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  // Dispose after the dialog's closing animation has released its TextField.
  Future<void>.delayed(
    const Duration(milliseconds: 300),
    nameController.dispose,
  );
  if (name != null && !c.createList(name) && context.mounted) {
    toast(context, 'A list with this name already exists.');
  }
}
