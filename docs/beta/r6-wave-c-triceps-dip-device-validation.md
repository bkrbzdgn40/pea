# R6 Wave C - Bench Dip Device Validation

Bu protokol R6 Dalga C kapsamında stable internal id'si `triceps_dip` olan canonical **Bench Dip** hareketinin exercise-specific gerçek cihaz validation'ını tanımlar.

Jumping Jack ve Sit-up blocker bulguları nedeniyle `R6 Validation Blocked / Deferred` durumunda tutulur. Aktif validation sırası Bench Dip (`triceps_dip`) ile devam eder.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Product Scope

Canonical production hareketi:

```text
Bench Dip
stable internal id = triceps_dip
```

Setup:

```text
stable bench / sturdy raised surface
hands behind the body on the edge
hips just in front of the support
feet supported on the floor
side-view camera
```

Parallel-bar dip artık bu exercise id için formal positive path değildir.

Scope değişikliğinin nedeni yalnız isim tercihi değildir. Bench, bar ve ring dip varyasyonlarının 3D kinematik profilleri farklıdır; bench dip daha fazla shoulder extension ve bar dip'e göre daha az elbow flexion kullanabilir. Bu nedenle bar-dip için daha derin elbow-flexion varsayımını bench-dip canonical path'e zorlamak doğru değildir.

Internal id ve persisted exercise identity uyumluluk için değiştirilmez.

## 2. Production Contract

Production kaynaklarına göre Bench Dip (`triceps_dip`):

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
thresholdPeak = 100°

idealDescentSeconds = 1.2
idealAscentSeconds = 1.0

formThreshold = 100°
targetMinAngle = 90°
```

Generic peak-entry margin:

```text
3°
```

olduğu için decreasing-to-peak strict peak acquisition fiilen:

```text
primaryMetric < 97°
```

gerektirir.

Bu eşikler canonical Bench Dip scope'u ve yaklaşık 90° kontrollü bottom hedefiyle hizalanmıştır; yeniden değişiklik için yeni cihaz kanıtı ve partial-negative koruması birlikte aranır.

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
stable bench / sturdy raised surface
side view
shoulder, elbow and wrist clearly visible
hip visible when possible for technique proxy
hips kept close to the support edge
feet supported on the floor
whole upper-body movement remains in frame
```

Başlangıç:

```text
arms controlled and extended
hips just in front of the bench
feet placed forward with stable floor support
body stable
```

Alt pozisyonda amaç dirseği yaklaşık 90° civarına getiren kontrollü elbow flexion'dır. Daha fazla derinlik scoring avantajı olarak teşvik edilmez.

Kullanıcı omuz ağrısı veya rahatsızlık hissederse derinlik zorlanmaz; validation için anatomik limit zorlamak kabul kriteri değildir.

Front view formal PASS için kullanılmaz.

