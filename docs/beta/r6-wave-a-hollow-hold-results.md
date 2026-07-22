# R6 Wave A - Hollow Hold Results

Bu belge, R6 Dalga A Hollow Hold engineering revalidation ve hold visibility telemetry hardening closure kaydıdır.

## 1. Closure Kararı

**Status: `R6 Engineering Revalidated`**

Hollow Hold, commit `036a81f4b65dbd78fb197e5a6f807c7178d90da0` üzerinde profile build ile gerçek cihazda valid hold accuracy, invalid/form-break safety, short/long visibility lifecycle, pause/resume, persistence, provisional performance ve exception safety açısından doğrulanmıştır.

Aynı execution, R5 Plank revalidation sırasında bulunan hold visibility observability açığının yeni Diagnostics schema v6 alanlarıyla kapanış kanıtını da üretmiştir.

Bu closure **formal protocol-complete değildir**. Telemetry smoke planı Plank öngörürken execution Hollow Hold üzerinde yapılmış, ilk long-gap run `INCONCLUSIVE` kalmış ve formal çoklu tekrar/döngü seti uygulanmamıştır.

## 2. Hold Visibility Telemetry Closure

SHA: `036a81f4b65dbd78fb197e5a6f807c7178d90da0`

### Short gap

Kanıt: `diagnostics_v6_hollow_hold_20260722_165459.json`

- `hold_visibility_suspend_count = 1`
- `hold_visibility_recovery_count = 1`
- `hold_visibility_abort_count = 0`
- `hold_visibility_suspended_ms_total = 701`
- `last_hold_visibility_gap_ms = 701`
- `hold_is_visibility_suspended = false`
- `analysis_exception_count = 0`
- `analysis_fps_p50 = 7.9681`
- `frame_processing_ms_p95 = 111`

Sonuç: **PASS**

### Long gap - first attempt

Kanıt: `diagnostics_v6_hollow_hold_20260722_165636.json`

- best hold = 6 sn
- current hold = 4 sn
- pose reacquisition = 1
- yeni hold-visibility sayaçları = 0

Tek JSON event yolunu açıklayamadığı için sonuç: **INCONCLUSIVE**

### Long gap - repeat

Kanıt: `diagnostics_v6_hollow_hold_20260722_165832.json`

- `hold_visibility_suspend_count = 1`
- `hold_visibility_recovery_count = 0`
- `hold_visibility_abort_count = 1`
- `hold_visibility_suspended_ms_total = 1669`
- `last_hold_visibility_gap_ms = 1669`
- best hold = 5 sn
- current hold = 4 sn
- `analysis_exception_count = 0`
- `analysis_fps_p50 = 7.9444`
- `frame_processing_ms_p95 = 118`

Sonuç: **PASS**

Bu iki kabul run'ı sonrasında R5 F1 hold visibility lifecycle telemetry finding'i **CLOSED** kabul edilir.

## 3. Hollow Hold Cihaz Kanıtı

### 30 saniye valid hold

Kanıt: `diagnostics_v6_hollow_hold_20260722_170033.json`

- ground truth = 30 sn
- `current_hold_seconds = 30`
- `best_hold_seconds = 30`
- `is_holding = true`
- bütün Hollow Hold signal validity alanları = true
- visibility abort = 0
- exception = 0
- `analysis_fps_p50 = 7.9523`
- `frame_processing_ms_p95 = 130`

Sonuç: **PASS**

### Invalid posture / form break

Kanıt: `diagnostics_v6_hollow_hold_20260722_170450.json`

Doğru ve yanlış pozisyon arasında geçiş yapılan run sonunda:

- `best_hold_seconds = 4`
- `current_hold_seconds = 0`
- `current_phase = BROKEN`
- `is_holding = false`
- `kneeExtension = false`
- feedback = `straighten_knees`
- exception = 0

Yanlış form aktif hold süresini ilerletmemiştir.

Sonuç: **PASS**

### Pause / resume

Kanıt: `diagnostics_v6_hollow_hold_20260722_170540.json`

- `best_hold_seconds = 5`
- `current_hold_seconds = 3`
- final phase = `HOLDING`
- bütün Hollow Hold signal validity alanları = true
- exception = 0
- `analysis_fps_p50 = 7.8278`
- `frame_processing_ms_p95 = 80`

Pause öncesi best hold korunmuş, resume sonrası aktif hold ayrı devam etmiştir; background/pause süresinin hold'a taşındığına dair kanıt yoktur.

Sonuç: **PASS**

### Persistence

Kullanıcı gerçek cihazda 10 saniyelik Hollow Hold persistence kaydını doğrulamıştır.

Sonuç: **PASS**

## 4. Protocol Sapmaları

- Hold visibility real-device smoke planı Plank öngörürken execution Hollow Hold üzerinde yapıldı.
- İlk long-gap denemesi event telemetry üretmediği için `INCONCLUSIVE` bırakıldı; aynı SHA üzerinde tekrar edilen 1669 ms run closure kanıtı oldu.
- Hollow Hold için formal çoklu-run cihaz protokolü önceden ayrı bir dokümanda sabitlenmedi; validation engineering acceptance senaryolarıyla yürütüldü.
- Persistence 10 saniye olarak kullanıcı tarafından doğrulandı; diagnostics export persistence storage yüzeylerini ayrı ayrı taşımaz.

Bu nedenle sonuç **`R6 Engineering Revalidated`** olarak tutulur; formal protocol-complete iddiası yapılmaz.

## 5. Sonuç

Hollow Hold için şu acceptance alanları gerçek cihazda desteklenmiştir:

- 30 saniye valid hold accuracy,
- invalid posture / form-break safety,
- short visibility suspend + recovery,
- long visibility suspend + abort,
- hidden-time safety,
- pause/resume lifecycle safety,
- persistence,
- provisional performance gate,
- exception safety.

Matrix status: **`R6 Engineering Revalidated`**.
