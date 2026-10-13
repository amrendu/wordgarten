import 'helpers/premium_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/screens/practice_screen.dart';
import 'package:german_vocabulary/ui/theme.dart';
import 'package:german_vocabulary/ui/widgets.dart';

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
  compactLayoutChecks(() => catalog);
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Home opens each exam at the selected level at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = AppController(
          catalog: catalog,
          storage: MemoryProgressStorage(),
        )..onboarded = true;
        c.chooseLevel('B1');
        c.startSession(
          [catalog.words['guten-morgen']!],
          PracticeMode.flashcards,
          'Existing session',
        );
        await tester.pumpWidget(WortgartenApp(controller: c));
        await tester.pumpAndSettle();

        final levelSelector = find.byKey(
          const ValueKey('current-level-selector'),
        );
        expect(tester.getSize(levelSelector).height, greaterThanOrEqualTo(48));
        await tester.tap(levelSelector);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('level-choice-C1')),
        );
        await tester.tap(find.byKey(const ValueKey('level-choice-C1')));
        await tester.pumpAndSettle();
        expect(c.level, 'C1');
        await tester.tap(levelSelector);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('level-choice-B1')));
        await tester.pumpAndSettle();
        expect(c.level, 'B1');
        expect(find.text('Find your level'), findsNothing);

        for (final exam in ['goethe', 'telc', 'goethe']) {
          final card = find.byKey(ValueKey('home-exam-$exam'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final lessons = catalog.collections(c.level, exam: exam);
          final wordCount = lessons.expand((l) => l.wordIds).toSet().length;
          expect(
            find.descendant(
              of: card,
              matching: find.text(
                '${lessons.length} topics · $wordCount words',
              ),
            ),
            findsOneWidget,
          );
          await tester.tap(card);
          await tester.pumpAndSettle();
          final name = exam == 'goethe' ? 'Goethe' : 'telc';
          expect(find.text('$name · ${c.level}'), findsOneWidget);
          expect(find.text(lessons.first.title), findsOneWidget);
          expect(find.text('Wortgarten Premium'), findsNothing);
          expect(c.session!.currentId, 'guten-morgen');
          expect(c.progress, isEmpty);
          expect(tester.takeException(), isNull);

          // A Home shortcut must clear stale browsing/search state, even when
          // re-entering an exam that was already selected before.
          await tester.enterText(find.byType(TextField), 'no-such-exam-word');
          await tester.pumpAndSettle();
          expect(find.text('No words found'), findsOneWidget);
          if (exam == 'telc') c.chooseLevel('C1');
          await tester.tap(find.text('Home'));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(const SizedBox());
        await c.flush();
        c.dispose();
      },
    );
  }
  testWidgets(
    'image preview returns to the same practice card without changing progress',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      c.startSession(
        [catalog.words['apfel']!, catalog.words['brot']!],
        PracticeMode.flashcards,
        'Picture preview',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: PracticeScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WordArtwork), findsNothing);
      expect(find.text(catalog.words['apfel']!.translation), findsNothing);
      await tester.tap(find.text('Reveal meaning'));
      await tester.pumpAndSettle();
      expect(find.byType(WordArtwork), findsOneWidget);
      await tester.ensureVisible(find.text('Example & word details'));
      await tester.tap(find.text('Example & word details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enlarge image'));
      await tester.pumpAndSettle();
      expect(find.text('Pinch to zoom'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(c.session!.currentId, 'apfel');
      expect(c.session!.index, 0);
      expect(c.progress, isEmpty);
      expect(c.session!.revealed, isTrue);
      await tester.tap(find.byTooltip('Close image preview'));
      await tester.pumpAndSettle();
      expect(find.text('Pinch to zoom'), findsNothing);
      expect(find.byTooltip('Enlarge image'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('browse and navigate without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      )..onboarded = true;
      await tester.pumpWidget(WortgartenApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Let your German\ngrow a little.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C1').last);
      await tester.pumpAndSettle();
      expect(find.text(catalog.collections('C1').first.title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('By topic'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('By exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goethe'));
      await tester.pumpAndSettle();
      expect(
        find.text(catalog.collections('C1', exam: 'goethe').first.title),
        findsOneWidget,
      );
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Levels'));
      await tester.pumpAndSettle();
      expect(find.text('Your learning paths'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    });
  }
  testWidgets('welcome selects a level and opens the app', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final c = AppController(catalog: catalog, storage: MemoryProgressStorage());
    await tester.pumpWidget(WortgartenApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Start growing').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Start growing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try my first word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal meaning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Wortgarten Premium'), findsOneWidget);
    await tester.tap(find.text('Continue free'));
    await tester.pumpAndSettle();
    expect(c.level, 'B1');
    expect(c.onboarded, isTrue);
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });
  for (final mode in PracticeMode.values) {
    testWidgets('${mode.label} grades, finishes and stores a real session', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      final word = catalog.words.values.firstWhere(
        (w) => w.term == 'der Apfel',
      );
      c.startSession([word], mode, 'Test topic');
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: PracticeScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      switch (mode) {
        case PracticeMode.flashcards:
        case PracticeMode.forms:
          await tester.tap(
            find.text(
              mode == PracticeMode.forms
                  ? 'Reveal word forms'
                  : 'Reveal meaning',
            ),
          );
          await tester.pumpAndSettle();
          final grade = mode == PracticeMode.flashcards
              ? 'I knew it'
              : 'Got it';
          await tester.ensureVisible(find.text(grade));
          await tester.tap(find.text(grade));
          await tester.pumpAndSettle();
        case PracticeMode.spelling:
          await tester.enterText(find.byType(TextField), 'Apfel');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Check my answer'));
          await tester.tap(find.text('Check my answer'));
          await tester.pumpAndSettle();
        case PracticeMode.quiz:
          await tester.ensureVisible(find.text(word.translation));
          await tester.tap(find.text(word.translation));
          await tester.pumpAndSettle();
        case PracticeMode.review:
          break;
      }
      await tester.ensureVisible(find.text('Finish session'));
      await tester.tap(find.text('Finish session'));
      await tester.pumpAndSettle();
      expect(c.sessions, 1);
      expect(c.todayCount, 1);
      expect(c.learned, mode == PracticeMode.review ? 0 : 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    });
  }
}

// These checks measure actual scroll extents and button hit targets, rather than
// passing only because a test scrolled an off-screen action into view.
void compactLayoutChecks(Catalog Function() getCatalog) {
  for (final (width, height, scale) in [
    (360.0, 800.0, .9),
    (360.0, 800.0, 1.0),
    (320.0, 640.0, 1.0),
  ]) {
    testWidgets(
      'Practice fits ${width.toInt()}x${height.toInt()} at $scale text scale',
      (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final catalog = getCatalog();
        final c = AppController(
          catalog: catalog,
          storage: MemoryProgressStorage(),
          purchases: await premiumFixture(),
        )..onboarded = true;
        final word = catalog.words.values.firstWhere(
          (w) => w.term == 'der Apfel',
        );
        c.startSession([word], PracticeMode.flashcards, 'An unfinished lesson');
        await tester.pumpWidget(WortgartenApp(controller: c));
        await tester.pumpAndSettle();
        expect(find.text('Let your German\ngrow a little.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-discovery-scroll')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-overview-scroll')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        for (final mode in PracticeMode.values) {
          c.startSession([word], mode, 'Screen fit');
          await tester.pumpWidget(
            MaterialApp(
              theme: Garden.theme,
              home: PracticeScreen(controller: c),
            ),
          );
          await tester.pumpAndSettle();
          if (width == 360 &&
              height == 800 &&
              mode == PracticeMode.flashcards) {
            expect(find.byType(WordArtwork), findsNothing);
            expect(find.text(word.translation), findsNothing);
          }
          final scroll = find
              .descendant(
                of: find.byKey(const ValueKey('practice-content-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          expect(
            tester.state<ScrollableState>(scroll).position.maxScrollExtent,
            lessThanOrEqualTo(1),
            reason: '${mode.label} must fit before answering',
          );
          switch (mode) {
            case PracticeMode.flashcards:
            case PracticeMode.forms:
              final reveal = mode == PracticeMode.forms
                  ? 'Reveal word forms'
                  : 'Reveal meaning';
              expect(find.text(reveal).hitTestable(), findsOneWidget);
              await tester.tap(find.text(reveal));
              await tester.pumpAndSettle();
              if (mode == PracticeMode.forms) {
                expect(
                  tester
                      .state<ScrollableState>(scroll)
                      .position
                      .maxScrollExtent,
                  lessThanOrEqualTo(1),
                );
              } else {
                expect(find.byType(WordArtwork), findsOneWidget);
                expect(find.text(word.example), findsOneWidget);
              }
              final grade = mode == PracticeMode.flashcards
                  ? 'I knew it'
                  : 'Got it';
              expect(find.text(grade).hitTestable(), findsOneWidget);
              await tester.tap(find.text(grade));
            case PracticeMode.spelling:
              tester.view.viewInsets = const FakeViewPadding(bottom: 300);
              await tester.pumpAndSettle();
              await tester.enterText(find.byType(TextField), 'Apfel');
              await tester.pumpAndSettle();
              expect(
                find.text('Check my answer').hitTestable(),
                findsOneWidget,
              );
              expect(
                tester.getRect(find.text('Check my answer')).bottom,
                lessThan(height - 300),
              );
              await tester.tap(find.text('Check my answer'));
              tester.view.resetViewInsets();
            case PracticeMode.quiz:
              expect(find.text(word.translation).hitTestable(), findsOneWidget);
              await tester.tap(find.text(word.translation));
            case PracticeMode.review:
              break;
          }
          await tester.pumpAndSettle();
          expect(find.text('Finish session').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Finish session'));
          await tester.pumpAndSettle();
          expect(find.text('Back to my words').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await c.flush();
        c.dispose();
      },
    );
  }
}
