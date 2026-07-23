# R6 Wave A - Lateral Raise Results

Bu belge, R6 Dalga A Lateral Raise engineering revalidation closure kaydıdır.

## 1. Closure Kararı

**Status: `R6 Engineering Revalidated`**

Lateral Raise gerçek cihaz validation'ı sırasında iki production reliability problemi bulundu:

1. doğal bilateral dinlenme pozisyonunun yaklaşık `20-30°` ölçülmesine rağmen strict `thresholdNeutral = 20°` nedeniyle ilk `acquireNeutral` ve rep sonundaki neutral reacquisition'ın bloke olması,
2. bilateral `syncScore` jitter/asimetrisinin dirsek-form metriğine karışması nedeniyle kabul edilebilir hafif dirsek fleksiyonunda yanıltıcı `Dirseklerini gereksiz bükme.` feedback'i oluşması.

Minimal hardening sonrası final SHA üzerinde controlled positive, static negative, shallow-ROM rejection, one-arm bilateral rejection, deliberate form violation, short occlusion recovery, pause/resume lifecycle, persistence ve provisional performance kabul edilmiştir.

Final validation SHA:

`d1120a32e870ee4c8efa466e9b0fda3593a2b69d`

Bu closure **formal protocol-complete değildir**. Dedicated `PREFLIGHT-1` diagnostics export'u tutulmamış, `LIFE-3` için planlanan üç pause/resume döngüsü yerine bir döngü içinde üç toplam rep uygulanmış ve persistence için exact rep değeri closure kaydında sabitlenmemiştir.

## 2. Fix Özeti

### Neutral acquisition / reacquisition

- `thresholdNeutral`: `20° -> 32°`
- effective active entry: yaklaşık `>38°`
- doğal neutral ile active entry arasında yaklaşık `6°` hysteresis/deadband korunur
- generic range-rep engine ve PEAK threshold'u değişmez

Gerçek cihaz videosunda doğal başlangıç pozisyonu yaklaşık `20-30°` ölçülürken eski strict `<20°` gate engine'i arm etmiyor ve completed rep'i kapatamıyordu. `32°` Lateral Raise'a özel neutral threshold bu failure'ı giderdi.

### Dirsek form toleransı ve feedback semantiği

- `formThreshold`: `150° -> 145°`
- Lateral Raise bilateral form policy: `includeSync -> sideFormOnly`
- dirsek form metriği artık `min(leftElbowForm, rightElbowForm)` üzerinden değerlendirilir
- `syncScore` diagnostics için hesaplanmaya devam eder, ancak dirsek feedback'ini tetiklemez
- bilateral counting güvenliği değişmez; increasing-to-peak primary metric geride kalan kolu kullanmaya devam eder

Bu ayrım kabul edilebilir hafif bilateral asimetri veya landmark jitter'ının dirsek bükülmesi gibi raporlanmasını azaltırken deliberate bent-elbow run'ında form violation sinyalini korudu.

## 3. Cihaz Kanıtı

| Senaryo | Diagnostics / kanıt | Ground truth | Uygulama | Sonuç |
| --- | --- | ---: | ---: | --- |
| Controlled positive | `diagnostics_v6_lateral_raise_20260722_230950.json` | 20 | 20 | PASS |
| Static negative | `diagnostics_v6_lateral_raise_20260722_231211.json` | 0 | 0 | PASS |
| Shallow-ROM negative | `diagnostics_v6_lateral_raise_20260722_231547.json` | 0 / 10 shallow deneme | 0 | PASS |
| One-arm negative | `diagnostics_v6_lateral_raise_20260722_232249.json` | 0 / 10 tek-kol deneme | 0 | PASS |
| Deliberate bent-elbow form | `diagnostics_v6_lateral_raise_20260722_232538.json` | 5 | 5 | PASS |
| Controlled short occlusion | `diagnostics_v6_lateral_raise_20260722_232817.json` | 3 | 3 | PASS |
| Pause/resume lifecycle | `diagnostics_v6_lateral_raise_20260722_233003.json` | 3 | 3 | PASS |
| Persistence | kullanıcı gerçek cihaz doğrulaması | eşleşme | Live = Summary = History | PASS |

### Controlled positive - 20 rep

- `rep_count = 20`
- `completeRep = 20`
- `range_rep_abort_count = 0`
- `valid = 18`
- `lowConfidence = 2`
- `persistentFormBreak = 2`
- `analysis_exception_count = 0`
- `analysis_fps_p50 = 8.6873`
- `frame_processing_ms_p95 = 81`

Sonuç: **PASS**

### Static negative

Yaklaşık `32.857 s` neutral beklemede:

- `rep_count = 0`
- yalnız `acquireNeutral = 1`
- phantom lifecycle transition yok
- exception = 0

Sonuç: **PASS**

### Shallow-ROM negative

10 shallow bilateral denemede:

- `rep_count = 0`
- `reachPeak = 0`
- `startDescending = 11`
- `abortToNeutral = 11`
- `range_rep_abort_count = 11`

Ek active excursion completed rep üretmeden güvenli biçimde neutral'a dönmüştür.

