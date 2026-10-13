import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/premium.dart';

class PurchaseConfig {
  const PurchaseConfig({
    this.endpoint = const String.fromEnvironment('PURCHASE_VERIFY_URL'),
    this.publicKey = const String.fromEnvironment('ENTITLEMENT_PUBLIC_KEY'),
    this.privacyUrl = const String.fromEnvironment('PRIVACY_URL'),
    this.termsUrl = const String.fromEnvironment('TERMS_URL'),
  });
  final String endpoint, publicKey, privacyUrl, termsUrl;
  bool get ready {
    final uri = Uri.tryParse(endpoint);
    try {
      return uri?.scheme == 'https' &&
          uri!.host.isNotEmpty &&
          base64Decode(base64.normalize(publicKey)).length == 32;
    } catch (_) {
      return false;
    }
  }
}

enum StorePurchaseStatus { pending, purchased, restored, cancelled, error }

class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.source,
    required this.proof,
    required this.status,
    this.id,
    this.native,
    this.needsCompletion = false,
  });
  final String productId, source, proof;
  final String? id;
  final StorePurchaseStatus status;
  final bool needsCompletion;
  final PurchaseDetails? native;
  Map<String, dynamic> get verificationRequest => {
    'productId': productId,
    'source': source,
    'proof': proof,
    'transactionId': id,
  };
  factory StorePurchase.fromJson(Map<String, dynamic> j) => StorePurchase(
    productId: j['productId'],
    source: j['source'],
    proof: j['proof'],
    id: j['transactionId'],
    status: StorePurchaseStatus.restored,
  );
}

class StoreOffer {
  const StoreOffer(this.plan, this.price, {this.native});
  final PremiumPlan plan;
  final String price;
  final ProductDetails? native;
}

abstract class PurchaseStore {
  Stream<List<StorePurchase>> get updates;
  Future<bool> available();
  Future<List<StoreOffer>> offers();
  Future<bool> buy(StoreOffer offer);
  Future<void> restore();
  Future<void> complete(StorePurchase purchase);
}

class NativePurchaseStore implements PurchaseStore {
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  final _store = InAppPurchase.instance;
  @override
  Stream<List<StorePurchase>> get updates => _store.purchaseStream.map(
    (list) => [
      for (final p in list)
        StorePurchase(
          productId: p.productID,
          source: p.verificationData.source,
          proof: p.verificationData.serverVerificationData,
          id: p.purchaseID,
          native: p,
          needsCompletion: p.pendingCompletePurchase,
          status: switch (p.status) {
            PurchaseStatus.pending => StorePurchaseStatus.pending,
            PurchaseStatus.purchased => StorePurchaseStatus.purchased,
            PurchaseStatus.restored => StorePurchaseStatus.restored,
            PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
            PurchaseStatus.error => StorePurchaseStatus.error,
          },
        ),
    ],
  );
  @override
  Future<bool> available() async => supported && await _store.isAvailable();
  @override
  Future<List<StoreOffer>> offers() async {
    final result = await _store.queryProductDetails({
      for (final p in PremiumPlan.values) p.productId,
    });
    if (result.error != null) throw StateError('Store products unavailable');
    return [
      for (final p in result.productDetails)
        if (PremiumPlan.fromProduct(p.id) case final plan?)
          StoreOffer(plan, p.price, native: p),
    ];
  }

  @override
  Future<bool> buy(StoreOffer offer) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: offer.native!),
  );
  @override
  Future<void> restore() => _store.restorePurchases();
  @override
  Future<void> complete(StorePurchase purchase) => purchase.native == null
      ? Future.value()
      : _store.completePurchase(purchase.native!);
}

class UnavailablePurchaseStore implements PurchaseStore {
  const UnavailablePurchaseStore();
  @override
  Stream<List<StorePurchase>> get updates => const Stream.empty();
  @override
  Future<bool> available() async => false;
  @override
  Future<List<StoreOffer>> offers() async => [];
  @override
  Future<bool> buy(StoreOffer offer) async => false;
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(StorePurchase purchase) async {}
}

abstract class PurchaseCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

class DevicePurchaseCache implements PurchaseCache {
  static const _key = 'wortgarten.purchases.v1';
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null ? null : jsonDecode(value);
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(value),
    );
    if (!saved) throw StateError('Purchase could not be saved');
  }
}

class MemoryPurchaseCache implements PurchaseCache {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async => value = data;
}

abstract class PurchaseVerifier {
  bool get configured;
  Future<VerifiedEntitlement> verify(StorePurchase purchase);
  Future<VerifiedEntitlement> decode(String token);
}

