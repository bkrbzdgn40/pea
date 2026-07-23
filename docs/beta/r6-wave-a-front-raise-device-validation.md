# R6 Wave A - Front Raise Device Validation

Bu protokol R6 Dalga A kapsamında `Front Raise` exercise-specific gerçek cihaz validation'ını tanımlar.

Amaç production threshold'larını önceden tuning etmek değildir. Mevcut selected-side, increasing-to-peak range-rep contract'ının doğru yan kamera kurulumu altında natural neutral acquisition, tam tekrar sayımı, shallow-ROM reddi, dirsek form sinyali, selected-side kararlılığı, lifecycle ve persistence davranışını gerçek cihaz üzerinde ölçmektir. Per-exercise occlusion tekrar testi, shared range-rep/hold visibility hardening daha önce doğrulandığı için varsayılan olarak atlanır; yalnız exercise-specific visibility logic veya yeni regression görülürse geri açılır.

## 1. Production Contract Özeti

Production kaynaklarına göre Front Raise:

- `exercise_type = front_raise`
- engine: `rangeRep`
- side mode: `selected-side`
- primary metric direction: `increasingToPeak`
- preferred camera: `side`
- unsupported camera: `front`
- primary metric: seçilen tarafta `elbow -> shoulder -> hip` açısı
- form metric: seçilen tarafta `shoulder -> elbow -> wrist` dirsek açısı
- `thresholdNeutral = 15°`
- `thresholdActive = 35°`
- `thresholdPeak = 75°`
- `formThreshold = 145°`
- `minAcceptableRomDelta = 45°`

`thresholdNeutral = 15°` strict neutral acquisition açısından gerçek cihazda özellikle izlenecektir. Doğal kol dinlenme pozisyonu engine tarafından güvenilir biçimde neutral kabul edilmiyorsa validation durdurulur; cihaz/video kanıtı olmadan threshold değiştirilmez.

## 2. Kamera Kurulumu

Cihaz test yapan kişiye **tam yandan** bakacak şekilde sabitlenmelidir.

Kadrajda seçilen tarafta aynı anda görünmesi gereken minimum bölgeler:

- omuz,
- dirsek,
- bilek,
- kalça.

Kol öne kaldırıldığında bilek kadraj dışına çıkmamalıdır. Gövdenin geriye savrulması ile gerçek omuz fleksiyonunun ayrıştırılabilmesi için omuz-kalça hattı görünür kalmalıdır.

`side` burada subject-view kontratıdır; `camera_lens_direction` ile aynı kavram değildir. Ön veya arka kamera kullanılabilir, ancak cihaz kişinin yanına yerleştirilmelidir.

Önden veya belirgin çapraz kurulum bu validation için kullanılmaz. Böyle bir run protokol dışı kabul edilir ve manifestte `INVALID` olarak işaretlenir.

## 2.1 Preflight Bulgusu ve Selected-Side Hardening

İlk exploratory video önden çekildiği için camera contract dışı ve `INVALID` kabul edilir.

Doğru tam yan retest'te:

- natural neutral yaklaşık `5-13°` aralığında güvenilir biçimde acquire edildi,
- ilk tam tekrarlar completed rep olarak sayıldı,
- `thresholdNeutral = 15°` için cihaz kanıtına dayalı bir blocker görülmedi; threshold değiştirilmedi,
- buna karşılık kabul edilebilir düz dirsek formunda aralıklı false-positive `Dirseklerini gereksiz bükme.` feedback'i ve side-view self-occlusion sırasında visibility kararsızlığı gözlendi.

Kök neden incelemesinde pose-quality katmanının selected-side hareketler için daha yüksek landmark kalitesine sahip tarafı `preferredRangeRepSide` olarak ürettiği, ancak coordinator side-selection yolunun bu tercihi kullanmadığı bulundu. Eşit signal coverage durumunda seçim legacy sol-taraf tie-break'ine düşebiliyor ve arkada kalan/örtüşen kolun dirsek geometrisi teknik feedback'i kirletebiliyordu.

Hardening sonrası selected-side seçim:

1. signal coverage farkını birincil güvenlik kriteri olarak korur,
2. coverage eşitse pose-quality `preferredRangeRepSide` değerini tie-break olarak kullanır,
3. mevcut side stabilizer hysteresis'ini korur,
4. aktif rep side-lock / rep-consistency güvenliğini değiştirmez.