Sonuç: **PASS**

### One-arm bilateral negative

10 tek-kol denemede:

- `rep_count = 0`
- `completeRep = 0`
- `reachPeak = 0`
- yalnız `acquireNeutral = 1`

Run'ın son bölümünde pose quality düşmüş olsa da 334 detected pose frame'in 303'ü accepted olmuş ve bilateral PEAK oluşmamıştır.

Sonuç: **PASS**

### Deliberate bent-elbow form

5 deliberately bent-elbow tam raise:

- `rep_count = 5`
- `completeRep = 5`
- `persistentFormBreak = 5`
- `lowConfidence = 4`
- `invalid = 1`
- `insufficientRom = 1`

Bu sonuç, feedback semantiği gevşetilirken belirgin gerçek dirsek form bozulmasının kaybolmadığını gösterir.

Sonuç: **PASS**

### Controlled short occlusion

3 rep:

- `rep_count = 3`
- `completeRep = 3`
- `brief_occlusion_count = 2`
- `brief_occlusion_recovery_count = 2`
- `brief_occlusion_abort_count = 0`
- `coverageLoss = 2`
- exception = 0

Kısa visibility kaybı phantom/duplicate rep veya abort üretmemiştir.

Sonuç: **PASS**

### Pause / resume

1 kontrollü pause/resume döngüsü içinde toplam 3 rep:

- `rep_count = 3`
- `completeRep = 3`
- `valid = 3`
- `range_rep_abort_count = 0`
- `analysis_exception_count = 0`

Runtime lifecycle sonucu güvenlidir. Buna rağmen global telemetry `brief_occlusion_count = 20`, `brief_occlusion_abort_count = 18` ve `resync_count = 18` üretmiştir. Bu diagnostics semantiği counting closure'ını bloklamaz ve `docs/beta/r6-wave-a-findings.md` içinde P1 olarak izlenir.

Sonuç: **PASS** runtime / **P1 telemetry finding**

### Persistence

Kullanıcı gerçek cihazda Live, Summary ve History persistence yüzeylerinin eşleştiğini doğrulamıştır. Exact persisted rep değeri closure sohbet kaydında sabitlenmemiştir.

Sonuç: **PASS**

## 4. Contract Profile Dokümantasyon Düzeltmesi

Validation protokolünün ilk sürümü `contract_profile == "rangeRep:lateralRaise"` bekliyordu. Production diagnostics bu alanı exercise identity olarak değil `RangeRepExtensionProfile` olarak üretir.

Lateral Raise exercise-specific analysis extension kullanmadığı için doğru değer:

`rangeRep:none`

Bu bir runtime reliability failure değildir. Egzersiz kimliği şu alanlarla doğrulanır:

- `exercise_type = lateral_raise`
- `config_asset_path = assets/config/exercises/lateral_raise.json`
- `range_rep_side_mode = bilateral`
- `range_rep_primary_metric_direction = increasingToPeak`

Protokol closure kapsamında production davranışıyla hizalanmıştır.

## 5. Exploratory Low-Light Notu

Formal run setinden önce düşük ışıklı gerçek-dünya denemesi yapıldı. Counting akışı çalıştı ve kullanıcı omuz kası hedeflemesini gerçek kullanım açısından olumlu değerlendirdi. Ancak daha düşük ışıkta landmark jitter belirginleştiği için bu koşul formal Lateral Raise acceptance gate'i olarak kullanılmadı.

Bu exploratory gözlem production low-light threshold tuning gerekçesi değildir.

## 6. Protocol Sapmaları

- Dedicated `R6-LR-PREFLIGHT-1` diagnostics export'u final closure setinde tutulmadı; aynı final SHA üzerindeki `POS-20` build/SHA/config smoke kanıtını supersede etti.
- `R6-LR-LIFE-3`: planlanan üç pause/resume döngüsü yerine bir pause/resume döngüsü içinde üç toplam rep uygulandı.
- Persistence başarıyla kullanıcı tarafından doğrulandı; exact persisted rep değeri closure kaydında sabitlenmedi.
- Validation sırasında neutral gate ve feedback semantics hardening yapıldığı için hazırlık ile final acceptance aynı değişmez production state üzerinde başlamadı; final formal JSON run'ları tek SHA `d1120a32e870ee4c8efa466e9b0fda3593a2b69d` üzerinde toplandı.

Bu nedenle sonuç **`R6 Engineering Revalidated`** olarak tutulur; formal protocol-complete iddiası yapılmaz.

## 7. Sonuç

Lateral Raise için şu acceptance alanları gerçek cihazda desteklenmiştir:

- full bilateral counting,
- natural neutral acquisition ve rep-end reacquisition,
- static phantom-rep safety,
- shallow-ROM rejection,
- one-arm bilateral rejection,
- deliberate elbow-form violation detection,
- short occlusion recovery,
- pause/resume runtime lifecycle safety,
- persistence,
- provisional performance gate,
- exception safety.

Açık diagnostics P1 finding'i runtime closure'ını bloklamaz.

Matrix status: **`R6 Engineering Revalidated`**.
