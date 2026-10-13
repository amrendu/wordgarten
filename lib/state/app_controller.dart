import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/vocabulary.dart';
import '../services/progress_storage.dart';
import '../services/purchase_service.dart';
import 'content_access.dart';

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class WordProgress {
  WordProgress({
    this.box = 0,
    this.due,
    this.correct = 0,
    this.attempts = 0,
    this.reviewed = false,
    this.difficult = false,
  });
  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
    box: j['box'] ?? 0,
    due: DateTime.tryParse(j['due'] ?? ''),
    correct: j['correct'] ?? 0,
    attempts: j['attempts'] ?? 0,
    reviewed: j['reviewed'] ?? false,
    difficult: j['difficult'] ?? false,
  );
  int box, correct, attempts;
  DateTime? due;
  bool reviewed, difficult;
  bool get learned => box > 0;
  Map<String, dynamic> toJson() => {
    'box': box,
    'due': due?.toIso8601String(),
    'correct': correct,
    'attempts': attempts,
    'reviewed': reviewed,
    'difficult': difficult,
  };
}

class StudySession {
  StudySession({
    required this.title,
    required this.mode,
    required this.wordIds,
    required this.seed,
    this.index = 0,
    Map<String, bool>? results,
    this.revealed = false,
    this.answer = '',
    this.lessonId,
  }) : results = results ?? {};
  factory StudySession.fromJson(Map<String, dynamic> json) {
    final j = Map<String, dynamic>.from(json);
    final original = List<String>.from(j['wordIds']);
    final wordIds = original.map(canonicalWordId).toSet().toList();
    final index = j['index'] as int? ?? 0;
    final results = Map<String, bool>.from(j['results'] ?? {});
    final migrated = <String, bool>{};
    for (final entry in results.entries) {
      final id = canonicalWordId(entry.key);
      if (!migrated.containsKey(id) || entry.key == id) {
        migrated[id] = entry.value;
      }
    }
    j['wordIds'] = wordIds;
    j['index'] = index < 0
        ? index
        : index > original.length
        ? wordIds.length + 1
        : index == original.length
        ? wordIds.length
        : wordIds.indexOf(canonicalWordId(original[index]));
    j['results'] = migrated;
    return StudySession(
      title: j['title'],
      mode: PracticeMode.values.byName(j['mode']),
      wordIds: List<String>.from(j['wordIds']),
      seed: j['seed'],
      index: j['index'] ?? 0,
      results: Map<String, bool>.from(j['results'] ?? {}),
      revealed: j['revealed'] ?? false,
      answer: j['answer'] ?? '',
      lessonId: j['lessonId'],
    );
  }
  final String title;
  final PracticeMode mode;
  final List<String> wordIds;
  final int seed;
  final String? lessonId;
  int index;
  bool revealed;
  String answer;
  final Map<String, bool> results;
  bool get complete => index >= wordIds.length;
  String get currentId => wordIds[index];
  bool? get result => complete ? null : results[currentId];
  Map<String, dynamic> toJson() => {
    'title': title,
    'mode': mode.name,
    'wordIds': wordIds,
    'seed': seed,
    'index': index,
    'results': Map<String, bool>.from(results),
    'revealed': revealed,
    'answer': answer,
    'lessonId': lessonId,
  };
}

