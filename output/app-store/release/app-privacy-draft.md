# App Privacy draft — Wortgarten 1.3.0 (19)

Published in App Store Connect on 14 October 2026 after verifying the deployed RevenueCat privacy policy. App and purchase items were submitted on 14 October 2026 and are Waiting for Review.

- Data collected: **Yes** (RevenueCat purchase processing).
- Data type: **Purchases → Purchase History**.
- Purposes: **App Functionality** and **Analytics**.
- Linked to identity: **No**, for the current anonymous setup without accounts, email attributes or custom user IDs.
- Used for tracking: **No**, for the current implementation without advertising or attribution integrations.

The native client uses RevenueCat's anonymous identifier, disables automatic device identifier collection, and does not send contact attributes. Learning progress and favourites remain local. Recheck these answers if authentication, analytics or attribution is added.

Basis: [RevenueCat's Apple App Privacy guidance](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy) and `lib/services/revenuecat_service.dart`.

Policy URL: https://deutsch-pruefung.de/wortgarten-privacy

The live policy now covers enabled RevenueCat purchases. The full replacement source is `docs/wortgarten-privacy-policy.html`. Both English and German privacy-policy URLs are saved. The app is Waiting for Review.
