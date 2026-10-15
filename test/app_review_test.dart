import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/app_review_service.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/screens/practice_screen.dart';
import 'package:german_vocabulary/ui/theme.dart';

class FakeReviews implements AppReviewClient {
  @override
  bool supported = true;
  bool available = true, fail = false;
  int requests = 0, storeVisits = 0;
  Completer<bool>? availability;
  @override
  Future<bool> isAvailable() async => availability?.future ?? available;
  @override
  Future<void> requestReview() async {
    requests++;
    if (fail) throw StateError('Store unavailable');
  }

  @override
  Future<void> openStoreListing() async {
    if (fail) throw StateError('Store unavailable');
    storeVisits++;
  }
}

class FailedReviewStorage extends MemoryProgressStorage {
  @override
  Future<void> write(Map<String, dynamic> data) async {
    throw StateError('Disk full');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
    final font = FontLoader('Geist');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
    }
    await font.load();
  });

  test('90-day cooldown and three attempts per rolling year', () {
    final now = DateTime(2026, 10, 15);
    final history = AppReviewHistory()
      ..studyDays.addAll(['2026-10-13', '2026-10-14', '2026-10-15']);
    expect(history.eligible(now, 2), isFalse);
    expect(history.eligible(now, 3), isTrue);
    history.attempts.add(now);
    expect(history.eligible(now.add(const Duration(days: 89)), 3), isFalse);
    expect(history.eligible(now.add(const Duration(days: 90)), 3), isTrue);
    history.attempts.addAll([
      now.add(const Duration(days: 90)),
      now.add(const Duration(days: 180)),
    ]);
    expect(history.eligible(now.add(const Duration(days: 270)), 3), isFalse);
    expect(history.eligible(now.add(const Duration(days: 365)), 3), isTrue);
  });

  test(
    'all-incorrect sessions qualify and request history survives restart',
    () async {
      var now = DateTime(2026, 10, 13);
      final storage = MemoryProgressStorage();
      final reviews = FakeReviews();
      final c = AppController(
        catalog: catalog,
        storage: storage,
        reviews: reviews,
        clock: () => now,
      )..onboarded = true;
      for (var day = 13; day <= 15; day++) {
        now = DateTime(2026, 10, day);
        c.startSession(
          [catalog.words['guten-morgen']!],
          PracticeMode.quiz,
          'Test',
        );
        c.grade(false);
        c.nextWord();
      }
      expect(c.days, isEmpty); // Existing success-only progress is unchanged.
      expect(c.reviewHistory.studyDays.length, 3);
      expect(c.eligibleForReview, isTrue);
      await Future.wait([
        c.requestReviewAfterSession(canPresent: () => true),
        c.requestReviewAfterSession(canPresent: () => true),
      ]);
      expect(reviews.requests, 1);
      expect(reviews.storeVisits, 0);
      final restored = AppController(
        catalog: catalog,
        storage: storage,
        reviews: reviews,
        clock: () => now,
      );
      await restored.load();
      expect(restored.sessions, 3);
      expect(restored.progress['guten-morgen']!.attempts, 3);
      expect(restored.reviewHistory.studyDays.length, 3);
      expect(restored.eligibleForReview, isFalse);
      await c.flush();
      c.dispose();
      restored.dispose();
    },
  );

  test(
    'unavailable, errors, and navigation never force a store redirect',
    () async {
      final reviews = FakeReviews()..available = false;
      final c = _eligible(catalog, reviews);
      await c.requestReviewAfterSession(canPresent: () => true);
      expect(c.reviewHistory.attempts, isEmpty);
      reviews.availability = Completer<bool>();
      var visible = true;
      final pending = c.requestReviewAfterSession(canPresent: () => visible);
      visible = false;
      reviews.availability!.complete(true);
      await pending;
      expect(reviews.requests, 0);
      reviews.availability = null;
      reviews.available = true;
      reviews.fail = true;
      await c.requestReviewAfterSession(canPresent: () => true);
      expect(reviews.requests, 1);
      expect(reviews.storeVisits, 0);
      expect(c.reviewHistory.attempts.length, 1);
      await c.flush();
      c.dispose();
    },
  );

  test(
    'manual review link bypasses native quotas and delays automatic prompts',
    () async {
      final reviews = FakeReviews();
      final c = _eligible(catalog, reviews);
      c.reviewHistory.attempts.addAll(List.filled(3, c.clock()));
      expect(await c.openStoreReview(), isTrue);
      expect(reviews.storeVisits, 1);
      expect(reviews.requests, 0);
      expect(c.reviewHistory.lastStoreVisit, c.clock());
      expect(c.eligibleForReview, isFalse);
      await c.flush();
      c.dispose();
    },
  );

  test(
    'three distinct days and a completed session are both required',
    () async {
      final reviews = FakeReviews();
      final c = _eligible(catalog, reviews);
      c.reviewHistory.studyDays.remove('2026-10-13');
      await c.requestReviewAfterSession(canPresent: () => true);
      expect(reviews.requests, 0);
      c.reviewHistory.studyDays.add('2026-10-13');
      c.session!.index = 0;
      await c.requestReviewAfterSession(canPresent: () => true);
      expect(reviews.requests, 0);
      c.dispose();
    },
  );

  test('legacy study progress migrates without losing saved data', () async {
    final original = _eligible(catalog, FakeReviews());
    original.days['2026-10-13'] = {'guten-morgen'};
    original.saved.add('guten-morgen');
    final storage = MemoryProgressStorage()
      ..value = (original.snapshot()..remove('appReview'));
    final c = AppController(catalog: catalog, storage: storage);
    await c.load();
    expect(c.sessions, 3);
    expect(c.saved, contains('guten-morgen'));
    expect(c.reviewHistory.studyDays, {'2026-10-13'});
    expect(c.reviewHistory.attempts, isEmpty);
    original.dispose();
    c.dispose();
  });

  test('a request is skipped if its cooldown cannot be saved', () async {
    final reviews = FakeReviews();
    final original = _eligible(catalog, reviews);
    final c = AppController(
      catalog: catalog,
      storage: FailedReviewStorage(),
      reviews: reviews,
      clock: original.clock,
    )..onboarded = true;
    c.sessions = 3;
    c.session = original.session;
    c.reviewHistory.studyDays.addAll(original.reviewHistory.studyDays);
    await c.requestReviewAfterSession(canPresent: () => true);
    expect(reviews.requests, 0);
    expect(c.storageError, isNotNull);
    original.dispose();
    c.dispose();
  });

  testWidgets('summary waits two seconds and requests only once', (
    tester,
  ) async {
    final reviews = FakeReviews();
    final c = _eligible(catalog, reviews);
    await tester.pumpWidget(
      MaterialApp(
        theme: Garden.theme,
        home: PracticeScreen(controller: c),
      ),
    );
    await tester.pump();
    expect(find.text('Back to my words'), findsOneWidget);
    expect(reviews.requests, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(reviews.requests, 1);
    c.changed();
    await tester.pump(const Duration(seconds: 3));
    expect(reviews.requests, 1);
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });

  testWidgets('leaving the summary cancels the pending request', (
    tester,
  ) async {
    final reviews = FakeReviews();
    final c = _eligible(catalog, reviews);
    await tester.pumpWidget(
      MaterialApp(
        theme: Garden.theme,
        home: PracticeScreen(controller: c),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(reviews.requests, 0);
    expect(c.reviewHistory.attempts, isEmpty);
    c.dispose();
  });

  testWidgets('backgrounding the summary postpones the request', (
    tester,
  ) async {
    final reviews = FakeReviews();
    final c = _eligible(catalog, reviews);
    await tester.pumpWidget(
      MaterialApp(
        theme: Garden.theme,
        home: PracticeScreen(controller: c),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(reviews.requests, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(reviews.requests, 1);
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });

  testWidgets('permanent Home and Settings links open the store directly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reviews = FakeReviews();
    final c = AppController(
      catalog: catalog,
      storage: MemoryProgressStorage(),
      reviews: reviews,
    )..onboarded = true;
    await tester.pumpWidget(WortgartenApp(controller: c));
    await tester.pumpAndSettle();
    final homeLink = find.byKey(const ValueKey('home-rate-app'));
    await tester.scrollUntilVisible(
      homeLink,
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('home-discovery-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.descendant(of: homeLink, matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    expect(reviews.storeVisits, 1);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final settingsLink = find.byKey(const ValueKey('settings-rate-app'));
    await tester.ensureVisible(settingsLink);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: settingsLink, matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    expect(reviews.storeVisits, 2);
    expect(reviews.requests, 0);
    expect(find.byTooltip('Close settings').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.text('Make it your own'), findsNothing);
    expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });
}

AppController _eligible(Catalog catalog, FakeReviews reviews) {
  final c = AppController(
    catalog: catalog,
    storage: MemoryProgressStorage(),
    reviews: reviews,
    clock: () => DateTime(2026, 10, 15),
  )..onboarded = true;
  c.sessions = 3;
  c.reviewHistory.studyDays.addAll(['2026-10-13', '2026-10-14', '2026-10-15']);
  c.session = StudySession(
    title: 'Greetings',
    mode: PracticeMode.quiz,
    wordIds: ['guten-morgen'],
    seed: 1,
    index: 1,
    results: {'guten-morgen': false},
  );
  return c;
}
