# PEA Beta Hardening Gates

Bu belge güncel kapı durumudur. `hardening-baseline.md` tarihsel snapshot olarak değiştirilmez.

> **Kapsam ayrımı:** Aşağıdaki G0-G8 kanıtları, tarihsel beta hardening programında cihaz üzerinde doğrulanan Squat, Push-up ve Plank kapsamına aittir. Güncel `ExerciseCatalog` 18 hareket içerir. Diğer 15 hareket bu tarihsel cihaz kanıtını otomatik olarak devralmaz. Güncel exercise reliability baseline: `docs/beta/exercise-reliability-baseline.md`.

| Gate | Durum | Kanıt | Sonraki koşul |
| --- | --- | --- | --- |
| G0 Baseline ve freeze | PASSED | `docs/beta/hardening-baseline.md`, support matrisi ve feature-freeze kontratı | Tarihsel baseline korunmalı |
| G1 Security CI | PASSED | Merge `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d`; main run `29186161518`; Java 21, Node 22, Firebase CLI 15.17.0; 17 passed, 0 skipped | Her main run'da korunmalı |
| G2 Measurement contract | PASSED | PR #8, merge `2f760e523ffe598817edad932e13e7b731caaa47`; v1 kapsamı Squat, Plank, Push-up | Tarihsel contract kapsamı korunmalı; yeni egzersizler ayrı kanıt gerektirir |
| G3 Testable runtime | PASSED | Task 06A merge `da6431a3048278c419c917e527c74fb5ed4216e9`; Task 06B PR #15 merge `98b56a6b55badb797f3e0becd52341e973171145`; implementation, automated tests, CI ve real-device verification PASSED; issue #16 completed | Regression testleriyle korunmalı |
| G4 Observability | PASSED | Beta Diagnostics v0, debug/profile diagnostics paneli, privacy-minimized JSON export ve profile artifact commit SHA injection doğrulandı; cihaz diagnostics SHA değeri build metadata ile eşleşti | Yeni egzersiz cihaz kayıtlarında aynı kanıt standardı kullanılmalı |
| G5 Reproducible beta build | PASSED | Android profile artifact workflow'u `main` üzerinde başarılı; artifact indirildi; SHA-256 checksum, APK signature, cihaz kurulumu ve diagnostics/build metadata SHA eşleşmesi doğrulandı | Aynı workflow ve metadata kontratıyla korunmalı |
| G6 Device baseline | PASSED | Tek cihazda Squat, Push-up ve Plank için pozitif, negatif, occlusion, lifecycle/form-break ve persistence davranışları doğrulandı; diagnostics performans sınırları geçti; issue #19 completed | Bu PASS yalnız kanıtlanan üç egzersiz ve tek-cihaz engineering kapsamı için geçerlidir |
| G7 Data evaluation | PASSED | Tek cihaz E0 diagnostics dataset'inde Squat, Push-up ve Plank count/hold sonuçları, statik negatifler, occlusion/lifecycle davranışları, analysis FPS ve p95 sınırları değerlendirildi; genel runtime veya persistence red-line bulunmadı | Yeni egzersizler için ayrı dataset değerlendirmesi yapılmalı |
| G8 Runtime regression | PASSED | Plank visibility loss posture grace'den ayrıldı; 1200 ms freeze penceresi eklendi; PR #22 merge `1800ae63df45fa7abe16477ac9857c2f6bdcd261`; Flutter CI run #50 ve real-device 1 saniyelik visibility-gap smoke check PASSED | Kanıtlanan davranış regression testleriyle korunmalı |
| G9 Final beta release | IN_PROGRESS | G0-G8 mevcut tek cihaz mühendislik beta kapsamı için tamamlandı; çoklu cihaz genellemesi ve sonradan eklenen egzersizlerin eşdeğer cihaz kanıtı açık risk | Nihai beta kapsam, paketleme ve release kararı |

## Durum Sözleşmesi

Yalnız `PASSED`, `IN_PROGRESS`, `BLOCKED`, `NOT_STARTED` ve `FAILED` kullanılır. Bir gate kanıt tamamlanmadan `PASSED` yapılamaz. `NOT_MEASURABLE` test sonucu gate başarısı değildir.

Bir gate'in `PASSED` olması yalnız gate satırında ve bağlı kanıtta tanımlanan kapsam için geçerlidir. Yeni egzersiz, yeni cihaz sınıfı veya yeni engine semantiği eski PASS sonucunu otomatik olarak devralmaz.

## Güncel Program Gerçeği

### Güncel ürün / catalog kapsamı

`ExerciseCatalog` bugün şu hareketleri canlı analiz için destekler:

