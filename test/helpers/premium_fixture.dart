import 'package:german_vocabulary/models/premium.dart';
import 'package:german_vocabulary/services/purchase_service.dart';

Future<PurchasesController> premiumFixture() async {
  final cache = MemoryPurchaseCache()
    ..value = {'license': 'verified-test-fixture'};
  final purchases = PurchasesController(
    store: const UnavailablePurchaseStore(),
    verifier: _FixtureVerifier(),
    cache: cache,
  );
  await purchases.initialize();
  return purchases;
}

class _FixtureVerifier implements PurchaseVerifier {
  @override
  bool get configured => true;
  @override
  Future<VerifiedEntitlement> decode(String token) async => VerifiedEntitlement(
    plan: PremiumPlan.lifetime,
    active: true,
    issuedAt: DateTime.utc(2026, 1, 1),
    validUntil: null,
    proofHash: 'test-fixture',
    signedToken: token,
  );
  @override
  Future<VerifiedEntitlement> verify(StorePurchase purchase) =>
      decode('verified-test-fixture');
}
