# Wortgarten RevenueCat and iOS release

The Flutter integration uses purchases_flutter 10.15.2 with the existing garden paywall. Buying, restoring, subscription management, localized prices, customer updates and expiry use RevenueCat. Only verified active `premium` entitlements from recognized Wortgarten products grant access. The original local progress format and free access rules are preserved. RevenueCat and the legacy purchase backend are selected exclusively; they are never initialized together.

## Account identifiers

- RevenueCat project: Wortgarten, `73132ff1`
- RevenueCat iOS app: `app3a8fa84ec9`
- Apple app: Wortgarten: German Vocabulary, `6821670098`
- Apple bundle ID: `com.wortgarten.germanVocabulary`
- Apple team: `W7JD7K34XR`
- Subscription group: Wortgarten Premium, `22465184`
- Android package: `com.wortgarten.german_vocabulary`
- Entitlement identifier: `premium`
- Offering identifier: `default`

| Plan | Store product ID | RevenueCat package | Type | Germany price |
| --- | --- | --- | --- | --- |
| Weekly | wortgarten_premium_weekly | $rc_weekly | Auto-renewable, 1 week | €4.90 |
| Monthly | wortgarten_premium_monthly | $rc_monthly | Auto-renewable, 1 month | €9.99 |
| Lifetime | wortgarten_premium_lifetime | $rc_lifetime | Non-consumable | €99.00 |

Weekly and monthly belong in the same subscription group and service level, because both grant identical access. Lifetime is a separate non-consumable in-app purchase. Attach all three products to `premium` and their packages in the `default` offering. Prices shown by the app come from the store, including currency and taxes. The requested €4.90 price is available under Apple's additional prices.

## Local configuration

`config/revenuecat.local.json` is ignored by Git. It contains the public iOS SDK key obtained through the RevenueCat dashboard. No private Apple key or RevenueCat secret API key belongs in the application. Missing/disabled keys keep purchases unavailable and free practice accessible. The example configuration uses Apple's standard EULA for iOS Terms.

The local configuration now has `REVENUECAT_ENABLED` set to true for store testing, with both public iOS and Android SDK keys configured. Keep `BILLING_PROVIDER` as `revenuecat`. The committed example stays disabled. Android uses `ANDROID_TERMS_URL` for Google Play platform terms, while iOS retains Apple's standard EULA in `TERMS_URL`. RevenueCat Test Store keys are deliberately rejected in the app build configuration.

```sh
flutter run --dart-define-from-file=config/revenuecat.local.json
flutter build ios --simulator --dart-define-from-file=config/revenuecat.local.json
flutter build ios --release --no-codesign --dart-define-from-file=config/revenuecat.local.json
flutter build ipa --release --dart-define-from-file=config/revenuecat.local.json
```

The last command requires valid distribution provisioning. Team `W7JD7K34XR` and automatic signing are configured; open `ios/Runner.xcworkspace` in Xcode and sign in to the Apple developer account to obtain the necessary certificate and profile. Confirm Signing & Capabilities, then archive/export or use Flutter. Compilation without code signing does not produce an uploadable IPA. Release version is 1.3.0 (17); existing Android 1.2.5 (16) files are separate artifacts.

## Apple and RevenueCat configuration

App Store Connect shows the Paid Apps agreement, bank account and tax forms as Active. Existing Apple purchase and product-import credentials were selected inside RevenueCat; their private key contents were never copied to the workspace. RevenueCat credentials were revalidated after creating the Apple app and show valid. Production and sandbox notification URLs were entered in App Store Connect using the RevenueCat app's endpoint and persisted after reloading; this Apple interface did not expose a notification-version selector. Confirm v2 delivery with a sandbox transaction before release.

English product names/descriptions and subscription-group localization are saved. All three products have Germany base prices from the table and availability in all 175 Apple regions, with localized prices elsewhere. Review screenshots and the app's release metadata, screenshots, age rating, review contact information and privacy details remain to complete. The first subscriptions and lifetime product must accompany the first app review submission. Creating records does not publish the app or enable approved live purchases.

Weekly currently has service level 1 and monthly level 2. Before release, use the subscription group's Edit Level dialog to place both in the same service level because they grant the same access. The browser drag operation did not save a grouping change.

RevenueCat uses an anonymous SDK customer ID. Restore is an explicit user action. Review the project's restore-transfer behavior before release. A store account can restore purchases after reinstalling; there is no app account or cross-platform learning-progress sync. Store transactions and receipt verification are handled by RevenueCat; the legacy signing server is not needed for this provider.

## Privacy before release

Publish the purchase paragraph in `docs/revenuecat-privacy-addendum.html` at the app's privacy URL and remove any claim that purchases are disabled for the payment-enabled release. The disabled Android code16 build's Data Safety declaration remains accurate for that artifact; update it before uploading a RevenueCat-enabled Android release.

