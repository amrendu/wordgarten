import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/speech_service.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/screens/practice_screen.dart';
import 'package:german_vocabulary/ui/theme.dart';

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
  testWidgets(
    'flashcards play only word audio once per card and stop on exit',
    (tester) async {
      final backends = <_FakeBackend>[];
      final speech = SpeechService(
        backendFactory: () {
          final backend = _FakeBackend();
          backends.add(backend);
          return backend;
        },
      );
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
      );
      final words = [
        catalog.words['guten-morgen']!,
        catalog.words['guten-abend']!,
      ];
      c.startSession(words, PracticeMode.flashcards, 'Greetings');
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: PracticeScreen(controller: c, speech: speech),
        ),
      );
      await tester.pumpAndSettle();
      expect(backends.single.assets, [words.first.audioAssets['term']]);
      c.toggleSaved(words.first.id);
      await tester.tap(find.text('Reveal meaning'));
      await tester.pumpAndSettle();
      expect(backends.length, 1);
      backends.first.finishAudio(true);
      await tester.pumpAndSettle();
      expect(c.session!.index, 0);
      await tester.tap(find.text('I knew it'));
      await tester.pumpAndSettle();
      expect(backends.length, 1);
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(backends.length, 2);
      expect(backends.last.assets, [words.last.audioAssets['term']]);
      expect(c.session!.revealed, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(backends.last.stops, 1);
      await c.flush();
      c.dispose();
    },
  );
}

class _FakeBackend implements SpeechBackend {
  final assets = <String>[];
  final spoken = <(String, String)>[];
  Completer<bool>? pending;
  bool failAssets = false, disposed = false;
  double? rate;
  int stops = 0;
  @override
  Future<bool> playAsset(String asset, {required double rate}) async {
    assets.add(asset);
    this.rate = rate;
    if (failAssets) return false;
    pending = Completer<bool>();
    return pending!.future;
  }

  void finishAudio(bool result) {
    if (pending != null && !pending!.isCompleted) pending!.complete(result);
  }

  @override
  Future<bool> speak(
    String text, {
    required String language,
    required double rate,
  }) async {
    spoken.add((text, language));
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    finishAudio(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    finishAudio(false);
  }
}
