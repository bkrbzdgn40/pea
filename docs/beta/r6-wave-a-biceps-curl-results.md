# R6 Wave A - Biceps Curl Results

Bu belge, R6 Dalga A Biceps Curl engineering revalidation closure kaydıdır.

## 1. Closure Kararı

**Status: `R6 Engineering Revalidated`**

Biceps Curl gerçek cihaz validation'ı sırasında iki production reliability problemi bulundu:

1. fiziksel olarak shallow curl'ün absolute elbow-angle metriği nedeniyle completed rep'e dönüşebilmesi,
2. bilateral angle-sync jitter'ın generic form violation içine karışması nedeniyle kullanıcı dirseklerini sabit tutarken yanıltıcı corrective feedback oluşabilmesi.

Minimal hardening sonrası kritik positive ve negative cihaz run'ları tekrarlandı. Shallow-ROM discrimination, full-ROM counting, bilateral enforcement, occlusion safety, pause/resume, persistence ve performans kabul edildi.

Bu closure **formal protocol-complete değildir**. Multi-SHA execution ve planlanan bazı tekrar/döngü adetlerindeki sapmalar Bölüm 4'te kayıtlıdır.

## 2. Fix Özeti

- `thresholdPeak`: `88° -> 78°`
- effective primary PEAK entry: yaklaşık `<75°`
- Biceps Curl için secondary PEAK gate:
  - her kolun neutral `shoulder-wrist` mesafesi ayrı baseline alınır,
  - PEAK için her iki kolda `current / neutral <= 0.64` gerekir,
  - gate yalnız `DESCENDING -> PEAK` geçişini kısıtlar.
- Biceps Curl form metric'i bilateral angle-sync jitter'ı generic `formViolation` birleşimine katmaz.
- corrective UI semantiği: `Dirseklerini gövdene yakın tut.`

## 3. Cihaz Kanıtı

### Pre-fix baseline / setup kanıtı

| Run | SHA | Sonuç |
| --- | --- | --- |
| Preflight 1 full rep | `b2f4a3bcef252f6a9e1894f53a9f0207994917b8` | 1 -> 1, PASS |
| Static negative ~30 sn | aynı SHA | 0 phantom rep, PASS |

Pre-fix controlled POS-20 run'ında 20 ground-truth rep'e karşı 18 count görülmesi ve video incelemesinde shallow motion'ın completed rep'e dönüşebilmesi validation'ı bloklamış ve hardening'i tetiklemiştir.

### Post-fix kritik run'lar

Fix sonrası SHA:

`db33f6243dd16c1cbaefc5b15231d9f4ba96053d`

| Senaryo | Diagnostics / kanıt | Ground truth | Uygulama | Sonuç |
| --- | --- | ---: | ---: | --- |
| Full-ROM smoke | `diagnostics_v6_biceps_curl_20260722_161901.json` | 1 | 1 | PASS |
| Shallow-ROM negative | `diagnostics_v6_biceps_curl_20260722_161726.json` | 0 / 10 shallow deneme | 0 | PASS |
| Controlled positive | `diagnostics_v6_biceps_curl_20260722_162317(2).json` | 20 | 20 | PASS |
| One-arm negative | `diagnostics_v6_biceps_curl_20260722_162432(2).json` | 0 / 10 tek-kol deneme | 0 | PASS |
| Controlled occlusion | `diagnostics_v6_biceps_curl_20260722_162828(1).json` | 1 | 1 | PASS |
| Pause/resume | `diagnostics_v6_biceps_curl_20260722_163341.json` | 1 | 1 | PASS |
| Persistence | kullanıcı gerçek cihaz doğrulaması | 5 | Live=5, Summary=5, History=5 | PASS |

Ana POS-20 performans sonucu:

- `fps_sample_count = 112`
- `analysis_fps_p50 = 8.7977`
- `frame_processing_ms_p95 = 95`
- `analysis_exception_count = 0`

## 4. Protocol Sapmaları

- Validation sırasında reliability fix gerektiği için execution tek SHA üzerinde tamamlanmadı.
- `R6-BC-STATIC-30` secondary PEAK gate öncesi SHA üzerinde çalıştırıldı.
- `R6-BC-OCC-3`: planlanan 3 kontrollü döngü yerine 1 kontrollü run yapıldı.
- `R6-BC-LIFE-3`: planlanan 3 döngü yerine 1 pause/resume run yapıldı.
- `R6-BC-PERSIST`: planlanan 3 yerine 5 rep yapıldı ve 5/5/5 persistence doğrulandı.

Bu nedenle sonuç `R6 Engineering Revalidated` olarak tutulur; formal protocol-complete iddiası yapılmaz.

## 5. Açık Finding

Post-fix POS-20 run'ında counting 20/20 olmasına rağmen:

- `valid = 6`
- `lowConfidence = 14`
- `excessiveDescentSpeed = 8`
- `excessiveAscentSpeed = 10`
- `persistentFormBreak = 1`

Validation reason sayaçları aynı rep üzerinde birden fazla neden taşıyabileceği için toplamları rep sayısıyla bire bir toplanmaz.

`persistentFormBreak` önceki controlled run'daki 11 seviyesinden 1'e düşmüştür; form-feedback semantik hardening'i olumlu sinyal vermiştir. Tempo-confidence hassasiyeti counting closure'ını bloklamaz ve `docs/beta/r6-wave-a-findings.md` içinde izlenir.

## 6. Sonuç

Biceps Curl için şu acceptance alanları gerçek cihazda desteklenmiştir:

- full-ROM counting,
- shallow-ROM rejection,
- static phantom-rep safety,
- bilateral one-arm rejection,
- controlled occlusion safety,
- pause/resume lifecycle safety,
- persistence,
- provisional performance gate,
- exception safety.

Matrix status: **`R6 Engineering Revalidated`**.
