import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/garden_motion.dart';
import 'package:german_vocabulary/ui/screens/onboarding_screen.dart';
import 'package:german_vocabulary/ui/screens/paywall_screen.dart';
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
  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
  ]) {
    testWidgets('onboarding and free exit work at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: OnboardingScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start growing').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Start growing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('C1'));
      await tester.tap(find.text('C1'));
      await tester.pumpAndSettle();
      expect(find.text('Try my first word').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Try my first word'));
      await tester.pumpAndSettle();
      expect(find.byType(WordArtwork), findsNothing);
      expect(find.text('Guten Morgen'), findsOneWidget);
      expect(find.text('A1 · expression'), findsOneWidget);
      expect(find.text('Reveal meaning').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Reveal meaning'));
      await tester.pumpAndSettle();
      expect(find.byType(WordArtwork), findsOneWidget);
      expect(find.text('IN CONTEXT'), findsOneWidget);
      expect(find.text('I knew it').hitTestable(), findsOneWidget);
      await tester.tap(find.text('I knew it'));
      await tester.pumpAndSettle();
      expect(c.learned, 1);
      expect(c.sessions, 1);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Wortgarten Premium'), findsOneWidget);
      expect(find.text('Continue free').hitTestable(), findsOneWidget);
      final purchase = find.widgetWithText(
        FilledButton,
        'Purchases unavailable right now',
      );
      expect(tester.widget<FilledButton>(purchase).onPressed, isNull);
      await tester.tap(find.text('Continue free'));
      await tester.pumpAndSettle();
      expect(c.onboarded, isTrue);
      expect(c.premium, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    });
    testWidgets(
      'paywall prices and close controls work at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = AppController(
          catalog: catalog,
          storage: MemoryProgressStorage(),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: Garden.theme,
            home: PaywallScreen(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('€9.99'), findsOneWidget);
        expect(find.text('€4.90'), findsOneWidget);
        expect(find.text('€99.00'), findsOneWidget);
        await tester.ensureVisible(find.text('Weekly'));
        await tester.tap(find.text('Weekly'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '€4.90 per week. Renews automatically; cancel in your store settings.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Lifetime'));
        await tester.tap(find.text('Lifetime'));
        await tester.pumpAndSettle();
        expect(
          find.text('€99.00 once. Lifetime access has no recurring charge.'),
          findsOneWidget,
        );
        expect(find.text('Continue free').hitTestable(), findsOneWidget);
        expect(
          find.byTooltip('Close premium offer').hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Restore purchases'));
        await tester.tap(find.text('Restore purchases'));
        await tester.pumpAndSettle();
        expect(c.premium, isFalse);
        expect(c.purchases.message, contains('unavailable'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  testWidgets(
    'skip enters the free app without grading or showing a compulsory offer',
    (tester) async {
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: OnboardingScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(c.onboarded, isTrue);
      expect(c.progress, isEmpty);
      expect(find.text('Wortgarten Premium'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
  testWidgets(
    'splash completes its entrance once and respects reduced motion',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onFinished: () => completed++)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(ready: true, onFinished: () => completed++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(completed, 0);
      await tester.pumpAndSettle();
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SplashScreen(ready: true, onFinished: () => completed++),
          ),
        ),
      );
      await tester.pump();
      expect(completed, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('late content does not restart the completed entrance', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onFinished: () => completed++)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(completed, 0);
    expect(find.text('Opening your garden…'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(ready: true, onFinished: () => completed++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('enabling reduced motion during startup finishes only once', (
    tester,
  ) async {
    var completed = 0;
    Widget screen(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: SplashScreen(ready: true, onFinished: () => completed++),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, 0);
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(completed, 1);
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fast content still gets a finite, complete brand entrance', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(ready: true, onFinished: () => completed++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(completed, 0);
    await tester.pumpAndSettle();
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, padding) in [
    (const Size(402, 874), const FakeViewPadding(top: 62, bottom: 34)),
    (const Size(440, 956), const FakeViewPadding(top: 62, bottom: 34)),
    (const Size(320, 640), const FakeViewPadding(top: 24, bottom: 24)),
    (const Size(1024, 1366), const FakeViewPadding(top: 24, bottom: 20)),
    (const Size(1024, 600), const FakeViewPadding(left: 32, bottom: 21)),
  ]) {
    testWidgets('splash content centers at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        MaterialApp(theme: Garden.theme, home: const SplashScreen()),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      final garden = tester.getRect(find.byType(GrowingGarden));
      final caption = tester.getRect(find.text('GERMAN VOCABULARY'));
      final content = garden.expandToInclude(caption);
      expect(content.center.dx, closeTo(size.width / 2, 1));
      expect(content.center.dy, closeTo(size.height / 2, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('completed garden stays readable before the handoff', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: Garden.theme,
        home: SplashScreen(ready: true, onFinished: () => completed++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    final wordmarkOpacity = find
        .ancestor(of: find.text('wortgarten'), matching: find.byType(Opacity))
        .first;
    final levelOpacity = find
        .ancestor(of: find.text('C1'), matching: find.byType(Opacity))
        .first;
    expect(tester.widget<Opacity>(wordmarkOpacity).opacity, 1);
    expect(tester.widget<Opacity>(levelOpacity).opacity, 1);
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 450));
    expect(completed, 0);
    await tester.pumpAndSettle();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'app crossfades underneath splash and receives taps only afterwards',
    (tester) async {
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      )..onboarded = true;
      await tester.pumpWidget(WortgartenApp(controller: c, showSplash: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.tap(
        find.text('Start my daily practice'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(c.session, isNull);
      await tester.pump(const Duration(milliseconds: 1850));
      await tester.pump(const Duration(milliseconds: 120));
      final fade = find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, greaterThan(0));
      expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
      expect(find.text('Let your German\ngrow a little.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      await tester.tap(find.text('Start my daily practice'));
      await tester.pumpAndSettle();
      expect(c.session, isNotNull);
      expect(c.progress, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );

  for (final (size, textScale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 480), 1.6),
  ]) {
    testWidgets(
      'splash error remains usable at ${size.height.toInt()}px and $textScale text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var retried = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: Garden.theme,
            home: SplashScreen(failed: true, onRetry: () => retried++),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Try again'));
        await tester.tap(find.text('Try again'));
        expect(retried, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