class SignedPurchaseVerifier implements PurchaseVerifier {
  SignedPurchaseVerifier(this.config, {this.client});
  final PurchaseConfig config;
  http.Client? client;
  @override
  bool get configured => config.ready;
  @override
  Future<VerifiedEntitlement> decode(String token) async {
    if (!configured) throw StateError('Verification unavailable');
    final parts = token.split('.');
    if (parts.length != 2) throw const FormatException('Invalid license');
    final key = SimplePublicKey(
      base64Decode(base64.normalize(config.publicKey)),
      type: KeyPairType.ed25519,
    );
    final valid = await Ed25519().verify(
      utf8.encode(parts[0]),
      signature: Signature(
        base64Url.decode(base64Url.normalize(parts[1])),
        publicKey: key,
      ),
    );
    if (!valid) throw const FormatException('Invalid signature');
    final j = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    );
    final plan = PremiumPlan.fromProduct(j['productId']);
    if (j['version'] != 1 ||
        j['app'] != 'wortgarten' ||
        plan == null ||
        j['active'] is! bool ||
        j['issuedAt'] is! int ||
        j['proofHash'] is! String) {
      throw const FormatException('Invalid entitlement');
    }
    final until = j['validUntil'];
    if (plan.subscription && until is! int ||
        !plan.subscription && until != null) {
      throw const FormatException('Invalid expiration');
    }
    return VerifiedEntitlement(
      plan: plan,
      active: j['active'],
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        j['issuedAt'] * 1000,
        isUtc: true,
      ),
      validUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until * 1000, isUtc: true),
      proofHash: j['proofHash'],
      signedToken: token,
    );
  }

  @override
  Future<VerifiedEntitlement> verify(StorePurchase purchase) async {
    if (!configured || purchase.proof.isEmpty) {
      throw StateError('Verification unavailable');
    }
    final result = await (client ??= http.Client())
        .post(
          Uri.parse(config.endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(purchase.verificationRequest),
        )
        .timeout(const Duration(seconds: 20));
    if (result.statusCode != 200) {
      throw StateError('Purchase verification unavailable');
    }
    final entitlement = await decode(jsonDecode(result.body)['entitlement']);
    final digest = await Sha256().hash(utf8.encode(purchase.proof));
    final hash = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final originalPlan = PremiumPlan.fromProduct(purchase.productId);
    if (entitlement.proofHash != hash ||
        originalPlan == null ||
        originalPlan.subscription != entitlement.plan.subscription) {
      throw const FormatException('Purchase identity mismatch');
    }
    return entitlement;
  }
}

/// Shared by RevenueCat and the existing signed purchase backend.
abstract class BillingController extends ChangeNotifier {
  PurchaseConfig get config;
  String get purchasePrivacyText =>
      "Apple or Google processes payments. Purchase identifiers and receipts are sent to the purchase verification service to confirm and restore access. Payment card details are not handled by this app.";
  Map<PremiumPlan, StoreOffer> get offers;
  PremiumEntitlement? get entitlement;
  bool get premium;
  bool get available;
  bool get loading;
  bool get busy;
  String? get message;
  bool get canRetry;
  bool canBuy(PremiumPlan plan);
  Future<void> initialize();
  Future<void> refresh();
  Future<void> buy(PremiumPlan plan);
  Future<void> restore();
  Future<void> retryVerification();
  Future<bool> manage();
}

class PurchasesController extends BillingController {
  PurchasesController({
    required this.store,
    required this.verifier,
    required this.cache,
    this.config = const PurchaseConfig(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  factory PurchasesController.unavailable() => PurchasesController(
    store: const UnavailablePurchaseStore(),
    verifier: SignedPurchaseVerifier(const PurchaseConfig()),
    cache: MemoryPurchaseCache(),
  );
  final PurchaseStore store;
  final PurchaseVerifier verifier;
  final PurchaseCache cache;
  @override
  final PurchaseConfig config;
  final DateTime Function() clock;
  @override
  final offers = <PremiumPlan, StoreOffer>{};
  VerifiedEntitlement? _entitlement;
  @override
  VerifiedEntitlement? get entitlement => _entitlement;
  StorePurchase? _proof, _retryPurchase;
  StreamSubscription<List<StorePurchase>>? _subscription;
  Future<void> _queue = Future.value();
  Timer? _expiry, _restoreTimer;
  @override
  bool available = false;
  @override
  bool loading = false;
  @override
  bool busy = false;
  bool _disposed = false, _initialized = false;
  @override
  String? message;
  @override
  bool get premium => _entitlement?.validAt(clock()) == true;
  @override
  bool canBuy(PremiumPlan plan) =>
      !premium &&
      !busy &&
      !loading &&
      available &&
      verifier.configured &&
      offers.containsKey(plan);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final boot = Completer<void>();
    _queue = boot.future;
    if (store is! UnavailablePurchaseStore) {
      _subscription = store.updates.listen(
        (events) {
          for (final event in events) {
            _queue = _queue.then((_) => _handle(event)).catchError((Object _) {
              busy = false;
              message =
                  'Your purchase could not be confirmed. Try restoring it.';
              _changed();
            });
          }
        },
        onError: (Object _) {
          busy = false;
          message = 'The store is unavailable right now.';
          _changed();
        },
      );
    }
    try {
      final cached = await cache.read();
      if (cached?['license'] != null) {
        _entitlement = await verifier.decode(cached!['license']);
        if (cached['purchase'] != null) {
          _proof = StorePurchase.fromJson(cached['purchase']);
        }
        _scheduleExpiry();
      }
    } catch (_) {
      /* An invalid cache never grants access or erases learning data. */
    }
    _changed();
    boot.complete();
    await refresh();
    if (!_disposed &&
        available &&
        verifier.configured &&
        store is NativePurchaseStore &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        await store.restore();
      } catch (_) {
        /* Manual restore remains available. */
      }
    }
  }

  @override
  Future<void> refresh() async {
    if (loading || busy || _disposed) return;
    loading = true;
    _changed();
    _queue = _queue.then((_) async {
      if (_disposed) return;
      if (_retryPurchase != null) await _handle(_retryPurchase!);
      if (_proof != null && verifier.configured) {
        try {
          await _accept(await verifier.verify(_proof!), _proof!);
        } catch (_) {
          /* Valid signed access remains usable offline. */
        }
      }
    });
    await _queue;
    try {
      available =
          !(store is NativePurchaseStore && !verifier.configured) &&
          await store.available();
      if (available) {
        final products = await store.offers();
        offers
          ..clear()
          ..addEntries(products.map((p) => MapEntry(p.plan, p)));
      }
    } catch (_) {
      available = false;
    }
    loading = false;
    _scheduleExpiry();
    _changed();
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
      if (!await store.buy(offers[plan]!)) {
        busy = false;
        message = 'Purchase cancelled.';
      }
    } catch (_) {
      busy = false;
      message = 'The store could not open. Please try again.';
    }
    _changed();
  }

