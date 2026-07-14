# PEA Beta Hardening Gates

Bu belge guncel kapi durumudur. `hardening-baseline.md` tarihsel snapshot olarak degistirilmez.

| Gate | Durum | Kanit | Sonraki kosul |
| --- | --- | --- | --- |
| G0 Baseline ve freeze | PASSED | `docs/beta/hardening-baseline.md`, support matrisi ve feature-freeze kontrati | Korunmali |
| G1 Security CI | PASSED | Merge `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d`; main run `29186161518`; Java 21, Node 22, Firebase CLI 15.17.0; 17 passed, 0 skipped | Her main run'da korunmali |
| G2 Measurement contract | PASSED | PR #8, merge `2f760e523ffe598817edad932e13e7b731caaa47` | Korunmali |
| G3 Testable runtime | PASSED | Task 06A merge `da6431a3048278c419c917e527c74fb5ed4216e9`; Task 06B PR #15 merge `98b56a6b55badb797f3e0becd52341e973171145`; implementation, automated tests, CI ve real-device verification PASSED; issue #16 completed | Regression testleriyle korunmali |
| G4 Observability | PASSED | Beta Diagnostics v0, debug/profile diagnostics paneli, privacy-minimized JSON export ve profile artifact commit SHA injection dogrulandi; cihaz diagnostics SHA degeri build metadata ile eslesti | E0 cihaz kayitlarinda kanit standardi korunmali |
| G5 Reproducible beta build | PASSED | Android profile artifact workflow'u `main` uzerinde basarili; artifact indirildi; SHA-256 checksum, APK signature, cihaz kurulumu ve diagnostics/build metadata SHA eslesmesi dogrulandi | Ayni workflow ve metadata kontratiyla korunmali |
| G6 Device baseline | PASSED | Tek cihazda Squat, Push-up ve Plank icin pozitif, negatif, occlusion, lifecycle/form-break ve persistence davranislari dogrulandi; diagnostics performans sinirlari gecti; issue #19 completed | Coklu cihaz kapsami beta iddiasi icin ertelenmis risk olarak tutulmali |
| G7 Data evaluation | PASSED | Tek cihaz E0 diagnostics dataset'inde count/hold sonuclari, statik negatifler, occlusion/lifecycle davranislari, analysis FPS ve p95 sinirlari degerlendirildi; genel runtime veya persistence red-line bulunmadi | Kanitli bulgular disinda runtime degisikligi yapilmamali |
| G8 Runtime regression | PASSED | Plank visibility loss posture grace'den ayrildi; 1200 ms freeze penceresi eklendi; PR #22 merge `1800ae63df45fa7abe16477ac9857c2f6bdcd261`; Flutter CI run #50 ve real-device 1 saniyelik visibility-gap smoke check PASSED | G9 final beta karari |
| G9 Final beta release | IN_PROGRESS | G0-G8 mevcut tek cihaz muhendislik beta kapsami icin tamamlandi; coklu cihaz genellemesi ertelenmis risk | Son beta kapsam, paketleme ve release karari |

## Durum Sozlesmesi

Yalniz `PASSED`, `IN_PROGRESS`, `BLOCKED`, `NOT_STARTED` ve `FAILED` kullanilir. Bir gate kanit tamamlanmadan `PASSED` yapilamaz. `NOT_MEASURABLE` test sonucu gate basarisi degildir.

## Guncel Program Gercegi

- Desteklenen analiz egzersizleri Squat, Plank ve Push-up'tir.
- Security CI main uzerinde basarilidir; rules testleri skip edilmeden calisir.
- Controller production-path testleri, neutral arming, pose-quality, brief occlusion ve hold lifecycle hardening tamamlanmistir.
- Kamera analiz guvenilirligi mevcut beta kapsami icin tamamlanmis kabul edilir.
- Telemetry artifact dogrulamasi ve tekrarlanabilir beta build kaniti tamamlanmistir.
- Tek cihaz muhendislik baseline'i ve dataset degerlendirmesi tamamlanmistir.
- Low/Mid/High coklu cihaz kapsami dogrulanmamistir ve beta genellemesi icin ertelenmis risk olarak kalir.
- Plank posture break grace'i 300 ms olarak kalir; visibility loss icin ayri 1200 ms freeze penceresi vardir. Gizli sure hold toplamına eklenmez; 1200 ms ve uzeri kayip aktif hold'u sonlandirir ve `bestHoldSeconds` degerini korur.

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
