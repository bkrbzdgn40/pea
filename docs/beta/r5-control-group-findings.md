# R5 Control-Group Findings

Bu belge, R5 gerçek cihaz execution'ında bulunan ve kontrol grubu closure'ını engellemeyen açık engineering konularını tutar. Bulgular kanıt olmadan threshold tuning gerekçesi değildir.

## F1 - Hold visibility lifecycle telemetry eksikliği

- Durum: **CLOSED - real-device short/long gap telemetry verified**
- Öncelik: **P0 - R6 hold-family validation öncesi**
- Katman: Diagnostics / observability
- Etkilenen alan: Plank ve gelecekte Hollow Hold, Wall Sit, Side Plank
- Kanıt:
  - `diagnostics_v6_plank_20260722_141940.json`
  - `diagnostics_v6_plank_20260722_142108.json`
  - `diagnostics_v6_plank_20260722_142259.json`

### Gözlem

Hold run'larında `no_pose_frame_count` ve `pose_reacquisition_count` değişirken generic `brief_occlusion_*` sayaçları hold visibility lifecycle'ını temsil etmiyor. Mevcut `hold_is_visibility_suspended` yalnız snapshot anındaki state'i gösteriyor; geçmiş suspend/recovery/abort olaylarını kanıtlamıyor.

### Minimum doğru çözüm

Hold davranışını değiştirmeden privacy-safe session telemetry ekle:

- `hold_visibility_suspend_count`
- `hold_visibility_recovery_count`
- `hold_visibility_abort_count`
- `hold_visibility_suspended_ms_total`
- `last_hold_visibility_gap_ms`

### Implementation

R6 hardening patch'i mevcut hold lifecycle davranışını değiştirmeden şu session-level alanları Diagnostics schema v6 export'una taşır:

- `hold_visibility_suspend_count`
- `hold_visibility_recovery_count`
- `hold_visibility_abort_count`
- `hold_visibility_suspended_ms_total`
- `last_hold_visibility_gap_ms`

`hold_visibility_suspended_ms_total` yalnız recovery veya abort ile tamamlanmış gap'leri toplar. Devam eden açık gap, kapanana kadar toplam süreye eklenmez.

### Exit kriteri

Deterministic test + gerçek cihaz hold run'ında kısa ve uzun visibility loss için event sayaçları ile hidden-time davranışı tek JSON'dan açıklanabilir olmalı. Kısa gap'te recovery, uzun gap'te abort ve gap duration alanları gerçek cihaz export'unda doğrulanmadan finding `CLOSED` sayılmaz.

### R6 closure kanıtı

SHA-pinned profile build: `036a81f4b65dbd78fb197e5a6f807c7178d90da0`

- Kısa gap: `diagnostics_v6_hollow_hold_20260722_165459.json`
  - suspend = 1
  - recovery = 1
  - abort = 0
  - last gap = 701 ms
  - suspended total = 701 ms
- İlk uzun-gap denemesi: `diagnostics_v6_hollow_hold_20260722_165636.json`
  - hold continuity kırılması gözlendi ancak yeni event sayaçları oluşmadı
  - sonuç `INCONCLUSIVE`; closure kanıtı olarak kullanılmadı
- Tekrarlanan uzun gap: `diagnostics_v6_hollow_hold_20260722_165832.json`
  - suspend = 1
  - recovery = 0
  - abort = 1
  - last gap = 1669 ms
  - suspended total = 1669 ms

İkinci long-gap run ve kısa-gap run aynı SHA üzerinde deterministic testlerin beklediği lifecycle semantiğini gerçek cihazda doğrulamıştır. Finding **CLOSED**.

## F2 - Camera autofocus hunting during static hold/form-break

- Öncelik: **P1**
- Katman: Camera / UX / observability
- Etkilenen alan: Özellikle floor/static hold egzersizleri
- Kanıt: Kullanıcı gözlemi, `diagnostics_v6_plank_20260722_142513.json` ile aynı run

