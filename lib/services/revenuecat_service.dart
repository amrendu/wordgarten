import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:url_launcher/url_launcher.dart';

import '../models/premium.dart';
import 'purchase_service.dart';

class RevenueCatConfig {
  const RevenueCatConfig({
    this.enabled = const bool.fromEnvironment('REVENUECAT_ENABLED'),
    this.iosKey = const String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
    this.androidKey = const String.fromEnvironment(
      'REVENUECAT_ANDROID_API_KEY',
    ),
    this.entitlementId = const String.fromEnvironment(
      'REVENUECAT_ENTITLEMENT_ID',
      defaultValue: 'premium',
    ),
    this.offeringId = const String.fromEnvironment(
      'REVENUECAT_OFFERING_ID',
      defaultValue: 'default',
    ),
  });
  final bool enabled;
  final String iosKey, androidKey, entitlementId, offeringId;

  String keyFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => iosKey,
    TargetPlatform.android => androidKey,
    _ => '',
  };

  bool readyFor(TargetPlatform platform) {
    final prefix = platform == TargetPlatform.iOS ? 'appl_' : 'goog_';
    final key = keyFor(platform);
    return enabled &&
        [TargetPlatform.iOS, TargetPlatform.android].contains(platform) &&
        key.startsWith(prefix) &&
        key.length > prefix.length &&
        !key.contains('YOUR_') &&
        entitlementId.trim().isNotEmpty &&
        offeringId.trim().isNotEmpty;
  }
}

/// Thin SDK boundary, so payment and access behavior can be tested without
/// StoreKit or a live RevenueCat account. RevenueCat owns receipt validation,
/// transaction completion and its persistent anonymous customer/cache.
abstract class RevenueCatClient {
  Future<void> configure(String publicKey);
  void addListener(rc.CustomerInfoUpdateListener listener);
  void removeListener(rc.CustomerInfoUpdateListener listener);
  Future<rc.CustomerInfo> customerInfo();
  Future<rc.Offerings> offerings();
  Future<rc.CustomerInfo> purchase(rc.Package package);
  Future<rc.CustomerInfo> restore();
}

class NativeRevenueCatClient implements RevenueCatClient {
  @override
  Future<void> configure(String publicKey) async {
    await rc.Purchases.setLogLevel(
      kDebugMode ? rc.LogLevel.debug : rc.LogLevel.warn,
    );
    final configuration = rc.PurchasesConfiguration(publicKey)
      ..entitlementVerificationMode =
          rc.EntitlementVerificationMode.informational
      ..automaticDeviceIdentifierCollectionEnabled = false
      ..storeKitVersion = rc.StoreKitVersion.storeKit2;
    await rc.Purchases.configure(configuration);
  }

  @override
  void addListener(rc.CustomerInfoUpdateListener listener) =>
      rc.Purchases.addCustomerInfoUpdateListener(listener);
  @override
  void removeListener(rc.CustomerInfoUpdateListener listener) =>
      rc.Purchases.removeCustomerInfoUpdateListener(listener);
  @override
  Future<rc.CustomerInfo> customerInfo() => rc.Purchases.getCustomerInfo();
  @override
  Future<rc.Offerings> offerings() => rc.Purchases.getOfferings();
  @override
  Future<rc.CustomerInfo> purchase(rc.Package package) async =>
      (await rc.Purchases.purchase(rc.PurchaseParams.package(package)))
          .customerInfo;
  @override
  Future<rc.CustomerInfo> restore() => rc.Purchases.restorePurchases();
}

