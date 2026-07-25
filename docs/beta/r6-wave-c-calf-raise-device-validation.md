# R6 Wave C - Calf Raise Device Validation

Bu protokol `Calf Raise` için başlangıç pozisyonu hardening değişikliğini ve gerçek cihaz doğrulama kapsamını tanımlar.

Shared range-rep visibility, lifecycle ve persistence davranışları merkezi reliability testleriyle korunur. Bu çalışma yalnız Calf Raise primary-metric kalibrasyonuna odaklanır.

## 1. Production Contract

Production kaynaklarına göre Calf Raise:

```text
tracking = repetitions
engine = rangeRep
sideMode = selectedSide
primaryMetricDirection = increasingToPeak
primaryMetricKind = jointAngle
camera = side preferred
front = unsupported
towardPeakMuscleAction = concentric
```

Selected taraftaki primary metric:

```text
knee -> ankle -> footIndex
```

Diz büyük ölçüde uzatılmışken kullanılan technique/form metriği:

```text
hip -> knee -> ankle
```

Primary metric ve form metric pose acceptance için gereklidir. Bu nedenle kalça, diz, ayak bileği ve ayak ucu kadrajda görünmelidir.

## 2. Kök Neden

Eski config:

```text
thresholdNeutral = 85°
thresholdActive = 100°
thresholdPeak = 115°
targetMaxAngle = 125°
```

Side-view landmark geometrisinde ayak ucu, ayak bileğinin önünde ve çoğunlukla biraz aşağısında görünür. Bu nedenle doğal düz taban başlangıç pozisyonundaki `knee -> ankle -> footIndex` iç açısı akut bir değer yerine yaklaşık `110-120°` bandında oluşabilir.

Generic increasing-to-peak lifecycle neutral acquisition için strict olarak:

```text
primaryMetric < thresholdNeutral
```

koşulunu kullanır. Yaklaşık `115°` doğal başlangıç metriği eski `85°` kapısının altında olmadığı için engine silahlanamaz ve kullanıcı doğru pozisyonda olsa da `Başlangıç pozisyonuna geç` feedback'inde kalır.

## 3. Kalibre Edilmiş Lifecycle Bandı

Absolute ankle-angle bandı, relative aralıklar korunarak `+40°` kaydırılmıştır:

```text
thresholdNeutral = 125°
thresholdActive = 140°
thresholdPeak = 155°
targetMaxAngle = 165°
```

Generic engine marginleriyle effective gates:

```text
strict neutral acquisition = primaryMetric < 125°
effective active entry     = primaryMetric > 143°
strict peak acquisition    = primaryMetric > 158°
peak exit / return entry   = primaryMetric < 147°
```

Bu düzen:

- yaklaşık `115°` doğal düz taban duruşunu neutral kabul eder,
- neutral ile active entry arasında yaklaşık `18°` deadband bırakır,
- eski config'teki `15° + 15°` lifecycle aralıklarını korur,
- `targetMaxAngle` değerini yeni absolute metric bandıyla hizalar,
- catalog validation'daki `minAcceptableRomDelta = 15°` kuralını değiştirmez.

Generic `RangeRepEngine`, form threshold, pose quality, side selection, tempo, scoring ağırlıkları ve persistence davranışları değiştirilmez.

## 4. Regression Coverage

`calf_raise_production_contract_test.dart` şu davranışları sabitler:

1. `115°` ankle primary metric ve `175°` knee form metriği üreten doğal side-view başlangıç pozu neutral olarak acquire edilir.
2. Başlangıç pozisyonunda sayaç sıfır kalır.
3. `115 -> 145 -> 165 -> 145 -> 115` kontrollü lifecycle'ı tam bir tekrar üretir.
4. Completed-rep primary ROM `20°` olur ve mevcut `15°` validation alt sınırını aşar.

## 5. SHA-Pinned Device Smoke Test

### Kamera kurulumu

- Kamera yandan yerleştirilir.
- Kalça, diz, ayak bileği ve ayak ucu aynı tarafta görünür tutulur.
- Ayak tabanı yerde, diz büyük ölçüde uzatılmış, gövde dengeli başlanır.

### Başlangıç pozisyonu

- Doğal ayakta duruş 1-2 saniye korunur.
- `Başlangıç pozisyonuna geç` feedback'i kaybolmalıdır.
- 10 saniye hareketsiz beklemede `rep_count = 0` kalmalıdır.

### Pozitif tekrar

- Topuklar kontrollü biçimde kaldırılır.
- Üst noktada kısa süre dengede kalınır.
- Topuklar kontrollü biçimde yere indirilir.
- 10 fiziksel tekrar için sayaç hedefi `10` olmalıdır.

### Negatif tekrar

- Yalnız küçük topuk hareketleri strict peak gate'e ulaşmamalı ve completed rep üretmemelidir.
- Dizlerden belirgin yaylanma form feedback'i üretmeli; tek başına lifecycle'ı yanlışlıkla tamamlamamalıdır.

### Lifecycle

- Pause/resume sonrasında neutral yeniden acquire edilmelidir.
- Session finish sonrası rep count ve özet/persistence değerleri aynı session ile tutarlı olmalıdır.

## 6. Acceptance

Bu değişiklik ancak aşağıdakiler temiz olduğunda merge-ready kabul edilir:

```text
dart format .
flutter analyze
flutter test test/features/workout_analysis/domain/calf_raise_production_contract_test.dart
flutter test
git diff --check
SHA-pinned profile device smoke test
```

Gerçek cihaz smoke test sonucu alınmadan Calf Raise için formal protocol-complete veya engineering-revalidated iddiası yapılmaz.
