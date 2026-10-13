import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/services/purchase_service.dart';
import 'package:german_vocabulary/state/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native onboarding, sample recall and free paywall exit work without store configuration',
    (tester) async {
      final purchases = PurchasesController(
        store: NativePurchaseStore(),
        verifier: SignedPurchaseVerifier(const PurchaseConfig()),
        cache: MemoryPurchaseCache(),
      );
      await purchases.initialize();
      final c = AppController(
        catalog: await Catalog.load(),
        storage: MemoryProgressStorage(),
        purchases: purchases,
      );
      await tester.pumpWidget(WortgartenApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start growing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try my first word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal meaning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I knew it'));
      await tester.pumpAndSettle();
      expect(c.learned, 1);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Wortgarten Premium'), findsOneWidget);
      expect(c.premium, isFalse);
      await tester.tap(find.text('Continue free'));
      await tester.pumpAndSettle();
      expect(c.onboarded, isTrue);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
}
