import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:german_vocabulary/models/premium.dart';
import 'package:german_vocabulary/services/purchase_service.dart';
import 'package:german_vocabulary/services/revenuecat_service.dart';

final now = DateTime.utc(2026, 10, 11);
rc.CustomerInfo info({
  PremiumPlan? plan,
  bool active = true,
  rc.VerificationResult verification = rc.VerificationResult.verified,
  DateTime? requested,
  DateTime? expires,
  String id = 'premium',
  String? product,
}) {
  final stamp = (requested ?? now).toIso8601String();
  final grant = plan == null
      ? null
      : rc.EntitlementInfo(
          id,
          active,
          false,
          stamp,
          stamp,
          product ?? plan.productId,
          true,
          expirationDate: plan == PremiumPlan.lifetime
              ? null
              : (expires ?? now.add(const Duration(days: 7))).toIso8601String(),
          verification: verification,
        );
  return rc.CustomerInfo(
    rc.EntitlementInfos(
      grant == null ? {} : {id: grant},
      grant == null || !active ? {} : {id: grant},
      verification: verification,
    ),
    {},
    [],
    [],
    [],
    stamp,
    r'$RCAnonymousID:test',
    {},
    stamp,
  );
}

rc.Package package(PremiumPlan plan, {String? period, String? product}) =>
    rc.Package(
      plan.name,
      switch (plan) {
        PremiumPlan.weekly => rc.PackageType.weekly,
        PremiumPlan.monthly => rc.PackageType.monthly,
        PremiumPlan.lifetime => rc.PackageType.lifetime,
      },
      rc.StoreProduct(
        product ?? plan.productId,
        'Premium access',
        plan.name,
        4.9,
        '4,90 €',
        'EUR',
        subscriptionPeriod:
            period ??
            switch (plan) {
              PremiumPlan.weekly => 'P1W',
              PremiumPlan.monthly => 'P1M',
              PremiumPlan.lifetime => null,
            },
        productCategory: plan == PremiumPlan.lifetime
            ? rc.ProductCategory.nonSubscription
            : rc.ProductCategory.subscription,
      ),
      const rc.PresentedOfferingContext('default', null, null),
    );

class FakeClient implements RevenueCatClient {
  int configurations = 0, purchases = 0, restores = 0;
  rc.CustomerInfo current = info();
  Object? purchaseError, networkError;
  rc.CustomerInfoUpdateListener? listener;
  List<rc.Package> packages = PremiumPlan.values.map(package).toList();
  @override
  Future<void> configure(String publicKey) async {
    configurations++;
  }

  @override
  void addListener(rc.CustomerInfoUpdateListener value) {
    listener = value;
  }

  @override
  void removeListener(rc.CustomerInfoUpdateListener value) {
    listener = null;
  }

  @override
  Future<rc.CustomerInfo> customerInfo() async {
    if (networkError != null) throw networkError!;
    return current;
  }

  @override
  Future<rc.Offerings> offerings() async {
    if (networkError != null) throw networkError!;
    final offer = rc.Offering('default', 'Premium', {}, packages);
    return rc.Offerings({'default': offer}, current: offer);
  }

  @override
  Future<rc.CustomerInfo> purchase(rc.Package value) async {
    purchases++;
    if (purchaseError != null) throw purchaseError!;
    return current;
  }

  @override
  Future<rc.CustomerInfo> restore() async {
    restores++;
    return current;
  }
}

