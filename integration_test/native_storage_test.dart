import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native SQLite saves and reloads recall, favourites and an unfinished session',
    (tester) async {
      final catalog = await Catalog.load();
      final storage = LocalProgressStorage();
      final original = await storage.read();
      final c = AppController(catalog: catalog, storage: storage);
      try {
        await c.load();
        c.finishOnboarding();
        c.chooseLevel('B2');
        final words = catalog.levelWords('B2').take(2).toList();
        c.toggleSaved(words.first.id);
        c.startSession(words, PracticeMode.flashcards, 'Native storage test');
        c.reveal();
        c.grade(true);
        c.nextWord();
        await c.flush();
        final restored = AppController(catalog: catalog, storage: storage);
        await restored.load();
        expect(restored.storageError, isNull);
        expect(restored.level, 'B2');
        expect(restored.session!.index, 1);
        expect(restored.progress[words.first.id]!.learned, isTrue);
        expect(restored.saved, contains(words.first.id));
        await tester.pumpWidget(WortgartenApp(controller: restored));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Pick up where you left off'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Pick up where you left off'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await c.flush();
        await storage.write(
          original ??
              AppController(
                catalog: catalog,
                storage: MemoryProgressStorage(),
              ).snapshot(),
        );
        await storage.close();
      }
    },
  );
}
