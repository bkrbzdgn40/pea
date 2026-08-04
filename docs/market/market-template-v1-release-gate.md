# Market Template v1 Release Gate

Market Template v1 is a supporting demonstration inside the movement-analysis
application. It is not a production commerce system.

## Frozen scope

- drawer destination and responsive two-column catalog
- bundled, versioned JSON preview catalog
- eight optimized local WebP illustrations
- product detail flow
- in-memory cart with quantity and subtotal calculations
- checkout/order-summary template with payment disabled
- Turkish and English presentation copy
- loading, error, retry, empty, compact-screen, accessibility, and provider-lifecycle coverage

## Explicit non-goals

- remote catalog or product administration
- Firebase reads or writes for market data
- account, address, stock, variant, coupon, shipping, tax, payment, or order logic
- background listeners, timers, isolates, or image prefetching
- any dependency on camera, ML Kit, or workout-analysis implementation code

## Automated gate

```powershell
flutter test test/features/market
dart analyze
```

The market architecture test blocks camera, pose, Firebase, and workout imports.
The visual-budget test limits the eight WebP assets to 300 KB each and 2 MB in
total. Accessibility tests verify meaningful product-specific semantics and
48 × 48 logical-pixel interaction targets.

## Profile snapshot

Run on the market-template branch:

```powershell
.\tool\market_template_profile.ps1 -RunFullTests -LaunchProfile
```

The script builds a profile APK and records build/asset figures in:

```text
performance_logs/market_template_profile_snapshot.json
```

Fill the device fields after three comparable runs for the main baseline and
market branch. A repeatable median regression above 10% in live UI frames,
raster frames, or pose processing blocks integration.

## Manual smoke sequence

1. Open Market and scroll the complete catalog.
2. Change every category filter.
3. Open a product detail and add the same product twice.
4. Change quantities, remove a line, and inspect the subtotal.
5. Open checkout and verify payment remains disabled.
6. Return to Home and start Live Analysis.
7. Complete the standard exercise smoke sequence.
8. Confirm camera preparation, feedback, repetition count, and session completion remain unchanged.

## Integration decision

Merge only after the current main branch and market branch both pass their full
test suites. Integration must carry market feature commits, tests, assets, and
documentation while preserving the main application's package identity and
Firebase configuration.
