import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/services/speech_service.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/screens/practice_screen.dart';
import 'package:german_vocabulary/ui/app_shell.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture actual app screens for the App Store', (tester) async {
    final catalog = await Catalog.load();
    var now = DateTime(2026, 10, 13, 10);
    final c = AppController(
      catalog: catalog,
      storage: MemoryProgressStorage(),
      clock: () => now,
    )..onboarded = true;
    // Representative, in-memory learning data; never read or write user storage.
    final greetingWords = catalog.lessonWords(catalog.collections('A1').first);
    for (var day = 6; day >= 0; day--) {
      now = DateTime(2026, 10, 13 - day, 10);
      for (final word in greetingWords.skip((6 - day) * 3).take(3)) {
        c.recordMiniLesson(word, true);
      }
    }
    now = DateTime(2026, 10, 13, 10);
    c.chooseLevel('A2');
    final word = catalog.words['termin']!;
    c.startSession(
      [word, catalog.words['einladung']!],
      PracticeMode.flashcards,
      'Plans and invitations',
    );
    final speech = SpeechService(backendFactory: _QuietBackend.new);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      // Wait for bundled WebP decoding to settle on the native renderer.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    Future<void> openCard(SpeechService speech) async {
      await tester.pumpWidget(WortgartenApp(controller: c, showSplash: false));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AppShell))).push(
        MaterialPageRoute<void>(
          builder: (_) => PracticeScreen(controller: c, speech: speech),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openCard(speech);
    await capture('02-recall');
    c.reveal();
    await capture('01-illustrated');
    await tester.pumpWidget(const SizedBox());
    c.session = null;
    c.chooseLevel('B1');
    await tester.pumpWidget(WortgartenApp(controller: c, showSplash: false));
    await tester.pumpAndSettle();
    final exam = find.byKey(const ValueKey('home-exam-goethe'));
    await tester.ensureVisible(exam);
    await tester.tap(exam);
    await capture('03-exams');
    c.chooseLevel('C1');
    await tester.tap(find.text('By level'));
    await capture('04-levels');
    await tester.pumpWidget(const SizedBox());
    c.chooseLevel('A2');
    c.startSession(
      [word, catalog.words['einladung']!],
      PracticeMode.review,
      'Plans and invitations',
    );
    await openCard(SpeechService(backendFactory: _QuietBackend.new));
    await capture('05-audio');
    await tester.pumpWidget(const SizedBox());
    c.session = null;
    c.chooseLevel('A1');
    await tester.pumpWidget(WortgartenApp(controller: c, showSplash: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await capture('06-progress');
    await tester.tap(find.text('Home'));
    await capture('07-home');
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });
}

// Keep the audio controls in their actual playing state without simulator sound
// or automatic advancement during still-image capture.
class _QuietBackend implements SpeechBackend {
  final _done = Completer<bool>();
  @override
  Future<bool> playAsset(String asset, {required double rate}) => _done.future;
  @override
  Future<bool> speak(
    String text, {
    required String language,
    required double rate,
  }) => _done.future;
  @override
  Future<void> stop() async {
    if (!_done.isCompleted) _done.complete(false);
  }

  @override
  Future<void> dispose() => stop();
}
