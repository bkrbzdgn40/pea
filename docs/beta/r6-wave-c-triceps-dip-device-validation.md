# R6 Wave C - Triceps Dip Device Validation

Bu protokol R6 Dalga C kapsamında `Triceps Dip` exercise-specific gerçek cihaz validation'ını tanımlar.

Jumping Jack ve Sit-up blocker bulguları nedeniyle `R6 Validation Blocked / Deferred` durumunda tutulur. Aktif validation sırası Triceps Dip ile devam eder.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Product Scope

Production guide ve engineering contract bu hareketi:

```text
parallel-bar Triceps Dip
```

olarak tanımlar.

Bench dip bu validation kapsamının canonical positive path'i değildir.

Formal cihaz testinde paralel bar / dip station kullanılır.

## 2. Production Contract

Production kaynaklarına göre Triceps Dip:

```text
tracking = repetitions
engine = rangeRep
sideMode = selectedSide
primaryMetricDirection = decreasingToPeak
primaryMetricKind = jointAngle
camera = side preferred
front = unsupported
towardPeakMuscleAction = eccentric
```

Primary metric:

```text
shoulder -> elbow -> wrist
```

Elbow angle üst pozisyonda yüksek, aşağı inerken daha düşüktür.

Technique proxy:

```text
elbow -> shoulder -> hip
transform = complement180
```

Bu sinyal aşırı shoulder-extension davranışına karşı warning-level technique feedback amacı taşır.

Production contract'ta `formMetric` ve `postureAngle`:

```text
technique-only
```

rolündedir.

Pose acceptance yalnız:

```text
primaryMetric
```

sinyalini zorunlu tutar.

Bu nedenle shoulder-extension proxy eksikliği veya warning tek başına rep counting validity gate'i olarak yorumlanmaz.

## 3. Config ve Lifecycle Eşikleri

Production config:

```text
thresholdNeutral = 150°
thresholdActive = 130°
thresholdPeak = 90°

idealDescentSeconds = 1.2
idealAscentSeconds = 1.0

formThreshold = 100°
targetMinAngle = 70°
```

Generic peak-entry margin:

```text
3°
```

olduğu için decreasing-to-peak strict peak acquisition fiilen:

```text
primaryMetric < 87°
```

gerektirir.

Tek cihaz videosu nedeniyle bu threshold'lar değiştirilmez.

## 4. Completed-Rep Validation

Production validation config:

```text
minAcceptableRomDelta = 30°
minDescentMillis = 250
minAscentMillis = 250
allowLowConfidenceOnCoverageLoss = true
```

`minAcceptableRomDelta`, confirmed active-phase başlangıcından observed peak'e ölçülen conservative consistency guard'dır; klinik ROM cut-off değildir.

İdeal positive path'te:

```text
neutral -> active -> peak -> return -> neutral
```

tam lifecycle beklenir.

## 5. Technique Feedback

Production feedback:

```text
TR: Omuzlarını gereksiz derine zorlama.
EN: Do not force your shoulders too deep.
```

Technique proxy warning-level sinyaldir.

FORM testinde amaç shoulder-extension warning'in semantik olarak doğru zamanda ve gerçek davranışla ilişkili görünmesini doğrulamaktır.

Warning görülmesi completed rep'in otomatik invalid olması gerektiği anlamına gelmez.

## 6. Kamera ve Setup

Formal setup:

```text
parallel bars / dip station
side view
shoulder, elbow and wrist clearly visible
hip visible when possible for technique proxy
whole upper-body movement remains in frame
```

Başlangıç:

```text
top support
arms controlled and extended
body stable
```

Kullanıcı omuz ağrısı veya rahatsızlık hissederse derinlik zorlanmaz; validation için anatomik limit zorlamak kabul kriteri değildir.

Front view formal PASS için kullanılmaz.

## 7. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-TD-PREFLIGHT-1` | Preflight | Side view; top support -> controlled bottom -> top support | Bir temiz lifecycle; sayaç 1 artar; beklenmeyen abort/resync yok |
| `R6-TD-POS-20` | Positive counting | 20 kontrollü tam parallel-bar dip | Count ground truth ile uyumlu; phantom/double count yok |
| `R6-TD-STATIC-30` | Static negative | Top support pozisyonunda 30 sn stabil kal | 0 phantom rep |
| `R6-TD-PARTIAL-10` | Partial ROM | 10 sığ dip; gerçek peak/bottom bölgesine ulaşmadan geri dön | 0 completed rep veya açık insufficient-ROM validation; ideal beklenti peak öncesi abort |
| `R6-TD-FORM-5` | Technique behavior | 5 kontrollü tekrarda yalnız güvenli sınırlar içinde daha fazla shoulder extension davranışı üret | Uygun koşulda shoulder-depth corrective feedback; counting sonucu technique-only semantikten ayrı değerlendirilir |
| `R6-TD-SIDE-2x5` | Selected-side robustness | Aynı setup'ta kameraya sağ ve sol fiziksel tarafı göstererek ayrı 5'er tam tekrar | Her iki fiziksel tarafta counting çalışır; active rep sırasında gereksiz side-switch/resync yok |
| `R6-TD-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; resume sonrası temiz neutral reacquire |
| `R6-TD-PERSIST` | Persistence | Ölçülebilir completed-rep setiyle session bitir | Live, Summary ve History rep sayısı aynı |

`OCC` **SKIPPED - covered by shared reliability validation**.

Exercise-specific bar/arm occlusion failure görülürse yeniden açılır.

## 8. İlk Cihaz Adımı

İlk run:

```text
R6-TD-PREFLIGHT-1
```

Uygulama:

1. Paralel barlarda top support pozisyonuna geç.
2. Kamerayı yandan shoulder-elbow-wrist hattını net görecek şekilde yerleştir.
3. Kolları kontrollü uzatılmış başlangıçta 1-2 saniye bekle.
4. Dirsekleri bükerek kontrollü aşağı in.
5. Güvenli ve doğal alt pozisyona ulaş.
6. Kontrollü biçimde tekrar top support'a dön.
7. Üst pozisyonda 1-2 saniye bekle ve diagnostics snapshot al.

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

## 9. İlk Failure Triage Sırası

Preflight başarısızsa threshold'a doğrudan dokunulmaz.

İnceleme sırası:

1. parallel-bar product scope ve gerçek hareket setup'ı,
2. side-view framing,
3. selected shoulder/elbow/wrist landmark quality,
4. selected-side stability,
5. elbow primary metric zaman serisi,
6. neutral 150° / active 130° / effective peak <87° topology,
7. sparse sampling / peak confirmation,
8. completed-rep ROM validation,
9. shoulder-extension technique proxy ve feedback semantiği.

Jumping Jack veya Sit-up blocker'ları gerekçe gösterilerek generic lifecycle/camera pipeline'a refleks müdahale yapılmaz. Triceps Dip failure'ı kendi exercise-specific kanıtıyla sınıflandırılır.

## 10. Diagnostics İncelemesi

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

## 11. Closure Kriteri

Triceps Dip `R6 Engineering Revalidated` statüsüne aday olmak için minimum olarak:

1. preflight + controlled positive counting,
2. static phantom-count rejection,
3. partial-ROM rejection,
4. shoulder-extension technique behavior,
5. selected-side robustness,
6. pause/resume lifecycle,
7. persistence

kanıtı gerekir.

Formal protokol sapması olursa closure kaydında açıkça yazılır; çalıştırılmayan run PASS gösterilmez.