Bu değişiklik Front Raise threshold'larını, peak gate'ini veya counting contract'ını değiştirmez. Amaç yalnız daha güvenilir görünen tarafın primary/form metric kaynağı olmasını sağlamaktır.

Selected-side quality hardening sonrası doğru side-view gerçek cihaz retest'inde counting ve lifecycle stabil kaldı; ancak kabul edilebilir hafif dirsek fleksiyonunda aralıklı false-positive `Dirseklerini gereksiz bükme.` feedback'i devam etti. Bu nedenle Front Raise'a özel `formThreshold`, counting/ROM gate'lerine dokunmadan `155° -> 145°` olarak gevşetildi. Bu ayar doğal hafif fleksiyona yaklaşık 10° ek tolerans verir; belirgin kötü dirsek formunun hâlâ `R6-FR-FORM-5` senaryosunda `persistentFormBreak`, low-confidence veya corrective feedback ile yakalanması zorunludur.

Son side-view retest'inde elbow-feedback false positive belirgin biçimde gerilerken, doğal ve kullanıcı açısından kabul edilebilir Front Raise tekrarlarının bir bölümü UI'da yaklaşık `78-81°` peak görmesine rağmen completed rep'e ulaşmadı. Generic engine `peakEntryMargin = 3°` ile strict entry kullandığından `thresholdPeak = 80°` efektif olarak `>83°` gerektiriyordu. Front Raise'a özel `thresholdPeak`, generic engine semantiği değiştirilmeden `80° -> 75°` olarak ayarlandı; yeni efektif peak-entry gate strict `>78°` olur. `thresholdNeutral = 15°`, `thresholdActive = 35°`, `formThreshold = 145°` ve selected-side quality hardening değişmeden kalır. `40-55°` partial-motion negatif testi shallow false-positive rep'leri engelleyen zorunlu kabul kapısı olmaya devam eder.

## 3. SHA-Pinned Profile Build

PowerShell:

```powershell
$sha = (git rev-parse HEAD).Trim()
flutter run --profile --dart-define=PEA_COMMIT_SHA=$sha
```

Her diagnostics JSON için:

```text
schema_version == 6
app_commit_sha == test edilen HEAD SHA
build_mode == "profile"
exercise_type == "front_raise"
config_asset_path == "assets/config/exercises/front_raise.json"
contract_profile == "rangeRep:none"
range_rep_side_mode == "selectedSide"
range_rep_primary_metric_direction == "increasingToPeak"
analysis_exception_count == 0
```

`contract_profile` egzersiz kimliği değildir. Front Raise exercise-specific range-rep extension kullanmadığı için production diagnostics değeri `rangeRep:none` olmalıdır.

Bu kimlik alanlarından biri yanlışsa run `INVALID` olur.

## 4. Canlı Run Manifest Kuralı

Her run başlamadan önce `docs/beta/r6-wave-a-run-manifest.csv` içindeki ilgili satır kullanılır.

Run bittikten hemen sonra şu alanlar doldurulur:

- `actual_units`
- `ground_truth_reps`
- `app_reps`
- `app_commit_sha`
- `diagnostics_file`
- performans alanları
- `result`
- gerekiyorsa `deviation_reason`

Planlanan adet ile gerçek execution farklıysa run ID geriye dönük değiştirilmez. Sapma açıkça yazılır.

## 5. Zorunlu Run'lar

| Run ID | Senaryo | Planlanan uygulama | Beklenen |
| --- | --- | --- | --- |
| `R6-FR-PREFLIGHT-1` | Smoke/preflight | 1 temiz Front Raise | Natural neutral acquire edilir; 1 completed rep; profile/SHA/config/contract alanları doğru |
| `R6-FR-POS-20` | Kontrollü pozitif | 20 tam raise; kol omuz hizası civarına | `absolute_count_error <= 1`; phantom/duplicate count yok |
| `R6-FR-STATIC-30` | Statik negatif | 30 sn kol gövde yanında natural neutral | 0 phantom rep; natural neutral güvenilir biçimde acquire edilir |
| `R6-FR-PARTIAL-10` | Partial motion | Kolu yaklaşık `40-55°` seviyesinde geri çevirerek 10 sığ tekrar | 0 completed rep; PEAK oluşmamalı |
| `R6-FR-FORM-5` | Teknik form sinyali | 5 tam raise sırasında dirseği belirgin bük | Count ground truth ile uyumlu; form violation/low-confidence veya corrective feedback gözlenmeli |
| `R6-FR-LIFE-3` | Pause/resume | Aktif rep bağlamında pause/resume, 3 döngü | Dönüşte phantom rep yok; active context güvenli temizlenir/reacquire edilir |
| `R6-FR-PERSIST` | Persistence | 5 temiz Front Raise ile session bitir | Live = Summary = History = 5 |

