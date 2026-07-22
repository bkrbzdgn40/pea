# R6 Wave A - Biceps Curl Device Validation

Bu belge, R6 Dalga A'nın ilk egzersizi olan **Biceps Curl** için exercise-specific gerçek cihaz validation protokolüdür.

Amaç production threshold tuning yapmak değil; mevcut bilateral range-rep contract'ının doğru kamera kurulumu altında sayım, negatif senaryo, partial motion, tek-kol reddi, occlusion, lifecycle, persistence ve performans davranışını SHA-pinned profile build üzerinde ölçmektir.

## 1. Değişmez Analiz Kontratı

Biceps Curl için güncel production gerçekleri:

- engine: `rangeRep`
- side mode: `bilateral`
- primary metric direction: `decreasing-to-peak`
- preferred camera view: `front`
- unsupported camera view: `side`
- config: `assets/config/exercises/biceps_curl.json`
- neutral threshold: `155°`
- active threshold: `140°`
- peak threshold: `78°`
- effective PEAK entry gate: yaklaşık `<75°` (`peakEntryMargin = 3°`)
- ROM scoring target: `targetMinAngle = 75°`
- validation minimum acceptable peak angle: `minAcceptableRomAngle = 110°` (count gate değildir)
- minimum descent timing: `250 ms`
- minimum ascent timing: `250 ms`
- coverage loss sırasında low-confidence kabulü: açık

Bu protokol, R6 sırasında gözlenen shallow-ROM erken sayım bulgusundan sonra sıkılaştırılan `78°` peak threshold ile çalışır. Validation sırasında threshold, bilateral policy veya feedback mapping yeniden değiştirilmez. Fail önce camera/setup, pose quality, bilateral metric, lifecycle, occlusion/recovery, persistence veya performance olarak sınıflandırılır.

## 2. Kamera Kurulumu

Cihaz, test yapan kişiye **doğrudan karşıdan** bakacak şekilde sabitlenmelidir.

Kadrajda aynı anda görünmesi gereken minimum bölgeler:

- iki omuz,
- iki dirsek,
- iki bilek,
- iki kalça.

`front` burada subject-view kontratıdır; `camera_lens_direction` ile aynı kavram değildir. Arka kamera kullanılabilir, ancak cihaz kişinin önüne yerleştirilmelidir.

30-45 derece çapraz veya tam yan kurulum bu validation için kullanılmaz. Böyle bir run protokol dışı kabul edilir ve manifestte `INVALID` olarak işaretlenir.

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
exercise_type == "biceps_curl"
config_asset_path == "assets/config/exercises/biceps_curl.json"
contract_profile == "rangeRep:bicepsCurl"
range_rep_side_mode == "bilateral"
analysis_exception_count == 0
```

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

Planlanan adet ile gerçek execution farklıysa run ID geriye dönük değiştirilmez. Sapma açıkça yazılır. Böylece R5'teki plan/execution belirsizliği tekrar edilmez.

## 5. Zorunlu Run'lar

| Run ID | Senaryo | Planlanan uygulama | Beklenen |
| --- | --- | --- | --- |
| `R6-BC-PREFLIGHT-1` | Smoke/preflight | 1 temiz bilateral curl | 1 completed rep; profile/SHA/config/contract alanları doğru |
| `R6-BC-POS-20` | Kontrollü pozitif | 20 tam, eş zamanlı bilateral curl | `absolute_count_error <= 1`; beklenmeyen invalid çoğunluğu yok |
| `R6-BC-STATIC-30` | Statik negatif | 30 sn başlangıç/neutral pozisyonunda bekle | 0 phantom rep |
| `R6-BC-PARTIAL-10` | Partial motion | Her iki dirsek açısını yaklaşık `80-100°` aralığında tutarak 10 sığ bilateral curl | 0 completed rep; abort/neutral recovery beklenir |
| `R6-BC-ONE-ARM-10` | Bilateral contract negatif | 10 kez yalnız tek kolu tam curl yap, diğer kol neutral kalsın | 0 completed rep |
| `R6-BC-OCC-3` | Kısa occlusion | Aktif rep sırasında yaklaşık 1 sn pose kaybı, 3 kontrollü deneme | Phantom/auto-complete yok; completed count ground truth ile tutarlı |
| `R6-BC-LIFE-3` | Pause/resume | Aktif rep bağlamında pause/resume, 3 döngü | Dönüşte phantom rep yok; active context güvenli temizlenir/reacquire edilir |
| `R6-BC-PERSIST` | Persistence | 3 temiz bilateral curl ile session bitir | Live = Summary = History = 3 |

## 6. Biceps Curl'a Özel Kırmızı Çizgiler

Aşağıdakilerden biri görülürse ilgili run `FAIL` olur:

- tek kol hareket ederken completed rep üretilmesi,
- neutral/static beklemede phantom rep,
- partial motion'ın completed rep'e dönüşmesi,
- kısa occlusion veya pause/resume sonrasında phantom rep,
- displayed/session/history rep uyuşmazlığı,
- analysis exception,
- profile performans gate'inin geçilememesi.

Bilateral contract nedeniyle iki kolun aynı rep içinde birlikte gözlemlenmesi gerekir. Tek-kol testi teknik coaching testi değil, counting safety testidir.

## 7. Diagnostics Değerlendirmesi

Pozitif/partial/one-arm/lifecycle run'larında özellikle:

```text
rep_count
range_rep_transition_counts
range_rep_abort_count
range_rep_validation_count
range_rep_validation_status_counts
range_rep_validation_reason_counts
active_rep_resync_count
side_switch_count
active_rep_side_switch_count
```

Bilateral Biceps Curl için normal durumda:

```text
current_selected_side == null
side_switch_count == 0
active_rep_side_switch_count == 0
```

olması beklenir.

Pose quality değerlendirmesinde iki kol ve iki kalçanın görünürlüğü önemlidir. Yüksek `low_landmark_likelihood`, `no_pose_frame_count` veya rejection oranı önce camera/setup problemi olarak incelenir; doğrudan threshold tuning gerekçesi değildir.

## 8. Performans Gate'i

Performans yalnız `fps_sample_count >= 10` olan yeterince uzun run'da değerlendirilir.

Provisional gate:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250
analysis_exception_count == 0
```

