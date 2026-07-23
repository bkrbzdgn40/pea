# R6 Wave B - Shoulder Press Results

Bu belge Shoulder Press R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

Shoulder Press validation sırasında gerçek bir bilateral counting reliability problemi bulundu.

Primary metric iki kol için de:

```text
shoulder -> elbow -> wrist
```

elbow angle ölçümüdür. Düz bir kol overhead konumdayken de gövdenin yanında aşağı doğru tutulurken de yüksek elbow angle üretebildiği için, bir kol overhead iken diğer kol aşağıda düz tutulduğunda generic bilateral aggregate yanlış PEAK kabulü yapabiliyordu.

Gerçek cihaz videosunda zero-overlap alternating-arm denemelerinde false bilateral rep gözlendi.

Minimum doğru katmanda Shoulder Press'e özel `RangeRepPeakEntryGate` eklendi:

```text
primary elbow-angle PEAK gate
AND
left wrist above left shoulder
AND
right wrist above right shoulder
```

Generic engine, bilateral aggregate ve mevcut angle threshold'ları değiştirilmedi.

## Fix Sonrası Gerçek Cihaz Kanıtı

Kullanıcı tarafından şu davranışlar doğrulandı:

| Alan | Sonuç | Closure yorumu |
| --- | --- | --- |
| Positive counting | PASS | 20 normal Shoulder Press tekrarı düzgün sayıldı. |
| Pause/resume lifecycle | PASS | Pause/resume davranışı düzgün çalıştı. |
| Persistence | PASS | Persistence davranışı düzgün çalıştı. |
| Unilateral / zero-overlap alternating negative | PASS | Fix sonrasında bağımsız tek-kol / sırayla kol hareketleri bilateral rep üretmedi. |

## Execution Sapmaları

İlk hızlandırılmış protokolde ayrıca `STATIC-30` ve `PARTIAL-10` tanımlanmıştı. Closure konuşmasında bu iki run için ayrı ve açık final PASS kanıtı sabitlenmedi.

Bu nedenle:

- `STATIC-30` ve `PARTIAL-10` çalıştırılmış gibi yazılmaz,
- formal protocol-complete iddiası yapılmaz,
- mevcut closure, gerçek failure'ın bulunması, minimal fix ve fix sonrası kritik positive/negative/lifecycle/persistence kanıtlarına dayanan engineering revalidation olarak tutulur.

## Form-Signal Sınırı

Shoulder Press v1 contract'ında ayrı exercise-specific technique/form metriği yoktur.

Bu closure:

- scapular mechanics doğruluğu,
- trunk compensation doğruluğu,
- shoulder mobility/form değerlendirmesi

için kanıt iddiası içermez.

## Closure Kararı

Gerçek cihazda bulunan false bilateral PEAK problemi exercise-specific gate ile giderildi. Normal bilateral counting korunurken zero-overlap unilateral/alternating false-positive yolu kapatıldı. Lifecycle ve persistence tekrar doğrulandı.

**Final karar: `Shoulder Press = R6 Engineering Revalidated`.**
