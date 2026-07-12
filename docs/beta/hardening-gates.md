# PEA Beta Hardening Gates

Bu belge güncel kapı durumudur. `hardening-baseline.md` tarihsel snapshot olarak değiştirilmez.

| Gate | Durum | Kanıt | Sonraki koşul |
| --- | --- | --- | --- |
| G0 Baseline ve freeze | PASSED | `docs/beta/hardening-baseline.md`, support matrisi ve feature-freeze kontratı | Korunmalı |
| G1 Security CI | PASSED | Merge `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d`; main run `29186161518`; Java 21, Node 22, Firebase CLI 15.17.0; 17 passed, 0 skipped | Her main run'da korunmalı |
| G2 Measurement contract | PASSED | PR #8, merge `2f760e523ffe598817edad932e13e7b731caaa47` | Korunmalı |
| G3 Testable runtime | IN_PROGRESS | WorkoutController metrics-processing seam ve diagnostics controller testleri | Production-yol rep, occlusion ve lifecycle integration testleri |
| G4 Observability | IN_PROGRESS | Beta Diagnostics v0 accumulator ve controller event entegrasyonu; debug/profile diagnostics paneli, canlı snapshot ve privacy-minimized JSON clipboard export; profile artifact commit SHA injection testi ve manuel build workflow kontratı | Main workflow run artifact'inin indirilmesi ve cihazda SHA eşleşmesinin doğrulanması |
| G5 Reproducible beta build | IN_PROGRESS | Manuel profile APK workflow'u, Flutter 3.41.2 ve Java 17 pin'i, APK signature verification, SHA-256 ve build metadata | Workflow main üzerinde çalıştırılmalı; artifact indirilmeli; checksum, signature ve diagnostics SHA eşleşmesi doğrulanmalı |
| G6 Device baseline | NOT_STARTED | G2-G5 ön koşulları açık değil | Ön koşullar sonrası E0 |
| G7 Data evaluation | BLOCKED | Gerçek cihaz dataset'i yok | G6 sonrası E1 değerlendirmesi |
| G8 Runtime regression | BLOCKED | Dataset temelli onaylı değişiklik yok | G7 sonrası ayrı runtime PR'ı |
| G9 Final beta release | BLOCKED | Önceki kapılar açık değil | En son release kararı |

## Durum Sözleşmesi

Yalnız `PASSED`, `IN_PROGRESS`, `BLOCKED`, `NOT_STARTED` ve `FAILED` kullanılır. Bir gate kanıt tamamlanmadan `PASSED` yapılamaz. `NOT_MEASURABLE` test sonucu gate başarısı değildir.

## Güncel Program Gerçeği

- Desteklenen analiz egzersizleri Squat, Plank ve Push-up'tır.
- Security CI main üzerinde başarılıdır; rules testleri skip edilmeden çalışır.
- Controller integration, telemetry, tekrarlanabilir beta build ve gerçek cihaz baseline'ı tamamlanmamıştır.
- G2 belgeleri runtime davranışını değiştirmez; G3 sonraki minimum güvenli uygulama kapısıdır.
