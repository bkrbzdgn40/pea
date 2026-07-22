# R6 Hold Visibility Telemetry Hardening

Bu adım, R5 Plank revalidation sırasında bulunan hold visibility observability açığını kapatır. Amaç hold engine davranışını değiştirmek değil, mevcut visibility-gap lifecycle'ını Diagnostics schema v6 içinde privacy-safe ve session-level olarak ölçülebilir hale getirmektir.

## 1. Kapsam

Eklenen alanlar:

- `hold_visibility_suspend_count`
- `hold_visibility_recovery_count`
- `hold_visibility_abort_count`
- `hold_visibility_suspended_ms_total`
- `last_hold_visibility_gap_ms`

Mevcut `hold_is_visibility_suspended` alanı snapshot anındaki state'i göstermeye devam eder.

## 2. Event Semantiği

### Suspend

Aktif hold sırasında ilk visibility loss engine'in visibility-gap penceresini başlatırsa:

`hold_visibility_suspend_count += 1`

Aynı açık gap sırasında gelen sonraki invalid frame'ler yeni suspend olarak sayılmaz.

### Recovery

Görüntü grace süresi içinde geri gelir ve hold aynı attempt olarak devam ederse:

`hold_visibility_recovery_count += 1`

Tamamlanan gap süresi:

- `hold_visibility_suspended_ms_total` alanına eklenir,
- `last_hold_visibility_gap_ms` alanına yazılır.

Hidden süre aktif hold süresine eklenmez.

### Abort

Görüntü grace sınırında veya sonrasında geri gelir ve eski hold attempt'i güvenli biçimde sonlandırılırsa:

`hold_visibility_abort_count += 1`

Tamamlanan gap süresi yine total ve last-gap alanlarına yazılır. `bestHoldSeconds` korunur; eski hidden süre yeni hold'a taşınmaz.

## 3. Süre Toplama Kuralı

`hold_visibility_suspended_ms_total` yalnız tamamlanmış gap'leri içerir:

`completed gap = recovery veya abort`

Snapshot anında hâlâ açık olan bir visibility gap:

- `hold_is_visibility_suspended = true`
- suspend count içinde görünür,
- fakat kapanana kadar total süreye eklenmez.

Bu kural double-count ve snapshot-time tahminini önler.

## 4. Schema ve Privacy

Bu değişiklik Diagnostics schema v6'ya additive telemetry ekler; mevcut alanların anlamını değiştirmez.

Yeni alanlar:

- raw frame içermez,
- raw landmark içermez,
- kullanıcı kimliği içermez,
- yalnız event count ve duration taşır.

## 5. Deterministic Acceptance

### Kısa gap

Beklenen:

- suspend count = 1
- recovery count = 1
- abort count = 0
- last gap > 0 ve `< 1200 ms`
- suspended total = tamamlanan kısa gap süresi
- hold devam eder
- hidden süre hold toplamına eklenmez

### Uzun gap

Beklenen:

- suspend count = 1
- recovery count = 0
- abort count = 1
- last gap `>= 1200 ms`
- suspended total = tamamlanan uzun gap süresi
- eski hold sona erer
- best hold korunur
- yeni hold sıfırdan başlar

## 6. Real-Device Exit Gate

Hollow Hold validation'a geçmeden önce aynı SHA-pinned profile build ile iki Plank smoke run yapılır.

### R6-HOLD-VIS-SHORT

1. Geçerli Plank başlat.
2. Yaklaşık 5 saniye tut.
3. Kamerayı yaklaşık 0.5-0.8 saniye tamamen kapat.
4. Görüntüyü geri getir ve hold'a devam et.
5. Stabil görüntüde JSON export et.

Beklenen:

- `hold_visibility_suspend_count >= 1`
- `hold_visibility_recovery_count >= 1`
- `hold_visibility_abort_count = 0`
- `last_hold_visibility_gap_ms < 1200`
- `hold_is_visibility_suspended = false`
- exception = 0

### R6-HOLD-VIS-LONG

1. Geçerli Plank başlat.
2. Yaklaşık 5 saniye tut.
3. Kamerayı en az 1.5-2 saniye tamamen kapat.
4. Görüntüyü geri getir.
5. Stabil görüntüde JSON export et.

Beklenen:

- `hold_visibility_suspend_count >= 1`
- `hold_visibility_abort_count >= 1`
- `last_hold_visibility_gap_ms >= 1200`
- eski hold'un hidden süreyi taşımadığı davranış
- exception = 0

Bu iki run tek JSON üzerinden hold visibility lifecycle'ını açıklayabiliyorsa R5 F1 finding'i kapatılır ve Hollow Hold cihaz validation'ına geçilir.
