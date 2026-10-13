import 'package:flutter/foundation.dart';

import 'purchase_service.dart';
import 'revenuecat_service.dart';

BillingController createBillingController({
  String provider = const String.fromEnvironment(
    'BILLING_PROVIDER',
    defaultValue: 'legacy',
  ),
  PurchaseConfig config = const PurchaseConfig(),
  RevenueCatConfig revenueCat = const RevenueCatConfig(),
}) {
  if (provider == 'revenuecat') {
    const androidTerms = String.fromEnvironment('ANDROID_TERMS_URL');
    final storeConfig =
        defaultTargetPlatform == TargetPlatform.android &&
            androidTerms.isNotEmpty
        ? PurchaseConfig(
            endpoint: config.endpoint,
            publicKey: config.publicKey,
            privacyUrl: config.privacyUrl,
            termsUrl: androidTerms,
          )
        : config;
    return RevenueCatController(
      client: NativeRevenueCatClient(),
      config: storeConfig,
      revenueCat: revenueCat,
    );
  }
  final native =
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);
  return PurchasesController(
    store: provider == 'legacy' && native
        ? NativePurchaseStore()
        : const UnavailablePurchaseStore(),
    verifier: SignedPurchaseVerifier(config),
    cache: DevicePurchaseCache(),
    config: config,
  );
}
