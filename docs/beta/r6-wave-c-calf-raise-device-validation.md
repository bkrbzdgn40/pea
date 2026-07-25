# R6 Wave C - Calf Raise Device Validation

Bu protokol `Calf Raise` için başlangıç pozisyonu ve gerçek cihaz peak-acquisition hardening değişikliğini tanımlar.

Shared range-rep visibility, lifecycle ve persistence davranışları merkezi reliability testleriyle korunur. Bu çalışma yalnız Calf Raise primary-metric lifecycle kalibrasyonuna odaklanır.

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

## 2. İlk Kök Neden: Neutral Acquisition

Eski config:

```text
thresholdNeutral = 85°
thresholdActive = 100°
thresholdPeak = 115°
targetMaxAngle = 125°
```

Side-view landmark geometrisinde ayak ucu, ayak bileğinin önünde ve çoğunlukla biraz aşağısında görünür. Bu nedenle doğal düz taban başlangıç pozisyonundaki `knee -> ankle -> footIndex` iç açısı akut bir değer yerine yaklaşık `105-118°` bandında oluşmuştur.

Generic increasing-to-peak lifecycle neutral acquisition için strict olarak:

```text
primaryMetric < thresholdNeutral
```

koşulunu kullanır. Yaklaşık `110-115°` doğal başlangıç metriği eski `85°` kapısının altında olmadığı için engine silahlanamıyordu.

## 3. İlk Patch Sonrası Cihaz Bulgusu

İlk hardening patch'i absolute açı bandını topluca `+40°` kaydırdı:

```text
thresholdNeutral = 125°
thresholdActive = 140°
thresholdPeak = 155°
targetMaxAngle = 165°
```

Bu değişiklik başlangıç pozisyonunu düzeltti ancak gerçek cihaz videosunda düzgün tekrarlar yapılmasına rağmen sayaç sıfır kaldı.

SHA-pinned profile diagnostics:

```text
app_commit_sha = 22e7b5d1193c96410e90fed01422839881826ac1
analysis_fps_p50 = 6.99
frame_processing_ms_p95 = 384
reentrant_drop_count = 142
range_rep_transition_count = 1
range_rep_transition_counts = { acquireNeutral: 1 }
rep_count = 0
```

Video üzerindeki engine-facing smoothed primary metric yaklaşık olarak:

```text
neutral band = 105-118°
full heel-raise peaks = 133-137°
```

İlk patch'in effective lifecycle kapıları ise:

```text
active entry = primaryMetric > 143°
peak entry = primaryMetric > 158°
```

olduğu için fiziksel tekrarlar `startTowardPeak` aşamasına dahi girememiştir. Diagnostics'te yalnız `acquireNeutral` bulunması bunun doğrudan kanıtıdır.

Kök hata, doğal başlangıç düzeltmesi yapılırken `neutral`, `active` ve `peak` eşiklerinin aynı offset ile taşınmasıdır. Calf Raise'ın gerçek cihazdaki ankle-angle hareket aralığı yaklaşık `20-30°` olduğu için tüm bandın `+40°` kaydırılması hareketi matematiksel olarak erişilemez hale getirmiştir.

## 4. Cihaz Kanıtına Göre Düzeltilmiş Lifecycle Bandı

Config:

```text
thresholdNeutral = 120°
thresholdActive = 123°
thresholdPeak = 132°
targetMaxAngle = 140°
```

Calf Raise contract hardening:

```text
peakEntryMargin = 0°
retainPeakEvidenceAcrossActiveTransition = true
allowSparseCycleRecovery = false
primaryMetricSmoothingWindow = 5
```

Generic engine marginleriyle effective gates:

```text
strict neutral acquisition = primaryMetric < 120°
effective active entry = primaryMetric > 126°
strict peak acquisition = primaryMetric > 132°
peak exit / return entry = primaryMetric < 124°
```

Bu bandın amacı:

- cihazda görülen `105-118°` doğal ayakta duruşu neutral kabul etmek,
- küçük ayak bileği jitter'ının `>126°` active kapısını geçmesini önlemek,
- cihazda görülen `133-137°` tam heel-raise tepesini peak kabul etmek,
- topuk yere dönerken `<124°` ile return fazına girmek,
- `<120°` ile tam neutral dönüşü tamamlamaktır.

`peakEntryMargin = 0°`, cihazda görülen dar tepe bandının generic ek `3°` guard yüzünden kaybolmasını önler.