## 7. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-TD-PREFLIGHT-1` | Preflight | Side view; bench-dip top position -> controlled bottom -> bench-dip top position | Bir temiz lifecycle; sayaç 1 artar; beklenmeyen abort/resync yok |
| `R6-TD-POS-20` | Positive counting | 20 kontrollü tam bench dip | Count ground truth ile uyumlu; phantom/double count yok |
| `R6-TD-STATIC-30` | Static negative | Bench-dip üst pozisyonunda 30 sn stabil kal | 0 phantom rep |
| `R6-TD-PARTIAL-10` | Partial ROM | 10 sığ dip; gerçek peak/bottom bölgesine ulaşmadan geri dön | 0 completed rep veya açık insufficient-ROM validation; ideal beklenti peak öncesi abort |
| `R6-TD-FORM-5` | Technique behavior | 5 kontrollü tekrarda yalnız güvenli sınırlar içinde daha fazla shoulder extension davranışı üret | Uygun koşulda shoulder-depth corrective feedback; counting sonucu technique-only semantikten ayrı değerlendirilir |
| `R6-TD-SIDE-2x5` | Selected-side robustness | Aynı setup'ta kameraya sağ ve sol fiziksel tarafı göstererek ayrı 5'er tam tekrar | Her iki fiziksel tarafta counting çalışır; active rep sırasında gereksiz side-switch/resync yok |
| `R6-TD-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; resume sonrası temiz neutral reacquire |
| `R6-TD-PERSIST` | Persistence | Ölçülebilir completed-rep setiyle session bitir | Live, Summary ve History rep sayısı aynı |

`OCC` **SKIPPED - covered by shared reliability validation**.

Exercise-specific bench/arm occlusion failure görülürse yeniden açılır.

## 8. İlk Cihaz Adımı

İlk run:

```text
R6-TD-PREFLIGHT-1
```

Uygulama:

1. Sağlam bir bench veya yükseltinin kenarında bench-dip başlangıç pozisyonuna geç.
2. Kamerayı yandan shoulder-elbow-wrist hattını net görecek şekilde yerleştir.
3. Kolları kontrollü uzatılmış başlangıçta 1-2 saniye bekle.
4. Dirsekleri bükerek kontrollü aşağı in.
5. Güvenli ve doğal alt pozisyona ulaş.
6. Kontrollü biçimde tekrar bench-dip üst pozisyonuna dön.
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

1. bench-dip product scope ve gerçek hareket setup'ı,
2. side-view framing,
3. selected shoulder/elbow/wrist landmark quality,
4. selected-side stability,
5. elbow primary metric zaman serisi,
6. neutral 150° / active 130° / effective peak <97° topology,
7. sparse sampling / peak confirmation,
8. completed-rep ROM validation,
9. shoulder-extension technique proxy ve feedback semantiği.

Jumping Jack veya Sit-up blocker'ları gerekçe gösterilerek generic lifecycle/camera pipeline'a refleks müdahale yapılmaz. Bench Dip (`triceps_dip`) failure'ı kendi exercise-specific kanıtıyla sınıflandırılır.

## 10. Bench-Dip Scope Conversion Evidence

Scope değişiminden önceki gerçek cihaz run'ı legacy parallel-bar-oriented contract ile değerlendirilmiştir:

```text
app_commit_sha = 3270aa9ff66f0d5010d7a6a58c81d176f8f69ed5
build_mode = profile

acquireNeutral = 1
startDescending = 6
reachPeak = 0
abortToNeutral = 6
rep_count = 0

analysis_fps_p50 = 5.8766
frame_processing_ms_p95 = 256
analysis_exception_count = 0
```

üretmiştir.

Video incelemesinde hareketin bench/chair dip olduğu ve uygulamanın bazı kontrollü alt pozisyonlarda yaklaşık `91°-96°` elbow-angle örnekleri gördüğü doğrulanmıştır. Legacy `thresholdPeak = 90°` ile generic `3°` peak-entry margin birleştiğinde strict gate `<87°` olduğu için bu canonical bench-dip derinlikleri peak acquire edememiştir.

Bench Dip scope'u için production config:

```text
thresholdNeutral = 150°
thresholdActive = 130°
thresholdPeak = 100°
effective strict peak entry = <97°
targetMinAngle = 90°
```

olarak hizalanır.

Bu karar tek videodaki tek değeri threshold'a kopyalamak değildir:

- canonical bench-dip coaching yaklaşık 90° elbow bottom'u hedefler,
- comparative 3D dip kinematics bench ve bar varyasyonlarının elbow/shoulder profillerinin aynı olmadığını gösterir (PMCID: PMC9603242),
- strict `<97°` gate kontrollü yaklaşık-90° bottom'u kapsarken `100°+` shallow/partial girişimler peak olarak kabul edilmez,
- scoring target `90°` yapılarak gereksiz ekstra derinlik ödüllendirilmez.

Scope conversion sonrası aynı bench-dip positive/partial paths gerçek cihazda yeniden doğrulanmalıdır.

## 11. Diagnostics İncelemesi

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

## 12. Closure Kriteri

Bench Dip (`triceps_dip`) `R6 Engineering Revalidated` statüsüne aday olmak için minimum olarak:

1. preflight + controlled positive counting,
2. static phantom-count rejection,
3. partial-ROM rejection,
4. shoulder-extension technique behavior,
5. selected-side robustness,
6. pause/resume lifecycle,
7. persistence

kanıtı gerekir.

Formal protokol sapması olursa closure kaydında açıkça yazılır; çalıştırılmayan run PASS gösterilmez.
