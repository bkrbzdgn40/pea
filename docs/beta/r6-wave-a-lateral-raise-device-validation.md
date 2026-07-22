# R6 Wave A - Lateral Raise Device Validation

Bu belge, R6 Dalga A kapsamındaki **Lateral Raise** için exercise-specific gerçek cihaz validation protokolüdür.

Amaç production threshold tuning yapmak değil; mevcut bilateral `increasing-to-peak` range-rep contract'ının doğru kamera kurulumu altında sayım, shallow-ROM reddi, tek-kol reddi, teknik form sinyali, occlusion, lifecycle, persistence ve performans davranışını SHA-pinned profile build üzerinde ölçmektir.

## 1. Değişmez Analiz Kontratı

Lateral Raise için güncel production gerçekleri:

- engine: `rangeRep`
- side mode: `bilateral`
- primary metric kind: `jointAngle`
- primary metric direction: `increasing-to-peak`
- preferred camera view: `front`
- unsupported camera view: `side`
- config: `assets/config/exercises/lateral_raise.json`
- neutral threshold: `32°`
- active threshold: `35°`
- effective active entry gate: yaklaşık `>38°` (`activeEntryMargin = 3°`)
- neutral/active hysteresis band: yaklaşık `32-38°`
- peak threshold: `80°`
- effective PEAK entry gate: yaklaşık `>83°` (`peakEntryMargin = 3°`)
- PEAK exit gate: yaklaşık `<72°` (`peakExitMargin = 8°`)
- ROM scoring target: `targetMaxAngle = 90°`
- validation minimum acceptable ROM delta: `35°`
- minimum toward-peak timing: `250 ms`
- minimum return timing: `300 ms`
- form threshold: `145°`
- coverage loss sırasında low-confidence kabulü: açık

Primary metric her kol için `elbow -> shoulder -> hip` omuz abdüksiyon açısıdır. Bilateral contract `increasing-to-peak` yönünde iki kolun **daha düşük** omuz açısını engine-facing primary metric olarak kullanır. Bu nedenle geride kalan kol PEAK girişini bloke etmelidir.

Form metriği `shoulder -> elbow -> wrist` dirsek açısıdır ve `technique` rolündedir. Bu sinyal counting gate değildir; belirgin dirsek bükülmesi completed rep'i otomatik olarak sıfırlamak yerine teknik kalite/feedback tarafında görünmelidir. Bilateral `syncScore` diagnostics için hesaplanmaya devam eder ancak Lateral Raise'ın dirsek-form metriğine dahil edilmez. Böylece sol-sağ omuz açısı farkı, `Dirseklerini gereksiz bükme.` feedback'ini yanlışlıkla tetiklemez.

Gerçek cihaz videosunda kabul edilebilir hafif dirsek fleksiyonunun eski `150°` sınırında aralıklı false-positive teknik uyarı ürettiği gözlendi. Lateral Raise'a özel `formThreshold` `145°` olarak hafifçe gevşetildi. Bu değişiklik counting/ROM gate'lerini etkilemez; yalnız teknik uyarının dirsek fleksiyonu toleransını yaklaşık `5°` artırır.

Düşük ışıklı gerçek-dünya videosunda counting akışı doğru çalışırken aynı dirsek feedback'inin kabul edilebilir formda hâlâ aralıklı tetiklendiği görüldü. İnceleme, bilateral aggregate form metriğinin `min(leftElbowForm, rightElbowForm, syncScore)` şeklinde olmasının hafif landmark jitter veya doğal sol-sağ zaman farkını dirsek bükülmesi gibi raporlayabildiğini gösterdi. Lateral Raise contract'ı bu nedenle `bilateralFormPolicy = sideFormOnly` kullanacak şekilde daraltıldı. Bilateral rep güvenliği değişmez: `increasing-to-peak` primary metric hâlâ geride kalan kolun daha düşük omuz açısını kullanır ve tek-kol hareketinin PEAK'e ulaşmasını bloke eder.

