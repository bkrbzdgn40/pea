# R6 Wave C - Sit-up Device Validation

Bu protokol R6 Dalga C kapsamında `Sit-up` exercise-specific gerçek cihaz validation'ını tanımlar.

Jumping Jack, fast-motion peak-acquisition blocker nedeniyle `R6 Validation Blocked / Deferred` durumunda bırakılmıştır. Aktif validation sırası Sit-up ile devam eder.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Sit-up:

```text
tracking = repetitions
engine = rangeRep
sideMode = selectedSide
primaryMetricDirection = decreasingToPeak
primaryMetricKind = imagePlaneInclination
camera = side preferred
front = unsupported
towardPeakMuscleAction = concentric
```

Primary metric klasik üç-landmark joint angle değildir.

Sit-up primary metriği selected tarafta:

```text
shoulder -> hip segment
image-plane torso inclination
```

üzerinden türetilir.

Amaç, gövde yerde/gerideyken daha yüksek olan torso-orientation değerinin kullanıcı yukarı curl oldukça azalmasını izlemektir.

Pose acceptance yalnız primary metric'i zorunlu tutar:

```text
poseAcceptanceRequiredSignals = primaryMetric
required landmarks = selected shoulder + selected hip
```

Bu nedenle knee/ankle setup sinyallerinin kaybı primary torso detection'ı tek başına düşürmemelidir.

## 2. Config ve Lifecycle Eşikleri

Production config:

```text
thresholdNeutral = 120°
thresholdActive = 113°
thresholdPeak = 83°

idealTowardPeakSeconds = 1.0
idealReturnSeconds = 1.2

formThreshold = 60°
targetMinAngle = 70°
```

Generic peak-entry margin varsayılan olarak:

```text
peakEntryMargin = 3°
```

olduğu için decreasing-to-peak strict peak acquisition fiilen:

```text
primaryMetric < 80°
```

gerektirir.

Deterministik production testleri şu sınırı karakterize eder:

```text
82° -> peak değil
79° -> peak
```

Gerçek cihaz preflight'ta doğal ve düzgün Sit-up tekrarları sistematik olarak 80° altına inemiyorsa tek videodan threshold değiştirilmez; önce torso inclination projection, framing, selected-side ve lifecycle sampling birlikte incelenir.

## 3. Completed-Rep Validation

Production validation config:

```text
minAcceptableRomAngle = 110°
minDescentMillis = 250
minAscentMillis = 300
allowLowConfidenceOnCoverageLoss = true
```

Absolute ROM validation:

```text
summary.minAngle > 110°
-> insufficientRom
```

Ancak production lifecycle'ın strict peak acquisition koşulu `<80°` olduğu için normal akışta peak'e ulaşmış completed rep zaten 110° ROM floor'unu geçmiş olur.

Bu nedenle partial hareketlerin ideal olarak completed-rep validator'a kadar gelmeden lifecycle içinde abort edilmesi beklenir.

## 4. Setup / Advisory Signal

Config ayrıca:

```text
postureAngle:
hip -> knee -> ankle
```

sinyalini tanımlar.

Sit-up contract'ında `formMetric` ve `postureAngle` setup rolündedir; primary counting sinyali değildir.

Gerçek cihaz validation'da kullanıcı:

```text
knees bent
feet comfortably on floor
```

setup'ıyla test edilir.

Diz/bacak setup'ındaki makul varyasyonun torso primary metric counting'ini bozmaması beklenir.

## 5. Kamera ve Setup

Formal setup:

```text
side view
whole torso visible
selected shoulder + hip clearly visible
knees bent
feet on floor
head/neck not used to force the movement
```

Mümkünse kamera torso hareket düzlemine yaklaşık dik konumlandırılır.

Başlangıçta kullanıcı kontrollü neutral pozisyonda kısa süre bekler ve engine'in neutral acquire etmesine izin verir.

Front view formal PASS için kullanılmaz.

