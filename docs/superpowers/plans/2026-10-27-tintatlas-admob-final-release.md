# TintAtlas AdMob Banner and Final Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add consent-aware Google AdMob anchored adaptive banners only to approved low-interaction TintAtlas surfaces, then re-verify the exact monetized candidate for an explicitly authorized platform release.

**Architecture:** Keep all Google SDK types behind testable consent, configuration, gateway, policy, and controller boundaries. A closed placement registry defaults every route to no ad; the shared slot reserves a measured safe-area-aware banner space without blocking content, and the entire app remains functional when consent, initialization, load, network, or fill is unavailable. Production identifiers and publication remain external authorization gates.

**Tech Stack:** Flutter/Dart 3.11, Riverpod, GoRouter, `google_mobile_ads: ^9.2.0`, Google User Messaging Platform APIs exposed by the plugin, Android manifest placeholders/Gradle, iOS xcconfig/Info.plist, Flutter unit/widget/integration tests, and repository release validators.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Start only after `2026-10-27-tintatlas-quality-release.md` has frozen a passing, checksummed ad-free core candidate for the platform being prepared.
- Monetization is banner-only: no interstitial, rewarded, rewarded-interstitial, native, app-open, forced-click, click-to-unlock, or gameplay-interruption format.
- Core actions never depend on an ad request, network, fill, consent, ATT choice, or click; no copy asks, suggests, or rewards a user for tapping an ad.
- The only candidate placements are Home hub, Rooms hub, Learn hub, Games hub, My Work read-only library, and an already-settled game result. Every unlisted route defaults to no ad.
- Onboarding, consent/privacy forms, camera, photo picker, permissions, model setup, loading/error screens, Room mask/editor, Illustrated editor, Coloring workspace, lesson interaction, active game/map, and any enlarged/private-content editor or preview remain ad-free. My Work is eligible only as its read-only library index; opening a photo/artwork/design preview, modal action, or editor makes it immediately ineligible, and no library content is copied into the request.
- Never pass photos, masks, drawings, palettes, color values/names, lesson answers, project/profile IDs, free text, content-derived labels, or precise local state into ad request extras/keywords/content URLs.
- Use official Google test App IDs and banner unit IDs in all source-controlled development configuration. Production IDs enter only user-owned release inputs after explicit authorization.
- Consent information refreshes once per app launch; ads start only when `canRequestAds` is true; privacy options are exposed exactly when the SDK reports they are required; SDK/ad requests are deduplicated.
- Do not add an ATT prompt/package by default. If the observed iOS SDK configuration or approved strategy would track across apps/sites, stop and add a separately approved, disclosed ATT task; UMP consent is never treated as ATT authorization.
- Android API 24 and iOS 13 floors, four root destinations, storage identities, data ownership, accessibility, localization, responsive, privacy, and per-platform release gates remain unchanged.
- Do not push, publish, upload, change AdMob/store state, create production ad units, or stage the user-owned `lib/main.dart` edit without explicit user authorization.

## Review Focus

- A consent form error, denial, unavailable network, slow response, invalid unit, or no fill leaves every feature reachable and never creates a full-screen/dead-end ad state.
- Rapid route/orientation/width changes cannot attach a stale banner, issue duplicate loads, leak native ad objects, or move a control while the user is about to tap it.
- Deep links, dialogs, editor subroutes, active game transitions, and private-content views default to no ad even when their path resembles an allowlisted hub.
- At 200% text on `320×568`, landscape, tablet split view, keyboard-visible, and bottom-navigation layouts, a banner neither overlaps nor obscures content/navigation/safe areas.
- Debug/test IDs can never enter a production candidate, and production IDs/configuration can never make a source-controlled development build request live ads.

---

## Locked official integration references