For iOS, declare Purchase History used for App Functionality and Analytics. With this anonymous-ID implementation, no customer attributes or advertising integrations, it is not linked to an identifiable person and not used for tracking. Review declarations if other integrations or account identity are added. RevenueCat does not receive the local vocabulary progress or payment card details. Automatic device-identifier collection is disabled.

Official guidance: [Apple privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy), [Google Data Safety](https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety), [Flutter installation](https://www.revenuecat.com/docs/getting-started/installation/flutter), [trusted entitlements](https://www.revenuecat.com/docs/customers/trusted-entitlements).

## Required sandbox validation

Automated app tests: **76 passed**, and Flutter analysis is clean. iOS simulator and RevenueCat-enabled unsigned release builds compile. The live native simulator diagnostic connected to RevenueCat and fetched CustomerInfo successfully, but its three-product assertion failed: Apple returned only `wortgarten_premium_lifetime`. RevenueCat's saved offering maps all three packages correctly, and Apple agreements, banking and tax forms show Active. Weekly/monthly StoreKit availability remains unresolved; do not treat this as a successful payment test. Recheck Apple metadata and product propagation, then run:

```sh
flutter test integration_test/revenuecat_native_test.dart -d <ios-device-id> --dart-define-from-file=config/revenuecat.local.json
```

On a real iPhone using sandbox or TestFlight, exercise weekly/monthly/lifetime purchases, cancellation, pending payment, restore after reinstall, renewal/expiration, refund/revocation and subscription management. Confirm transactions and `premium` access in RevenueCat. Test offline access and reconnect after expiration. Verify free users can access the first general, Goethe and telc topic in every level A1–C1 and all five practice modes for that content. The automated tests cover these access decisions through a fake SDK client; they do not prove a live Apple transaction.

Do not submit to App Review until products and credentials are valid, the privacy policy is published, a signed build is uploaded and real sandbox purchase/restore tests pass.

## Android account configuration

RevenueCat Android app `app2c4daa6054` is connected to package `com.wortgarten.german_vocabulary`. The existing Google Cloud service account `revenuecat@gen-lang-client-0008577437.iam.gserviceaccount.com` was used. A new JSON key was downloaded through Google Cloud and uploaded directly to RevenueCat; its private contents were never copied into source or printed. RevenueCat reports **Valid credentials**. Keep the downloaded key securely outside the app repository.

Play products are active: `wortgarten_premium_weekly` with base plan `weekly`, `wortgarten_premium_monthly` with base plan `monthly`, and non-consumable `wortgarten_premium_lifetime` with Buy option `lifetime`. Germany prices are €4.90, €9.99 and €99.00. Regional pricing is generated by Google; exact Germany amounts were checked after tax and rounding. All three are attached to `premium` and their matching packages in offering `default`, alongside the existing Apple products.

The dedicated topic `projects/gen-lang-client-0008577437/topics/revenuecat-wortgarten` is connected in RevenueCat and entered in Play Monetization setup, with subscriptions, voided purchases and all one-time products selected. The initial test failed because Google Play lacked publishing permission. After explicit user approval, `google-play-developer-notifications@system.gserviceaccount.com` received Pub/Sub Publisher on this topic only. Retesting succeeded: RevenueCat shows Last received October 11, 2026 at 19:21 UTC (21:21 Berlin time). The notification connection is verified.

The current closed-test build has not been replaced. Before distributing a payment-enabled Android build, publish the Wortgarten/RevenueCat privacy update, update Play Data Safety for Purchase History, and complete real-device license-tester purchases and restore tests. The public policy checked on October 11 still describes German Exam Prep and does not mention Wortgarten. The existing mobile-app terms describe another free, ad-supported app; add suitable Wortgarten terms before release. The Google Play platform terms link alone does not replace app-specific terms.

```sh
flutter run -d <android-device-id> --dart-define-from-file=config/revenuecat.local.json
flutter test integration_test/revenuecat_native_test.dart -d <android-device-id> --dart-define-from-file=config/revenuecat.local.json
flutter build appbundle --release --dart-define-from-file=config/revenuecat.local.json
```

For no-charge Play purchase testing, the tester must be a Google Play license tester and use the expected Google account on the device. Install a billing-enabled build from an internal/closed test, check the purchase sheet offers Google's test payment methods, then verify sandbox transactions and active `premium` in RevenueCat. Test cancellation, expiry, grace/account-hold behavior, refund, lifetime restoration and restore after reinstall. Reinstalling erases local learning progress, so use a dedicated test device/account. No Android device was connected during this setup; a live purchase has not been tested.