Gerçek cihaz videosunda doğal bilateral dinlenme pozisyonunun yaklaşık `20-30°` aralığında ölçüldüğü ve eski strict `primaryMetric < 20°` neutral kapısının hem ilk `acquireNeutral` hem rep sonundaki `completeRep` geçişini bloke ettiği görüldü. Lateral Raise'a özel `thresholdNeutral` bu nedenle `32°` olarak harden edildi. Effective active entry hâlâ yaklaşık `>38°` olduğu için doğal dinlenme ile aktif hareket başlangıcı arasında yaklaşık `6°` hysteresis/deadband korunur. Bu değişiklik PEAK threshold'unu veya generic range-rep engine davranışını değiştirmez.

Bu tuning adımlarından sonra validation sırasında threshold, bilateral policy veya feedback mapping yeniden değiştirilmez. Yeni bir fail önce camera/setup, pose quality, bilateral lagging-arm davranışı, lifecycle, occlusion/recovery, persistence veya performance olarak sınıflandırılır.

## 2. Kamera Kurulumu

Cihaz test yapan kişiye **doğrudan karşıdan** bakacak şekilde sabitlenmelidir.

Kadrajda aynı anda görünmesi gereken minimum bölgeler:

- iki omuz,
- iki dirsek,
- iki bilek,
- iki kalça.

Kollar yana açıldığında iki bilek de kadraj dışına çıkmamalıdır. Kamera, tam tepe pozisyonunda her iki omuz-dirsek-bilek hattını birlikte görecek kadar uzakta olmalıdır.

`front` burada subject-view kontratıdır; `camera_lens_direction` ile aynı kavram değildir. Arka kamera kullanılabilir, ancak cihaz kişinin önüne yerleştirilmelidir.

Tam yan veya belirgin çapraz kurulum bu validation için kullanılmaz. Böyle bir run protokol dışı kabul edilir ve manifestte `INVALID` olarak işaretlenir.

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
exercise_type == "lateral_raise"
config_asset_path == "assets/config/exercises/lateral_raise.json"
contract_profile == "rangeRep:lateralRaise"
range_rep_side_mode == "bilateral"
range_rep_primary_metric_direction == "increasingToPeak"
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

Planlanan adet ile gerçek execution farklıysa run ID geriye dönük değiştirilmez. Sapma açıkça yazılır.

## 5. Zorunlu Run'lar

| Run ID | Senaryo | Planlanan uygulama | Beklenen |
| --- | --- | --- | --- |
| `R6-LR-PREFLIGHT-1` | Smoke/preflight | 1 temiz bilateral lateral raise | 1 completed rep; profile/SHA/config/contract alanları doğru |
| `R6-LR-POS-20` | Kontrollü pozitif | 20 tam, eş zamanlı bilateral raise; kollar omuz hizası civarına | `absolute_count_error <= 1`; phantom/duplicate count yok |
| `R6-LR-STATIC-30` | Statik negatif | 30 sn kollar yanlarda neutral pozisyonda bekle | 0 phantom rep |
| `R6-LR-PARTIAL-10` | Partial motion | Her iki kolu yaklaşık `50-65°` omuz abdüksiyonunda geri çevirerek 10 sığ tekrar | 0 completed rep; neutral recovery/abort beklenir |
| `R6-LR-ONE-ARM-10` | Bilateral contract negatif | 10 kez yalnız tek kolu omuz hizasına kaldır, diğer kol neutral kalsın | 0 completed rep |
| `R6-LR-FORM-5` | Teknik form sinyali | 5 tam raise sırasında dirsekleri belirgin bük | Count ground truth ile uyumlu; form violation/low-confidence veya corrective feedback gözlenmeli |
| `R6-LR-OCC-3` | Kısa occlusion | Aktif rep sırasında yaklaşık 1 sn pose kaybı, 3 kontrollü deneme | Phantom/auto-complete yok; completed count ground truth ile tutarlı |
| `R6-LR-LIFE-3` | Pause/resume | Aktif rep bağlamında pause/resume, 3 döngü | Dönüşte phantom rep yok; active context güvenli temizlenir/reacquire edilir |
| `R6-LR-PERSIST` | Persistence | 5 temiz bilateral raise ile session bitir | Live = Summary = History = 5 |

