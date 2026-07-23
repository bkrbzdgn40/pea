# R6 Wave B - Lying Leg Raise Device Validation

Bu protokol R6 Dalga B kapsamında `Lying Leg Raise` exercise-specific gerçek cihaz validation'ını tanımlar.

Shared range-rep visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Lying Leg Raise:

```text
tracking = repetitions
engine = rangeRep
sideMode = selectedSide
primaryMetricDirection = decreasingToPeak
camera = side preferred
front = unsupported
```

Primary metric:

```text
shoulder -> hip -> knee
```

Bu açı bacaklar gövde hattına yakınken daha yüksek, bacaklar kalça fleksiyonuyla yükseldikçe daha düşüktür.

Technique/form metric:

```text
hip -> knee -> ankle
```

Bu sinyal diz ekstansiyonunu izler. Contract'ta technique-only roldedir; rep validity için zorunlu signal değildir.

Pose acceptance yalnız primary metric'i zorunlu tutar:

```text
poseAcceptanceRequiredSignals = primaryMetric
```

Bu nedenle knee/ankle technique sinyali geçici olarak üretilemediğinde counting'in sırf form metriği eksik diye bloklanması beklenmez; yalnız ilgili technique feedback'i kullanılamayabilir.

## 2. Config ve Validation Eşikleri

Production config:

```text
thresholdNeutral = 160°
thresholdActive = 145°
thresholdPeak = 105°

formThreshold = 155°
targetMinAngle = 90°

idealDescentSeconds = 1.2
idealAscentSeconds = 1.2
```

Completed-rep validation:

```text
minAcceptableRomDelta = 30°
minDescentMillis = 300
minAscentMillis = 300
allowLowConfidenceOnCoverageLoss = true
```

`formThreshold = 155°`, selected-side knee-extension metriği için technique feedback eşiğidir. Diz açısı bu değerin belirgin altına düştüğünde form uyarısı beklenir; bu sinyal technique-only olduğu için uyarı alınması rep'in mutlaka invalid sayılması gerektiği anlamına gelmez.

Threshold'lar tek kişi veya tek video nedeniyle değiştirilmez.

## 3. Kamera ve Setup

Formal validation setup:

```text
side view
tüm vücut kadrajda
omuz, kalça, diz ve ayak bileği görünür
kullanıcı sırt üstü
bacaklar birlikte
başlangıçta bacaklar zemine yakın
```

Front view formal PASS için kullanılmaz.

Kamera mümkün olduğunca gövde ve bacakların sagittal hareketini tek düzlemde görmelidir.

## 4. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-LLR-PREFLIGHT-1` | Preflight | Side view; neutral başlangıçtan 1 kontrollü tam tekrar | Bir lifecycle tamamlanır, sayaç 1 artar, beklenmeyen blocking feedback yok |
| `R6-LLR-POS-20` | Positive counting | 20 kontrollü tam tekrar | App count ground truth ile uyumlu; phantom/çift sayım yok |
| `R6-LLR-STATIC-30` | Static negative | Bacakları zemine yakın neutral başlangıçta 30 sn sabit tut | 0 phantom rep |
| `R6-LLR-PARTIAL-10` | Partial / invalid ROM | 10 sığ kaldırış; gerçek peak'e ulaşmadan geri dön | 0 completed rep veya completed olsa bile validation yetersiz ROM'u açıkça işaretler; ideal beklenti lifecycle'ın peak öncesi abort etmesidir |
| `R6-LLR-FORM-5` | Technique violation | 5 kontrollü tekrar sırasında dizleri belirgin bük | Knee-extension corrective feedback beklenir; technique-only signal olduğu için counting sonucu ayrıca gözlenir, otomatik olarak 0 rep şartı aranmaz |
| `R6-LLR-LIFE` | Pause/resume | Aktif set içinde pause/resume | Pause sırasında phantom count yok; resume sonrası temiz neutral reacquire ve counting |
| `R6-LLR-PERSIST` | Persistence | Ölçülebilir completed rep setiyle session bitir | Live, Summary ve History rep sayısı aynı |

`OCC` **SKIPPED - covered by shared reliability validation**.

## 5. İlk Cihaz Adımı

İlk run:

```text
R6-LLR-PREFLIGHT-1
```

Uygulama:

1. Side-view kamerada sırt üstü uzan.
2. Tüm vücudu ve özellikle omuz-kalça-diz-ayak bileği hattını kadraja al.
3. Bacakları birlikte, dizleri rahatça düz tut.
4. Bacaklar zemine yakın neutral pozisyondan başla.
5. Kontrollü biçimde yukarı kaldır, peak'e ulaş ve kontrollü biçimde neutral pozisyona dön.

Beklenen:

```text
rep_count: 0 -> 1
completeRep transition: 1
unexpected resync: 0
unexpected abort: 0
```

Preflight başarısızsa eşik değiştirilmez. Önce şu sıra incelenir:

