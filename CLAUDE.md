# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter app (Android / iOS / Web) that shows a single eBay seller's active listings as cards/table with filters and live auction countdowns. README.md is in Spanish and has more product detail.

## Commands

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # regenerate lib/core/models/listing.g.dart (Hive adapter) after editing listing.dart
flutter analyze                       # lints: flutter_lints; android/ios/web/macos/build are excluded
flutter test                          # only test/widget_test.dart exists
flutter test test/widget_test.dart    # single test file
flutter run --release                 # or: flutter run -d chrome --release
flutter run --dart-define=API_URL=http://localhost:PORT/   # point at a different backend
flutter run --dart-define=ODOO_BRIDGE_TOKEN=...             # only if the backend sets ODOO_BRIDGE_TOKEN
flutter build apk --release --split-per-abi
flutter build web --release
```

## Setup requirements

- A `.env` file in the repo root (gitignored, but declared as a Flutter **asset** in pubspec.yaml, so the app fails to build/start without it). It needs only `EBAY_SELLER_USERNAME=...` (the initial store; more can be added in-app from Settings). It is bundled into the build, so never put eBay Client ID/Secret in it.
- The app never talks to eBay directly. It calls our own Go backend (separate repo `ebay_seller_backend`), which holds the OAuth credentials. Default base URL is `https://ebay-back.kaerdos.dev/`, overridable via `--dart-define=API_URL=`. It lives in one place, `AppConfig.apiUrl` (`lib/core/utils/app_config.dart`), used by both API clients and `ImageProxy`.

## Architecture

Feature-first layout: `lib/core` (api, cache, models, utils), `lib/features/listings` (providers, screens, widgets), `lib/shared/theme`.

**Data flow (offline-first)**, spread across `listings_provider.dart`, `cache_service.dart` and `ebay_api_client.dart`:
1. `main()` loads `.env`, then initializes Hive and `CacheService` (a singleton with a `late` init; access it via `CacheService.instance` only after `init()`).
2. `ListingsNotifier` (Riverpod 3 `Notifier`) kicks off `load()` from `build()` via `Future.microtask`. It shows Hive-cached listings immediately, and skips the network if the cache is under 30 min old (`CacheService.cacheTTL`). Otherwise it fetches and rewrites the cache.
3. `EbayApiClient.getAllSellerListings` calls backend `GET /listings`. It fetches page 0 (limit 200), then all remaining pages in parallel using `total`. Ended listings are filtered out client-side.
4. Sorting is always redone locally (`_sortLocally`), because eBay's ordering is unreliable when auctions and Buy It Now are mixed. `changeSort` re-sorts locally first, then refetches.
5. Connectivity errors are detected by **substring matching on `EbayApiException.message`** ("internet" / "timed out") in `_fetchFromApi` to set `isOffline`. If you reword those messages in the API client, update that check.

**Cache keys:** listings are stored in one Hive box under keys `seller_<username>_item_<itemId>`, and per-seller timestamps live in a separate `cache_meta` box. Lookups are prefix scans over box keys.

**Models:** `EbayListing` (`core/models/listing.dart`) is a `HiveObject` with `@HiveField` indices and `typeId: 0`. Never reuse or renumber field indices, or existing on-device caches break. The `.g.dart` file is generated and committed. The `ListingSort` enum maps to Browse API sort values via `browseApiValue`.

**Hive package:** uses `hive_ce` / `hive_ce_flutter` (the maintained fork), not `hive`. Note that `main.dart` and `CacheService.init` both call `Hive.initFlutter()`.

**Images:** all listing images go through `ImageProxy.proxied()`, which routes them via the backend's `/image-proxy?url=` endpoint to avoid browser third-party blocking of eBay's CDN.

**Platform switching:** `core/utils/image_saver.dart` is a conditional export, choosing `image_saver_io.dart` (uses `gal`) or `image_saver_web.dart` (browser download via `package:web`) with `dart.library.js_interop`. Keep the web variant free of `dart:io`, and the io variant free of `package:web`.

**Multi-store:** the user-configured sellers live in `features/stores` (`SellerStore` model, `storesProvider`, settings screen + add/edit dialog). They are persisted in a third Hive box, `stores` (plain `Map`s, no TypeAdapter), with the list under key `list` and the selected username under `selected`. `EBAY_SELLER_USERNAME` in `.env` only *seeds* the first store when the list is empty. `ListingsNotifier.build()` watches the selected username, so switching stores rebuilds it and triggers `load()`; `_fetchFromApi` drops responses for a store that is no longer selected. Renaming or deleting a store calls `CacheService.clearSeller`. The store pills (`listings/widgets/store_pills.dart`) share `SelectablePill` with the heat filter.

**Odoo purchases:** `features/odoo` + `core/api/odoo_api_client.dart`. The backend's `/odoo/*` routes register a figure in Odoo's Purchase module (vendor = the eBay seller, product `EBAY-<legacyItemId>` with the first image, RFQ line at the user's cost); the app never talks to Odoo directly. Items are keyed by `EbayListing.legacyItemId` (the middle part of `itemId` `v1|<id>|0`; a getter, not a Hive field). `odooPurchasesProvider` batch-looks-up the state of all loaded listings whenever the set of item ids changes; `OdooPurchaseButton` (overlaid on each card's image) shows that state and opens `OdooPurchaseSheet`, which re-reads the item, shows the current eBay value and saves the cost (`PUT` creates the RFQ the first time, then only updates the cost). The seller sent to Odoo is the selected store's username. Confirming the RFQ and receiving it happens in Odoo.

**UI state:** besides `listingsProvider` and `storesProvider`, there are `sortProvider` and `heatFilterProvider` (Hot/Warm/Cold), both simple `Notifier`s. Theme tokens (dark theme only) are in `shared/theme/app_theme.dart`.

## Gotchas

- `test/widget_test.dart` pumps `EbaySellerApp` without a `ProviderScope`, and `main()`-time init (dotenv, Hive) doesn't run in tests. It is unlikely to pass as written.
- `ebay_api_client.dart` contains a `TEMP DEBUG` block that logs the raw first item's JSON, guarded by `kDebugMode`.
- Development is centralized on mobile + web. The desktop platform folders were removed from git, though a local `macos/` directory may still exist.
