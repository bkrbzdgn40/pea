# R6 Wave C - Glute Bridge Device Validation

Bu protokol R6 Dalga C kapsamında `Glute Bridge` exercise-specific gerçek cihaz validation'ını tanımlar.

Jumping Jack, Sit-up ve Bench Dip blocker bulguları nedeniyle `R6 Validation Blocked / Deferred` durumunda tutulur. Aktif validation sırası Glute Bridge ile devam eder.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Glute Bridge:

```text
tracking = repetitions
engine = rangeRep
sideMode = selectedSide
primaryMetricDirection = increasingToPeak
primaryMetricKind = jointAngle
camera = side preferred
front = unsupported
towardPeakMuscleAction = concentric
```

Primary metric selected tarafta:

```text
shoulder -> hip -> knee
```

Kalça yerde neutral pozisyonda açı daha düşük, kalça yükselip omuz-kalça-diz hattı açıldıkça primary metric artar.

Setup signal:

```text
hip -> knee -> ankle
```

Production contract'ta `formMetric` ve `postureAngle` setup rolündedir; technique veya completed-rep validation gate'i değildir.

Pose acceptance yalnız:

```text
primaryMetric
```

sinyalini zorunlu tutar.

Bu nedenle ankle/setup metriğinin geçici kaybı primary counting'i tek başına bloklamamalıdır.

## 2. Config ve Lifecycle Eşikleri

Production config:

```text
thresholdNeutral = 135°
thresholdActive = 145°
thresholdPeak = 155°

idealTowardPeakSeconds = 1.0
idealReturnSeconds = 1.2

targetMaxAngle = 170°
```

Primary direction `increasingToPeak` olduğundan lifecycle kapıları fiilen:

```text
strict neutral acquisition = primaryMetric < 135°
effective active entry     = primaryMetric > 148°
strict peak acquisition    = primaryMetric > 158°
```

şeklindedir. Böylece resimdeki hips-down başlangıç pozisyonunun yaklaşık `125°` shoulder-hip-knee geometrisi neutral kabul edilirken, hareketin başlaması için yaklaşık `13°` ek açılma gerekir.

Önceki `105°` strict neutral kapısı, doğru sırtüstü ve dizler bükülü başlangıç pozisyonunu active aralığın içinde bıraktığı için `awaitNeutral` durumundan çıkamıyordu. Bu hardening yalnız Glute Bridge config ve ona bağlı ROM-delta validation kalibrasyonunu değiştirir; generic lifecycle'a dokunmaz.

## 3. Completed-Rep Validation

Production validation config:

```text
minAcceptableRomDelta = 10°
minDescentMillis = 300
minAscentMillis = 300
allowLowConfidenceOnCoverageLoss = true
```

`minAcceptableRomDelta`, confirmed active-phase başlangıcından observed peak'e ölçülen conservative ROM consistency guard'dır; klinik veya rehabilitasyon cut-off'u değildir. Active gate `>148°`, peak gate `>158°` olacak şekilde yeniden kalibre edildiği için validation floor da bu yaklaşık `10°` lifecycle bandıyla hizalanmıştır. Peak gate değişmediğinden sığ hip raise hareketleri completed lifecycle üretmemeye devam eder.

Ideal positive path:

```text
neutral
-> toward peak / hip rise
-> peak
-> return
-> neutral
```

olarak tamamlanır.

## 4. Form / Setup Semantiği

Glute Bridge production feedback seti movement-only'dir.

Contract:

```text
formMetric = setup
postureAngle = setup
```

olarak tanımlıdır.

Bu nedenle validation sırasında:

- diz bükümü / ayak yerleşimi setup robustness olarak gözlenir,
- generic `formViolation` feedback'inin biomekanik teknik koçluğu yaptığı varsayılmaz,
- setup sinyali counting validity ile karıştırılmaz.

Bel aşırı ekstansiyonu gibi gerçek teknik hatalar mevcut primary contract tarafından doğrudan ölçülüyor kabul edilmez.

Closure, kapsam dışı form doğruluğu iddiası içermez.

## 5. Kamera ve Setup

Formal setup:

```text
side view
user supine
knees bent
feet planted on floor
shoulder, hip and knee clearly visible
ankle visible when possible for setup signal
```

Başlangıç:

```text
hips lowered in neutral
feet stable
shoulders remain on floor
```

Hareket:

```text
drive hips upward
reach a controlled shoulder-hip-knee open line
avoid forcing lumbar overextension
return under control
```

Front view formal PASS için kullanılmaz.