1. camera contract / framing,
2. selected-side landmark quality,
3. shoulder-hip-knee primary metric,
4. neutral -> active -> peak threshold topology,
5. lifecycle / confirmation,
6. completed-rep validation,
7. knee-extension technique feedback.

## 6. Kritik Negatif Testler

### STATIC-30

Amaç neutral pozisyonda jitter'ın rep lifecycle başlatmamasını doğrulamaktır.

```text
ground_truth_reps = 0
expected_app_reps = 0
```

### PARTIAL-10

Bacaklar active bölgeye yaklaşabilir veya girebilir; ancak tam peak'e ulaşmadan geri dönülür.

Amaç shallow excursion'ın completed rep üretmemesidir.

Tek run nedeniyle `thresholdPeak` veya `minAcceptableRomDelta` değiştirilmez.

### FORM-5

Dizleri belirgin bükerek hip flexion tekrarları yapılır.

Beklenen ana kanıt:

```text
hip -> knee -> ankle < formThreshold
-> knee-extension corrective feedback
```

Bu sinyal `technique` rolündedir. Rep validity için zorunlu olmadığı için form-warning ile counting birbirinden ayrı değerlendirilir.

## 7. Diagnostics İncelemesi

Final kanıtta özellikle şu alanlar incelenir:

```text
exercise_type
app_commit_sha
build_mode
camera_view_contract
range_rep_side_mode
range_rep_primary_metric_direction

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

Tek run'daki `frame_processing_ms_max` spike'ı tek başına blocker sayılmaz; p95 ve tekrar eden davranış esas alınır.

## 8. Closure Kriteri

Lying Leg Raise şu kritik kapılarla `R6 Engineering Revalidated` statüsüne aday olur:

1. preflight + positive counting,
2. static negative,
3. partial / invalid-ROM rejection,
4. knee-extension technique behavior,
5. pause/resume lifecycle,
6. persistence.

Per-exercise occlusion tekrar edilmez; yalnız Lying Leg Raise'e özgü visibility/occlusion failure görülürse yeniden açılır.

Formal protokolde sapma olursa closure kaydında açıkça yazılır; çalıştırılmayan run PASS olarak gösterilmez.

## 9. Device Finding - Peak Acquisition False Negative

SHA-pinned profile gerçek cihaz run'ında kullanıcı kontrollü tam ve kısmi tekrarları aynı sette gerçekleştirdi. Video + diagnostics karşılaştırmasında bazı kısmi hareketlerin doğru biçimde sayılmadığı, ancak birkaç fiziksel olarak geçerli tekrarın da `reachPeak` transition'ına ulaşamadığı görüldü.

Failure diagnostics:

```text
startDescending = 7
reachPeak = 0
startAscending = 0
completeRep = 0
abortToNeutral = 6
rep_count = 0
range_rep_validation_count = 0
```

Bu nedenle failure completed-rep validation veya `minAcceptableRomDelta` kaynaklı değildir. Lifecycle peak acquisition aşamasında kalmaktadır.

Production threshold değişmedi:

```text
thresholdPeak = 105°
```

Shared generic lifecycle varsayılan `peakEntryMargin = 3°` uyguladığı için eski efektif giriş koşulu decreasing-to-peak hareketlerde:

```text
primaryMetric < 102°
```

oluyordu. Ayrıca 80 ms peak confirmation sırasında ikinci analiz sample'ının tekrar katı entry bandında kalması gerekiyordu. Yaklaşık 6 FPS analysis sampling altında doğal tepe kısa süreyle görülüp bir sonraki sample exit hysteresis bandında kaldığında bile pending peak iptal edilebiliyordu.

### Hardening

Lying Leg Raise contract'ı artık configured peak threshold'u literal giriş sınırı olarak kullanır:

```text
peakEntryMargin = 0°
entry condition = primaryMetric < 105°
```

Generic peak debounce ise gerçek hysteresis davranışıyla hizalandı:

1. strict peak entry bir kez görülür,
2. pending confirmation başlar,
3. sonraki sample strict entry bandından çıkmış olsa bile peak exit bandını aşmadığı sürece pending confirmation korunur,
4. exit bandı aşılırsa pending peak iptal edilir.

Bu değişiklik `thresholdPeak`, `minAcceptableRomDelta`, form threshold veya generic default margin'i değiştirmez. Exercise-specific fark yalnız Lying Leg Raise contract'ının `peakEntryMargin = 0°` seçmesidir.

Deterministik regression kapsamı:

```text
104° peak entry -> 110° next sparse sample -> peak confirmation -> completed rep
109° shallow partial -> no peak entry -> 0 rep
120° exit-hysteresis breach while peak pending -> pending peak cancelled
```

Gerçek cihaz retest'i closure öncesi zorunludur. Özellikle daha önce false-negative görülen doğal tam tekrarlar ile 109° civarında kalan partial hareketler aynı run'da tekrar karşılaştırılmalıdır.

