import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:german_vocabulary/services/revenuecat_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native RevenueCat connects and loads the configured offering', (
    tester,
  ) async {
    const config = RevenueCatConfig();
    expect(config.readyFor(defaultTargetPlatform), isTrue);
    final client = NativeRevenueCatClient();
    await client.configure(config.keyFor(defaultTargetPlatform));
    expect(await rc.Purchases.isConfigured, isTrue);
    final info = await client.customerInfo();
    expect(info.originalAppUserId, isNotEmpty);
    final offerings = await client.offerings();
    final offering = offerings.all[config.offeringId];
    expect(offering, isNotNull);
    expect(
      offering!.availablePackages.map(
        (p) => p.storeProduct.identifier.split(':').first,
      ),
      containsAll([
        'wortgarten_premium_weekly',
        'wortgarten_premium_monthly',
        'wortgarten_premium_lifetime',
      ]),
    );
  });
}