`retainPeakEvidenceAcrossActiveTransition = true`, yaklaşık `7 FPS` analysis akışında ilk güçlü peak örneğinin active-entry confirmation tamamlanmadan önce görülüp tüketilmesini önler. Bu davranış yalnız Calf Raise contract'ına uygulanır.

`allowSparseCycleRecovery` açılmaz. Cihaz kanıtında intermediate active ve return örnekleri hâlâ vardır; daha geniş lifecycle relaxation gerekli değildir.

İkinci patch sonrası yapılan incelemede regression testinin değerleri doğrudan `RangeRepAnalysisEngine` içine verdiği ve production `DefaultRangeRepCoordinator` içindeki primary moving-average katmanını atladığı görüldü. Calf Raise contract'ı default `primaryMetricSmoothingWindow = 5` değerini koruduğu için yaklaşık `7 FPS` analiz akışında bu pencere fiziksel tekrarın yaklaşık `0.7 saniyesini` kapsayabilir. Dar ankle-angle hareketi active kapısına ulaşmadan ortalamada bastırılabilir ve UI `Hazır` durumunda kalabilir.

Bu nedenle Calf Raise için:

```text
primaryMetricSmoothingWindow = 1
```

seçilir. Bu değişiklik generic engine confirmation/hysteresis kapılarını gevşetmez; yalnız engine'e verilen primary metric'in beş frame gecikmeli ortalama yerine kabul edilen güncel frame ölçümü olmasını sağlar. Form metriği beş frame smoothing kullanmaya devam eder.

## 5. Regression Coverage

`calf_raise_production_contract_test.dart` şu davranışları sabitler:

1. `115°` ankle primary metric ve `175°` knee form metriği üreten doğal side-view başlangıç pozu neutral olarak acquire edilir.
2. Production config ve Calf Raise contract hardening değerleri doğrulanır.
3. Cihaz videosuna benzeyen sparse sequence sayılır:

```text
115, 115,
133, 127, 134,
114, 114,
112, 112
```

4. Completed-rep primary ROM `19°` olur.
5. `126-128°` aralığındaki küçük heel movement peak'e ulaşmadığı için tekrar üretmez.
6. Aynı device-observed sequence production `DefaultRangeRepCoordinator` üzerinden geçirilir; contract smoothing katmanı dahilken bir completed rep üretmelidir. Retained peak örneği active-entry ile aynı effective timestamp'te başladığı için bu sparse fixture validation tarafında `excessive descent speed` gerekçesiyle `low confidence` olarak sınıflandırılır; bu sınıflandırma rep sayımını iptal etmez.
7. Videoda gözlenen `103-118°` standing-jitter sequence'i coordinator üzerinden sıfır rep olarak kalmalıdır.

## 6. SHA-Pinned Device Revalidation

### Kamera kurulumu

- Kamera yandan yerleştirilir.
- Kalça, diz, ayak bileği ve ayak ucu aynı tarafta görünür tutulur.
- Ayak tabanı yerde, diz büyük ölçüde uzatılmış, gövde dengeli başlanır.

### Pozitif tekrar

- En az 5 kontrollü tam tekrar yapılır.
- Beklenen canonical transition sırası:

```text
acquireNeutral
startTowardPeak
reachPeak
startReturning
completeRep
```

- `rep_count`, videodaki fiziksel tam tekrar sayısıyla eşleşmelidir.

### Negatif tekrar

- Yalnız küçük topuk hareketleri strict peak gate'e ulaşmamalı ve completed rep üretmemelidir.
- Dizlerden belirgin yaylanma form feedback'i üretmeli; tek başına lifecycle'ı yanlışlıkla tamamlamamalıdır.

### Lifecycle

- Pause/resume sonrasında neutral yeniden acquire edilmelidir.
- Session finish sonrası rep count ve özet/persistence değerleri aynı session ile tutarlı olmalıdır.

## 7. Acceptance

Bu değişiklik ancak aşağıdakiler temiz olduğunda merge-ready kabul edilir:

```text
dart format .
flutter analyze
flutter test test/features/workout_analysis/domain/calf_raise_production_contract_test.dart
flutter test
git diff --check
SHA-pinned profile device smoke test
```

Fix sonrası cihaz diagnostics'i `startTowardPeak`, `reachPeak`, `startReturning` ve `completeRep` geçişlerini göstermeden Calf Raise için engineering-revalidated iddiası yapılmaz.
