# Wortgarten

An illustrated Flutter vocabulary app for Android and iOS, with a web preview.
Learning progress stays on the device. The reference project is used for vocabulary,
original illustrations, recorded audio, the licensed Geist font, and design inspiration.

Free learning works without an account or server. Premium purchases use Apple/
Google billing and a purchase-verification service. The unconfigured development
build shows the plans and allows free access; it cannot charge or grant Premium.

## What works

- A1–C1 browsing by level, topic, and Goethe/telc exam collection.
- Illustrated Goethe and telc shortcuts on Home open the matching exam at the
  selected level, with topic and unique vocabulary counts from the catalog.
- One branded launch animation with growing vines, a settling dictionary logo,
  the A1–C1 trail, and a crossfade into the app. The reveal takes 1.4 seconds,
  followed by a 0.7-second hold. Native launch screens use only the matching
  background, without a duplicate logo. Reduced motion opens the ready app
  immediately; slower loading and retry remain accessible.
- Three onboarding steps (discover, level/goal,
  first illustrated word), a skippable introduction and a dismissible paywall.
  Settings can replay the introduction without changing existing learning data.
- Free: the first general, Goethe and telc topic in each level from A1 to C1,
  all five practice modes for that content, audio, bookmarks and basic progress.
  Premium: remaining general/exam collections, custom lists, difficult-word
  practice and detailed insights. No ads or daily quotas on free content.
- 3,284 unique words and expressions in 565 general and exam lessons.
- German/English search, including noun plurals; examples, definitions, articles,
  plurals, present-tense forms, and provided IPA.
- Five practice modes: review (with optional auto-play), animated flashcards,
  spelling, meaning/context quizzes, and word forms.
- Saved words, topic bookmarks, custom lists, and difficult-word practice.
- Local session resume with stable shuffled quiz answers and spelling drafts.
- Daily goals, calendar streaks, recall accuracy, level progress, and spaced reviews
  at 1, 3, 7, and 14 days. Reading a word does not award recall mastery.
- Bundled MP3 pronunciation, example and full-card recordings, with adjustable
  playback speed. Review auto-play advances after the full recording finishes.
  Words without recordings use system text-to-speech; install German and English
  system voices for those cards to work offline.
- Opt-in daily local reminders with device notification permission and time-zone
  aware scheduling. Android uses inexact alarms to avoid exact-alarm permission.
- Bundled illustrations/fonts/content and local SQLite progress on Android/iOS.
  The web preview uses browser local storage. There is no cloud sync.
- Individual illustrations for all 3,196 reference entries, including 2,603 custom
  word images and 27 custom topic images. Images are optimized to WebP at up to
  512 pixels. The media snapshot contains 9,539 MP3 clips and takes about 428 MiB.
- Larger square artwork in practice cards, image-led topic cards and lesson
  headers, and visual thumbnails in word lists. Practice images adapt to the space
  left by text, feedback and controls. Word details open an image preview with
  pinch-to-zoom; illustrations keep their proportions without cropping.
- Three bundled AI illustrations, interactive A1–C1 path, practice shortcuts,
  weekly activity bars, memory-stage donut, and a spaced-review timeline.
  Charts use real progress and accessible native labels. Generation prompts and
  asset paths are recorded in `docs/image-generation.json`.
- The selected AI logo combines an open German dictionary, leafy sprout, Ä and
  a German flag bookmark. The app, welcome screen and platform launcher icons use
  the same artwork. Its original master and prompt are retained in `design/brand/`
  and `docs/brand-logo.json`.
- Illustrated discovery Home and grouped Activity/Memory/Levels progress views.
  Compact practice buttons stay fixed at the bottom, including above the spelling keyboard.
  Examples and extra forms open on demand. Long lists, unusually long entries,
  and large accessibility text can still scroll safely without hiding actions.

Existing progress, saved words, lists and unfinished sessions survive this update.
Older saved cards and session words retain access; new subscription access is
verified separately from learning progress. Cancellation keeps learning data.
Premium remains available offline through the verified paid subscription period;
lifetime access is permanent, with refund/revocation checks when online.

