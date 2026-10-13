import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });
  test(
    'all imported image and audio mappings resolve to offline files',
    () async {
      final inventory = jsonDecode(
        File('assets/data/media-inventory.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final path in List<String>.from(inventory['files'])) {
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(File(path).lengthSync(), greaterThan(0), reason: path);
      }
      for (final word in catalog.words.values) {
        if (word.imageAsset != null) {
          expect(File(word.imageAsset!).existsSync(), isTrue);
          expect(word.imageAsset, endsWith('.webp'));
        }
        for (final asset in word.audioAssets.values) {
          expect(File(asset).existsSync(), isTrue);
          expect(asset, endsWith('.mp3'));
        }
      }
      expect(catalog.topicImages.length, 27);
      for (final asset in catalog.topicImages.values) {
        expect(File(asset).existsSync(), isTrue);
      }
      final word = catalog.words['apfel']!;
      expect(
        (await rootBundle.load(word.imageAsset!)).lengthInBytes,
        greaterThan(0),
      );
      expect(
        (await rootBundle.load(word.audioAssets['term']!)).lengthInBytes,
        greaterThan(0),
      );
    },
  );
  test(
    'new organized source media is bundled for B1, B2 and C1 words',
    () async {
      for (final id in [
        'b1-v-sich-erinnern',
        'b2-n-die-position',
        'c1-n-die-auffassung',
      ]) {
        final word = catalog.words[id]!;
        final imageData = await rootBundle.load(word.imageAsset!);
        expect(imageData.lengthInBytes, greaterThan(0), reason: '$id image');
        final codec = await ui.instantiateImageCodec(
          imageData.buffer.asUint8List(
            imageData.offsetInBytes,
            imageData.lengthInBytes,
          ),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: '$id decoded image');
        frame.image.dispose();
        codec.dispose();
        for (final kind in AudioKind.values) {
          expect(
            (await rootBundle.load(word.audioAssets[kind.name]!)).lengthInBytes,
            greaterThan(16),
            reason: '$id ${kind.name} recording',
          );
        }
      }
    },
  );
  test(
    'recorded pronunciation uses its word ID asset and waits for completion',
    () async {
      final fake = _FakeBackend();
      final speech = SpeechService(backendFactory: () => fake);
      final word = catalog.words['apfel']!;
      final playing = speech.playWord(word, rate: .3);
      await _settle();
      expect(fake.assets, [word.audioAssets['term']]);
      expect(fake.spoken, isEmpty);
      expect(fake.rate, .3);
      fake.finishAudio(true);
      expect(await playing, PlaybackResult.completed);
      await _settle();
      expect(fake.disposed, isTrue);
    },
  );
  test(
    'failed recording falls back to speech for the right term and language',
    () async {
      final fake = _FakeBackend()..failAssets = true;
      final speech = SpeechService(backendFactory: () => fake);
      final word = catalog.words['apfel']!;
      expect(await speech.playWord(word), PlaybackResult.completed);
      expect(fake.spoken, [(word.term, 'de-DE')]);
    },
  );
  test('full card fallback reads term, meaning and example in order', () async {
    final word = Word(
      id: 'test',
      term: 'der Test',
      translation: 'test',
      definition: 'Eine Prüfung.',
      example: 'Der Test beginnt.',
      exampleTranslation: 'The test starts.',
      artwork: 'school',
      part: 'noun',
    );
    final fake = _FakeBackend();
    final speech = SpeechService(backendFactory: () => fake);
    expect(
      await speech.playWord(word, kind: AudioKind.card),
      PlaybackResult.completed,
    );
    expect(fake.spoken, [
      (word.term, 'de-DE'),
      (word.translation, 'en-US'),
      (word.example, 'de-DE'),
    ]);
  });
  test('a newer player cancels the old one and stale stop does not cancel the new one', () async {
    final first = _FakeBackend(), second = _FakeBackend();
    final old = SpeechService(backendFactory: () => first),
        current = SpeechService(backendFactory: () => second);
    final oldPlaying = old.playWord(catalog.words['apfel']!);
    await _settle();
    final newPlaying = current.playWord(catalog.words['brot']!);
    await _settle();
    expect(await oldPlaying, PlaybackResult.cancelled);
    expect(first.stops, 1);
    await old.stop();
    expect(second.stops, 0);
    second.finishAudio(true);
    expect(await newPlaying, PlaybackResult.completed);
  });
  test(
    'cancel before startup does not play or leak the pending recording',
    () async {
      final first = _FakeBackend(), second = _FakeBackend();
      final old = SpeechService(backendFactory: () => first),
          current = SpeechService(backendFactory: () => second);
      final previous = old.playWord(catalog.words['apfel']!);
      final next = current.playWord(catalog.words['brot']!);
      await _settle();
      expect(await previous, PlaybackResult.cancelled);
      expect(first.assets, isEmpty);
      expect(first.disposed, isTrue);
      second.finishAudio(true);
      expect(await next, PlaybackResult.completed);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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
