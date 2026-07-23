# R6 Wave B - Stationary Lunge Results

Bu belge Stationary Lunge R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

Stationary Lunge ana selected-side counting akışı gerçek cihazda güvenilir şekilde tekrar üretti. Validation sırasında completed rep ROM hesabında gerçek bir confirmation-lag problemi bulundu.

## Bulgu ve Fix

`startTowardPeak` transition debounce'u ilk active-threshold crossing'de başlıyor, ancak eski implementasyonda completed-rep ROM başlangıç metriği confirmation'ın yaklaşık 80 ms sonra tamamlandığı frame'den alınıyordu.

Orta analysis FPS ve hızlı inişte bu, full-ROM bir hareketin başlangıç açısını peak'e gereğinden fazla yaklaştırarak `primaryRom` değerini yapay olarak küçültebiliyordu.

Gerçek cihaz run'ında:

```text
completeRep = 10
valid = 6
invalid = 3
lowConfidence = 1
insufficientRom = 3
excessiveDescentSpeed = 1
```

gözlendi.

Fix:

- threshold'lar değiştirilmedi,
- `minAcceptableRomDelta = 20°` korundu,
- generic lifecycle ilk kesintisiz active-crossing metriğini confirmation boyunca koruyor,
- completed-rep validation canonical `GenericRepCompletedRep.startMetric` ve `rom` verisini kullanıyor,
- decreasing-to-peak ve increasing-to-peak yönleri regression testleriyle kapsandı.

## Fix Sonrası Cihaz Kanıtı

Fix sonrası SHA-pinned profile run:

```text
rep_count = 10
completeRep = 10
validation_count = 10
valid = 9
lowConfidence = 1
invalid = 0
insufficientRom = 0
excessiveDescentSpeed = 1
abortToNeutral = 9
analysis_exception_count = 0
```

Bu sonuç:

- full-ROM completed tekrarların sahte `insufficientRom` sınıflandırmasının ortadan kalktığını,
- sığ/partial girişimlerin completed rep'e dönüşmeden abort edilebildiğini,
- ana counting lifecycle'ın korunmuş olduğunu

gösterir.

Tek `excessiveDescentSpeed` low-confidence sonucu için threshold tuning yapılmamıştır.

## Side / Symmetry Gözlemi

Gerçek cihaz run'ında kullanıcı stance değiştirerek iki fiziksel bacağı da çalıştırdı. Ana counting her iki blokta çalıştı.

`side_switch_count` idle/neutral bölgelerde yüksek olabilse de completed lifecycle bütünlüğünü bu run'larda bozmadı. Symmetry/asymmetry değerinin sayısal doğruluğu ayrı aggregate sidecar export alanları bulunmadığı için formal olarak doğrulanmış sayılmaz.

## Execution Sapmaları

Closure konuşmasında aşağıdaki run'lar ayrı final kanıt olarak sabitlenmedi:

- `STATIC-30`
- `LIFE pause/resume`
- `PERSIST`

Bu nedenle sonuç **formal protocol-complete değildir**.

Kullanıcı kararıyla Stationary Lunge ana counting reliability ve bulunan ROM-validation bug'ının fix sonrası cihaz doğrulaması temelinde kapatılmıştır.

## Closure Kararı

Ana counting doğru çalıştı, confirmation-lag kaynaklı ROM underestimation bug'ı minimal generic lifecycle fix'iyle giderildi ve partial rejection davranışı korundu.

**Final karar: `Stationary Lunge = R6 Engineering Revalidated`**, execution deviations yukarıda açıkça kayıtlıdır.
