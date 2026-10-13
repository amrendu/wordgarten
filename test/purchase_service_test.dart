import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:german_vocabulary/models/premium.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/purchase_service.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';

final _now = DateTime.utc(2026, 10, 10);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'signed responses bind product, expiration and the exact purchase proof',
    () async {
      final pair = await Ed25519().newKeyPair();
      final key = await pair.extractPublicKey();
      const proof = 'a-valid-store-token';
      final hash = (await Sha256().hash(utf8.encode(proof))).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'version': 1,
                'app': 'wortgarten',
                'productId': PremiumPlan.monthly.productId,
                'active': true,
                'issuedAt': _now.millisecondsSinceEpoch ~/ 1000,
                'validUntil':
                    _now.add(const Duration(days: 30)).millisecondsSinceEpoch ~/
                    1000,
                'proofHash': hash,
              }),
            ),
          )
          .replaceAll('=', '');
      final signature = await Ed25519().sign(
        utf8.encode(payload),
        keyPair: pair,
      );
      final token =
          '$payload.${base64Url.encode(signature.bytes).replaceAll('=', '')}';
      final verifier = SignedPurchaseVerifier(
        PurchaseConfig(
          endpoint: 'https://billing.example/verify',
          publicKey: base64Encode(key.bytes),
        ),
        client: MockClient(
          (request) async =>
              http.Response(jsonEncode({'entitlement': token}), 200),
        ),
      );
      final purchase = StorePurchase(
        productId: PremiumPlan.monthly.productId,
        source: 'google_play',
        proof: proof,
        status: StorePurchaseStatus.purchased,
      );
      expect((await verifier.verify(purchase)).validAt(_now), isTrue);
      expect(
        (await verifier.decode(token))
            .validAt(_now.add(const Duration(days: 31))),
        isFalse,
      );
      await expectLater(
        verifier.decode('$payload.x${token.split('.').last}'),
        throwsA(anything),
      );
      final altered = StorePurchase(
        productId: purchase.productId,
        source: purchase.source,
        proof: 'different-purchase-proof',
        status: purchase.status,
      );
      await expectLater(
        verifier.verify(altered),
        throwsA(isA<FormatException>()),
      );
      final wrongProduct = StorePurchase(
        productId: PremiumPlan.lifetime.productId,
        source: purchase.source,
        proof: proof,
        status: purchase.status,
      );
      await expectLater(
        verifier.verify(wrongProduct),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'pending or cancelled payments never unlock or complete a transaction',
    () async {
      final store = _Store(), verifier = _Verifier();
      final manager = _manager(store, verifier);
      await manager.initialize();
      await manager.buy(PremiumPlan.monthly);
      store.emit(StorePurchaseStatus.pending);
      await _settle();
      expect(manager.premium, isFalse);
      expect(manager.busy, isTrue);
      expect(store.completed, 0);
      store.emit(StorePurchaseStatus.cancelled);
      await _settle();
      expect(manager.premium, isFalse);
      expect(manager.busy, isFalse);
      expect(store.completed, 0);
      manager.dispose();
      await store.close();
    },
  );
  test(
    'purchase updates arriving during cache loading are buffered and verified',
    () async {
      final cache = _DelayedCache();
      final store = _Store(cache: cache);
      final manager = _manager(store, _Verifier(), cache: cache);
      final booting = manager.initialize();
      store.emit(StorePurchaseStatus.purchased);
      await _settle();
      expect(manager.premium, isFalse);
      expect(store.completed, 0);
      cache.loaded.complete(null);
      await booting;
      await _settle();
      expect(manager.premium, isTrue);
      expect(store.completed, 1);
      expect(store.savedBeforeCompletion, isTrue);
      manager.dispose();
      await store.close();
    },
  );
  test('verification failure keeps the purchase retryable and does not acknowledge it', () async {
    final store = _Store(), verifier = _Verifier()..fail = true;
    final manager = _manager(store, verifier);
    await manager.initialize();
    store.emit(StorePurchaseStatus.purchased);
    await _settle();
    expect(manager.premium, isFalse);
    expect(store.completed, 0);
    expect(manager.canRetry, isTrue);
    verifier.fail = false;
    await manager.retryVerification();
    expect(manager.premium, isTrue);
    expect(store.completed, 1);
    expect(store.buys, 0);
    expect(manager.canRetry, isFalse);
    manager.dispose();
    await store.close();
  });
  test('verified purchases are saved before acknowledgement and restore unlocks them', () async {
    final cache = MemoryPurchaseCache();
    final store = _Store(cache: cache);
    final manager = _manager(store, _Verifier(), cache: cache);
    await manager.initialize();
    await manager.buy(PremiumPlan.monthly);
    expect(manager.premium, isFalse);
    expect(store.buys, 1);
    store.emit(StorePurchaseStatus.purchased);
    await _settle();
    expect(manager.premium, isTrue);
    expect(store.completed, 1);
    expect(store.savedBeforeCompletion, isTrue);
    manager.dispose();
    final restored = _manager(store, _Verifier(), cache: cache);
    await restored.initialize();
    expect(restored.premium, isTrue);
    restored.dispose();
    await store.close();
  });
  test('restore events are verified and expired older receipts cannot replace lifetime access', () async {
    final store = _Store(),
        verifier = _Verifier()
          ..result = _grant(PremiumPlan.lifetime, hash: 'lifetime');
    final manager = _manager(store, verifier);
    await manager.initialize();
    await manager.restore();
    store.emit(StorePurchaseStatus.restored, plan: PremiumPlan.lifetime);
    await _settle();
    expect(manager.premium, isTrue);
    expect(manager.entitlement!.plan, PremiumPlan.lifetime);
    verifier.result = _grant(
      PremiumPlan.monthly,
      active: false,
      hash: 'old-subscription',
    );
    store.emit(StorePurchaseStatus.restored);
    await _settle();
    expect(manager.entitlement!.plan, PremiumPlan.lifetime);
    expect(manager.premium, isTrue);
    manager.dispose();
    await store.close();
  });
  test('offline cache respects subscription expiry and never trusts a forged premium flag', () async {
    final cache = MemoryPurchaseCache()..value = {'license': 'cached-license'};
    final verifier = _Verifier()..result = _grant(PremiumPlan.monthly);
    var now = _now;
    final store = _Store();
    final manager = _manager(store, verifier, cache: cache, clock: () => now);
    await manager.initialize();
    expect(manager.premium, isTrue);
    now = _now.add(const Duration(days: 31));
    expect(manager.premium, isFalse);
    manager.dispose();
    await store.close();
    final invalid = MemoryPurchaseCache()
      ..value = {'premium': true, 'license': 'forged'};
    final unavailable = PurchasesController(
      store: const UnavailablePurchaseStore(),
      verifier: SignedPurchaseVerifier(const PurchaseConfig()),
      cache: invalid,
    );
    await unavailable.initialize();
    expect(unavailable.premium, isFalse);
    unavailable.dispose();
  });
  test('free content and legacy migration keep progress and sessions without unlocking all levels', () async {
    final catalog = await Catalog.load();
    final c = AppController(catalog: catalog, storage: MemoryProgressStorage());
    for (final level in levels) {
      for (final exam in <String?>[null, 'goethe', 'telc']) {
        final topics = catalog.collections(level, exam: exam);
        expect(topics.where(c.canAccessLesson).map((l) => l.id), [
          topics.first.id,
        ]);
        final words = catalog.lessonWords(topics.first);
        expect(words.every((w) => c.canAccessWord(w.id)), isTrue);
        expect(
          c.startSession(
            words,
            PracticeMode.flashcards,
            topics.first.title,
            lessonId: topics.first.id,
          ),
          isTrue,
        );
      }
    }
    expect(c.access.freeLessonIds.length, 15);
    final paid = catalog.words.values.firstWhere((w) => !c.canAccessWord(w.id));
    c.startSession(
      [catalog.words['guten-morgen']!],
      PracticeMode.flashcards,
      'Free',
    );
    final original = c.session;
    expect(c.startSession([paid], PracticeMode.flashcards, 'Locked'), isFalse);
    expect(c.session, same(original));
    expect(c.createList('Paid feature'), isFalse);
    final storage = MemoryProgressStorage();
    final snapshot = c.snapshot()
      ..remove('accessVersion')
      ..remove('retainedWordIds');
    snapshot['saved'] = [paid.id];
    snapshot['progress'] = {
      paid.id: {'box': 2, 'correct': 2, 'attempts': 3},
    };
    await storage.write(snapshot);
    final migrated = AppController(catalog: catalog, storage: storage);
    await migrated.load();
    expect(migrated.canAccessWord(paid.id), isTrue);
    expect(migrated.premium, isFalse);
    expect(migrated.progress[paid.id]!.correct, 2);
    expect(migrated.session!.currentId, 'guten-morgen');
    await migrated.flush();
    expect(storage.value!['accessVersion'], 1);
    c.dispose();
    migrated.dispose();
  });
}