## 6. Lateral Raise'a Özel Kırmızı Çizgiler

Aşağıdakilerden biri görülürse ilgili run `FAIL` olur:

- tek kol hareket ederken completed bilateral rep üretilmesi,
- neutral/static beklemede phantom rep,
- `50-65°` shallow motion'ın completed rep'e dönüşmesi,
- kısa occlusion veya pause/resume sonrasında phantom/duplicate rep,
- displayed/session/history rep uyuşmazlığı,
- analysis exception,
- profile performans gate'inin geçilememesi.

`R6-LR-FORM-5` teknik kalite testi counting negatif testi değildir. Dirsek bükülmesine rağmen count ground truth ile uyumlu kalabilir; burada amaç `formMetric`/feedback yolunun belirgin form bozulmasını yakalayıp yakalamadığını ölçmektir.

## 7. Diagnostics Değerlendirmesi

Pozitif/partial/one-arm/form/lifecycle run'larında özellikle:

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

Bilateral Lateral Raise için normal durumda:

```text
current_selected_side == null
side_switch_count == 0
active_rep_side_switch_count == 0
```

olması beklenir.

Bilateral primary metric lagging-arm güvenliği nedeniyle tek-kol run'ında diğer kol neutral kaldıkça PEAK oluşmamalıdır. `PARTIAL-10` run'ında iki kol da effective PEAK entry gate olan yaklaşık `>83°` seviyesine ulaşmamalıdır.

Pose quality değerlendirmesinde iki kol yana açılırken bileklerin kadrajdan çıkmaması kritiktir. Yüksek `low_landmark_likelihood`, `no_pose_frame_count` veya rejection oranı önce camera/setup problemi olarak incelenir; doğrudan threshold tuning gerekçesi değildir.

## 8. Performans Gate'i

Performans yalnız `fps_sample_count >= 10` olan yeterince uzun run'da değerlendirilir.

Provisional gate:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250
analysis_exception_count == 0
```

Tercihen `R6-LR-POS-20` ana performans run'ıdır.

Tek bir `current_analysis_fps` değeri PASS/FAIL kararı için kullanılmaz.

## 9. PASS / FAIL / INVALID / NOT_MEASURABLE

- `PASS`: planlanan senaryo ölçüldü ve kırmızı çizgi ihlali yok.
- `FAIL`: ölçülebilir senaryoda acceptance gate ihlal edildi.
- `INVALID`: yanlış build/SHA/exercise/camera setup veya bozuk execution nedeniyle kanıt kullanılamaz.
- `NOT_MEASURABLE`: mevcut telemetry ile gerekli sonuç güvenilir biçimde çıkarılamaz.

`NOT_MEASURABLE` ve `INVALID`, `PASS` değildir.

## 10. Lateral Raise Closure Kriteri

Lateral Raise ancak zorunlu run'lar tamamlanıp gerçek execution manifestte açıkça görüldüğünde `R6 Engineering Revalidated` statüsüne aday olur.

Tek bir başarılı positive set yeterli değildir. Özellikle `PARTIAL`, `ONE-ARM`, teknik form, lifecycle ve persistence kanıtları closure'ın parçasıdır.

Validation sırasında gerçek reliability failure bulunursa validation durur, minimal fix uygulanır, yeni SHA-pinned profile build oluşturulur ve fix'in etkilediği kritik run'lar yeni SHA üzerinde tekrarlanır.
