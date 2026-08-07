# Tur 8 reward goldens

The release goldens are opt-in so a clean checkout is not blocked before the
first baseline is generated on the canonical Flutter toolchain.

Generate/update baselines:

```powershell
flutter test --no-pub --update-goldens --dart-define=RUN_GOLDENS=true `
  test\features\achievements\presentation\screens\achievements_screen_golden_test.dart
```

Verify existing baselines without rewriting them:

```powershell
flutter test --no-pub --dart-define=RUN_GOLDENS=true `
  test\features\achievements\presentation\screens\achievements_screen_golden_test.dart
```

Commit both PNG files after the first approved generation. Goldens run with
animations disabled and a fixed 390x844 logical viewport.
