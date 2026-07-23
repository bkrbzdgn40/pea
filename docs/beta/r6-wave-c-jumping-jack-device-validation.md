# R6 Wave C - Jumping Jack Device Validation

Bu protokol R6 Dalga C kapsamında `Jumping Jack` exercise-specific gerçek cihaz validation'ını tanımlar.

Jumping Jack yüksek temporal hareket ve bilateral koordinasyon riski taşıdığı için validation yalnız toplam sayıya bakmaz; arm-driven lifecycle ile leg/synchronization form sinyalinin birlikte davranışı ayrıca gözlenir.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Jumping Jack:

```text
tracking = repetitions
engine = rangeRep
sideMode = bilateral
primaryMetricDirection = increasingToPeak
camera = front preferred
side = unsupported
towardPeakMuscleAction = concentric
```

Primary metric, her tarafta:

```text
elbow -> shoulder -> hip
```

açısıdır.

Increasing-to-peak bilateral aggregation, lifecycle için iki kolun birlikte ilerlemesini konservatif biçimde temsil eder; düşük kalan taraf bilateral primary metric'i sınırlar.

Form / coordination metriği, configured `postureAngle` üzerinden her tarafta:

```text
knee -> hip -> oppositeHip
```

açısını izler.

Bilateral form aggregation ayrıca iki kolun primary metric senkronizasyonunu içerir. Form metriği pratikte sol bacak açılımı, sağ bacak açılımı ve iki kol arasındaki senkronizasyonun zayıf halkasını temsil eder.

Contract signal rolleri:

```text
primaryMetric = detection + validation + scoring
formMetric = validation + technique
postureAngle = technique
depthMetric = scoring
```

Pose acceptance için `primaryMetric` ve `formMetric` zorunludur. Front-view kadrajda iki kolun ve iki bacağın net görünmesi kritik setup gereksinimidir.

## 2. Config ve Validation Eşikleri

Production config:

```text
thresholdNeutral = 20°
thresholdActive = 55°
thresholdPeak = 135°

formThreshold = 105°
targetMinAngle = 0°
targetMaxAngle = 165°

idealDescentSeconds = 0.6
idealAscentSeconds = 0.6
```

Shared generic default `peakEntryMargin = 3°` olduğu için increasing-to-peak strict peak entry yaklaşık `primaryMetric > 138°` koşuluna karşılık gelir.

Completed-rep validation:

```text
minAcceptableRomDelta = 80°
minDescentMillis = 150
minAscentMillis = 150
allowLowConfidenceOnCoverageLoss = true
```

Threshold'lar tek kullanıcı veya tek video nedeniyle değiştirilmez.

## 3. Önemli Semantik Risk

Exercise guide açıkça iki kolun birlikte yükselmesini primary repetition signal, bacakların yana açılmasını ise supporting form signal olarak tanımlar.

Mevcut generic completed-rep validator'da persistent form break rep'i otomatik invalid yapmak yerine low-confidence sınıfına taşıyabilir. Bu nedenle yalnız kollarla yapılan tam arm cycle'ın kullanıcıya görünen rep sayısını artırıp artırmadığı gerçek cihazda özellikle test edilmelidir.

Arm-only hareket sayılır ve yalnız form warning / low-confidence üretirse bu, Jumping Jack ürün semantiği ile runtime counting contract'ı arasında potansiyel false-positive finding olarak ele alınır.

## 4. Kamera ve Setup

```text
front view
tüm vücut kadrajda
iki omuz, iki dirsek, iki kalça ve iki diz net görünür
ayaklar mümkünse kadraj içinde
başlangıçta ayaklar yakın
kollar yanlarda
```

Side view formal PASS için kullanılmaz.

## 5. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-JJ-PREFLIGHT-1` | Preflight | 1 kontrollü tam Jumping Jack | Tam lifecycle; sayaç 1 artar |
| `R6-JJ-POS-20` | Positive counting | 20 kontrollü tam tekrar | Ground truth ile app count uyumlu; çift/phantom sayım yok |
| `R6-JJ-STATIC-30` | Static negative | Ayaklar yakın, kollar yanda 30 sn sabit | 0 phantom rep |
| `R6-JJ-PARTIAL-10` | Partial ROM | İki kolu orta yüksekliğe kadar kaldır; peak'e gitme | 0 completed rep |
| `R6-JJ-ONE-ARM-10` | Bilateral asymmetry | Tek kol tam, diğer kol belirgin aşağıda | 0 bilateral completed rep |
| `R6-JJ-COORD-10` | Coordination negative | 5 arm-only + 5 leg-only cycle | Displayed count + validation + feedback birlikte incelenir |
| `R6-JJ-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; temiz neutral reacquire |
| `R6-JJ-PERSIST` | Persistence | Ölçülebilir completed rep seti | Live = Summary = History |

`OCC` **SKIPPED - covered by shared reliability validation**.

## 6. İlk Cihaz Adımı

İlk run:

```text
R6-JJ-PREFLIGHT-1
```

1. Kameraya tam önden bak.
2. Tüm vücudu kadraja al.
3. Ayakları yakın, kolları yanlarda tutup 1-2 saniye neutral acquire bekle.
4. Kolları iki tarafta birlikte yukarı kaldırırken bacakları yana aç.
5. Üst noktaya ulaş.
6. Kolları ve bacakları birlikte başlangıca döndür.
7. Neutral'da 1-2 saniye bekle ve diagnostics al.

Beklenen:

```text
rep_count: 0 -> 1
acquireNeutral >= 1
startDescending = 1
reachPeak = 1
startAscending = 1
completeRep = 1

