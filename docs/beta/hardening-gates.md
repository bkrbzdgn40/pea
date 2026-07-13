# PEA Beta Hardening Gates

Bu belge guncel kapi durumudur. `hardening-baseline.md` tarihsel snapshot olarak degistirilmez.

| Gate | Durum | Kanit | Sonraki kosul |
| --- | --- | --- | --- |
| G0 Baseline ve freeze | PASSED | `docs/beta/hardening-baseline.md`, support matrisi ve feature-freeze kontrati | Korunmali |
| G1 Security CI | PASSED | Merge `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d`; main run `29186161518`; Java 21, Node 22, Firebase CLI 15.17.0; 17 passed, 0 skipped | Her main run'da korunmali |
| G2 Measurement contract | PASSED | PR #8, merge `2f760e523ffe598817edad932e13e7b731caaa47` | Korunmali |
| G3 Testable runtime | IN_PROGRESS | WorkoutController metrics-processing seam ve diagnostics controller testleri; range-rep neutral arming/reacquisition gate implementasyonu tamamlandi | Runtime yolunda cihaz yeniden dogrulamasi ve occlusion/lifecycle senaryolari |
| G4 Observability | IN_PROGRESS | Beta Diagnostics v0 accumulator ve controller event entegrasyonu; debug/profile diagnostics paneli, canli snapshot ve privacy-minimized JSON clipboard export; profile artifact commit SHA injection testi ve manuel build workflow kontrati | Main workflow run artifact'inin indirilmesi ve cihazda SHA eslesmesinin dogrulanmasi |
| G5 Reproducible beta build | IN_PROGRESS | Manuel profile APK workflow'u, Flutter 3.41.2 ve Java 17 pin'i, APK signature verification, SHA-256 ve build metadata | Workflow main uzerinde calistirilmali; artifact indirilmeli; checksum, signature ve diagnostics SHA eslesmesi dogrulanmali |
| G6 Device baseline | NOT_STARTED | G2-G5 on kosullari acik degil; range-rep neutral arming fix'i icin cihaz yeniden dogrulamasi bekleniyor | On kosullar sonrasi E0 |
| G7 Data evaluation | BLOCKED | Gercek cihaz dataset'i yok | G6 sonrasi E1 degerlendirmesi |
| G8 Runtime regression | BLOCKED | Dataset temelli onayli degisiklik yok | G7 sonrasi ayri runtime PR'i |
| G9 Final beta release | BLOCKED | Onceki kapilar acik degil | En son release karari |

## Durum Sozlesmesi

Yalniz `PASSED`, `IN_PROGRESS`, `BLOCKED`, `NOT_STARTED` ve `FAILED` kullanilir. Bir gate kanit tamamlanmadan `PASSED` yapilamaz. `NOT_MEASURABLE` test sonucu gate basarisi degildir.

## Guncel Program Gercegi

- Desteklenen analiz egzersizleri Squat, Plank ve Push-up'tir.
- Security CI main uzerinde basarilidir; rules testleri skip edilmeden calisir.
- Controller integration, telemetry, tekrarlanabilir beta build ve gercek cihaz baseline'i tamamlanmamistir.
- G2 belgeleri runtime davranisini degistirmez; G3 sonraki minimum guvenli uygulama kapisidir.

## Device Finding: Range-rep neutral arming / reacquisition gate

- Finding: Range-rep session PEAK pozisyonunda baslatildiginda neutral geri donus tek basina rep sayilabiliyordu.
- Fix: Range-rep neutral arming/reacquisition gate.
- Durum: implementation complete; device re-verification pending.

Required device verification:

- PEAK start -> rise -> 0 rep
- neutral acquisition -> full rep -> 1 rep
- PEAK resync -> rise -> 0 rep
- pause/resume PEAK -> rise -> 0 rep

Separate follow-up:

- Pose detector confidence ve false-positive pose rejection isi ayri Task 06B kapsaminda kalir.
