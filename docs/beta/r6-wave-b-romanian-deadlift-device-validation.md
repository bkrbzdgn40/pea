# R6 Wave B - Romanian Deadlift Device Validation

Bu protokol R6 Dalga B kapsamında `Romanian Deadlift` exercise-specific gerçek cihaz validation'ını tanımlar. Zaman kısıtı nedeniyle hızlandırılmış range-rep matrisi kullanılır. Shared occlusion/visibility davranışı daha önce ortak reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract Özeti

Production kaynaklarına göre Romanian Deadlift:

- `exercise_type = romanian_deadlift`
- engine: `rangeRep`
- side mode: `selectedSide`
- primary metric direction: `decreasingToPeak`
- preferred camera: `side`
- unsupported camera: `front`
- primary metric: hip-angle based movement signal
- form metric: knee-angle stability signal
- `thresholdNeutral = 165°`
- `thresholdActive = 150°`
- `thresholdPeak = 115°`
- `formThreshold = 140°`
- range-rep validation minimum ROM delta: `25°`
- phase-quality floors: descent `350 ms`, ascent `300 ms`

Bu değerler cihaz failure kanıtı oluşmadan değiştirilmez.

### Equipment self-occlusion robustness

Büyük barbell plakalarının side-view'da özellikle ayak bileği landmark'ını kapatabildiği gerçek cihaz videosunda görüldü. Romanian Deadlift contract'ında `formMetric` yalnız `technique` rolündedir; tekrar detection'ı `primaryMetric` üzerinden yürür.

Bu nedenle pose acceptance artık yalnız `primaryMetric` landmark zincirini zorunlu tutar:

- omuz,
- kalça,
- diz.

Ayak bileği görünürse knee-angle technique feedback üretilmeye devam eder. Ayak bileği büyük plaka nedeniyle güvenilir değilse technique feedback kullanılamayabilir, fakat güvenilir primary hip-hinge metriği mevcutsa bu durum tek başına tüm pose'u reddedip counting'i kilitlememelidir.

Bu değişiklik threshold tuning değildir. `thresholdNeutral`, `thresholdActive`, `thresholdPeak` ve `formThreshold` değişmeden kalır.

## 2. Kamera ve Setup

Kamera kullanıcıyı **tam yandan** görmelidir.

Kadrajda aynı tarafta şu hatların görünmesi tercih edilir:

- omuz,
- kalça,
- diz,
- ayak bileği.

Kullanıcı ayakta dik başlar, dizleri hafif bükülü tutar ve hareketi kalça menteşesiyle yapar. Hareket squata dönüşecek kadar diz bükülmesi artırılmamalıdır.

Guide ile production camera contract aynı yöndedir: `side preferred`, `front unsupported`.

## 3. Hızlandırılmış Zorunlu Test Matrisi

| Run ID | Senaryo | Uygulama | Beklenen |
| --- | --- | --- | --- |
| `R6-RDL-PREFLIGHT-1` | Preflight | Doğru side-view setup'ta 1 temiz RDL | Natural standing neutral acquire olur; 1 tam lifecycle = 1 rep |
| `R6-RDL-POS-20` | Positive counting | Kontrollü tempoda 20 tam tekrar | Ground truth ile app count eşleşir; phantom/duplicate rep yok |
| `R6-RDL-STATIC-30` | Static negative | Yaklaşık 30 sn doğal standing neutral | `rep_count = 0`; phantom lifecycle yok |
| `R6-RDL-PARTIAL-10` | Partial / invalid ROM | 10 küçük hip-hinge denemesi; belirgin alt pozisyona ulaşmadan geri dön | Completed rep üretilmez |
| `R6-RDL-FORM-5` | Form violation | 5 tekrarda hareketi belirgin şekilde squata çevirip diz bükülmesini artır | Counting korunabilir; knee-angle form signal / lowConfidence / corrective feedback görülmeli |
| `R6-RDL-LIFE` | Pause/resume | Rep seti içinde 1 kontrollü pause/resume | Pause sırasında phantom rep yok; resume sonrası temiz reacquire |
| `R6-RDL-PERSIST` | Persistence | Ölçülebilir rep setiyle session bitir | Live/Summary/History aynı persisted rep değerini gösterir |

Per-exercise `OCC` testi **SKIPPED by policy**. Yalnız Romanian Deadlift'e özgü visibility/self-occlusion regression görülürse yeniden açılır.

## 4. Kırmızı Çizgiler

Aşağıdakilerden biri görülürse validation durdurulur ve ilgili katman incelenir:

- doğru side-view setup'ta doğal standing neutral'ın acquire edilememesi,
- tam hip-hinge tekrarlarının sistematik olarak sayılmaması,
- küçük partial hinge hareketlerinin completed rep olması,
- belirgin squat-benzeri diz bükülmesinin hiçbir teknik sinyal üretmemesi,
- pause/resume sırasında phantom veya duplicate rep,
- persistence yüzeylerinin ayrışması,
- analysis exception.
- büyük plaka ayak bileğini kapattığında primary hip-hinge metriği güvenilir olmasına rağmen tüm analizin sürekli `Vücut net görünmüyor` durumuna düşmesi.

## 5. Diagnostics Alanları

Diagnostics JSON varsa özellikle:

```text
exercise_type = romanian_deadlift
analysis_kind = rangeRep
range_rep_side_mode = selectedSide
range_rep_primary_metric_direction = decreasingToPeak
camera_view_contract.side = preferred
camera_view_contract.front = unsupported
range_rep_transition_counts
range_rep_abort_count
range_rep_validation_status_counts
range_rep_validation_reason_counts
current_selected_side
side_switch_count
active_rep_side_switch_count
active_rep_resync_count
analysis_exception_count
analysis_fps_p50
frame_processing_ms_p95
```

## 6. Performans Gate'i

Diagnostics örneği varsa:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250
analysis_exception_count == 0
```

Final hızlandırılmış run setinde diagnostics JSON tutulmazsa performans PASS iddiası ayrıca yapılmaz.

## 7. Threshold Tuning Kuralı

Tek kullanıcı veya tek video tek başına threshold tuning gerekçesi değildir.

Bir threshold değişikliği için en az iki güçlü kanıt aranır:

1. production contract / metric geometrisi açısından mantıksal gerekçe,
2. birden fazla tekrar veya koşulda aynı failure paterni,
3. değişiklik sonrası positive ve negative regression kapılarının korunması.

Failure önce camera/setup, pose quality, selected-side, primary metric, form metric, lifecycle veya persistence sınıfına ayrılır; minimum doğru katmana müdahale edilir.

## 8. Closure Kriteri

Romanian Deadlift şu kapılar geçildiğinde `R6 Engineering Revalidated` statüsüne aday olur:

1. preflight,
2. positive counting,
3. static negative,
4. partial / invalid-ROM rejection,
5. deliberate form-quality discrimination,
6. pause/resume lifecycle safety,
7. persistence.

Occlusion tekrar testi shared coverage nedeniyle zorunlu değildir.
