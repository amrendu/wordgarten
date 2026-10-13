import 'helpers/premium_fixture.dart';

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
    'review advances after full-card audio ends and pause retains the current word',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backends = <_FakeBackend>[];
      final speech = SpeechService(
        backendFactory: () {
          final fake = _FakeBackend();
          backends.add(fake);
          return fake;
        },
      );
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      c.startSession(
        [catalog.words['apfel']!, catalog.words['brot']!],
        PracticeMode.review,
        'Recorded review',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: PracticeScreen(controller: c, speech: speech),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pause auto-play'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(c.session!.index, 0);
      expect(backends.first.assets, [
        catalog.words['apfel']!.audioAssets['card'],
      ]);
      backends.first.finishAudio(true);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(c.session!.index, 1);
      expect(backends.length, 2);
      await tester.tap(find.byTooltip('Pause auto-play'));
      await tester.pumpAndSettle();
      expect(c.session!.index, 1);
      expect(backends.last.stops, 1);
      expect(c.learned, 0);
      expect(find.text('Finish session').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
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