## Content coverage

| General collection | Unique entries | Coverage |
| --- | ---: | --- |
| A1 | 897 | 44 topics from the reference course |
| A2 | 1,470 | 57 reference topics plus retained mobile practice |
| B1 | 1,532 | 58 reference topics plus retained mobile practice |
| B2 | 688 | 27 reference topics plus retained mobile practice |
| C1 | 390 | 18 reference topics plus retained mobile practice |

The exam-specific A1 collections retain their own inventories: Goethe has 827
entries and telc has 1,132, with overlapping entries sharing progress. Counts
include supplementary practice entries from the reference. telc's source is its
Einfach gut! A1 textbook vocabulary, not an exhaustive exam syllabus. The imported
A2 reference course has 1,443 entries across 57 lessons; B1 has 1,515 across 58.
Both are cumulative and include earlier-level revision. Their Goethe and telc
selections retain the source's separate lesson memberships. Earlier mobile packs
remain available, adding supplementary practice to the totals above. The B2
reference collection has 672 entries across 27 topics; C1 has 362 across 18.
Goethe/telc collections retain the reference's exam selections at each level.
Reference collections are selected vocabulary, not complete inventories of the
published lists.

References: [Goethe](https://www.goethe.de/en/spr/prf.html),
[telc teaching resources](https://www.telc.net/lehrmaterialien/downloadbereich/).
Definitions, examples and topic illustrations are original reference material;
the retained starter packs are original to this app. Geist's OFL license is bundled
in `assets/fonts/OFL.txt`.

## Run

```sh
flutter pub get
flutter run                         # choose an Android/iOS device
flutter run -d chrome              # interactive web preview
```

For iOS, install Xcode with a simulator runtime and CocoaPods. For Android,
install the Android SDK and an emulator or attach a device. Android release
signing is configured locally; App Store signing and store metadata still need
setup in their respective consoles.

```sh
flutter analyze
flutter test
flutter test integration_test/native_storage_test.dart -d <simulator-id>
flutter test integration_test/media_playback_test.dart -d <simulator-id>
flutter build apk --debug
flutter build ios --simulator
flutter build web --no-web-resources-cdn
python3 -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Build a signed release APK for ARM64 Android phones and an App Bundle for Play:

```sh
python3 scripts/generate_upload_key.py # first upload only; preserves existing key
flutter build apk --release --target-platform android-arm64 --split-per-abi -P force-version-code-ignoring-abi=true
flutter build appbundle --release
```

The APK is at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console. The
bundle supports ARM32, ARM64 and x86-64; Play delivers the matching device files.
The Gradle property keeps the APK version code from `pubspec.yaml` without an ABI
offset. Keep release preparation enabled (omit `--no-pub`) so test plugins are
excluded. Explicit release builds fail if the private signing setup is missing.

Back up `android/signing/wortgarten-upload.jks` and `android/key.properties`
together in a secure place. They are ignored and owner-readable; passwords are
never printed by the setup script. The public certificate is
`android/signing/wortgarten-upload-certificate.pem`. Reuse the key for future
uploads. For an app already uploaded to Play, restore its existing upload key
rather than generate another one. Google manages a separate distribution key
through [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

The earlier development installation on the connected phone has a different
signing certificate. This new APK cannot update it with `adb install -r`.
Use another device for the new signed build or back up learning progress before
planning a signing migration. Do not uninstall the existing app to resolve a
signature mismatch: that deletes local progress. For future APK updates with
the same signer, use `adb install -r`; this project's Flutter SDK uninstalls the
existing app when running `flutter install`.

## Google Play closed testing

These steps prepare a first Play listing for `com.wortgarten.german_vocabulary`.
Version `1.2.5` uses version code `16`; increase the number after `+` in
`pubspec.yaml` for every subsequent upload.

1. Complete developer-account identity and any device-verification tasks shown
   in [Play Console](https://play.google.com/console/).
2. Create **Wortgarten**, choose **App** and **Free**, set the default language
   to English, and enter your support email. Education suits this app. The app
   is free to download with planned Premium purchases. The uploaded package
   name is permanent. [Create an app](https://support.google.com/googleplay/android-developer/answer/9859152).
3. Complete the main store listing with accurate descriptions, the selected
   app icon, phone screenshots, and a feature graphic. Complete the Dashboard
   setup tasks and select tester countries.
4. In **Policy and programs → App content**, supply the public privacy-policy
   URL, declare no ads for this build, answer the content-rating and audience
   questions, and complete Data safety. App access instructions should explain
   how to skip onboarding/paywall, use the free version, and access restricted
   Premium features when configured. There is no app login. Do not declare all
   features unrestricted while Premium practice is locked.
   [Review setup](https://support.google.com/googleplay/android-developer/answer/9859455).
5. Go to **Test and release → Testing → Closed testing → Manage track**. Choose
   **Testers**, create/select an email list or Google Group, and add a feedback
   address. Use the Google accounts testers use in Play Store.
   [Tester setup](https://support.google.com/googleplay/android-developer/answer/9845334).
6. Under **Releases**, create a release and upload `app-release.aab`. Keep the
   default Google-managed app signing. Name it `1.2.5 – Closed test 1` and add
   the release notes below. Resolve Console errors, review the release, and
   submit/roll out to the closed track. If changes need review, send them from
   **Publishing overview** and wait for approval; publish approved changes if
   managed publishing is enabled.
   [Release workflow](https://support.google.com/googleplay/android-developer/answer/9859348).
7. Once the track is published, copy its tester opt-in link. Testers join with
   an allowed account, then install from Google Play. Sideloading the APK does
   not enroll anyone. New closed-test apps are reached through the link rather
   than Play search; the link may take several hours to become available.
   [Tester access](https://support.google.com/googleplay/android-developer/answer/9845334).
8. For personal developer accounts created after **13 November 2023**, maintain
   at least **12 testers opted in continuously for 14 days** before applying
   for production access. Collect actual usage feedback, fix issues, and answer
   the production-readiness questions on the Dashboard. Meeting the numbers
   lets you apply; production approval is separate.
   [Testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465).

Tester checks: cold launch, onboarding/skip, Goethe/telc Home shortcuts, available
practice modes, illustrations/audio offline, bookmarks, saved progress after
relaunch, and small-screen layouts. Ask testers to stay enrolled and report bugs.
If they previously joined internal testing, they must leave that track before
joining the closed test. [Track eligibility](https://support.google.com/googleplay/android-developer/answer/9845334).

The uploaded code 16 build links to `https://deutsch-pruefung.de/privacy` and has
no configured purchase-verification endpoint. Existing free content and the
paywall are retained; Premium purchases remain disabled. The Wortgarten-specific
privacy addendum must be published on that page before review. Reviewer access
to restricted Premium content is still unresolved: Google requires access to
all features, including paid content. The release is saved as a draft, with
`apphive-testers@googlegroups.com` and all 178 available countries configured.
See `output/play-store/publish-progress.json` for the saved setup and remaining
declarations. To test paid features, finish the store products, verification
service and license tester setup described below. Increment the version code
for any new artifact uploaded to Play.
Review Data safety again when enabling the verification service: local learning
progress and server-bound purchase proofs have different data flows.

The current media is all bundled offline. Google now permits a **500 MB
compressed base-module download** and warns mobile-data users above 200 MB.
The AAB's disk size is not the per-device download size. Check Console's estimate
after upload; the local bundletool estimate is recorded with the release files.
[Current size limits](https://support.google.com/googleplay/android-developer/answer/9859372).

Suggested release notes:

```text
<en-US>
Initial closed test of Wortgarten. Browse German vocabulary by level, topic and
exam; practise available free content with pictures and audio; save bookmarks
and learning progress. Includes the animated garden splash. Premium purchases
are not enabled in this build.
</en-US>
```

Regenerate launcher icons from the selected master with
`node scripts/generate_icons.cjs`. This also creates the small bundled app logo;
the master is retained outside the app bundle.

## Edit or expand content

`content/starter-packs.txt` is the editable source for the retained A2–C1 packs.
The six fields are German term, English meaning, German definition, German
example, translated example, and grammar (`n:plural`, `v:three;present;forms`,
`adj`, `adv`, or `ex`). Then rebuild the catalog:

```sh
python3 scripts/build_catalog.py
```

The reference snapshot in `assets/data/reference.json` is versioned so builds
do not depend on the other project. To refresh it deliberately (requires the
reference's Node dependencies):

```sh
node scripts/import_reference.cjs ../german-exam-prep --data-only --include-media --fetch-private-media
python3 scripts/build_catalog.py
```

The media importer reads the reference's A1–C1 audio/image folders and `topics`
folder, using manifest levels and falling back to flat or nested files. It prefers
custom word WebPs, then the reference's individual artwork. It rasterizes SVG
labels, optimizes images, copies completed MP3 files,
and creates missing topic fallbacks. It excludes raw PNG generation originals,
unrelated listening tracks and unfinished MP3 files. A generated inventory tracks
the files it owns, so later refreshes clean up obsolete generated assets safely.
All media is bundled; the app does not request it from the website.

The reference may move media to private storage. `--fetch-private-media` reads
only declared vocabulary objects through that project's existing storage
connection, verifies their SHA-256 hashes, and caches originals in the ignored
`output/reference-media/` folder. Cached originals and storage credentials are
never bundled. Existing compatible recordings are retained when their hashes
match the private inventory; illustrations are matched to their exact originals.

For a vocabulary-only refresh that retains compatible existing media mappings:

```sh
node scripts/import_reference.cjs ../german-exam-prep --data-only
python3 scripts/build_catalog.py
```

Pronunciation mappings remain when a term is unchanged. Example and full-card
recordings are retained only when the corresponding text is unchanged. Use
`--include-media` after generating new images or recordings. Generation can
continue in the reference project; rerun the command when more files are ready.

The catalog builder keeps existing mobile word and lesson IDs. The retired
duplicate `b1-adj-regelmaessig` migrates to `telc-a1-adv-regelmaessig` across
saved words, lists, daily counts, recall records, and unfinished sessions.
If an editorial
word ID also exists in the reference, refreshed reference content is preferred
after checking the term and part of speech. Expanded general topics retain their
earlier mobile words. Imported exam lessons keep their source-specific selection;
legacy exam packs are retained only when their lesson ID does not already exist.
Equivalent legacy mobile cards receive corrected reference content without
changing their IDs; homonyms are matched only by an unambiguous identity or meaning.

Grammar details include Präteritum, Partizip II, Perfekt auxiliaries and usage
notes, plus verb/preposition/case patterns. Plural headwords show singular forms
and number usage. Full explanations open on demand in word details; forms practice
also recalls the past tense. Spelling distinguishes capitalisation errors from
other mistakes, including formal `Sie`/`Ihr`. Sentence gaps use only editorially
reviewed questions and distractors; other words use meaning questions.

Never change published word IDs: progress is shared by ID, independently of
which lesson or exam collection displays a word. `lib/models`, `lib/state`,
`lib/services`, and `lib/ui` separate vocabulary, learning rules, native
integrations, and screens. Failed progress reads preserve existing data;
failed writes retain in-memory changes and offer retry.

## RevenueCat and iOS release

The new RevenueCat integration keeps the existing garden paywall and free access limits. The iOS account setup, product IDs, configuration and sandbox checklist are in [docs/revenuecat-ios-setup.md](docs/revenuecat-ios-setup.md). Use `--dart-define-from-file=config/revenuecat.local.json` to select this backend. The local configuration is ignored; it contains only the platform public SDK key. The existing Android code16 release remains payment-disabled.

## Legacy purchase backend (optional)

The screens and native purchase integration are implemented. Real purchases
remain disabled until store products and HTTPS verification are configured.
There is no development switch that unlocks Premium in the shipping app.

| Product ID (same on both stores) | Type | Euro price |
| --- | --- | ---: |
| `wortgarten_premium_weekly` | Auto-renewing weekly subscription | €4.90 |
| `wortgarten_premium_monthly` | Auto-renewing monthly subscription | €9.99 |
| `wortgarten_premium_lifetime` | Non-consumable permanent purchase | €99.00 |

1. **Google Play:** Create the app for `com.wortgarten.german_vocabulary`, complete
   the payments setup, and configure production signing. Add the two subscription
   products, each with one active auto-renewing base plan of its matching duration,
   and a non-consumable one-time lifetime product. Configure the requested euro
   prices, regional availability and translations. Upload a signed release AAB to
   an internal test track; add license testers and install through the track.
   Use the Play-installed build for purchase testing. Keep the development
   phone's progress backed up before changing signing keys; a signing mismatch
   should not be resolved by deleting app data.
2. **App Store:** Create the app for `com.wortgarten.germanVocabulary`. Put weekly
   and monthly products at the same entitlement level in a single subscription
   group, and create lifetime as a non-consumable. Complete agreements, payments,
   prices, availability and product review details. Enable In-App Purchase for
   the app and test with a Sandbox account/TestFlight. This app uses StoreKit 2.
3. **Verification service:** The prepared Node service is in `server/purchases/`.
   Install with `npm ci` there, then run `npm run keys`. It writes a private
   Ed25519 key into its ignored `private/` directory and prints only the public
   key. Keep the private key on the server. Copy `.env.example` to `.env` and set
   the file locations and store configuration. Use a Google service account with
   Play Developer API access to this app and subscription/order permissions;
   provide credentials through `GOOGLE_APPLICATION_CREDENTIALS`. Provide the
   Apple In-App Purchase API key `.p8`, key ID, issuer ID, app ID for production,
   and trusted Apple root certificates from [Apple PKI](https://www.apple.com/certificateauthority/).
   Sandbox and Production Apple verification should use separate deployments.
4. **Run and deploy:** Run `node --env-file=.env server.mjs`, behind an HTTPS
   endpoint, with `/verify` routed to it. Set the port through `PORT`. The service
   validates purchases directly with Apple/Google, checks the app/product,
   expiration, grace period and refunds, then signs the access response. It does
   not accept client-supplied Premium flags, log receipts or store card details.
   Native completion/Google acknowledgement occurs only after verification and
   saving the entitlement. Preserve the signing key across deployments.
5. **App configuration:** Copy `config/billing.example.json` to a local
   configuration file. Set `PURCHASE_VERIFY_URL` to the HTTPS `/verify` endpoint,
   `ENTITLEMENT_PUBLIC_KEY` to the printed raw Base64 public key, and `PRIVACY_URL`
   and `TERMS_URL` to published, reviewed policies. The public key is safe in the
   app; Apple/Google credentials and the private signing key must never enter it.
   Store-localized product prices replace the euro preview prices when available.

```sh
flutter run --dart-define-from-file=config/billing.local.json
flutter build appbundle --release --dart-define-from-file=config/billing.local.json
flutter build ipa --dart-define-from-file=config/billing.local.json
```

Before publishing, review the in-app policy text and your public policies, then
test completed, cancelled, pending, declined and interrupted purchases, restore
after reinstall, expiration, renewal, grace periods, refunds and offline access.
Restore uses the same store account/platform; it restores Premium access, not
local learning progress. Cross-platform purchase sharing is not implemented.
An active subscriber is directed to store management rather than being sold a
second overlapping plan. No automatic free trial is configured.

Verification tests: `npm test` in `server/purchases/`. Flutter purchase tests use
fake store events and real signature verification; live store transactions need
the accounts and products described above.

Sources: [Flutter purchase plugin](https://pub.dev/packages/in_app_purchase),
[Apple subscriptions](https://developer.apple.com/app-store/subscriptions/),
[Google billing integration](https://developer.android.com/google/play/billing/integrate),
[Apple server verification library](https://github.com/apple/app-store-server-library-node).
