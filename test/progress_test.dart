import 'helpers/premium_fixture.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async => catalog = await Catalog.load());
  test(
    'catalog has stable, complete references and useful packs at every level',
    () {
      expect(catalog.words.length, 3284);
      expect(catalog.lessons.length, 565);
      expect(
        catalog.lessons.map((l) => l.id).toSet().length,
        catalog.lessons.length,
      );
      for (final lesson in catalog.lessons) {
        expect(lesson.wordIds, isNotEmpty);
        expect(lesson.wordIds.toSet().length, lesson.wordIds.length);
        expect(lesson.wordIds.every(catalog.words.containsKey), isTrue);
      }
      for (final level in levels) {
        expect(catalog.levelWords(level).length, greaterThanOrEqualTo(32));
        for (final exam in ['goethe', 'telc']) {
          expect(catalog.collections(level, exam: exam), isNotEmpty);
        }
      }
      expect(catalog.collections('A1').length, 44);
      expect(catalog.levelWords('A2').length, 1470);
      expect(catalog.levelWords('B1').length, 1532);
      expect(catalog.levelWords('B2').length, 688);
      expect(catalog.levelWords('C1').length, 390);
      expect(
        catalog
            .collections('A2')
            .where((l) => l.coverage == 'reference')
            .length,
        57,
      );
      expect(
        catalog
            .collections('B1')
            .where((l) => l.coverage == 'reference')
            .length,
        58,
      );
      expect(catalog.collections('A1', search: 'Äpfel'), isNotEmpty);
    },
  );
  test(
    'spelling accepts articles and Unicode equivalents but keeps umlauts',
    () {
      final word = catalog.words.values.firstWhere(
        (w) => w.term == 'der Apfel',
      );
      expect(word.accepts('  Der   Apfel  '), isTrue);
      expect(
        word.checkSpelling('DER APFEL').status,
        SpellingStatus.capitalisation,
      );
      expect(word.accepts('Apfel'), isTrue);
      final clothing = catalog.words.values.firstWhere(
        (w) => w.term == 'die Bäckerei',
      );
      expect(clothing.accepts('Ba\u0308ckerei'), isTrue);
      expect(clothing.accepts('Backerei'), isFalse);
    },
  );
  test('recall advances intervals; duplicate grades do not count twice; review is not mastery', () async {
    var now = DateTime(2026, 10, 8, 16);
    final c = AppController(
      catalog: catalog,
      storage: MemoryProgressStorage(),
      clock: () => now,
    );
    final word = catalog.levelWords('A1').first;
    for (final interval in [1, 3, 7, 14]) {
      c.startSession([word], PracticeMode.flashcards, 'Recall');
      c.grade(true);
      c.grade(true);
      c.nextWord();
      expect(c.progress[word.id]!.due, now.add(Duration(days: interval)));
      expect(c.todayCount, 1);
      now = now.add(const Duration(days: 1));
    }
    expect(c.progress[word.id]!.attempts, 4);
    c.startSession([word], PracticeMode.flashcards, 'Recall');
    c.grade(false);
    expect(c.progress[word.id]!.learned, isFalse);
    expect(c.dueWords.map((w) => w.id), contains(word.id));
    c.startSession([word], PracticeMode.review, 'Review');
    c.nextWord();
    expect(c.progress[word.id]!.learned, isFalse);
    expect(c.progress[word.id]!.attempts, 5);
    await c.flush();
    c.dispose();
  });
  test(
    'shared words retain progress across exam and general collections',
    () async {
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      );
      final word = catalog
          .levelWords('A1')
          .firstWhere(
            (w) => catalog
                .collections('A1', exam: 'goethe')
                .any((l) => l.wordIds.contains(w.id)),
          );
      c.startSession([word], PracticeMode.quiz, 'Quiz');
      c.grade(true);
      final lesson = catalog
          .collections('A1', exam: 'goethe')
          .firstWhere((l) => l.wordIds.contains(word.id));
      expect(c.lessonProgress(lesson), greaterThan(0));
      c.toggleSaved(word.id);
      expect(c.savedWords.single.id, word.id);
      await c.flush();
      c.dispose();
    },
  );
  test(
    'session, drafts, lists, stable quiz choices and progress survive restart',
    () async {
      final storage = MemoryProgressStorage();
      final c = AppController(
        catalog: catalog,
        storage: storage,
        purchases: await premiumFixture(),
      );
      final words = catalog.levelWords('A1').take(3).toList();
      c.chooseLevel('B2');
      c.setGoal(15);
      c.finishOnboarding();
      c.createList('My trip');
      c.toggleListWord('My trip', words.first.id);
      c.toggleSaved(words.first.id);
      c.startSession(words, PracticeMode.quiz, 'Test');
      c.grade(true);
      c.nextWord();
      c.saveDraft('A draft');
      final choices = c.quizOptions(words[1]);
      await c.flush();
      final restarted = AppController(catalog: catalog, storage: storage);
      await restarted.load();
      expect(restarted.level, 'B2');
      expect(restarted.goal, 15);
      expect(restarted.onboarded, isTrue);
      expect(restarted.session!.index, 1);
      expect(restarted.session!.answer, 'A draft');
      expect(restarted.quizOptions(words[1]), choices);
      expect(restarted.lists['My trip'], contains(words.first.id));
      expect(restarted.savedWords.single.id, words.first.id);
      expect(restarted.learned, 1);
      expect(choices.toSet().length, 4);
      expect(choices, contains(words[1].translation));
      c.dispose();
      restarted.dispose();
    },
  );
  test(
    'expanded reference collections preserve an older mobile study session',
    () async {
      const oldIds = [
        'a2-n-die-erfahrung',
        'a2-n-die-gewohnheit',
        'b1-n-die-verantwortung',
      ];
      final storage = MemoryProgressStorage();
      await storage.write({
        'schema': 1,
        'level': 'A2',
        'onboarded': true,
        'saved': oldIds,
        'bookmarks': ['a2-travel', 'b1-work'],
        'lists': {'My earlier words': oldIds},
        'progress': {
          oldIds[0]: {
            'box': 2,
            'correct': 2,
            'attempts': 2,
            'reviewed': true,
            'due': '2026-10-11T18:00:00.000',
          },
        },
        'session': {
          'title': 'Earlier A2 practice',
          'mode': 'spelling',
          'wordIds': oldIds,
          'seed': 42,
          'index': 1,
          'answer': 'Gewohn',
          'results': {oldIds[0]: true},
          'lessonId': 'a2-daily-life',
        },
      });
      final c = AppController(
        catalog: catalog,
        storage: storage,
        purchases: await premiumFixture(),
      );
      await c.load();
      expect(c.storageError, isNull);
      expect(c.saved, containsAll(oldIds));
      expect(c.lists['My earlier words'], containsAll(oldIds));
      expect(c.progress[oldIds[0]]!.box, 2);
      expect(c.session!.wordIds, oldIds);
      expect(c.session!.currentId, oldIds[1]);
      expect(c.session!.answer, 'Gewohn');
      expect(c.bookmarks, everyElement(isIn(catalog.lessons.map((l) => l.id))));
      c.saveDraft('Gewohnheit');
      c.grade(true);
      c.nextWord();
      await c.flush();
      final restored = AppController(catalog: catalog, storage: storage);
      await restored.load();
      expect(restored.session!.index, 2);
      expect(restored.progress[oldIds[1]]!.learned, isTrue);
      c.dispose();
      restored.dispose();
    },
  );
  test('daily goal counts distinct words and stops when complete', () async {
    final c = AppController(catalog: catalog, storage: MemoryProgressStorage());
    final words = c.dailyWords;
    expect(words.length, 5);
    c.startSession(words, PracticeMode.review, 'Daily');
    for (final _ in words) {
      c.nextWord();
    }
    expect(c.todayCount, 5);
    expect(c.dailyWords, isEmpty);
    expect(c.learned, 0);
    c.startSession(words, PracticeMode.quiz, 'Quiz');
    c.grade(true);
    expect(c.todayCount, 5);
    await c.flush();
    c.dispose();
  });
  test('streak uses local calendar dates and carries over yesterday', () async {
    var now = DateTime(2026, 10, 25, 18);
    final c = AppController(
      catalog: catalog,
      storage: MemoryProgressStorage(),
      clock: () => now,
    );
    final word = catalog.levelWords('A1').first;
    for (var i = 0; i < 3; i++) {
      c.startSession([word], PracticeMode.quiz, 'Streak');
      c.grade(true);
      c.nextWord();
      now = DateTime(now.year, now.month, now.day + 1, 18);
    }
    expect(c.streak, 3);
    now = DateTime(now.year, now.month, now.day + 1, 18);
    expect(c.streak, 0);
    await c.flush();
    c.dispose();
  });
  test(
    'read failures preserve existing data and disable overwriting',
    () async {
      final storage = _BrokenRead();
      final c = AppController(catalog: catalog, storage: storage);
      await c.load();
      expect(c.storageError, isNotNull);
      c.chooseLevel('C1');
      await c.flush();
      expect(storage.writes, 0);
      c.dispose();
    },
  );
  test(
    'failed writes can be retried without losing in-memory progress',
    () async {
      final storage = _RetryStorage();
      final c = AppController(catalog: catalog, storage: storage);
      c.chooseLevel('C1');
      await c.flush();
      expect(c.storageError, isNotNull);
      storage.fail = false;
      await c.retryStorage();
      expect(c.storageError, isNull);
      expect(storage.value!['level'], 'C1');
      c.dispose();
    },
  );
}

class _BrokenRead extends MemoryProgressStorage {
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read() async =>
      throw const FormatException('Bad data');
  @override
  Future<void> write(Map<String, dynamic> data) async {
    writes++;
  }
}

class _RetryStorage extends MemoryProgressStorage {
  bool fail = true;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(data);
  }
}