Tercihen `R6-BC-POS-20` ana performans run'ıdır.

Tek bir `current_analysis_fps` değeri PASS/FAIL kararı için kullanılmaz.

## 9. PASS / FAIL / INVALID / NOT_MEASURABLE

- `PASS`: planlanan senaryo ölçüldü ve kırmızı çizgi ihlali yok.
- `FAIL`: ölçülebilir senaryoda acceptance gate ihlal edildi.
- `INVALID`: yanlış build/SHA/exercise/camera setup veya bozuk execution nedeniyle kanıt kullanılamaz.
- `NOT_MEASURABLE`: mevcut telemetry ile gerekli sonuç güvenilir biçimde çıkarılamaz.

`NOT_MEASURABLE` ve `INVALID`, `PASS` değildir.

## 10. Biceps Curl Closure Kriteri

Biceps Curl ancak zorunlu run'lar tamamlanıp gerçek execution manifestte açıkça görüldüğünde `Device Validated` benzeri daha güçlü bir statüye aday olur.

Tek bir başarılı positive set yeterli değildir. Özellikle `ONE-ARM`, `PARTIAL`, lifecycle ve persistence negatif/güvenlik kanıtları closure'ın parçasıdır.

Bu validation tamamlanmadan production threshold veya bilateral policy tuning yapılmaz.

## 11. Shallow-ROM Reliability Hardening

R6 cihaz videosunda yalnız absolute elbow-angle PEAK eşiğinin shallow curl'ü
ayırt etmek için yeterli olmadığı doğrulandı. ML pose geometrisi fiziksel olarak
sığ bir curl sırasında bile elbow angle'ı PEAK eşiğinin altında gösterebildi.

Biceps Curl PEAK artık iki bağımsız koşul ister:

1. Bilateral primary elbow-angle gate geçilmeli.
2. Her iki wrist, kullanıcının neutral pozisyonundaki shoulder-wrist mesafesine
   göre yeterince kapanmış olmalı.

Neutral baseline her kol için ayrı tutulur. PEAK sırasında her iki kolun
`current shoulder-wrist distance / neutral shoulder-wrist distance` oranı
`<= 0.64` olmalıdır. Bu ikinci kapı elbow landmark'ından bağımsız olarak
shoulder ve wrist geometrisini kullanır.

Ayrıca Biceps Curl live form metriği artık bilateral elbow-angle sync jitter'ını
`formViolation` içine katmaz. Generic form uyarısı yalnız iki kolun upper-arm
posture skorlarının kötüsüne dayanır ve UI metni ölçülen semantiğe uygun olarak
`Dirseklerini gövdene yakın tut.` şeklindedir.

### Fix sonrası zorunlu tekrar doğrulama

1. 1 temiz full-ROM bilateral rep: `rep_count == 1`
2. 10 shallow bilateral rep, fiziksel tepe yaklaşık 80-90 derece:
   `rep_count == 0`, `completeRep == 0`
3. 20 kontrollü full-ROM bilateral rep: absolute count error `<= 1`
4. One-arm-only 10 deneme: `rep_count == 0`
5. Form feedback gözlemi: sabit ve gövdeye yakın dirseklerde sürekli corrective
   warning görülmemeli.

Bu kapılar geçmeden Biceps Curl `Device Validated` olarak kapatılmaz.
