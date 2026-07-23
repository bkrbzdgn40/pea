# R6 Wave B - Shoulder Press Device Validation

Bu protokol R6 Dalga B kapsamında `Shoulder Press` exercise-specific gerçek cihaz validation'ını tanımlar. Zaman kısıtı nedeniyle hızlandırılmış bilateral range-rep matrisi kullanılır. Shared occlusion/visibility davranışı daha önce ortak reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Shoulder Press:

```text
camera = front preferred
side = unsupported
sideMode = bilateral
primaryMetricDirection = increasingToPeak
primaryMetric = shoulder -> elbow -> wrist
poseAcceptanceRequiredSignals = primaryMetric
minAcceptableRomDelta = 25°
```

Config:

```text
thresholdNeutral = 105°
thresholdActive = 120°
thresholdPeak = 155°
formThreshold = 0°
```

Primary lifecycle iki kolun elbow-angle sinyalinden bilateral aggregate ile yürür. `increasingToPeak` contract'ta lagging arm belirleyicidir; completed lifecycle için iki kolun birlikte yeterli extension'a ulaşması beklenir.

### Device finding: straight-down arm peak ambiguity

Gerçek cihaz videosunda zero-overlap alternating arm denemelerinde false bilateral rep gözlendi. Kök neden threshold tuning değil, primary metric geometrisinin tek başına arm elevation'ı ayırt edememesidir:

```text
overhead straight arm -> high elbow angle
straight arm beside torso -> high elbow angle
```

Bu nedenle bir kol overhead iken diğer kol vücudun yanında düz tutulduğunda generic bilateral elbow-angle aggregate PEAK threshold'unu yanlışlıkla sağlayabiliyordu.

Shoulder Press'e özel `RangeRepPeakEntryGate` eklendi. PEAK confirmation artık primary elbow-angle gate'e ek olarak şu koşulu ister:

```text
left wrist above left shoulder
AND
right wrist above right shoulder
```

Generic engine ve mevcut angle threshold'ları değiştirilmedi. Fix sonrası `R6-SP-ONE-ARM-10` / zero-overlap alternating-arm negatif testi gerçek cihazda yeniden çalıştırılmadan Shoulder Press closure yapılmaz.

## 2. Form-Signal Sınırı

Shoulder Press v1 contract'ında ayrı bir exercise-specific technique angle yoktur.

Development contract gerekçesi:

- primary sinyal elbow extension'dır,
- scapular mechanics tek bir ML Kit shoulder landmark'ından güvenilir biçimde çıkarılmaz,
- pseudo-precision üretilmez.

Bu nedenle bu validation'da generic bir `FORM` senaryosu üzerinden omuz/scapula tekniği doğrulanmış gibi davranılmaz.

Bilateral egzersiz için daha anlamlı exercise-specific negatif kapı:

```text
ONE-ARM / ASYMMETRY
```

Amaç, tek kolun overhead extension yapmasının veya belirgin şekilde geride kalan bir kolun completed bilateral rep üretmemesini doğrulamaktır.

## 3. Threshold Tuning Kuralı

İlk gerçek cihaz run'ında doğal başlangıç veya peak açıları config gate'leriyle uyuşmazsa doğrudan threshold değiştirilmez.

Önce şu sınıflandırma yapılır:

1. camera framing / full-body coverage,
2. wrist-elbow-shoulder landmark visibility,
3. bilateral aggregate / lagging-arm behavior,
4. lifecycle gate,
5. gerçek tekrarlanan ROM failure.

Threshold değişikliği için tek kullanıcı veya tek video yeterli kanıt değildir.

## 4. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-SP-PREFLIGHT-1` | Preflight | Doğru front-view setup'ta 1 temiz bilateral Shoulder Press | Natural start acquire olur; iki kol overhead extension ile 1 tam lifecycle = 1 rep |
| `R6-SP-POS-20` | Positive counting | Kontrollü tempoda 20 bilateral tam tekrar | Ground truth ile app count eşleşir; phantom/duplicate rep yok |
| `R6-SP-STATIC-30` | Static negative | Yaklaşık 30 sn doğal başlangıç pozisyonu | `rep_count = 0`; phantom lifecycle yok |
| `R6-SP-PARTIAL-10` | Partial / invalid ROM | 10 küçük press denemesi; yeterli overhead extension'a ulaşmadan geri dön | Completed rep üretilmez |
| `R6-SP-ONE-ARM-10` | One-arm / asymmetry | 10 denemede yalnız bir kolu tam press et veya diğer kolu belirgin şekilde geride bırak | Bilateral completed rep üretilmez |
| `R6-SP-LIFE` | Pause/resume | Rep seti içinde 1 kontrollü pause/resume | Pause sırasında phantom rep yok; resume sonrası temiz reacquire |
| `R6-SP-PERSIST` | Persistence | Ölçülebilir rep setiyle session bitir | Live/Summary/History aynı persisted rep değerini gösterir |

Per-exercise `OCC` testi **SKIPPED by policy**. Yalnız Shoulder Press'e özgü visibility regression veya bilateral landmark-loss failure görülürse yeniden açılır.

## 5. Preflight Gözlem Alanları

İlk gerçek cihaz run'ında özellikle şunları gözle:

```text
neutral/start elbow angle range
peak elbow angle range
left vs right primary angle
bilateral lagging-arm behavior
rep_count
unexpected form/low-confidence feedback
```

İlk amaç threshold tuning yapmak değil, production contract'ın gerçek hareket geometrisiyle uyumlu çalışıp çalışmadığını doğrulamaktır.

## 6. Closure Kriteri

Shoulder Press şu kapılar geçildiğinde `R6 Engineering Revalidated` statüsüne aday olur:

1. preflight,
2. positive counting,
3. static negative,
4. partial / invalid-ROM rejection,
5. one-arm / asymmetry rejection,
6. pause/resume lifecycle safety,
7. persistence.

Dedicated technique metric olmadığı için scapular veya shoulder-form doğruluğu bu closure'ın kanıt kapsamına dahil edilmez.

## 7. Closure Kaydı

**Status: `R6 Engineering Revalidated`**

Zero-overlap alternating-arm false bilateral rep bulgusu, Shoulder Press'e özel bilateral wrist-above-shoulder PEAK gate ile giderildi.

Fix sonrası kullanıcı gerçek cihazda:

- 20 normal bilateral tekrarı,
- pause/resume lifecycle davranışını,
- persistence davranışını,
- unilateral / zero-overlap alternating negatif senaryoyu

başarılı olarak doğruladı.

`STATIC-30` ve `PARTIAL-10` için closure konuşmasında ayrı final kanıt sabitlenmediği için formal protocol-complete iddiası yapılmaz.

Dedicated technique metriği bulunmadığından scapular/shoulder form doğruluğu closure kapsamı dışındadır.

Ayrıntılı sonuç kaydı: `docs/beta/r6-wave-b-shoulder-press-results.md`.