class AppController extends ChangeNotifier {
  AppController({
    required this.catalog,
    required this.storage,
    BillingController? purchases,
    this.disposePurchases = true,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       purchases = purchases ?? PurchasesController.unavailable(),
       access = ContentAccess(catalog) {
    this.purchases.addListener(_billingChanged);
  }
  final Catalog catalog;
  final ProgressStorage storage;
  final DateTime Function() clock;
  final BillingController purchases;
  final bool disposePurchases;
  final ContentAccess access;
  final retainedWordIds = <String>{};
  bool get premium => purchases.premium;
  bool canAccessLesson(Lesson lesson) =>
      premium || access.freeLessonIds.contains(lesson.id);
  bool canAccessWord(String id) =>
      premium ||
      access.freeWordIds.contains(id) ||
      retainedWordIds.contains(id);
  void _billingChanged() => notifyListeners();
  final saved = <String>{};
  final bookmarks = <String>{};
  final lists = <String, Set<String>>{};
  final progress = <String, WordProgress>{};
  final days = <String, Set<String>>{};
  String level = 'A1';
  int goal = 5, sessions = 0;
  bool onboarded = false, reminder = false;
  int reminderHour = 19, reminderMinute = 0;
  double speechRate = .45;
  StudySession? session;
  String? storageError;
  bool _readFailed = false;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    try {
      final j = await storage.read();
      if (j == null) return;
      if (j['schema'] != 1) {
        throw const FormatException('Unknown progress version');
      }
      level = levels.contains(j['level']) ? j['level'] : 'A1';
      goal = [5, 10, 15, 20].contains(j['goal']) ? j['goal'] : 5;
      onboarded = j['onboarded'] == true;
      reminder = j['reminder'] == true;
      reminderHour = (j['reminderHour'] as int? ?? 19).clamp(0, 23);
      reminderMinute = (j['reminderMinute'] as int? ?? 0).clamp(0, 59);
      speechRate = ((j['speechRate'] as num?)?.toDouble() ?? .45).clamp(
        .25,
        .65,
      );
      sessions = j['sessions'] ?? 0;
      saved.addAll(
        List<String>.from(j['saved'] ?? [])
            .map(canonicalWordId)
            .where(catalog.words.containsKey),
      );
      bookmarks.addAll(List<String>.from(j['bookmarks'] ?? []));
      for (final entry in (j['lists'] as Map<String, dynamic>? ?? {}).entries) {
        lists[entry.key] = List<String>.from(entry.value)
            .map(canonicalWordId)
            .where(catalog.words.containsKey)
            .toSet();
      }
      for (final entry
          in (j['progress'] as Map<String, dynamic>? ?? {}).entries) {
        final id = canonicalWordId(entry.key);
        if (catalog.words.containsKey(id) &&
            (!progress.containsKey(id) || entry.key == id)) {
          progress[id] = WordProgress.fromJson(entry.value);
        }
      }
      for (final entry in (j['days'] as Map<String, dynamic>? ?? {}).entries) {
        days[entry.key] = List<String>.from(entry.value)
            .map(canonicalWordId)
            .where(catalog.words.containsKey)
            .toSet();
      }
      retainedWordIds.addAll(
        List<String>.from(j['retainedWordIds'] ?? [])
            .map(canonicalWordId)
            .where(catalog.words.containsKey),
      );
      if (j['accessVersion'] == null) {
        // Existing learners keep access to their saved cards and unfinished work.
        retainedWordIds.addAll(
          {
            ...saved,
            ...progress.keys,
            ...lists.values.expand((ids) => ids),
            ...List<String>.from(j['session']?['wordIds'] ?? [])
                .map(canonicalWordId),
          }.where(catalog.words.containsKey),
        );
      }
      if (j['session'] != null) {
        final candidate = StudySession.fromJson(j['session']);
        if (candidate.wordIds.isNotEmpty &&
            candidate.index >= 0 &&
            candidate.index < candidate.wordIds.length &&
            candidate.wordIds.every(catalog.words.containsKey)) {
          session = candidate;
        }
      }
      if (j['accessVersion'] == null) changed();
    } catch (_) {
      _readFailed = true;
      storageError = 'Saved progress could not be loaded. Your existing data has been preserved.';
    }
    notifyListeners();
  }

  Map<String, dynamic> snapshot() => {
    'schema': 1,
    'accessVersion': 1,
    'retainedWordIds': retainedWordIds.toList(),
    'level': level,
    'goal': goal,
    'onboarded': onboarded,
    'saved': saved.toList(),
    'bookmarks': bookmarks.toList(),
    'lists': lists.map((k, v) => MapEntry(k, v.toList())),
    'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
    'days': days.map((k, v) => MapEntry(k, v.toList())),
    'sessions': sessions,
    'session': session?.toJson(),
    'reminder': reminder,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'speechRate': speechRate,
  };
  void changed() {
    notifyListeners();
    if (_readFailed) return;
    final value = snapshot();
    _pending = _pending.then((_) async {
      try {
        await storage.write(value);
        if (storageError != null) {
          storageError = null;
          notifyListeners();
        }
      } catch (_) {
        storageError =
            'Your last changes could not be saved. Tap Retry to try again.';
        notifyListeners();
      }
    });
  }

  Future<void> flush() => _pending;
  void refreshForClock() => notifyListeners();
  Future<void> retryStorage() async {
    if (_readFailed) {
      saved.clear();
      bookmarks.clear();
      lists.clear();
      progress.clear();
      days.clear();
      retainedWordIds.clear();
      _readFailed = false;
      storageError = null;
      await load();
    } else {
      changed();
      await flush();
    }
  }

  void chooseLevel(String value) {
    level = value;
    changed();
  }

  void setGoal(int value) {
    goal = value;
    changed();
  }

  void finishOnboarding() {
    onboarded = true;
    changed();
  }

  void toggleSaved(String id) {
    if (!saved.add(id)) saved.remove(id);
    changed();
  }

  void toggleBookmark(String id) {
    if (!bookmarks.add(id)) bookmarks.remove(id);
    changed();
  }

  bool createList(String name) {
    if (!premium) return false;
    name = name.trim();
    if (name.isEmpty || lists.containsKey(name)) return false;
    lists[name] = {};
    changed();
    return true;
  }

  void toggleListWord(String name, String id) {
    if (!premium) return;
    final list = lists[name];
    if (list == null) return;
    if (!list.add(id)) list.remove(id);
    changed();
  }

  void deleteList(String name) {
    lists.remove(name);
    changed();
  }

  int get todayCount => days[dayKey(clock())]?.length ?? 0;
  int get learned => progress.values.where((p) => p.learned).length;
  int get reviewed => progress.values.where((p) => p.reviewed).length;
  int get attempts => progress.values.fold(0, (sum, p) => sum + p.attempts);
  int get correct => progress.values.fold(0, (sum, p) => sum + p.correct);
  int get streak {
    var date = calendarDay(clock());
    if ((days[dayKey(date)] ?? {}).isEmpty) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var count = 0;
    while ((days[dayKey(date)] ?? {}).isNotEmpty) {
      count++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return count;
  }

  List<Word> get dueWords => catalog.words.values.where((w) {
    final p = progress[w.id];
    return canAccessWord(w.id) && p?.due != null && !p!.due!.isAfter(clock());
  }).toList();
  List<Word> get difficultWords => catalog.words.values
      .where((w) => progress[w.id]?.difficult == true)
      .toList();
  List<Word> get savedWords => [
    for (final id in saved)
      if (catalog.words[id] != null) catalog.words[id]!,
  ];
  double lessonProgress(Lesson l) =>
      l.wordIds.where((id) => progress[id]?.learned == true).length /
      l.wordIds.length;
  List<Word> get dailyWords {
    final today = days[dayKey(clock())] ?? {};
    final pool = catalog
        .levelWords(level)
        .where((w) => canAccessWord(w.id) && !today.contains(w.id))
        .toList();
    pool.shuffle(Random(dayKey(clock()).hashCode));
    pool.sort((a, b) {
      int rank(Word w) =>
          progress[w.id]?.due != null && !progress[w.id]!.due!.isAfter(clock())
          ? 0
          : progress[w.id]?.learned == true
          ? 2
          : 1;
      return rank(a).compareTo(rank(b));
    });
    return pool.take(max(0, goal - todayCount)).toList();
  }

  bool startSession(
    List<Word> words,
    PracticeMode mode,
    String title, {
    String? lessonId,
  }) {
    if (words.any((w) => !canAccessWord(w.id))) return false;
    final eligible = words
        .where((w) => mode != PracticeMode.forms || w.hasForms)
        .toList();
    if (eligible.isEmpty) return false;
    session = StudySession(
      title: title,
      mode: mode,
      wordIds: eligible.map((w) => w.id).toSet().toList(),
      seed: clock().millisecondsSinceEpoch & 0x7fffffff,
      lessonId: lessonId,
    );
    changed();
    return true;
  }

  void reveal() {
    session?.revealed = true;
    changed();
  }

  void saveDraft(String value) {
    session?.answer = value;
    changed();
  }

  void grade(bool success) {
    final s = session;
    if (s == null ||
        s.complete ||
        !canAccessWord(s.currentId) ||
        s.results.containsKey(s.currentId)) {
      return;
    }
    s.results[s.currentId] = success;
    _recordAnswer(s.currentId, success, recall: s.mode != PracticeMode.review);
    changed();
  }

  void recordMiniLesson(Word word, bool success) {
    if (!canAccessWord(word.id)) return;
    _recordAnswer(word.id, success, recall: true);
    sessions++;
    changed();
  }

  void _recordAnswer(String id, bool success, {required bool recall}) {
    final p = progress.putIfAbsent(id, WordProgress.new);
    p.reviewed = true;
    if (recall) {
      p.attempts++;
      if (success) {
        p.correct++;
        p.box = min(4, p.box + 1);
        p.difficult = false;
        p.due = clock().add(Duration(days: [1, 3, 7, 14][p.box - 1]));
      } else {
        p.box = 0;
        p.difficult = true;
        p.due = clock();
      }
    }
    if (success) days.putIfAbsent(dayKey(clock()), () => {}).add(id);
  }

  void nextWord() {
    final s = session;
    if (s == null || s.complete || !canAccessWord(s.currentId)) return;
    if (s.mode == PracticeMode.review && s.result == null) grade(true);
    if (s.result == null) return;
    s.index++;
    s.revealed = false;
    s.answer = '';
    if (s.complete) sessions++;
    changed();
  }

  List<String> quizOptions(Word word, {bool context = false}) {
    final s = session!;
    if (context && word.contextSentence != null) {
      return [...word.contextQuiz!.choices]
        ..shuffle(Random(s.seed + s.index + 1));
    }
    final answer = word.translation;
    final random = Random(s.seed + s.index);
    final candidates =
        catalog.words.values
            .where((w) => w.id != word.id && w.term != word.term)
            .toList()
          ..shuffle(random);
    final samePart = candidates.where((w) => w.part == word.part);
    final choices = <String>{answer};
    final seen = {normalizeVocabularyText(answer).toLowerCase()};
    for (final w in [...samePart, ...candidates]) {
      final candidate = w.translation;
      if (!seen.add(normalizeVocabularyText(candidate).toLowerCase())) continue;
      choices.add(candidate);
      if (choices.length == 4) break;
    }
    return choices.toList()..shuffle(Random(s.seed + s.index + 1));
  }

  @override
  void dispose() {
    purchases.removeListener(_billingChanged);
    if (disposePurchases) purchases.dispose();
    _pending.then((_) => storage.close());
    super.dispose();
  }
}
