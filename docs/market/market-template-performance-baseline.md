# Market Template Performance Baseline

The market is a supporting template. The live pose-analysis path remains the
product priority. A market change is not acceptable when it causes a measurable
regression in camera preparation, pose inference, live feedback, or repetition
tracking.

## Automated lifecycle contract

Run:

```powershell
flutter test test/features/market/presentation/performance/market_resource_lifecycle_test.dart
```

The contract verifies that:

- the bundled preview catalog asset is not read before the Market route opens;
- catalog and category-filter providers are released when the route closes;
- reopening Market creates a fresh catalog/filter scope;
- only the small in-memory cart state survives between Market visits.

These tests protect provider ownership and lazy loading. They do not prove the
absence of runtime jank, network traffic, timers, or retained native resources,
and they do not replace device profiling.

## Device profile procedure

Use the same physical device, build mode, camera position, exercise, and test
sequence for the main baseline and the market-template branch.

```powershell
flutter run --profile
```

Capture three runs for each scenario in Flutter DevTools.

### Scenario A: application start

1. Force-stop the application.
2. Start it from the launcher.
3. Open the home screen.
4. Record first-frame behavior and memory after the screen settles.

### Scenario B: market interaction

1. Open Market from the drawer.
2. Scroll the full two-column catalog twice.
3. Change categories.
4. Open two product-detail screens.
5. Add, increment, decrement, and remove a cart line.
6. Return to the home screen.
7. Trigger garbage collection in DevTools and record retained memory.

### Scenario C: market to live analysis

1. Open Market and add two products.
2. Return to the home screen.
3. Open preparation and start Live Analysis.
4. Complete the same exercise sequence used by the main baseline.
5. Record UI frame times, raster frame times, pose-processing timing, and memory.

## Acceptance gate

The market template passes when all of the following hold:

- catalog scrolling has no sustained jank or repeated frame spikes;
- Market creates no network request, timer, stream subscription, or background
  isolate;
- after leaving Market and collecting garbage, memory does not continue growing
  across repeated Market → Home → Market cycles;
- Live Analysis frame and pose-processing measurements show no repeatable median
  regression greater than 10% across three comparable runs;
- camera preparation, repetition counting, feedback, and session completion
  behave the same as the main baseline;
- no layout, paint, or navigation exception is produced.

A single noisy run is repeated. A consistent regression blocks the market
change, because the application is a movement-analysis product first.

## Build-size check

Compare profile APK sizes without cleaning one branch differently from the
other:

```powershell
flutter build apk --profile
Get-Item build\app\outputs\flutter-apk\app-profile.apk |
  Select-Object Name, Length, LastWriteTime
```

The frozen template uses one small bundled JSON catalog and eight 512 × 512
WebP illustrations totaling less than 50 KB. Images are decoded lazily at the
rendered width, capped at 1024 physical pixels, and are never precached during
application startup or live movement analysis. Run
`tool/market_template_profile.ps1` to capture the profile APK and asset figures.