- Package/version source: [`google_mobile_ads` on pub.dev](https://pub.dev/packages/google_mobile_ads)
- App ID, platform setup, and initialization: [Google Mobile Ads Flutter quick start](https://developers.google.com/admob/flutter/quick-start)
- UMP consent refresh, required form, privacy options, and `canRequestAds`: [Google Mobile Ads Flutter privacy](https://developers.google.com/admob/flutter/privacy)
- Anchored adaptive banner sizing/lifecycle: [Google Mobile Ads Flutter banners](https://developers.google.com/admob/flutter/banner)
- Test-ID and test-device rules: [Google Mobile Ads test ads](https://developers.google.com/admob/flutter/test-ads)

Source-controlled identifiers are fixed to Google's official samples:

| Platform | Test App ID | Anchored adaptive banner test unit ID |
|---|---|---|
| Android | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-3940256099942544/9214589741` |
| iOS | `ca-app-pub-3940256099942544~1458002511` | `ca-app-pub-3940256099942544/2435281174` |

### Task 1: Gate the dependency and native test configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Flutter/Debug.xcconfig`
- Modify: `ios/Flutter/Release.xcconfig`
- Modify: `.gitignore`
- Create: `test/core/ads/ad_native_config_test.dart`
- Modify: `tool/check_release_config.dart`

**Interfaces:**
- Consumes: a passing core-candidate evidence file, approved platform identity, Android Gradle property `TINTATLAS_ADMOB_APP_ID`, iOS build setting `ADMOB_APP_ID`, and Dart define `TINTATLAS_ADMOB_BANNER_ID`; all production values are user-owned release inputs.
- Produces: plugin `google_mobile_ads: ^9.2.0`; debug builds wired only to the table's test App IDs; production builds that fail validation when live IDs are absent and reject test IDs when present.
- Spec coverage: ADS-01–02.

- [ ] **Step 1: Add RED native configuration tests.** Assert the dependency is exactly `^9.2.0`, Android/iOS debug metadata resolve to the official test App IDs, release metadata use a non-source-controlled substitution, private release config filenames are ignored, and no production ID literal exists in tracked files.
- [ ] **Step 2: Run `flutter test test/core/ads/ad_native_config_test.dart`.** Expected: FAIL because the plugin and metadata are absent.
- [ ] **Step 3: Re-verify the core gate before changing dependencies.** Run `dart run tool/check_release_config.dart --mode=core --platform=<target>` against the frozen commit; stop this plan if it does not pass.
- [ ] **Step 4: Add `google_mobile_ads: ^9.2.0` and native App ID substitution.** Android debug falls back only to the official Android test App ID; iOS Debug.xcconfig sets only the official iOS test App ID; Release requires ignored user-owned values and has no debug fallback.
- [ ] **Step 5: Fetch dependencies and inspect the resolved package/native minimums against API 24/iOS 13.** If either floor is incompatible, keep this plan blocked and present measured options for approval; never raise a floor silently.
- [ ] **Step 6: Run native config tests, `flutter build apk --debug`, and `plutil -lint ios/Runner/Info.plist`.** Expected: PASS and the built debug manifests contain test App IDs only.
- [ ] **Step 7: Commit.** `git commit -m "build: add gated Google Mobile Ads dependency"`.

### Task 2: Implement typed ad configuration and request privacy

**Files:**
- Create: `lib/core/ads/ad_config.dart`
- Create: `lib/core/ads/ad_request_factory.dart`
- Create: `lib/core/ads/ad_audience_configuration.dart`
- Create: `test/core/ads/ad_config_test.dart`
- Create: `test/core/ads/ad_request_factory_test.dart`
- Modify: `tool/check_release_config.dart`

**Interfaces:**
- Consumes: `TargetPlatform`, `kReleaseMode`, approved audience declarations, and optional compile-time production banner ID.
- Produces: `AdConfig.forRuntime`, a release-gated `AdAudienceConfiguration`, and `AdRequestFactory.create()` that creates a plain request with no user/content targeting extras.
- Spec coverage: ADS-02 and ADS-04.

```dart
enum AdEnvironment { development, production }

final class AdConfig {
  const AdConfig({
    required this.environment,
    required this.bannerUnitId,
  });
  factory AdConfig.forRuntime({
    required TargetPlatform platform,
    required bool isRelease,
    required String productionBannerUnitId,
  });
  final AdEnvironment environment;
  final String bannerUnitId;
}

final class AdAudienceConfiguration {
  const AdAudienceConfiguration({
    required this.tagForChildDirectedTreatment,
    required this.tagForUnderAgeOfConsent,
    required this.maxAdContentRating,
  });
  final bool? tagForChildDirectedTreatment;
  final bool? tagForUnderAgeOfConsent;
  final String? maxAdContentRating;
}

abstract interface class AdRequestFactory {
  AdRequest create();
}
```

- [ ] **Step 1: Write configuration RED tests.** Development returns the exact platform test banner ID; release rejects empty/malformed/test IDs; unsupported platforms disable ads; the request contains no keywords, content URL, neighboring-content URL, location, device identifier, project/profile ID, or custom extras.
- [ ] **Step 2: Write audience-gate RED tests.** A production config cannot initialize while child-directed/under-age/content-rating treatment remains inconsistent with the approved store audience record; ATT status is not inferred from consent status.
- [ ] **Step 3: Run `flutter test test/core/ads/ad_config_test.dart test/core/ads/ad_request_factory_test.dart`.** Expected: FAIL before types exist.
- [ ] **Step 4: Implement the minimal typed configuration and plain request factory.** Keep all live IDs outside tracked source and fail closed for unsupported/invalid configuration.
- [ ] **Step 5: Run focused tests and `dart run tool/check_release_config.dart --mode=ads-test --platform=<target>`.** Expected: PASS with official test IDs and zero production identifiers.
- [ ] **Step 6: Commit.** `git commit -m "feat: add privacy-safe ad configuration"`.

### Task 3: Implement one-launch UMP consent and one-time SDK startup

**Files:**
- Create: `lib/core/ads/ad_consent_service.dart`
- Create: `lib/core/ads/google_ad_consent_service.dart`
- Create: `lib/core/ads/ad_sdk_gateway.dart`
- Create: `lib/core/ads/ad_bootstrap_controller.dart`
- Create: `lib/core/ads/ad_providers.dart`
- Create: `test/core/ads/ad_consent_service_test.dart`
- Create: `test/core/ads/ad_bootstrap_controller_test.dart`

**Interfaces:**
- Consumes: Google `ConsentInformation`, `ConsentForm`, `MobileAds`, the approved `AdAudienceConfiguration`, and injectable gateways in tests.
- Produces: immutable `AdConsentSnapshot`, `AdBootstrapState`, `refreshForLaunch()`, `showPrivacyOptions()`, and an idempotent `initialize()` Future.
- Spec coverage: ADS-03–04.

```dart
enum AdBootstrapPhase { idle, refreshingConsent, form, ready, unavailable }

final class AdConsentSnapshot {
  const AdConsentSnapshot({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });
  final bool canRequestAds;
  final bool privacyOptionsRequired;
}

final class AdBootstrapState {
  const AdBootstrapState({
    required this.phase,
    required this.consent,
    required this.failureCode,
  });
  final AdBootstrapPhase phase;
  final AdConsentSnapshot? consent;
  final String? failureCode;
}

abstract interface class AdConsentService {
  Future<AdConsentSnapshot> refreshForLaunch();
  Future<AdConsentSnapshot> showPrivacyOptions();
}

abstract interface class AdSdkGateway {
  Future<void> configure(AdAudienceConfiguration configuration);
  Future<void> initialize();
}
```

- [ ] **Step 1: Write UMP RED tests.** Each app-controller lifetime requests consent information exactly once, calls `loadAndShowConsentFormIfRequired`, re-reads `canRequestAds`/privacy-options requirement after completion, and exposes a non-blocking unavailable state for update/form errors.
- [ ] **Step 2: Write concurrency RED tests.** Ten simultaneous `initialize()` calls produce one consent refresh, at most one form flow, one audience configuration, one Mobile Ads initialization, and no ad-ready state before `canRequestAds` is true.
- [ ] **Step 3: Run `flutter test test/core/ads/ad_consent_service_test.dart test/core/ads/ad_bootstrap_controller_test.dart`.** Expected: FAIL before adapters/controllers exist.
- [ ] **Step 4: Implement the Google adapters and Riverpod controller.** Cache only the in-flight/completed launch Future, let UMP own consent persistence, and never make the app router await ad readiness.
- [ ] **Step 5: Test required/not-required/denied/error/privacy-option-change and controller disposal.** Expected: all variants PASS; denial/error means features work with no banner.
- [ ] **Step 6: Commit.** `git commit -m "feat: add nonblocking UMP ad bootstrap"`.

### Task 4: Encode a default-deny placement policy

**Files:**
- Create: `lib/core/ads/ad_placement.dart`
- Create: `lib/core/ads/ad_eligibility_policy.dart`
- Create: `lib/core/ads/ad_placement_registry.dart`
- Create: `test/core/ads/ad_eligibility_policy_test.dart`
- Create: `test/core/ads/ad_placement_registry_test.dart`
- Modify: `lib/routing/app_router.dart`

**Interfaces:**
- Consumes: stable named routes from Plan 01, modal/private/interaction/result state, and `AdBootstrapState`.
- Produces: the only six valid `BannerPlacement` values plus `placementFor(AdSurfaceContext)`; unknown routes and ambiguous states return `null`.
- Spec coverage: ADS-06–07.

```dart
enum BannerPlacement {
  homeHub,
  roomsHub,
  learnHub,
  gamesHub,
  myWorkLibrary,
  settledGameResult,
}

final class AdSurfaceContext {
  const AdSurfaceContext({
    required this.routeName,
    required this.hasModal,
    required this.showsPrivateContent,
    required this.hasActiveInteraction,
    required this.gameResultIsSettled,
  });
  final String routeName;
  final bool hasModal;
  final bool showsPrivateContent;
  final bool hasActiveInteraction;
  final bool gameResultIsSettled;
}

BannerPlacement? placementFor(AdSurfaceContext context);
```

- [ ] **Step 1: Write exhaustive RED policy tests.** Every named route in `appRouteCatalog` maps to `null` except the five exact hubs/libraries; `settledGameResult` requires a settled result flag; modal/private/active/loading/error/consent/onboarding state overrides any otherwise eligible route to `null`.
- [ ] **Step 2: Add deep-link/path-confusion cases.** Prefixes, query strings, nested editors, maps, lessons, project IDs, unknown paths, and an active game beneath a Games path remain ineligible.
- [ ] **Step 3: Run the two focused policy suites.** Expected: FAIL before the closed registry exists.
- [ ] **Step 4: Name routes in the router and implement an explicit switch over route names.** Do not infer eligibility by substring, widget runtime type, or bottom-tab index.
- [ ] **Step 5: Run focused policy tests plus all router tests.** Expected: PASS and a newly added route is ad-free until deliberately registered and tested.
- [ ] **Step 6: Commit.** `git commit -m "feat: enforce banner placement allowlist"`.

### Task 5: Load and render lifecycle-safe anchored adaptive banners

**Files:**
- Create: `lib/core/ads/banner_ad_gateway.dart`
- Create: `lib/core/ads/google_banner_ad_gateway.dart`
- Create: `lib/core/ads/banner_ad_controller.dart`
- Create: `lib/core/ads/banner_slot.dart`
- Create: `test/core/ads/banner_ad_controller_test.dart`
- Create: `test/core/ads/banner_slot_test.dart`
- Create: `test/support/fake_banner_ad_gateway.dart`

**Interfaces:**
- Consumes: eligible `BannerPlacement`, `AdConfig`, `AdRequestFactory`, Google anchored adaptive size API, available logical width, safe-area padding, and bootstrap readiness.
- Produces: `BannerSlotState`, one owned/disposable `BannerHandle`, and a widget that never exposes SDK objects to feature code.
- Spec coverage: ADS-05, ADS-08–09.

```dart
enum BannerLoadPhase { hidden, sizing, loading, loaded, unavailable }

abstract interface class BannerHandle {
  Size get logicalSize;
  Widget buildView();
  void dispose();
}

abstract interface class BannerAdGateway {
  Future<Size?> anchoredAdaptiveSize({required int width});
  Future<BannerHandle> load({
    required String unitId,
    required Size size,
    required AdRequest request,
  });
}

final class BannerSlotState {
  const BannerSlotState({
    required this.phase,
    required this.reservedSize,
    required this.handle,
  });
  final BannerLoadPhase phase;
  final Size? reservedSize;
  final BannerHandle? handle;
}

Future<void> load({
  required BannerPlacement placement,
  required double availableWidth,
});
```

- [ ] **Step 1: Write controller RED tests.** Width is clamped to a positive integral pixel request; equal placement/width loads once; width/placement change disposes the previous handle; stale success/failure after change/dispose is ignored and disposed; no-size/load error/no-fill becomes `unavailable` without throwing.
- [ ] **Step 2: Write slot RED tests.** Before consent it occupies zero space; once an eligible measured request starts it reserves the returned height plus fixed non-clickable separation; loading/no-fill keeps that reservation until route exit to prevent tap-target shift; loaded view never overlays controls/navigation and has an accessibility boundary without promotional click copy.
- [ ] **Step 3: Run `flutter test test/core/ads/banner_ad_controller_test.dart test/core/ads/banner_slot_test.dart`.** Expected: FAIL before gateway/controller/widget exist.
- [ ] **Step 4: Implement the gateway/controller/slot.** Use current-orientation anchored adaptive sizing, generation tokens for stale callbacks, explicit native disposal, `SafeArea`, and no retry loop; a user-neutral route revisit may request again.
- [ ] **Step 5: Run tests with slow load, no-fill, network error, zero/narrow width, 200% text, RTL, background/resume, rotation, and rapid navigation.** Expected: PASS with no leaked handle or shifted pending control.
- [ ] **Step 6: Commit.** `git commit -m "feat: add adaptive banner slot lifecycle"`.

### Task 6: Integrate only approved screens and privacy options

**Files:**
- Create: `lib/core/ads/eligible_banner_host.dart`
- Create: `lib/features/games/presentation/settled_game_result_banner_host.dart`
- Create: `test/core/ads/eligible_banner_host_test.dart`
- Create: `test/core/ads/ad_free_route_contract_test.dart`
- Create: `test/features/games/presentation/settled_game_result_banner_host_test.dart`
- Modify: `lib/features/shell/presentation/app_shell.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Modify: `lib/features/learning/presentation/learn_screen.dart`
- Modify: `lib/features/games/presentation/games_screen.dart`
- Modify: `lib/features/my_work/presentation/my_work_screen.dart`
- Modify: `lib/features/games/presentation/bubble_shooter_screen.dart` only at its persisted settled-result panel
- Modify: `lib/features/games/presentation/fruit_pop_screen.dart` only at its persisted settled-result panel
- Modify: `lib/features/games/presentation/water_sort_screen.dart` only at its persisted settled-result panel
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart` only at its persisted settled-result panel
- Modify: `lib/features/color_test/presentation/matching_screen.dart` only at its persisted settled-result panel
- Modify: `lib/features/settings/presentation/privacy_screen.dart`

**Interfaces:**
- Consumes: `placementFor`, `BannerSlot`, named route state, durable settled-game result state, and `AdConsentSnapshot.privacyOptionsRequired`.
- Produces: exactly one slot per eligible surface; Settings privacy-options action appears only when required and invokes `showPrivacyOptions()`.
- Spec coverage: ADS-06–09 and the layout portion of ADS-11.

- [ ] **Step 1: Write host RED tests across every catalogue route.** Assert one placement/key on each exact hub/My Work index, zero on every exclusion, zero while a hub modal or private preview is visible, and zero during any game action/animation/save; a persisted settled result may show one slot after result content with fixed non-clickable separation from every action and navigation target.
- [ ] **Step 2: Write accidental-click layout tests.** At all required viewports, safe areas, orientations, and 200% text, assert at least `AppSpacing.md` non-clickable separation from controls/navigation, stable control rectangles from pointer-down through load/no-fill, and scroll access without overlay.
- [ ] **Step 3: Run integration and ad-free route contract suites.** Expected: FAIL before hosts are connected.
- [ ] **Step 4: Add the shared shell host and settled-result-only host.** Feature/editor/gameplay widgets never instantiate `AdWidget`, request ads, or import `google_mobile_ads`; the ad-free contract scans and rejects those imports/usages.
- [ ] **Step 5: Add localized privacy-options UI and re-bootstrap after a changed choice.** When the refreshed snapshot makes `canRequestAds` false, dispose loaded banners immediately; features remain mounted and usable.
- [ ] **Step 6: Run router, shell, Settings, all five game, accessibility, responsive, and core ad suites.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "feat: place banners on safe TintAtlas surfaces"`.

### Task 7: Reconcile production configuration and disclosure variants

**Files:**
- Create: `docs/release/app-ads.txt.template`
- Create: `docs/release/ad-placement-register.md`
- Create: `docs/release/ad-qa-matrix.md`
- Modify: `docs/release/privacy-policy.md`
- Modify: `docs/release/data-safety.md`
- Modify: `docs/release/apple-app-privacy.md`
- Modify: `docs/release/store-listing.md`
- Modify: `docs/release/quality-evidence.schema.json`
- Modify: `tool/check_release_config.dart`
- Modify: user-owned ignored production AdMob/Gradle/xcconfig inputs only after explicit authorization

**Interfaces:**
- Consumes: authorized AdMob Android/iOS App IDs and banner units, verified app-ads.txt publisher/domain, final audience treatment, Google SDK data disclosure, ATT decision where applicable, and candidate behavior.
- Produces: `--mode=ads-production` validation with exact SDK/version, six-place maximum registry, hosted app-ads.txt verification evidence, and reconciled platform privacy answers.
- Spec coverage: ADS-10 and FINAL-01.

- [ ] **Step 1: Extend RED release validation.** Reject official test IDs, sample/example IDs, mismatched App ID platform, missing/duplicate banner units, unapproved format/placement, absent audience treatment, missing privacy-options path, missing app-ads.txt verification, stale disclosure dates, and production values checked into source.
- [ ] **Step 2: Run release-config tests.** Expected: FAIL until production-shaped external inputs and reconciled documents are supplied.
- [ ] **Step 3: With explicit user authorization, configure AdMob apps/banner units and user-owned release inputs.** Record account-side actions and publisher/domain identifiers without credentials; never enable another ad format.
- [ ] **Step 4: Publish/verify app-ads.txt only through the user-authorized domain workflow.** Store the public URL, fetched content checksum/time, and AdMob verification result in evidence; otherwise keep the production gate blocked.
- [ ] **Step 5: Reconcile observed collection/consent/ATT/audience behavior with public policy, Play Data Safety, Apple App Privacy, content rating, and store copy.** ATT denial, when applicable, cannot block contextual/non-personalized eligible behavior allowed by consent; do not claim zero SDK collection if the final SDK discloses data.
- [ ] **Step 6: Run `dart run tool/check_release_config.dart --mode=ads-production --platform=<target>`.** Expected: exit 0 only for a fully authorized production-shaped configuration; source-control scan remains free of production IDs/credentials.
- [ ] **Step 7: Commit tracked policy/register/validator changes only.** `git commit -m "docs: reconcile TintAtlas banner disclosures"`.

### Task 8: Re-run final verification and prepare controlled rollout

**Files:**
- Create: `integration_test/ad_variants_test.dart`
- Modify: `docs/release/verification-ledger.md`
- Modify: `docs/release/rollout-and-rollback.md`
- Modify: `docs/release/ad-qa-matrix.md`
- Create: `docs/release/final-approval-packet.md`

**Interfaces:**
- Consumes: the exact production-shaped configuration, signed artifact, core-candidate evidence, device matrices, consent test geography/device setup, store drafts, and rollout authority.
- Produces: final artifact/version/build/application-ID/signing/checksum evidence, monetization variant evidence, rollout/rollback criteria, and an approval packet; it does not publish.
- Spec coverage: ADS-11 and FINAL-02–05.

- [ ] **Step 1: Write/run the integration variant suite with fakes.** Cover consent required/not required/denied/update error, privacy-option change, SDK init failure, ad loaded/slow/no-fill/invalid/error, network loss/recovery, ATT denied where applicable, background/resume, rotation/resize, route churn, and app restart; every core action remains enabled and no duplicate request occurs.
- [ ] **Step 2: Run the full post-ad automated gate.** `flutter gen-l10n`; format check; `flutter analyze`; all unit/widget/integration/migration/failure/privacy/release-tool tests; ad-free route scan; and content-rights validation. Expected: all exit 0.
- [ ] **Step 3: Build and inspect the signed platform candidate.** Android publication requires release AAB plus manifest/dependency/signature inspection and named Android device gates; iOS publication requires archive/export plus plist/privacy-manifest/signature inspection and named iPhone/iPad gates. Never transfer evidence between platforms.
- [ ] **Step 4: Run real-device ad QA from `ad-qa-matrix.md`.** Exercise every approved/excluded surface, small/large/orientation/split widths, 200% text, bottom navigation, settled result, slow/no-fill/offline, consent regions, privacy-options change, backgrounding, and accidental-click spacing.
- [ ] **Step 5: Run internal → closed → optional open/limited-production stages only when separately authorized.** At each stage review platform crash/ANR, consent/ad errors, migration, task completion, reviews, and rollback triggers; an unresolved P0 halts and rolls back.
- [ ] **Step 6: Obtain an independent read-only review of the exact post-ad candidate.** Resolve every P0/P1 and rerun affected gates; record remaining limitations.
- [ ] **Step 7: Create `final-approval-packet.md`.** Include signed artifact identifiers/checksums, version/build, store copy/screenshots, SDK/plugin lock, app/ad IDs by redacted suffix, placements, consent/audience/privacy declarations, test/device results, known limits, rollout/rollback, and explicit unchecked `Publish authorized` field.
- [ ] **Step 8: Present the packet and stop.** Publication requires a new explicit user authorization; do not infer it from plan approval, AdMob setup, signing, or successful tests.
- [ ] **Step 9: Commit.** `git commit -m "test: verify final TintAtlas banner candidate"`.

## Exit Gate

Only the six allowlisted banner contexts can request an anchored adaptive banner; every private, active, loading, error, consent, editor, and gameplay flow is provably ad-free. Consent and privacy options follow current Google APIs, test/live identifiers cannot cross environments, no-fill/offline/denial never blocks a feature, and responsive/accessibility/privacy/store declarations match the exact signed candidate. A checksummed final approval packet exists, but publication remains stopped until the user explicitly authorizes it.