## 6. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-SU-PREFLIGHT-1` | Preflight | Side view; neutral -> controlled curl-up -> neutral | Bir tam lifecycle; sayaç 1 artar; beklenmeyen abort/resync yok |
| `R6-SU-POS-20` | Positive counting | 20 kontrollü tam Sit-up | Count ground truth ile uyumlu; phantom/double count yok |
| `R6-SU-STATIC-30` | Static negative | Neutral başlangıç pozisyonunda 30 sn sabit kal | 0 phantom rep |
| `R6-SU-PARTIAL-10` | Partial ROM | 10 sığ curl-up; gerçek peak'e ulaşmadan geri dön | 0 completed rep veya açık insufficient-ROM sonucu; ideal beklenti peak öncesi abort |
| `R6-SU-SETUP-5` | Setup robustness | Diz açısını/ayak mesafesini makul aralıkta değiştirerek 5 kontrollü tam tekrar | Primary torso counting çalışmaya devam eder; setup sinyali counting'i gereksiz yere bloklamaz |
| `R6-SU-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; resume sonrası temiz neutral reacquire |
| `R6-SU-PERSIST` | Persistence | Ölçülebilir completed-rep setiyle session bitir | Live, Summary ve History rep sayısı aynı |

`OCC` **SKIPPED - covered by shared reliability validation**.

Exercise-specific visibility failure görülürse yeniden açılır.

## 7. İlk Cihaz Adımı

İlk run:

```text
R6-SU-PREFLIGHT-1
```

Uygulama:

1. Kamerayı side view konumlandır.
2. Omuz, kalça ve torso hattını net göster.
3. Dizleri bük, ayakları rahatça yere koy.
4. Neutral başlangıçta 1-2 saniye bekle.
5. Boynu çekmeden kontrollü biçimde yukarı curl ol.
6. Rahat fakat belirgin tam üst pozisyona ulaş.
7. Kontrollü biçimde tekrar neutral'a dön.
8. Neutral'da 1-2 saniye bekledikten sonra diagnostics snapshot al.

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

Production diagnostics phase adları topology açısından `descending/ascending` olabilir; Sit-up contract'ında toward-peak muscle action concentric olarak işaretlidir. Validation sırasında transition isimleri biyomekanik yönle karıştırılmamalıdır.

## 8. İlk Failure Triage Sırası

Preflight başarısızsa threshold'a doğrudan dokunulmaz.

İnceleme sırası:

1. side-view framing,
2. selected shoulder/hip landmark quality,
3. selected-side stability,
4. shoulder -> hip image-plane inclination zaman serisi,
5. neutral 120° / active 113° / effective peak <80° topology,
6. sparse sampling / peak confirmation,
7. completed-rep validation,
8. setup posture sinyalinin counting'e beklenmeyen etkisi.

Özellikle Jumping Jack'teki fast-motion issue nedeniyle generic lifecycle'a refleks olarak müdahale edilmez. Sit-up failure'ı ayrı exercise-specific kanıtla sınıflandırılır.

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

Tek run'daki max spike tek başına blocker değildir. p95 ve tekrar eden counting davranışı birlikte değerlendirilir.

## 10. Closure Kriteri

Sit-up `R6 Engineering Revalidated` statüsüne aday olmak için minimum olarak:

1. preflight + controlled positive counting,
2. static phantom-count rejection,
3. partial-ROM rejection,
4. setup robustness,
5. pause/resume lifecycle,
6. persistence

kanıtı gerekir.

Formal protokol sapması olursa closure kaydında açıkça yazılır; çalıştırılmayan run PASS gösterilmez.

## 11. Current Validation Status

```text
R6 Validation Blocked / Deferred
Engineering Revalidated = No
```

Gerçek cihaz/video validation'da doğru fiziksel Sit-up başlangıcı kullanılmasına rağmen neutral acquisition oluşmamış ve range-rep lifecycle hiç başlamamıştır.

İkinci evidence run:

```text
rep_count = 0
range_rep_transition_count = 0
range_rep_validation_count = 0

sensor_orientation_degrees = 90
device_orientation = portraitUp
```

Kullanıcı aynı run'da telefonu fiziksel olarak yatay tuttuğunu doğrulamıştır.

Sit-up primary metriği `imagePlaneInclination` olduğu için orientation-dependent coordinate normalization / primary-metric interpretation blocker root area olarak açılmıştır. Kesin fix katmanı henüz converter, pose normalization veya Sit-up-specific metric seviyesinde ayrıştırılmamıştır.

Threshold tuning uygulanmamıştır.

Kalıcı issue, gerekçe ve reopen acceptance criteria:

```text
docs/beta/r6-wave-c-sit-up-results.md
```

Bu hareket PASS veya `R6 Engineering Revalidated` olarak yorumlanmamalıdır.
