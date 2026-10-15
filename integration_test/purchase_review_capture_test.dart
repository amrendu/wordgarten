import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:german_vocabulary/main.dart';
import 'package:german_vocabulary/models/premium.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/billing_factory.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/app_shell.dart';
import 'package:german_vocabulary/ui/screens/paywall_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture native paywall with live store offers', (tester) async {
    final billing = createBillingController();
    await billing.initialize();
    final controller = AppController(
      catalog: await Catalog.load(),
      storage: MemoryProgressStorage(),
      purchases: billing,
    )..onboarded = true;
    await tester.pumpWidget(
      WortgartenApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AppShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(controller: controller),
      ),
    );
    // The live store must supply all plans; do not capture unavailable or
    // placeholder pricing as an App Review purchase screenshot.
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(seconds: 1));
      if (billing.offers.length == PremiumPlan.values.length) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(billing.offers.length, PremiumPlan.values.length);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    for (final plan in PremiumPlan.values) {
      await tester.ensureVisible(find.text(plan.label));
      await tester.tap(find.text(plan.label));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('paywall-${plan.name}');
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