## 6. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-GB-PREFLIGHT-1` | Preflight | Side view; neutral -> controlled bridge top -> neutral | Bir temiz lifecycle; sayaç 1 artar; beklenmeyen abort/resync yok |
| `R6-GB-POS-20` | Positive counting | 20 kontrollü tam Glute Bridge | Count ground truth ile uyumlu; phantom/double count yok |
| `R6-GB-STATIC-30` | Static negative | Kalça yerde neutral başlangıçta 30 sn sabit kal | 0 phantom rep |
| `R6-GB-PARTIAL-10` | Partial ROM | 10 sığ hip raise; gerçek peak'e ulaşmadan geri dön | 0 completed rep veya açık insufficient-ROM validation; ideal beklenti peak öncesi abort |
| `R6-GB-SETUP-5` | Setup robustness | Makul diz bükümü / ayak mesafesi varyasyonuyla 5 kontrollü tam tekrar | Primary shoulder-hip-knee counting çalışır; setup sinyali gereksiz blocking yaratmaz |
| `R6-GB-SIDE-2x5` | Selected-side robustness | Kamera-near fiziksel tarafı değiştirerek ayrı 5'er tam tekrar | İki fiziksel tarafta counting çalışır; active rep sırasında gereksiz side-switch/resync yok |
| `R6-GB-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; resume sonrası temiz neutral reacquire |
| `R6-GB-PERSIST` | Persistence | Ölçülebilir completed-rep setiyle session bitir | Live, Summary ve History rep sayısı aynı |

`OCC` **SKIPPED - covered by shared reliability validation**.

Exercise-specific visibility failure görülürse yeniden açılır.

## 7. İlk Cihaz Adımı

İlk run:

```text
R6-GB-PREFLIGHT-1
```

Uygulama:

1. Kamerayı side view yerleştir.
2. Sırt üstü uzan; dizleri bük ve ayakları yere sabitle.
3. Omuz-kalça-diz hattını net biçimde kadraja al.
4. Kalça yerde neutral pozisyonda 1-2 saniye bekle.
5. Kalçayı kontrollü biçimde kaldır.
6. Omuz-kalça-diz hattını doğal biçimde aç; belini zorla aşırı yaylandırma.
7. Kontrollü biçimde neutral pozisyona dön.
8. Neutral'da 1-2 saniye bekleyip diagnostics snapshot al.

Beklenen:

```text
rep_count: 0 -> 1

acquireNeutral >= 1
startDescending >= 1
reachPeak >= 1
startAscending >= 1
completeRep >= 1

unexpected abort = 0
active rep resync = 0
```

Diagnostics transition isimleri generic topology nedeniyle `startDescending/startAscending` olarak kalabilir; Glute Bridge'te toward-peak muscle action production contract'ta concentric'tir. İsimler fiziksel hareket yönüyle birebir yorumlanmamalıdır.

## 8. İlk Failure Triage Sırası

Preflight başarısızsa threshold'a doğrudan dokunulmaz.

İnceleme sırası:

1. side-view framing,
2. selected shoulder/hip/knee landmark quality,
3. selected-side stability,
4. shoulder-hip-knee primary metric zaman serisi,
5. neutral <135° / effective active >148° / effective peak >158° topology,
6. sparse sampling / peak confirmation,
7. completed-rep ROM validation,
8. setup posture signalinin counting'e beklenmeyen etkisi,
9. performance / reentrant-drop davranışı.

Jumping Jack veya Bench Dip temporal blocker'ları gerekçe gösterilerek generic lifecycle'a refleks müdahale yapılmaz. Glute Bridge failure'ı kendi exercise-specific cihaz kanıtıyla sınıflandırılır.

## 9. Diagnostics İncelemesi

Özellikle:

```text
app_commit_sha
build_mode
exercise_type
camera_view_contract
range_rep_side_mode
range_rep_primary_metric_kind
range_rep_primary_metric_direction

current_selected_side
side_switch_count
active_rep_side_switch_count

rep_count
range_rep_transition_counts
range_rep_abort_count
range_rep_validation_status_counts
range_rep_validation_reason_counts
active_rep_resync_count

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

Tek run'daki max spike tek başına blocker değildir; p95 ve tekrar eden counting davranışı birlikte değerlendirilir.

## 10. Closure Kriteri

Glute Bridge `R6 Engineering Revalidated` statüsüne aday olmak için minimum olarak:

1. preflight + controlled positive counting,
2. static phantom-count rejection,
3. partial-ROM rejection,
4. setup robustness,
5. selected-side robustness,
6. pause/resume lifecycle,
7. persistence

kanıtı gerekir.

Formal protokol sapması olursa closure kaydında açıkça yazılır; çalıştırılmayan run PASS gösterilmez.
