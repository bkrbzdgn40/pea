# P2.2 - Calf Raise Real-Device Boundary Calibration

Bu turdaki karar yalnız teorik eşik hesabına değil, 2026-07-28 tarihli profile video ve schema-v6 diagnostics kaydına dayanır.

## 1. Gerçek cihaz bulgusu

Videoda doğal ayakta duruş primary metriği çoğunlukla yaklaşık `99-112°` bandındadır. Kontrollü ve fiziksel olarak sürdürülebilir heel-raise tepeleri tekrar tekrar yaklaşık `123-125°` üretmiş, tekil en yüksek görünür değer yaklaşık `129°` olmuştur.

Bu nedenle kullanıcıdan `130°+` istemek güvenilir bir production hedefi değildir. Kalibrasyon tekil maksimumu değil, tekrar edilebilir güvenli tepe bandını esas alır.

Diagnostics özeti:

```text
analysis_fps_p50 = 7.99
frame_processing_ms_p95 = 99
startTowardPeak = 3
reachPeak = 2
startReturning = 0
completeRep = 0
rep_count = 0
briefOcclusionCount = 10
briefOcclusionAbortCount = 3
resyncCount = 5
analysisExceptionCount = 0
invalidPoseGeometryFrameCount = 0
```

Bu tablo iki ayrı problemi gösterir:

1. `123-125°` fiziksel tepelerin çoğu eski active/peak kapılarında tüketiliyordu.
2. Yaklaşık 8 FPS akışında peak ile neutral dönüş arasındaki ara faz örnekleri seyrek kalabiliyordu.

## 2. Eski effective kapılar

Önceki config:

```text
thresholdNeutral = 120°
thresholdActive = 123°
thresholdPeak = 129°
targetMaxAngle = 140°
```

Shared active-entry margin `3°` olduğu için gerçek active kapısı:

```text
primaryMetric > 126°
```

idi. Dolayısıyla videoda tekrar tekrar görülen `123-125°` tam heel-raise tepeleri active lifecycle'a dahi güvenilir biçimde giremiyordu.

Ayrıca `targetMaxAngle = 140°`, cihazda tekrarlanabilir fiziksel tepe bandının belirgin biçimde üzerindeydi ve skor tarafında gereksiz ROM talebi oluşturuyordu.

## 3. Yeni production sözleşmesi

```text
thresholdNeutral = 120°   değişmedi
thresholdActive = 121°
thresholdPeak = 122°
targetMaxAngle = 125°
activeEntryMargin = 0°
peakEntryMargin = 0°
retainPeakEvidenceAcrossActiveTransition = true
allowSparseCycleRecovery = false   değişmedi
primaryMetricSmoothingWindow = 1
minAcceptableRomDelta = 15°   değişmedi
formThreshold = 160°          değişmedi
```

Effective lifecycle:

```text
neutral = primaryMetric < 120°
active = primaryMetric > 121°
peak = primaryMetric > 122°
```

Bunun sonucu:

- exact `123°` ölçümü production peak olarak kabul edilir,
- exact `122°` hâlâ peak değildir,
- `125°` tekrarlanabilir tam ROM hedefidir,
- `140°` zorlanmaz,
- yalnız absolute peak'e ulaşmak yetmez; validation hâlâ en az `15°` ROM ister.

Örnek:

```text
108° -> 123° = 15°   valid sınır
115° -> 123° = 8°    invalid, sayaca eklenmez
```

Bu nedenle peak kapısının düşürülmesi küçük ayak bileği jitter'ını otomatik olarak geçerli tekrara dönüştürmez.

## 4. Lifecycle toleransı korunur

`allowSparseCycleRecovery` açılmaz. Diagnostics'teki brief-occlusion ve resync olayları, videoda ayak landmark'larının tam gövde kadrajında küçük kalmasıyla birlikte değerlendirilmelidir. Önce threshold ve kamera kurulumu düzeltilir; strict peak-to-neutral lifecycle kanıt olmadan genel olarak gevşetilmez.

Yeni peak `122°` olduğu için motor tepeyi fiziksel hareketin daha erken ve daha uzun bölümünde acquire edebilir. Return kapısı mevcut hysteresis ile tam taban dönüşünü istemeye devam eder.

## 5. Form sınırı korunur

Videoda bazı tepelerde diz fleksiyonu görülmektedir. `hip -> knee -> ankle` form metriği ve `160°` threshold değiştirilmez.

Dolayısıyla:

- doğru heel raise lifecycle sayılabilir,
- belirgin dizden yaylanma yine technique/validation uyarısı üretir,
- daha yüksek açı uğruna diz kompansasyonu teşvik edilmez.

## 6. Regression coverage

`calf_raise_production_contract_test.dart` artık şu sınırları sabitler:

1. `115°` doğal side-view setup neutral olarak acquire edilir.
2. Exact `123°` peak, `108°` başlangıçtan `15°` ROM üretir.
3. `105° -> 123° -> 105°` cihaz-benzeri lifecycle tamamlanır.
4. Exact `122°` peak kabul edilmez.
5. `119-122°` küçük hareket bandı engine rep üretmez.
6. `115° -> 123°` yalnız `8°` ROM olduğu için coordinator tarafından invalid sayılır ve visible REPS artmaz.
7. Standing jitter sequence'i sıfır rep kalır.

## 7. Cihaz kabul kriteri

Pozitif smoke:

```text
en az 5 kontrollü fiziksel tekrar
video tekrar sayısı = visible REPS
tekrarlanabilir peak yaklaşık 123-129°
neutral yaklaşık 99-115°
```

Negatif smoke:

```text
yalnız küçük topuk kaldırışı
peak <= 122°
veya primary ROM < 15°
visible REPS artmamalı
```

Kamera alt gövde seviyesinde ve yandan tutulmalıdır. Ayak küçük kaldığında `footIndex` likelihood düşer ve lifecycle brief-occlusion nedeniyle kesilebilir.

## 8. Acceptance

```text
dart format .
flutter analyze
flutter test test/features/workout_analysis/domain/calf_raise_production_contract_test.dart
flutter test
git diff --check
real-device profile smoke
```