class RevenueCatController extends BillingController
    with WidgetsBindingObserver {
  RevenueCatController({
    required this.client,
    this.revenueCat = const RevenueCatConfig(),
    this.config = const PurchaseConfig(),
    TargetPlatform? platform,
    DateTime Function()? clock,
  }) : platform = platform ?? defaultTargetPlatform,
       clock = clock ?? DateTime.now;

  final RevenueCatClient client;
  final RevenueCatConfig revenueCat;
  final TargetPlatform platform;
  final DateTime Function() clock;
  @override
  final PurchaseConfig config;
  @override
  final offers = <PremiumPlan, StoreOffer>{};
  final _packages = <PremiumPlan, rc.Package>{};
  PremiumEntitlement? _entitlement;
  DateTime? _lastRequest;
  String? _managementUrl;
  bool _configured = false, _disposed = false, _observing = false;
  Future<void>? _initializing;
  Timer? _expiry;
  @override
  bool available = false, loading = false, busy = false;
  @override
  String? message;
  @override
  PremiumEntitlement? get entitlement => _entitlement;
  @override
  bool get premium => _entitlement?.validAt(clock()) == true;
  @override
  bool get canRetry => false;
  bool get configured => !kIsWeb && revenueCat.readyFor(platform);
  @override
  String get purchasePrivacyText => configured
      ? "Apple or Google processes payments. RevenueCat processes an anonymous customer identifier, purchase history and store transaction information to verify purchases, restore Premium and provide subscription analytics. Learning progress is not sent to RevenueCat. Payment card details are not handled by this app."
      : "In-app purchases are disabled in this build. The app does not initialize RevenueCat or send purchase information to it.";
  bool get _legalReady => [config.privacyUrl, config.termsUrl].every((value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'https' && uri!.host.isNotEmpty;
  });
  @override
  bool canBuy(PremiumPlan plan) =>
      configured &&
      _configured &&
      _legalReady &&
      available &&
      !premium &&
      !loading &&
      !busy &&
      _packages.containsKey(plan);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (!configured || _disposed) return;
    if (kDebugMode) debugPrint('RevenueCat: initializing native purchases.');
    loading = true;
    _changed();
    try {
      await client.configure(revenueCat.keyFor(platform));
      if (_disposed) return;
      _configured = true;
      client.addListener(_accept);
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RevenueCat initialization failed: ${error.runtimeType}');
      }
      message = 'Purchases are unavailable right now. You can continue free.';
    } finally {
      loading = false;
      _changed();
    }
    if (_configured && !_disposed) await refresh();
  }

  void _accept(rc.CustomerInfo info) {
    if (_disposed) return;
    final requested = DateTime.tryParse(info.requestDate);
    if (requested == null ||
        (_lastRequest != null && requested.isBefore(_lastRequest!))) {
      return;
    }
    _lastRequest = requested;
    final value = info.entitlements.active[revenueCat.entitlementId];
    final trusted =
        value?.verification == rc.VerificationResult.verified ||
        value?.verification == rc.VerificationResult.verifiedOnDevice;
    final plan = value == null
        ? null
        : PremiumPlan.fromProduct(value.productIdentifier.split(':').first);
    _entitlement =
        trusted &&
            value!.identifier == revenueCat.entitlementId &&
            value.isActive &&
            plan != null
        ? PremiumEntitlement(
            plan: plan,
            active: true,
            issuedAt: requested,
            validUntil: value.expirationDate == null
                ? null
                : DateTime.tryParse(value.expirationDate!),
          )
        : null;
    _managementUrl = trusted ? info.managementURL : null;
    if (value != null && !trusted) {
      message =
          'We could not verify your access. Reconnect and restore purchases.';
    }
    _expiry?.cancel();
    final until = _entitlement?.validUntil;
    if (until != null && until.isAfter(clock())) {
      _expiry = Timer(until.difference(clock()), () {
        _changed();
        unawaited(refresh());
      });
    }
    _changed();
  }

  @override
  Future<void> refresh() async {
    if (_disposed || loading || busy || !configured) return;
    if (!_configured) {
      _initializing = null;
      await initialize();
      return;
    }
    loading = true;
    _changed();
    try {
      _accept(await client.customerInfo());
    } catch (_) {
      // Keep only previously verified, unexpired access when offline.
    }
    try {
      final offerings = await client.offerings();
      if (_disposed) return;
      final offering = offerings.all[revenueCat.offeringId];
      offers.clear();
      _packages.clear();
      for (final package in offering?.availablePackages ?? <rc.Package>[]) {
        final product = package.storeProduct;
        final plan = PremiumPlan.fromProduct(
          product.identifier.split(':').first,
        );
        if (plan == null) continue;
        final correctPeriod = switch (plan) {
          PremiumPlan.weekly => product.subscriptionPeriod == 'P1W',
          PremiumPlan.monthly => product.subscriptionPeriod == 'P1M',
          PremiumPlan.lifetime =>
            product.productCategory == rc.ProductCategory.nonSubscription,
        };
        if (!correctPeriod) continue;
        _packages[plan] = package;
        offers[plan] = StoreOffer(plan, product.priceString);
      }
      available = offers.isNotEmpty;
    } catch (_) {
      available = false;
      offers.clear();
      _packages.clear();
    } finally {
      loading = false;
      _changed();
    }
  }

  @override
  Future<void> buy(PremiumPlan plan) async {
    if (!canBuy(plan)) {
      message = 'Purchases are unavailable right now. You can continue free.';
      _changed();
      return;
    }
    busy = true;
    message = null;
    _changed();
    try {
      _accept(await client.purchase(_packages[plan]!));
      if (!_disposed) {
        message = premium ? 'Your whole garden is unlocked.' : 'Your purchase has not unlocked access yet. Try restoring purchases.';
      }
    } on PlatformException catch (error) {
      final index = int.tryParse(error.code);
      final code =
          index != null &&
              index >= 0 &&
              index < rc.PurchasesErrorCode.values.length
          ? rc.PurchasesErrorCode.values[index]
          : rc.PurchasesErrorCode.unknownError;
      message = switch (code) {
        rc.PurchasesErrorCode.purchaseCancelledError =>
          'Purchase cancelled. You can continue free.',
        rc.PurchasesErrorCode.paymentPendingError =>
          'Waiting for your store to confirm payment.',
        _ => 'The purchase could not be completed. Please try again or restore purchases.',
      };
    } catch (_) {
      message = 'The purchase could not be completed. Please try again or restore purchases.';
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  Future<void> restore() async {
    if (busy || loading || _disposed) return;
    if (!_configured || !configured) {
      message = 'Restoring purchases is unavailable right now. Please try again later.';
      _changed();
      return;
    }
    busy = true;
    message = 'Looking for your purchases…';
    _changed();
    try {
      _accept(await client.restore());
      if (!_disposed) {
        message = premium
            ? 'Your whole garden is unlocked.'
            : 'No active Premium purchase was found for this store account.';
      }
    } catch (_) {
      message = 'Your purchases could not be restored. Try again.';
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  Future<void> retryVerification() => refresh();

  @override
  Future<bool> manage() async {
    final fallback = platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions?package=com.wortgarten.german_vocabulary';
    final supplied = Uri.tryParse(_managementUrl ?? '');
    final trustedHost =
        supplied?.scheme == 'https' &&
        ['apps.apple.com', 'play.google.com'].contains(supplied?.host);
    try {
      return await launchUrl(
        trustedHost ? supplied! : Uri.parse(fallback),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    if (_configured) client.removeListener(_accept);
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