RevenueCatController controller(
  FakeClient client, {
  RevenueCatConfig config = const RevenueCatConfig(
    enabled: true,
    iosKey: 'appl_public_test',
  ),
  String terms = 'https://example.com/terms',
  DateTime Function()? clock,
  TargetPlatform platform = TargetPlatform.iOS,
}) {
  final result = RevenueCatController(
    client: client,
    revenueCat: config,
    platform: platform,
    clock: clock ?? () => now,
    config: PurchaseConfig(
      privacyUrl: 'https://example.com/privacy',
      termsUrl: terms,
    ),
  );
  addTearDown(result.dispose);
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android base-plan identifiers map to the same Premium access',
    () async {
      const config = RevenueCatConfig(
        enabled: true,
        androidKey: 'goog_public_test',
      );
      expect(config.readyFor(TargetPlatform.android), isTrue);
      expect(config.readyFor(TargetPlatform.iOS), isFalse);
      final client = FakeClient()
        ..packages = [
          package(
            PremiumPlan.weekly,
            product: 'wortgarten_premium_weekly:weekly',
          ),
          package(
            PremiumPlan.monthly,
            product: 'wortgarten_premium_monthly:monthly',
          ),
          package(PremiumPlan.lifetime),
        ];
      final billing = controller(
        client,
        config: config,
        platform: TargetPlatform.android,
      );
      await billing.initialize();
      expect(billing.canBuy(PremiumPlan.weekly), isTrue);
      expect(billing.canBuy(PremiumPlan.monthly), isTrue);
      expect(billing.canBuy(PremiumPlan.lifetime), isTrue);
      client.current = info(
        plan: PremiumPlan.monthly,
        product: 'wortgarten_premium_monthly:monthly',
      );
      await billing.buy(PremiumPlan.monthly);
      expect(billing.premium, isTrue);
      expect(billing.entitlement!.plan, PremiumPlan.monthly);
    },
  );
  test(
    'disabled or missing key never configures SDK or grants access',
    () async {
      for (final config in [
        const RevenueCatConfig(enabled: false, iosKey: 'appl_public'),
        const RevenueCatConfig(enabled: true),
        const RevenueCatConfig(enabled: true, iosKey: 'test_public'),
      ]) {
        final client = FakeClient();
        final billing = controller(client, config: config);
        await billing.initialize();
        await billing.buy(PremiumPlan.weekly);
        expect(client.configurations, 0);
        expect(client.purchases, 0);
        expect(billing.premium, false);
      }
    },
  );
  test(
    'offers use store prices and reject wrong subscription durations',
    () async {
      final client = FakeClient()
        ..packages = [
          package(PremiumPlan.weekly, period: 'P1M'),
          package(PremiumPlan.monthly),
          package(PremiumPlan.lifetime),
        ];
      final billing = controller(client);
      await billing.initialize();
      expect(billing.canBuy(PremiumPlan.weekly), false);
      expect(billing.canBuy(PremiumPlan.monthly), true);
      expect(billing.offers[PremiumPlan.monthly]!.price, '4,90 €');
    },
  );
  test(
    'legal links gate purchases while restore still recovers access',
    () async {
      final client = FakeClient();
      final billing = controller(client, terms: '');
      await billing.initialize();
      expect(billing.canBuy(PremiumPlan.lifetime), false);
      client.current = info(plan: PremiumPlan.lifetime);
      await billing.restore();
      expect(billing.premium, true);
      expect(client.restores, 1);
    },
  );
  test(
    'successful purchase unlocks only verified configured entitlement',
    () async {
      final client = FakeClient();
      final billing = controller(client);
      await billing.initialize();
      client.current = info(plan: PremiumPlan.weekly);
      await billing.buy(PremiumPlan.weekly);
      expect(client.purchases, 1);
      expect(billing.premium, true);
      expect(billing.busy, false);
    },
  );
  test(
    'missing, unverified, wrong entitlement or unknown product stays free',
    () async {
      for (final value in [
        info(),
        info(
          plan: PremiumPlan.weekly,
          verification: rc.VerificationResult.failed,
        ),
        info(
          plan: PremiumPlan.weekly,
          verification: rc.VerificationResult.notRequested,
        ),
        info(plan: PremiumPlan.weekly, id: 'other'),
        info(plan: PremiumPlan.weekly, product: 'other_product'),
      ]) {
        final client = FakeClient();
        final billing = controller(client);
        await billing.initialize();
        client.current = value;
        await billing.buy(PremiumPlan.weekly);
        expect(billing.premium, false);
      }
    },
  );
  test(
    'refund revokes access and an older response cannot restore it',
    () async {
      final client = FakeClient()..current = info(plan: PremiumPlan.lifetime);
      final billing = controller(client);
      await billing.initialize();
      expect(billing.premium, true);
      client.listener!(
        info(
          plan: PremiumPlan.lifetime,
          active: false,
          requested: now.add(const Duration(seconds: 1)),
        ),
      );
      expect(billing.premium, false);
      client.listener!(info(plan: PremiumPlan.lifetime));
      expect(billing.premium, false);
    },
  );
  test('offline access lasts only until the verified expiration', () async {
    var time = now;
    final client = FakeClient()..current = info(plan: PremiumPlan.weekly);
    final billing = controller(client, clock: () => time);
    await billing.initialize();
    client.networkError = Exception('offline');
    await billing.refresh();
    expect(billing.premium, true);
    expect(billing.canBuy(PremiumPlan.monthly), false);
    time = now.add(const Duration(days: 8));
    await billing.refresh();
    expect(billing.premium, false);
  });
  test(
    'cancellation, pending and malformed native errors never unlock',
    () async {
      for (final code in [
        rc.PurchasesErrorCode.purchaseCancelledError.index.toString(),
        rc.PurchasesErrorCode.paymentPendingError.index.toString(),
        'native_error',
        '-1',
      ]) {
        final client = FakeClient()
          ..purchaseError = PlatformException(code: code);
        final billing = controller(client);
        await billing.initialize();
        await billing.buy(PremiumPlan.weekly);
        expect(billing.premium, false);
        expect(billing.busy, false);
        expect(billing.message, isNotEmpty);
      }
    },
  );
  test('SDK customer update listener is removed on dispose', () async {
    final client = FakeClient();
    final billing = RevenueCatController(
      client: client,
      revenueCat: const RevenueCatConfig(enabled: true, iosKey: 'appl_public'),
      platform: TargetPlatform.iOS,
      clock: () => now,
    );
    await billing.initialize();
    expect(client.listener, isNotNull);
    billing.dispose();
    expect(client.listener, isNull);
  });
}
