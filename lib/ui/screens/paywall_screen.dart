import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/premium.dart';
import '../../state/app_controller.dart';
import '../garden_motion.dart';
import '../theme.dart';
import '../widgets.dart';

Future<bool> showPaywall(
  BuildContext context,
  AppController c, {
  String? reason,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(controller: c, reason: reason),
      ),
    ) ??
    false;

Future<bool> requirePremium(
  BuildContext context,
  AppController c,
  String reason,
) async => c.premium || await showPaywall(context, c, reason: reason);

class PremiumInvitation extends StatelessWidget {
  const PremiumInvitation({
    super.key,
    required this.controller,
    this.title = 'Let your whole garden grow.',
    this.description =
        'Unlock every level, exam collection and your own word lists.',
  });
  final AppController controller;
  final String title, description;
  @override
  Widget build(BuildContext context) => GardenCard(
    color: Garden.lavender,
    padding: const EdgeInsets.all(18),
    onTap: () => showPaywall(context, controller, reason: title),
    child: Row(
      children: [
        const IconBadge(
          Icons.workspace_premium_outlined,
          color: Garden.background,
          size: 42,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Garden.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_rounded, color: Garden.green, size: 18),
      ],
    ),
  );
}

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.controller, this.reason});
  final AppController controller;
  final String? reason;
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PremiumPlan _selected = PremiumPlan.monthly;
  bool _closing = false, _wasPremium = false;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _wasPremium = c.premium;
    c.purchases.addListener(_purchased);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.purchases.refresh();
    });
  }

  void _purchased() {
    if (mounted && !_wasPremium && c.premium && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  @override
  void dispose() {
    c.purchases.removeListener(_purchased);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c.purchases,
    builder: (context, _) {
      final billing = c.purchases;
      final size = MediaQuery.sizeOf(context);
      final compact = size.height < 900;
      final price = billing.offers[_selected]?.price ?? _selected.previewPrice;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close premium offer',
            onPressed: () => Navigator.pop(context, c.premium),
            icon: const Icon(Icons.close_rounded),
          ),
          title: const Text(
            'Wortgarten Premium',
            style: TextStyle(fontSize: 14),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            key: const ValueKey('paywall-content'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Column(
              children: [
                GrowingGarden(
                  size: size.height < 700
                      ? 100
                      : compact
                      ? 145
                      : 190,
                ),
                Text(
                  c.premium
                      ? 'Your garden is fully unlocked.'
                      : 'Let your German flourish.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: compact ? 26 : 29),
                ),
                const SizedBox(height: 8),
                Text(
                  c.premium
                      ? 'Every level. Every way to learn.'
                      : widget.reason ??
                            'More words. More confidence. Your own path.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
                const SizedBox(height: 18),
                const _Benefit(
                  Icons.auto_stories_outlined,
                  'All A1–C1 topics and exam collections',
                ),
                const _Benefit(
                  Icons.folder_outlined,
                  'Your own lists and difficult-word practice',
                ),
                const _Benefit(
                  Icons.insights_rounded,
                  'Detailed progress and learning insights',
                ),
                const _Benefit(
                  Icons.offline_bolt_outlined,
                  'Illustrations and audio, ready offline',
                ),
                const SizedBox(height: 16),
                if (!c.premium)
                  for (final plan in [
                    PremiumPlan.monthly,
                    PremiumPlan.weekly,
                    PremiumPlan.lifetime,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        selected: _selected == plan,
                        button: true,
                        child: GardenCard(
                          color: _selected == plan ? Garden.mint : Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: compact ? 10 : 13,
                          ),
                          onTap: billing.busy
                              ? null
                              : () => setState(() => _selected = plan),
                          child: Row(
                            children: [
                              Icon(
                                _selected == plan
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 22,
                                color: Garden.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          plan.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (plan == PremiumPlan.monthly) ...[
                                          const SizedBox(width: 7),
                                          const Flexible(
                                            child: Text(
                                              'Recommended',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Garden.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      plan.subscription
                                          ? 'Billed every ${plan.period}'
                                          : 'One payment. Permanent access.',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Garden.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                billing.offers[plan]?.price ??
                                    plan.previewPrice,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (c.premium)
                  GardenCard(
                    color: Garden.mint,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Garden.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            billing.entitlement?.plan == PremiumPlan.lifetime
                                ? 'Lifetime access'
                                : 'Your subscription is active',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (billing.message != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      billing.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Garden.green),
                    ),
                  ),
                ],
                if (billing.canRetry)
                  TextButton(
                    onPressed: billing.retryVerification,
                    child: const Text('Retry purchase verification'),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: billing.busy ? null : billing.restore,
                      child: const Text(
                        'Restore purchases',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _legal(context, 'Privacy'),
                      child: const Text(
                        'Privacy',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _legal(context, 'Terms'),
                      child: const Text(
                        'Terms',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!c.premium)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _selected.subscription
                          ? '$price per ${_selected.period}. Renews automatically; cancel in your store settings.'
                          : '$price once. Lifetime access has no recurring charge.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Garden.muted),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: c.premium
                        ? () async {
                            if (billing.entitlement?.plan ==
                                PremiumPlan.lifetime) {
                              Navigator.pop(context, true);
                            } else if (!await billing.manage() &&
                                context.mounted) {
                              toast(
                                context,
                                'Open your app store to manage your subscription.',
                              );
                            }
                          }
                        : billing.canBuy(_selected)
                        ? () => billing.buy(_selected)
                        : null,
                    child: Text(
                      c.premium
                          ? (billing.entitlement?.plan == PremiumPlan.lifetime
                                ? 'Back to my garden'
                                : 'Manage subscription')
                          : billing.busy
                          ? 'Confirming purchase…'
                          : billing.loading
                          ? 'Checking available plans…'
                          : billing.canBuy(_selected)
                          ? (_selected.subscription
                                ? 'Subscribe · $price / ${_selected.period}'
                                : 'Unlock lifetime · $price')
                          : 'Purchases unavailable right now',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, c.premium),
                  child: Text(
                    c.premium ? 'Back to my garden' : 'Continue free',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  void _legal(BuildContext context, String title) async {
    final config = c.purchases.config;
    final url = title == 'Privacy' ? config.privacyUrl : config.termsUrl;
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'https') {
      try {
        if (await launchUrl(uri!, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              title == 'Privacy'
                  ? 'Your vocabulary progress, saved words and preferences stay on this device. No account is required. There are no advertising trackers.\n\n${c.purchases.purchasePrivacyText}\n\nYou can remove local learning data by removing the app. Restoring purchases uses your store account; it does not restore learning progress from another device.'
                  : 'Free access includes the first general, Goethe and telc topic in every level from A1 to C1. Premium unlocks the remaining collections and study tools.\n\nWeekly and monthly subscriptions renew automatically until cancelled in your store settings. Cancellation preserves access until the end of the paid period. Lifetime is a one-time purchase for permanent access to this app’s Premium features.\n\nPrices and purchase confirmation are supplied by your store. Refunds follow the store’s policies. Your learning progress remains saved when a subscription ends. Verified access is available offline until the paid subscription period expires; reconnect to confirm renewal.',
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Garden.green),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
