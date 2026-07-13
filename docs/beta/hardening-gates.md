# PEA Beta Hardening Gates

Bu belge guncel kapi durumudur. `hardening-baseline.md` tarihsel snapshot olarak degistirilmez.

| Gate | Durum | Kanit | Sonraki kosul |
| --- | --- | --- | --- |
| G0 Baseline ve freeze | PASSED | `docs/beta/hardening-baseline.md`, support matrisi ve feature-freeze kontrati | Korunmali |
| G1 Security CI | PASSED | Merge `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d`; main run `29186161518`; Java 21, Node 22, Firebase CLI 15.17.0; 17 passed, 0 skipped | Her main run'da korunmali |
| G2 Measurement contract | PASSED | PR #8, merge `2f760e523ffe598817edad932e13e7b731caaa47` | Korunmali |
| G3 Testable runtime | PASSED | Task 06A merge `da6431a3048278c419c917e527c74fb5ed4216e9`; Task 06B PR #15 merge `98b56a6b55badb797f3e0becd52341e973171145`; implementation, automated tests, CI ve real-device verification PASSED; issue #16 completed | Regression testleriyle korunmali |
| G4 Observability | IN_PROGRESS | Beta Diagnostics v0 accumulator ve controller event entegrasyonu; debug/profile diagnostics paneli, canli snapshot ve privacy-minimized JSON clipboard export; profile artifact commit SHA injection testi ve manuel build workflow kontrati | Main workflow run artifact'inin indirilmesi ve cihazda SHA eslesmesinin dogrulanmasi |
| G5 Reproducible beta build | IN_PROGRESS | Manuel profile APK workflow'u, Flutter 3.41.2 ve Java 17 pin'i, APK signature verification, SHA-256 ve build metadata | Workflow main uzerinde calistirilmali; artifact indirilmeli; checksum, signature ve diagnostics SHA eslesmesi dogrulanmali |
| G6 Device baseline | NOT_STARTED | Kamera analiz hardening tamamlandi; tam Low/Mid/High cihaz matrisi ve E0 dataset'i henuz tamamlanmadi | G4-G5 tamamlandiktan sonra E0 cihaz matrisi |
| G7 Data evaluation | BLOCKED | Tam gercek cihaz dataset'i yok | G6 sonrasi E1 degerlendirmesi |
| G8 Runtime regression | BLOCKED | Dataset temelli yeni degisiklik yok | G7 sonrasi ayri runtime PR'i |
| G9 Final beta release | BLOCKED | Onceki kapilar acik degil | En son release karari |

## Durum Sozlesmesi

Yalniz `PASSED`, `IN_PROGRESS`, `BLOCKED`, `NOT_STARTED` ve `FAILED` kullanilir. Bir gate kanit tamamlanmadan `PASSED` yapilamaz. `NOT_MEASURABLE` test sonucu gate basarisi degildir.

## Guncel Program Gercegi

- Desteklenen analiz egzersizleri Squat, Plank ve Push-up'tir.
- Security CI main uzerinde basarilidir; rules testleri skip edilmeden calisir.
- Controller production-path testleri, neutral arming, pose-quality, brief occlusion ve hold lifecycle hardening tamamlanmistir.
- Kamera analiz guvenilirligi mevcut beta kapsami icin tamamlanmis kabul edilir.
- Telemetry artifact dogrulamasi, tekrarlanabilir beta build kaniti ve tam cihaz baseline'i tamamlanmamistir.

## Device Finding: Range-rep neutral arming / reacquisition gate

- Finding: Range-rep session PEAK pozisyonunda baslatildiginda neutral geri donus tek basina rep sayilabiliyordu.
- Fix: Range-rep neutral arming/reacquisition gate.
- Durum:
  - Implementation: PASSED
  - Automated tests: PASSED
  - CI: PASSED
  - Manual USB device verification: PASSED
  - Kanit: merge `da6431a3048278c419c917e527c74fb5ed4216e9`

Required device verification:

- PEAK start -> rise -> 0 rep
- neutral acquisition -> full rep -> 1 rep
- PEAK resync -> rise -> 0 rep
- pause/resume PEAK -> rise -> 0 rep

## Device Finding: Task 06B pose-quality ve brief occlusion

- Finding: Low-resolution detector output can contain false-positive poses.
- Finding: The previous 450 ms / 4-frame visibility resync was too aggressive for a roughly 1-second brief occlusion.
- Fix: Exercise-aware pose-quality rejection, temporal acceptance stabilization, 1500 ms brief-occlusion recovery, side-specific quality binding ve hold lifecycle/visibility handling.
- Durum:
  - Implementation: PASSED
  - Automated tests: PASSED
  - CI: PASSED
  - Real-device verification: PASSED for current beta scope
  - Known limitation follow-up: issue #16 completed without threshold changes because no false rep, hold total, session total or persisted result corruption was observed
  - Kanit: PR #15, merge `98b56a6b55badb797f3e0becd52341e973171145`