  Future<void> _handle(StorePurchase purchase) async {
    if (PremiumPlan.fromProduct(purchase.productId) == null || _disposed) {
      return;
    }
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        busy = true;
        message = 'Waiting for your store to confirm payment.';
        _changed();
        return;
      case StorePurchaseStatus.cancelled:
        busy = false;
        message = 'Purchase cancelled. You can continue free.';
        _changed();
        return;
      case StorePurchaseStatus.error:
        busy = false;
        message = 'The purchase could not be completed. Please try again.';
        _changed();
        return;
      case StorePurchaseStatus.purchased:
      case StorePurchaseStatus.restored:
        busy = true;
        message = 'Confirming your purchase…';
        _changed();
        try {
          final verified = await verifier.verify(purchase);
          await _accept(verified, purchase);
          if (purchase.needsCompletion) await store.complete(purchase);
          _retryPurchase = null;
          message = premium
              ? 'Your whole garden is unlocked.'
              : 'This purchase is no longer active.';
        } catch (_) {
          _retryPurchase = purchase;
          message = 'We could not confirm your purchase yet. Retry or restore it; you will not be charged again by retrying.';
        }
        busy = false;
        _restoreTimer?.cancel();
        _changed();
    }
  }

  Future<void> _accept(
    VerifiedEntitlement value,
    StorePurchase purchase,
  ) async {
    if (_disposed) return;
    // A restore may contain expired older subscriptions as well as a lifetime
    // upgrade. Only refresh/revocation of the same proof can replace that grant.
    final current = _entitlement;
    if (current?.validAt(clock()) == true &&
        current!.proofHash != value.proofHash) {
      if (!value.validAt(clock()) ||
          current.plan == PremiumPlan.lifetime ||
          value.plan.subscription &&
              current.validUntil != null &&
              value.validUntil!.isBefore(current.validUntil!)) {
        return;
      }
    }
    // Persist before finishing the store transaction, so a crash can be recovered.
    await cache.write({
      'license': value.signedToken,
      'purchase': purchase.verificationRequest,
    });
    _entitlement = value;
    _proof = purchase;
    _scheduleExpiry();
    _changed();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (_disposed) return;
    final until = _entitlement?.validUntil;
    if (until != null && until.isAfter(clock())) {
      _expiry = Timer(until.difference(clock()), _changed);
    }
  }

  @override
  bool get canRetry => _retryPurchase != null && !busy;
  @override
  Future<void> retryVerification() async {
    final purchase = _retryPurchase;
    if (purchase != null && !busy) await _handle(purchase);
  }

  @override
  Future<void> restore() async {
    if (busy) return;
    if (!available || !verifier.configured) {
      message = 'Restoring purchases is unavailable right now. Please try again later.';
      _changed();
      return;
    }
    busy = true;
    message = 'Looking for your purchases…';
    _changed();
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 12), () {
      if (message == 'Looking for your purchases…') {
        busy = false;
        message = 'No purchases were found for this store account.';
        _changed();
      }
    });
    try {
      await store.restore();
    } catch (_) {
      _restoreTimer?.cancel();
      busy = false;
      message = 'Your purchases could not be restored. Try again.';
      _changed();
    }
  }

  @override
  Future<bool> manage() async {
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.https('play.google.com', '/store/account/subscriptions', {
            'package': 'com.wortgarten.german_vocabulary',
            if (_entitlement?.plan.subscription == true)
              'sku': _entitlement!.plan.productId,
          });
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (verifier is SignedPurchaseVerifier) {
      (verifier as SignedPurchaseVerifier).client?.close();
    }
    _subscription?.cancel();
    _expiry?.cancel();
    _restoreTimer?.cancel();
    super.dispose();
  }
}