unexpected abort = 0
unexpected resync = 0
```

Diagnostics legacy transition isimleri `startDescending` / `startAscending` olarak kalır; Jumping Jack biomekaniğinde toward-peak hareket açılma/yükselme fazıdır.

## 7. Kritik Negatifler

### PARTIAL-10

İki kol birlikte hareket eder ancak bilateral primary metric gerçek peak bandına ulaşmadan geri dönülür.

Beklenen:

```text
completeRep = 0
rep_count = 0
```

### ONE-ARM-10

Bir kol tam overhead'e giderken diğer kol belirgin biçimde aşağıda tutulur.

Bilateral primary aggregation nedeniyle `reachPeak = 0` ve `rep_count = 0` beklenir.

### COORD-10

İlk 5 cycle:

```text
arms full
legs mostly closed
```

İkinci 5 cycle:

```text
legs open/close
arms mostly down
```

Leg-only hareket primary arm metric'i peak'e taşımamalıdır.

Arm-only hareket lifecycle başlatırsa şu dört şey birlikte kaydedilir:

```text
displayed rep count
validation status
validation reasons
form feedback
```

Arm-only tam rep olarak sayılır ve yalnız `lowConfidence/persistentFormBreak` ile işaretlenirse bu closure öncesi potansiyel false-positive / contract mismatch finding'idir.

## 8. Diagnostics İncelemesi

Özellikle:

```text
app_commit_sha
build_mode
exercise_type
camera_view_contract
range_rep_side_mode
range_rep_primary_metric_direction

rep_count
range_rep_transition_counts
range_rep_abort_count
range_rep_validation_status_counts
range_rep_validation_reason_counts
last_range_rep_validation_reasons

analysis_fps_p50
frame_processing_ms_p95
analysis_exception_count
```

Provisional performans gate'leri:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250 ms
analysis_exception_count = 0
```

Jumping Jack yüksek temporal hareket olduğu için düşük analysis FPS sayım doğruluğunu doğrudan etkileyebilir. Tek run threshold tuning gerekçesi değildir; tekrar eden pattern aranır.

## 9. Closure Kriteri

Jumping Jack closure adayı olmak için en az:

1. controlled positive counting,
2. static phantom-count rejection,
3. partial-ROM rejection,
4. bilateral one-arm rejection,
5. arm/leg coordination semantics'in kabul edilebilir olması veya bulunan mismatch'in harden edilmesi,
6. pause/resume lifecycle,
7. persistence

kanıtı gerekir.

Per-exercise occlusion tekrar edilmez; yalnız Jumping Jack'e özgü visibility failure görülürse yeniden açılır.

Formal protokol sapmaları closure kaydında açıkça tutulur; çalıştırılmayan run PASS yazılmaz.

## 10. Current Validation Status

```text
R6 Validation Blocked / Deferred
Engineering Revalidated = No
```

`R6-JJ-PREFLIGHT-1` gerçek cihaz/video kanıtında geçerli open-close hareketleri bulunmasına rağmen `rep_count = 0`, `reachPeak = 0` ve `abortToNeutral = 2` gözlenmiştir.

Aynı run'da:

```text
analysis_fps_p50 = 4.8077
frame_processing_ms_p95 = 568
reentrant_drop_count = 373
analysis_exception_count = 0
```

Pose rejection, resync ve side-switching ana failure'ı açıklamamıştır.

Ayrıca doğru neutral pozisyonda `Open your legs farther` feedback'inin gösterilmesi phase-semantics finding'i olarak kaydedilmiştir.

Threshold tuning uygulanmamıştır. Güvenli çözüm generic fast-motion lifecycle regression riski, Jumping Jack'e özel temporal acquisition veya analysis-pipeline performance çalışması gerektirebileceği için exercise mevcut validation turunda bilinçli olarak deferred bırakılmıştır.

Kalıcı issue, gerekçe ve reopen acceptance criteria:

```text
docs/beta/r6-wave-c-jumping-jack-results.md
```

Bu hareket PASS veya `R6 Engineering Revalidated` olarak yorumlanmamalıdır.
