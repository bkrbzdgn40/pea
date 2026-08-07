# Tur 8 release assurance

This gate finalizes the reward/achievement experience without changing the V1
reward contracts.

## Visual contract

- Reward marks are vector-rendered in Flutter; no external bitmap assets are
  required.
- Bronze, silver and gold keep the V1 reward colors.
- Achievement badges use the existing achievement-category accents.
- Entry/reveal and progress animations obey reduced-motion accessibility
  settings and resolve to zero duration when animations are disabled.
- The production app is intentionally dark-first and explicitly runs with
  `ThemeMode.dark`.

## Accessibility and layout gate

- Reward marks expose one concise image semantic instead of leaking internal
  icon semantics.
- View and history filter controls expose button + selected semantics and keep
  the 48 logical-pixel minimum touch target.
- Achievement and reward-history screens are exercised across the shared
  presentation matrix, including 320x568 and 2x text.
- Reward-history cards switch to a stacked layout when text or available width
  makes the horizontal layout unsafe.

## Golden gate

Goldens are opt-in until the canonical Flutter installation generates the first
approved baselines. Use `tool/tur8_release_gate.ps1 -UpdateGoldens`, inspect the
two generated PNG files, then commit them. Subsequent runs verify without
rewriting the baseline.

## Emulator gate

`test/firestore_rules_test.dart` contains a release-flow contract covering a
trusted session through contribution, activity day, achievement event, medal
reward and achievement reward on the Firebase Auth + Firestore emulators.

## Legacy compatibility

- Pre-evidence session documents continue to decode using the historical field
  names and remain `unknown` evidence instead of being promoted to trusted.
- Mid-rollout sessions with trusted evidence but no captured timezone remain
  eligible for the approved backfillable achievements.
- Period medals are still not invented for sessions without a captured timezone.
- Existing earned reward documents remain immutable and are not recomputed away.