Hızlandırılmış validation kararıyla `R6-FR-OCC-3` exercise-specific olarak tekrar edilmez. Manifest satırı `SKIPPED` tutulur ve gerekçe `covered by shared reliability validation` olarak kaydedilir.

## 6. Front Raise'a Özel Kırmızı Çizgiler

Aşağıdakilerden biri görülürse ilgili run `FAIL` olur:

- natural kol dinlenmesinde neutral'ın güvenilir biçimde acquire edilememesi,
- neutral/static beklemede phantom rep,
- `40-55°` shallow motion'ın completed rep'e dönüşmesi,
- tam raise sonrası natural neutral'a dönüşte rep'in tamamlanmaması,
- active rep sırasında selected side değişimi nedeniyle duplicate/phantom rep,
- pause/resume sonrasında phantom/duplicate rep,
- displayed/session/history rep uyuşmazlığı,
- analysis exception,
- profile performans gate'inin geçilememesi.

`R6-FR-FORM-5` counting negatif testi değildir. Belirgin dirsek bükülmesine rağmen count ground truth ile uyumlu kalabilir; burada amaç form metric / feedback yolunun gerçek dirsek form bozulmasını yakalayıp yakalamadığını ölçmektir.

## 7. Diagnostics Değerlendirmesi

Pozitif/partial/form/lifecycle run'larında özellikle:

```text
rep_count
range_rep_transition_counts
range_rep_abort_count
range_rep_validation_count
range_rep_validation_status_counts
range_rep_validation_reason_counts
current_selected_side
side_switch_count
active_rep_side_switch_count
active_rep_resync_count
```

Selected-side Front Raise için aktif bir rep sırasında:

```text
active_rep_side_switch_count == 0
```

beklenir.

Neutral durumda side stabilizer kontrollü side seçimi yapabilir; ancak aktif rep'in ortasında taraf değişimi rep context'ini bozmamalı veya duplicate count üretmemelidir.

`PARTIAL-10` run'ında primary metric effective PEAK entry gate olan strict `>78°` seviyesine ulaşmamalıdır.

Pose quality değerlendirmesinde seçilen taraftaki omuz-dirsek-bilek-kalça landmark'larının görünürlüğü kritiktir. Yüksek `low_landmark_likelihood`, `no_pose_frame_count` veya rejection oranı önce camera/setup problemi olarak incelenir; doğrudan threshold tuning gerekçesi değildir.

## 8. Performans Gate'i

Performans yalnız `fps_sample_count >= 10` olan yeterince uzun run'da değerlendirilir.

Provisional gate:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250
analysis_exception_count == 0
```

Tercihen `R6-FR-POS-20` ana performans run'ıdır.

Tek bir `current_analysis_fps` değeri PASS/FAIL kararı için kullanılmaz.

## 9. PASS / FAIL / INVALID / NOT_MEASURABLE

- `PASS`: planlanan senaryo ölçüldü ve kırmızı çizgi ihlali yok.
- `FAIL`: ölçülebilir senaryoda acceptance gate ihlal edildi.
- `INVALID`: yanlış build/SHA/exercise/camera setup veya bozuk execution nedeniyle kanıt kullanılamaz.
- `NOT_MEASURABLE`: mevcut telemetry ile gerekli sonuç güvenilir biçimde çıkarılamaz.

`NOT_MEASURABLE` ve `INVALID`, `PASS` değildir.

## 10. Front Raise Closure Kriteri

Front Raise ancak zorunlu run'lar tamamlanıp gerçek execution manifestte açıkça görüldüğünde `R6 Engineering Revalidated` statüsüne aday olur.

Tek bir başarılı positive set yeterli değildir. Özellikle natural neutral acquisition, partial-ROM rejection, teknik form, selected-side lifecycle ve persistence kanıtları closure'ın parçasıdır. Per-exercise occlusion bu hızlandırılmış matriste `SKIPPED` kabul edilir; shared reliability validation kapsamındaki ortak visibility/occlusion kanıtı kullanılır.

Validation sırasında gerçek reliability failure bulunursa validation durur, minimal fix uygulanır, yeni SHA-pinned profile build oluşturulur ve fix'in etkilediği kritik run'lar yeni SHA üzerinde tekrarlanır.