### Gözlem

Kalıcı hatalı Plank formunda beklerken kamera görüntüsü tekrar tekrar bulanıklaşıp netleşti. Aynı diagnostics run'ında pose pipeline stabil kaldı: no-pose=0, detected=207, accepted=206, exception=0, resync=0. Bu nedenle mevcut kanıt analiz failure'ı değil autofocus hunting UX bulgusudur.

### Minimum doğru çözüm yönü

Önce kamera backend davranışını ölç:

- focus mode capability,
- focus point / locked focus desteği,
- analiz başlangıcından sonra focus hunting frekansı,
- cihazlar arası fark.

Körlemesine global `FocusMode.locked` uygulama. Kullanıcı mesafesi değişen egzersizlerde sabit odak ters regression oluşturabilir.

### Exit kriteri

En az iki cihaz/koşul karşılaştırmasında focus stratejisi analiz frame acceptance'ını bozmadan görünür hunting'i azaltmalı. Gerekirse focus telemetry veya debug event log eklenmeli.

## F3 - Push-up tempo-confidence sensitivity

- Öncelik: **P1**
- Katman: Rep validation / confidence
- Etkilenen alan: Push-up
- Kanıt: `diagnostics_v6_push_up_20260722_140024.json`

### Gözlem

12 ground-truth Push-up'ın tamamı doğru sayıldı ancak 9/12 rep `lowConfidence` ve `excessiveDescentSpeed` nedeni aldı. Controlled occlusion run'ında ayrıca `excessiveAscentSpeed` görüldü.

### Risk

Counting doğru kalırken confidence/quality katmanı normal kullanıcı temposunu gereğinden agresif cezalandırıyor olabilir. Tek kullanıcı verisi bu sonucu kanıtlamak için yeterli değildir.

### Minimum doğru çözüm yönü

Threshold değiştirmeden önce:

1. farklı kontrollü tempo run'ları topla,
2. mümkünse birden fazla kullanıcı/cihaz gözlemi ekle,
3. raw persisted tempo metric dağılımını mevcut threshold ile karşılaştır,
4. detector FPS/performance etkisini ayır.

### Exit kriteri

Normal kontrollü Push-up temposunda false low-confidence oranının yüksek olduğu tekrarlanabilir veriyle kanıtlanırsa yalnız ilgili tempo validation threshold'u minimal patch ile güncellenir ve positive/static/partial regression tekrar edilir.

## F4 - R5 protocol execution sapması

- Öncelik: **P1 - R6 process hardening**
- Katman: Validation process

### Gözlem

R5 sırasında formal protokolde tanımlanan bazı run adetleri kullanıcı/test akışında azaltıldı. Sonuçlar güçlü engineering regression kanıtı sağladı ancak formal protocol-complete iddiasını desteklemedi.

### Minimum doğru çözüm

R6 başlamadan önce her exercise için canlı bir run manifest kullan:

- planlanan adet,
- gerçek adet,
- diagnostics filename,
- build SHA,
- PASS / FAIL / INVALID / NOT_MEASURABLE,
- deviation reason.

Run ID anlamını execution sonrasında geriye dönük değiştirme.

### Exit kriteri

R6 Dalga A closure'ında planlanan ve gerçek execution arasındaki fark tek sonuç dosyasından açıkça görülebilmeli.

### R6 uygulama durumu

Biceps Curl validation hazırlığında `docs/beta/r6-wave-a-run-manifest.csv` canlı manifesti eklenmiştir. Planlanan ve gerçek execution adetleri ayrı kolonlarda tutulur; `deviation_reason` alanı run ID anlamını geriye dönük değiştirmeden protokol sapmasını kaydeder. F4 process hardening maddesi R6 execution için uygulanmıştır; closure'da manifestin eksiksiz doldurulduğu ayrıca doğrulanacaktır.
