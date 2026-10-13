enum PremiumPlan {
  weekly('wortgarten_premium_weekly', 'Weekly', '€4.90', 'week'),
  monthly('wortgarten_premium_monthly', 'Monthly', '€9.99', 'month'),
  lifetime('wortgarten_premium_lifetime', 'Lifetime', '€99.00', 'one payment');

  const PremiumPlan(this.productId, this.label, this.previewPrice, this.period);
  final String productId, label, previewPrice, period;
  bool get subscription => this != lifetime;
  static PremiumPlan? fromProduct(String id) {
    for (final plan in values) {
      if (plan.productId == id) return plan;
    }
    return null;
  }
}

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.plan,
    required this.active,
    required this.issuedAt,
    required this.validUntil,
  });
  final PremiumPlan plan;
  final bool active;
  final DateTime issuedAt;
  final DateTime? validUntil;
  bool validAt(DateTime now) =>
      active &&
      !issuedAt.isAfter(now.add(const Duration(minutes: 5))) &&
      (plan.subscription
          ? validUntil != null && validUntil!.isAfter(now)
          : validUntil == null);
}

/// Entitlement returned by the legacy, signed verification service.
class VerifiedEntitlement extends PremiumEntitlement {
  const VerifiedEntitlement({
    required super.plan,
    required super.active,
    required super.issuedAt,
    required super.validUntil,
    required this.proofHash,
    required this.signedToken,
  });
  final String proofHash, signedToken;
}