- Squat: `rangeRep`, selected-side
- Plank: `hold`, plank family
- Hollow Hold: `hold`, hollow-hold family
- Stationary Lunge: `rangeRep`, selected-side
- Push-up: `rangeRep`, selected-side
- Sit-up: `rangeRep`, selected-side
- Biceps Curl: `rangeRep`, bilateral
- Lying Leg Raise: `rangeRep`, selected-side
- Bench Dip: `rangeRep`, selected-side
- Romanian Deadlift: `rangeRep`, selected-side
- Lateral Raise: `rangeRep`, bilateral, increasing-to-peak
- Shoulder Press: `rangeRep`, bilateral, increasing-to-peak
- Calf Raise: `rangeRep`, selected-side, increasing-to-peak
- Front Raise: `rangeRep`, selected-side, increasing-to-peak
- Glute Bridge: `rangeRep`, selected-side, increasing-to-peak
- Wall Sit: `hold`, wall-sit family
- Side Plank: `hold`, side-plank family
- Jumping Jack: `rangeRep`, bilateral, increasing-to-peak

Güncel 18 hareketin tamamı catalog içinde supported durumdadır; bu destek tarihsel G6/G7 cihaz PASS kapsamını genişletmez.

### Tarihsel beta hardening kanıt kapsamı

G0-G8 programında gerçek cihaz baseline ve dataset değerlendirmesi aşağıdaki hareketler için üretildi:

- Squat
- Push-up
- Plank

Hollow Hold, Stationary Lunge, Sit-up, Biceps Curl, Lying Leg Raise, Bench Dip, Romanian Deadlift, Lateral Raise, Shoulder Press, Calf Raise, Front Raise, Glute Bridge, Wall Sit, Side Plank ve Jumping Jack tarihsel üçlü kapsamın dışında kalır. Bu hareketlerin catalog desteği vardır; ancak bu belge içindeki eski G6/G7 cihaz PASS sonucu onlar için otomatik acceptance kanıtı değildir.

### Altyapı durumu

- Security CI main üzerinde başarılıdır; rules testleri skip edilmeden çalışır.
- Controller production-path testleri, neutral arming, pose-quality, brief occlusion ve hold lifecycle hardening tamamlanmıştır.
- Kamera analiz güvenilirliği tarihsel beta kapsamı için tamamlanmış kabul edilir.
- Telemetry artifact doğrulaması ve tekrarlanabilir beta build kanıtı tamamlanmıştır.
- Tek cihaz mühendislik baseline'ı ve dataset değerlendirmesi Squat, Push-up ve Plank için tamamlanmıştır.
- Low/Mid/High çoklu cihaz kapsamı doğrulanmamıştır ve beta genellemesi için ertelenmiş risk olarak kalır.
- Sonradan etkinleştirilen egzersizlerin gerçek cihaz kabulü exercise-specific kanıtla izlenmelidir.
- Plank posture break grace'i 300 ms olarak kalır; visibility loss için ayrı 1200 ms freeze penceresi vardır. Gizli süre hold toplamına eklenmez; 1200 ms ve üzeri kayıp aktif hold'u sonlandırır ve `bestHoldSeconds` değerini korur.

## Device Finding: Range-rep neutral arming / reacquisition gate

- Finding: Range-rep session PEAK pozisyonunda başlatıldığında neutral geri dönüş tek başına rep sayılabiliyordu.
- Fix: Range-rep neutral arming/reacquisition gate.
- Durum:
  - Implementation: PASSED
  - Automated tests: PASSED
  - CI: PASSED
  - Manual USB device verification: PASSED
  - Kanıt: merge `da6431a3048278c419c917e527c74fb5ed4216e9`

Required device verification:

- PEAK start -> rise -> 0 rep
- neutral acquisition -> full rep -> 1 rep
- PEAK resync -> rise -> 0 rep
- pause/resume PEAK -> rise -> 0 rep

Bu kanıt tarihsel olarak Squat/Push-up beta kapsamındaki range-rep davranışını doğrular. Sonradan eklenen range-rep egzersizlerde contract ve metric semantiği ayrıca test edilmelidir.

## Device Finding: Task 06B pose-quality ve brief occlusion

- Finding: Low-resolution detector output can contain false-positive poses.
- Finding: The previous 450 ms / 4-frame visibility resync was too aggressive for a roughly 1-second brief occlusion.
- Fix: Exercise-aware pose-quality rejection, temporal acceptance stabilization, 1500 ms brief-occlusion recovery, side-specific quality binding ve hold lifecycle/visibility handling.
- Durum:
  - Implementation: PASSED
  - Automated tests: PASSED
  - CI: PASSED
  - Real-device verification: PASSED for current historical beta scope
  - Known limitation follow-up: issue #16 completed without threshold changes because no false rep, hold total, session total or persisted result corruption was observed
  - Kanıt: PR #15, merge `98b56a6b55badb797f3e0becd52341e973171145`

Bu finding'in cihaz kanıtı da o tarihteki destek matrisiyle sınırlıdır. Yeni hold family veya bilateral range-rep davranışı için eşdeğer cihaz kanıtı ayrı değerlendirilmelidir.
