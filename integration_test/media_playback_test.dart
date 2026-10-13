import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/speech_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native player decodes bundled term, example and full-card MP3s',
    (tester) async {
      final catalog = await Catalog.load();
      final word = catalog.words['c1-n-die-auffassung']!;
      for (final kind in AudioKind.values) {
        final backend = FlutterSpeechBackend();
        try {
          final played = await tester.runAsync(
            () => backend
                .playAsset(word.audioAssets[kind.name]!, rate: .45)
                .timeout(const Duration(seconds: 40)),
          );
          expect(played, isTrue, reason: '${kind.name} recording');
        } finally {
          await backend.dispose();
        }
      }
      final speech = SpeechService();
      final cancelled = await tester.runAsync(() async {
        final playing = speech.playWord(word, kind: AudioKind.card);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await speech.stop();
        return playing;
      });
      expect(cancelled, PlaybackResult.cancelled);
    },
  );
}