PurchasesController _manager(
  _Store store,
  _Verifier verifier, {
  MemoryPurchaseCache? cache,
  DateTime Function()? clock,
}) => PurchasesController(
  store: store,
  verifier: verifier,
  cache: cache ?? MemoryPurchaseCache(),
  clock: clock ?? () => _now,
);
VerifiedEntitlement _grant(
  PremiumPlan plan, {
  bool active = true,
  String hash = 'test-proof',
}) => VerifiedEntitlement(
  plan: plan,
  active: active,
  issuedAt: _now,
  validUntil: plan.subscription ? _now.add(const Duration(days: 30)) : null,
  proofHash: hash,
  signedToken: 'verified-${plan.name}-$hash',
);

class _Verifier implements PurchaseVerifier {
  bool fail = false;
  VerifiedEntitlement result = _grant(PremiumPlan.monthly);
  @override
  bool get configured => true;
  @override
  Future<VerifiedEntitlement> decode(String token) async => result;
  @override
  Future<VerifiedEntitlement> verify(StorePurchase purchase) async {
    if (fail) throw StateError('offline');
    return result;
  }
}

class _Store implements PurchaseStore {
  _Store({this.cache});
  final MemoryPurchaseCache? cache;
  final events = StreamController<List<StorePurchase>>.broadcast(sync: true);
  int completed = 0, buys = 0;
  bool savedBeforeCompletion = false;
  @override
  Stream<List<StorePurchase>> get updates => events.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<List<StoreOffer>> offers() async => [
    for (final p in PremiumPlan.values) StoreOffer(p, p.previewPrice),
  ];
  @override
  Future<bool> buy(StoreOffer offer) async {
    buys++;
    return true;
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(StorePurchase purchase) async {
    completed++;
    savedBeforeCompletion = cache?.value?['license'] != null;
  }

  void emit(
    StorePurchaseStatus status, {
    PremiumPlan plan = PremiumPlan.monthly,
  }) => events.add([
    StorePurchase(
      productId: plan.productId,
      source: 'google_play',
      proof: 'test-proof',
      status: status,
      needsCompletion: true,
    ),
  ]);
  Future<void> close() => events.close();
}

class _DelayedCache extends MemoryPurchaseCache {
  final loaded = Completer<Map<String, dynamic>?>();
  @override
  Future<Map<String, dynamic>?> read() => loaded.future;
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
