# Yeni Egzersiz Ekleme Kılavuzu

Bu kılavuz, PEA'ya yeni egzersiz eklerken mevcut analiz mimarisini doğru kullanmak için yaşayan mühendislik kontratıdır. Biyomekanik doğruluk, güvenilir landmark seçimi veya threshold değerleri üretmez. Bu kararlar gerçek görüntü, diagnostics, deterministic testler ve cihaz ölçümüyle kanıtlanmalıdır.

> **Temel kural:** Bir egzersizin rehberde görünmesi, canlı analiz için desteklendiği anlamına gelmez. Analiz desteğinin merkezi kaynağı `ExerciseCatalog` sınıfıdır.

> **İkinci temel kural:** `ExerciseCatalog` içinde `supported` olmak, bütün cihazlarda doğrulanmış olmak anlamına gelmez. Catalog desteği ile device validation ayrı kanıt katmanlarıdır.

---

## 1. Kapsam

Bu belge üç farklı işi kapsar:

1. Kimliği ve rehber içeriği bulunan mevcut bir hareketin analiz contract/config yolunu genişletmek.
2. Kimliği, rehber içeriği ve analiz tanımı henüz bulunmayan tamamen yeni bir hareket eklemek.
3. Mevcut `rangeRep` veya `hold` ailesine yeni bir exercise-specific contract/config eklemek.

Şunlar ayrı mimari çalışmadır ve “hızlı egzersiz ekleme” kapsamında değildir:

- yeni pose modeli,
- yeni kamera pipeline'ı,
- çoklu kişi takibi,
- gerçek sağ-sol dönüşümlü tekrar state machine'i,
- mevcut hold family'lerine uymayan yeni statik posture semantiği,
- yeni persistence şeması,
- yeni engine ailesi.

---

## 2. Güncel destek durumu

| Egzersiz | Kalıcı ID | Rehber | Analiz | Engine / family |
| --- | --- | --- | --- | --- |
| Squat | `squat` | Var | Aktif | `rangeRep`, selected-side |
| Plank | `plank` | Var | Aktif | `hold`, `plank` family |
| Hollow Hold | `hollow_hold` | Var | Aktif | `hold`, `hollowHold` family |
| Stationary Lunge | `lunge` | Var | Aktif | `rangeRep`, selected-side |
| Push-up | `push_up` | Var | Aktif | `rangeRep`, selected-side |
| Sit-up | `sit_up` | Var | Aktif | `rangeRep`, selected-side |
| Biceps Curl | `biceps_curl` | Var | Aktif | `rangeRep`, bilateral |
| Lying Leg Raise | `lying_leg_raise` | Var | Aktif | `rangeRep`, selected-side |
| Triceps Dip | `triceps_dip` | Var | Aktif | `rangeRep`, selected-side |
| Romanian Deadlift | `romanian_deadlift` | Var | Aktif | `rangeRep`, selected-side |
| Lateral Raise | `lateral_raise` | Var | Aktif | `rangeRep`, bilateral, increasing-to-peak |
| Shoulder Press | `shoulder_press` | Var | Aktif | `rangeRep`, bilateral, increasing-to-peak |

Catalog desteği device-validation kanıtı değildir. Yeni eklenen hareketler gerçek cihazda ayrı kabul testi gerektirir.

`RangeRepEngine` artık hem `decreasingToPeak` hem `increasingToPeak` primary metric yönünü destekler. `bilateral`, dönüşümlü sağ-sol tekrar anlamına gelmez; iki tarafın aynı tekrar içinde eş zamanlı değerlendirilmesidir. Gerçek dönüşümlü tekrarlar için `EngineKind.alternatingRep` ayrı motor ailesidir ve henüz uygulanmamıştır.

Plank ve Hollow Hold ortak `HoldEngine` altyapısını kullanır; family-specific contract ve posture policy ile ayrılır.

---

## 3. Beş dakikalık engine karar ağacı

Yeni hareket için kod yazmadan önce aşağıdaki soruları cevapla.

### 3.1 Range-rep adayı

```text
1. Hareket neutral -> descending -> peak -> ascending -> neutral
   sırasına anlamlı biçimde uyuyor mu?
   ├─ Hayır -> Mevcut RangeRepEngine uygun değil.
   └─ Evet
       ↓
2. Ana metric neutral -> peak yönünde tekdüze olarak azalıyor veya artıyor mu?
   ├─ Hayır -> Mevcut RangeRepEngine uygun olmayabilir.
   └─ Evet -> `decreasingToPeak` veya `increasingToPeak` açıkça seç.
       ↓
3. Tek bir tarafın güvenilir ölçümü tekrar için yeterli mi?
   ├─ Evet -> RangeRepSideMode.selectedSide adayı.
   └─ Hayır
       ↓
4. İki taraf aynı tekrar içinde eş zamanlı değerlendirilmek zorunda mı?
   ├─ Evet -> RangeRepSideMode.bilateral adayı.
   └─ Hayır -> Yeni metrics/engine tasarımı gerekebilir.
```

`bilateral`, dönüşümlü sağ-sol tekrar anlamına gelmez. Biceps Curl örneğinde iki kol aynı rep içinde birlikte değerlendirilir.

Sağ ve sol taraf sırayla bağımsız tekrar sayacaksa `EngineKind.alternatingRep` düşünülebilir; ancak bu engine factory'de henüz uygulanmamıştır.

### 3.2 Hold adayı

```text
1. Hareket statik ve geçerli posture belirli semantik sinyallerle
   sürdürülebilir biçimde tanımlanabiliyor mu?
   ├─ Hayır -> HoldEngine uygun değil.
   └─ Evet
       ↓
2. Hareket mevcut bir HoldAnalysisFamily semantiğine uyuyor mu?
   ├─ Plank family -> alignment + support + extension
   ├─ Hollow Hold family -> compression + armExtension + kneeExtension
   └─ Hiçbiri -> Yeni hold family + contract + posture policy gerekir.
```

Yalnız JSON config eklemek yeni bir hold egzersizini otomatik olarak destekli yapmaz.

---

## 4. Mimari veri akışı

```text
ExerciseType
    ↓
ExerciseGuideContent
    ↓
ExerciseCatalog / ExerciseDefinition
    ↓
ExerciseAnalysisResolver
    ↓
ExerciseConfigResolver
    ↓
ExerciseLandmarkRequirements
    ↓
Pose quality / side selection
    ↓
ExerciseMetricsExtractor
    ↓
RangeRepContract veya HoldContract
    ↓
AnalysisEngineFactory
    ↓
RangeRepEngine veya HoldEngine + family posture policy
    ↓
WorkoutController
    ↓
Live Analysis UI + Diagnostics + Persistence
```

### Katman sahipliği

| Konu | Kaynak |
| --- | --- |
| Kalıcı egzersiz kimliği | `lib/features/workout_analysis/domain/models/exercise_type.dart` |
| Kullanıcıya gösterilen rehber metni | `lib/features/workout_analysis/presentation/data/exercise_guide_contents.dart` |
| Analiz destek politikası | `lib/features/workout_analysis/application/exercise_catalog.dart` |
| Engine/config metadata | `ExerciseDefinition` |
| Range-rep domain contract | `RangeRepContract` |
| Hold family contract | `HoldContract` |
| Config asset yükleme | `ExerciseConfigResolver` |
| Landmark gereksinimleri | `ExerciseLandmarkRequirements` |
| Pose -> motor sinyali dönüşümü | `ExerciseMetricsExtractor` |
| Motor oluşturma | `AnalysisEngineFactory` |
| Range tekrar state machine'i | `RangeRepEngine` |
| Statik hold state machine'i | `HoldEngine` |
| Hold family posture davranışı | `HoldPosturePolicy`, `HollowHoldPosturePolicy` |
| Oturum diagnostics | `WorkoutDiagnosticsSnapshot` |
| Persist edilen egzersiz kimliği | `WorkoutSession.exerciseType` |
| Session summary persistence | `WorkoutSessionFirestoreMapper` |
| Rep-level persistence | `WorkoutRepFirestoreMapper` |

### Selection ekranının önemli davranışı

`ExerciseSelectionScreen`, kartları guide content listesinden üretir ve aynı exercise kimliği için catalog kaydına bakar.

Bunun sonucu:

- Yalnız guide content eklersen hareket listede görünür ancak analiz kapalı olabilir.
- Yalnız catalog kaydı eklersen guide content yoksa hareket listede görünmeyebilir.
- `ExerciseType.id`, guide kimliği ve config/catalog eşleşmesi tutarlı olmalıdır.

---

## 5. Kimlik ve isimlendirme

Örnek:

```text
Dart enum:      bicepsCurl
Kalıcı ID:      biceps_curl
Config dosyası: biceps_curl.json
Başlık:         Biceps Curl
```

Kurallar:

1. Kalıcı ID `snake_case` olmalıdır.
2. Dart enum değeri `camelCase` olmalıdır.
3. Persist edilen ID, guide ve catalog boyunca aynı exercise kimliğini temsil etmelidir.
4. Kullanıcıya gösterilen başlık değişebilir; persisted ID yalnız estetik gerekçeyle değiştirilmez.
5. `WorkoutSession.exerciseType` Firestore'a string olarak yazılır. ID değişikliği migration gerektirebilir.
6. Tamamen yeni hareket için `ExerciseType` kaydı eklenir. Mevcut kimliği bulunan hareketlerde enum tekrar oluşturulmaz.

---

## 6. Mevcut bir hareketin analiz desteğini etkinleştirme

Bu akış, catalog içinde geçici olarak `unsupported` tutulan gelecekteki hareketler için kullanılabilir.

### Adımlar

1. Engine uyumluluğunu yazılı olarak açıkla.
2. Hareketi `rangeRep`, mevcut bir `hold` family veya yeni mimari çalışma olarak sınıflandır.
3. Ground-truth ve cihaz ölçüm planını oluştur.
4. Gerekli config JSON'unu ekle.
5. `rangeRep` ise `RangeRepContract` tanımla.
6. `hold` ise doğru `HoldContract` family'sini seç veya yeni family tasarla.
7. Extractor, landmark requirement ve engine testlerini yaz.
8. Diagnostics davranışını doğrula.
9. Persistence ve UI support durumunu test et.
10. Profile APK üret ve commit SHA'yı doğrula.
11. Gerçek cihaz kabul senaryolarını çalıştır.
12. Kanıt tamamlandığında catalog kaydını `supported` yap.

### Güncel catalog örüntüsü

Range-rep:

```dart
ExerciseDefinition.supported(
  type: ExerciseType.example,
  engineKind: EngineKind.rangeRep,
  configAssetPath: 'assets/config/exercises/example.json',
  rangeRepContract: RangeRepContracts.example,
),
```

Hold:

```dart
ExerciseDefinition.supported(
  type: ExerciseType.example,
  engineKind: EngineKind.hold,
  configAssetPath: 'assets/config/exercises/example.json',
  holdContract: HoldContracts.exampleFamily,
),
```

`ExerciseDefinition.supported` artık `id` veya `title` parametresi almaz. Bu değerler `ExerciseType` üzerinden türetilir.

Catalog kaydını yalnız config, contract ve testler hazır olduğunda `supported` yap. Daha güvenli akış, runtime doğrulaması tamamlanana kadar `unsupported` tutup enablement'i ayrı bir PR olarak yapmaktır.

---

## 7. Yeni range-rep egzersizi

### 7.1 Engine varsayımları

Mevcut `RangeRepEngine` şu temel varsayımlara sahiptir:

- neutral durumda ana açı yüksektir,
- descending sırasında ana açı düşer,
- peak düşük açı bölgesidir,
- ascending sırasında açı tekrar yükselir,
- neutral konuma dönüş tekrarın tamamlanmasıdır,
- peak'e ulaşmayan iniş tamamlanmış tekrar değildir.

Hareket yönü bu modele uymuyorsa threshold'ları ters çevirerek motoru zorla kullanma.

### 7.2 Minimum dosya seti

Tamamen yeni bir range-rep hareket için genellikle:

```text
lib/features/workout_analysis/domain/models/exercise_type.dart
lib/features/workout_analysis/domain/models/range_rep_contract.dart
lib/features/workout_analysis/application/exercise_catalog.dart
lib/features/workout_analysis/presentation/data/exercise_guide_contents.dart
assets/config/exercises/<exercise_id>.json
ilgili test dosyaları
```

değişir.

`pubspec.yaml`, `assets/config/exercises/` klasörünü topluca asset olarak ekler.

### 7.3 `RangeRepContract`

Factory mevcut motor için şu fazların tamamını ister:

```dart
RangeRepPhase.descending
RangeRepPhase.peak
RangeRepPhase.ascending
```

Ayrıca engine creation için:

```dart
RangeRepSignal.primaryMetric
RangeRepSignal.formMetric
```

sinyalleri contract içinde bulunmalıdır.

Minimum örnek:

```dart
static final RangeRepContract example = RangeRepContract(
  supportedPhases: const <RangeRepPhase>{
    RangeRepPhase.descending,
    RangeRepPhase.peak,
    RangeRepPhase.ascending,
  },
  supportedSignals: const <RangeRepSignal>{
    RangeRepSignal.primaryMetric,
    RangeRepSignal.formMetric,
  },
);
```

### 7.4 Pose acceptance sinyalleri

`supportedSignals`, engine ve analysis pipeline'ın kullanabileceği sinyalleri tanımlar.

`poseAcceptanceRequiredSignals`, bir frame'in pose kabulü için zorunlu olan alt kümeyi tanımlar.

Örnek Sit-up yaklaşımı:

```dart
poseAcceptanceRequiredSignals: const <RangeRepSignal>{
  RangeRepSignal.primaryMetric,
},
```

Bu, form metric'in analiz için desteklenebildiği ancak pose kabulünü tek başına bloke etmeyebildiği anlamına gelir.

`poseAcceptanceRequiredSignals`, her zaman `supportedSignals` kümesinin alt kümesi olmalıdır.

### 7.5 Form-threshold calibration policy

Varsayılan:

```dart
RangeRepFormThresholdCalibrationPolicy.enabled
```

Bazı egzersizlerde session baseline ile form threshold offset'i uygulanması semantik olarak uygun değilse:

```dart
formThresholdCalibrationPolicy:
    RangeRepFormThresholdCalibrationPolicy.disabled,
```

kullanılır.

Sit-up ve Biceps Curl güncel örneklerdir.

### 7.6 Side mode

Varsayılan:

```dart
RangeRepSideMode.selectedSide
```

Bu modda sol ve sağ adaylardan biri seçilir ve engine o tarafın normalized metric'lerini kullanır.

İki taraf aynı rep içinde birlikte değerlendirilmek zorundaysa:

```dart
sideMode: RangeRepSideMode.bilateral,
```

kullanılabilir.

Biceps Curl güncel bilateral örnektir. Bilateral metrics, iki kolun primary metric ve form değerlerini birlikte çözer.

Bu mod gerçek alternating-rep motoru değildir.

---

## 8. Range-rep config referansı

Çalışan örnekler:

```text
assets/config/exercises/squat.json
assets/config/exercises/push_up.json
assets/config/exercises/sit_up.json
assets/config/exercises/biceps_curl.json
```

### Temel alanlar

| Alan | Anlam | Durum |
| --- | --- | --- |
| `name` | İnsan tarafından okunabilir config adı | Zorunlu |
| `primaryJoint` | Ana açının orta landmark'ı | Zorunlu |
| `joint1` | Ana açının ilk landmark'ı | Zorunlu |
| `joint2` | Ana açının son landmark'ı | Zorunlu |
| `thresholdNeutral` | Neutral ve neutral'a dönüş bölgesi | Gerekli |
| `thresholdActive` | Aktif faza geçiş | Gerekli |
| `thresholdPeak` | Peak bölgesi | Gerekli |
| `idealDescentSeconds` | İdeal ilk faz süresi | Skor için |
| `idealAscentSeconds` | İdeal dönüş fazı süresi | Skor için |
| `formThreshold` | Form metriği sınırı | Form değerlendirmesi için |
| `targetMinAngle` | ROM skor hedefi | Skor için |
| `tempoPenaltyPerSecond` | Tempo sapması cezası | Skor için |
| `rangeRepSignals` | Ek normalized sinyaller | Önerilir |
| `rangeRepScoreWeights` | Skor ağırlıkları | Opsiyonel |
| `rangeRepPhaseQuality` | Minimum faz süreleri | Opsiyonel |

Parser bazı legacy numerik alanlarda fallback davranışı taşıyabilir. Yeni config'lerde threshold, tempo ve skor alanlarını açıkça yaz.

### Signal tanımları

Açı üçlüsü:

```json
{
  "first": "leftShoulder",
  "middle": "leftHip",
  "last": "leftAnkle"
}
```

Ana metriğe alias:

```json
{
  "source": "primaryMetric"
}
```

Transform kullanan açı:

```json
{
  "first": "leftElbow",
  "middle": "leftShoulder",
  "last": "leftHip",
  "transform": "complement180"
}
```

Desteklenen transform'lar:

```text
identity
complement180
```

`complement180`, hesaplanan açıyı `180 - angle` semantiğine dönüştürür. Biceps Curl posture metric güncel production örneğidir.

Bir signal `source` veya angle triple tanımından birini kullanmalıdır; ikisini aynı anda taşımaz.

Desteklenen ek signal adları:

```text
postureAngle
depthMetric
alignmentMetric
stabilityMetric
endRangeMetric
bottomControlMetric
```

Contract'ta desteklenen signal ile JSON config'teki extraction tanımı tutarlı olmalıdır.

---

## 9. Threshold ve config kalibrasyonu

Yeni egzersiz threshold'ları mevcut hareketlerden körlemesine kopyalanmaz.

Önerilen sıra:

1. Profile build üret.
2. Live Analysis calibration/debug yüzeyini aç.
3. Neutral, active, gerçek peak ve dönüş değerlerini gözle.
4. Selected-side hareketlerde sol ve sağ görünümü ayrı test et.
5. Bilateral hareketlerde iki tarafın aynı frame içindeki eş zamanlı davranışını gözle.
6. Ground truth tut.
7. Başlangıç config'i oluştur.
8. Static-negative ve partial-rep testlerini çalıştır.
9. Occlusion ve lifecycle senaryolarını çalıştır.
10. Diagnostics JSON'u incele.
11. Threshold'u yalnız hatanın gerçekten threshold kaynaklı olduğu kanıtlandıysa değiştir.

“Rep saymıyor” sonucu tek başına threshold değiştirme gerekçesi değildir.

---

## 10. Hold egzersizi ekleme

Çalışan production örnekleri:

```text
assets/config/exercises/plank.json
assets/config/exercises/hollow_hold.json
```

### 10.1 Ortak mimari

Hold pipeline şu bileşenlerden oluşur:

```text
ExerciseDefinition
  -> HoldContract
  -> holdSignals config
  -> HoldAnalysisFamily
  -> family-specific posture policy
  -> shared HoldEngine
```

`HoldContract`, motor family'sinin beklediği semantik signal setini tanımlar.

`holdSignals`, bu semantik signal'ların hangi landmark angle triple'larından çıkarılacağını tanımlar.

`AnalysisEngineFactory`, family'ye göre uygun posture policy'yi oluşturur.

### 10.2 Plank family

Contract:

```text
alignment
support
extension
```

Posture config:

```text
activePostureAngle
bodyLineEntryAngle
bodyLineSustainAngle
armSupportMinAngle
armSupportMaxAngle
legExtensionMinAngle
breakGraceMillis
```

### 10.3 Hollow Hold family

Contract:

```text
compression
armExtension
kneeExtension
```

Posture config:

```text
activePostureMaxAngle
compressionEntryMaxAngle
compressionSustainMaxAngle
armExtensionMinAngle
kneeExtensionMinAngle
breakGraceMillis
```

### 10.4 Hold signal config

Her hold config bir `referenceSide` ve family contract'ının gerektirdiği signal tanımlarını taşımalıdır.

Plank örneği:

```json
"holdSignals": {
  "referenceSide": "left",
  "alignment": {
    "first": "leftShoulder",
    "middle": "leftHip",
    "last": "leftAnkle"
  },
  "support": {
    "first": "leftShoulder",
    "middle": "leftElbow",
    "last": "leftWrist"
  },
  "extension": {
    "first": "leftHip",
    "middle": "leftKnee",
    "last": "leftAnkle"
  }
}
```

Hollow Hold örneği farklı semantik key'ler kullanır:

```text
compression
armExtension
kneeExtension
```

### 10.5 Bilateral extraction ve side lock

Config canonical geometriyi tek `referenceSide` üzerinden tanımlar. Karşı taraf requirement ve extraction landmark'ları paired-landmark mirroring ile türetilir.

Controller:

- left/right pose quality adaylarını değerlendirir,
- seçilen hold side'ı stabilize eder,
- aktif attempt boyunca side'ı lock eder,
- kısa visibility gap sırasında side continuity'yi korur.

Bu davranış, bütün hold family'lerinin bütün kamera açılarında doğrulandığı anlamına gelmez. Cihaz kabulü egzersiz bazında yapılmalıdır.

### 10.6 Yeni hold family ne zaman gerekir?

Yeni statik hareket:

- Plank'in alignment/support/extension semantiğine,
- Hollow Hold'un compression/armExtension/kneeExtension semantiğine

uymuyorsa yalnız config ekleme.

Yeni family çalışması en az:

1. `HoldAnalysisFamily` genişletmesi,
2. `HoldContract`,
3. required signal seti,
4. config parser alanları,
5. metrics extraction,
6. posture policy,
7. factory validation ve routing,
8. diagnostics,
9. deterministic testler,
10. gerçek cihaz kanıtı

gerektirir.

---

## 11. Yeni engine ailesi ne zaman gerekir?

Aşağıdaki durumlardan biri varsa mevcut config-only yolu kullanma:

- ana metric mevcut neutral/descending/peak/ascending sırasına uymuyorsa,
- sağ ve sol taraf sırayla bağımsız rep sayıyorsa,
- bir rep birden fazla bağımsız state machine gerektiriyorsa,
- adım veya denge yönü state'in parçasıysa,
- bilateral aggregation mevcut `RangeRepSideMode.bilateral` ile ifade edilemiyorsa,
- statik posture mevcut hold family'lerinden hiçbirine uymuyorsa.

Yeni engine çalışması en az:

1. Domain contract.
2. Engine implementation.
3. Metrics modeli ve extractor.
4. Factory kaydı.
5. Controller sonucu.
6. Diagnostics.
7. Persistence anlamı.
8. Deterministic testler.
9. Profile build ve gerçek cihaz ölçümü.

---

## 12. Rehber içeriği

Yeni bir egzersiz için `ExerciseGuideContent` ürün metni taşır.

Kurallar:

- Guide kimliği kalıcı exercise ID ile tutarlı olmalıdır.
- Tıbbi doğruluk, rehabilitasyon veya yaralanmayı önleme iddiası yazma.
- Rahatsızlık durumunda zorlamama yönlendirmesi kullanılabilir.
- Video kaynağı gerçek ve ilgili olmalıdır.
- Guide metni, catalog desteği kapalı bir hareketi analiz aktifmiş gibi anlatmamalıdır.
- Kullanıcı metinlerinde Türkçe karakterleri doğru kullan.

---

## 13. Persistence ve geriye uyumluluk

Session yapısı:

```text
users/{uid}/sessions/{sessionId}
```

Rep subcollection:

```text
users/{uid}/sessions/{sessionId}/reps/{repId}
```

Yeni exercise ID için şu kontroller zorunludur:

- session document doğru exercise ID içeriyor mu,
- `analysisKind` doğru mu,
- range-rep session'da rep subcollection doğru yazılıyor mu,
- history/detail ekranları ID'yi doğru başlığa map ediyor mu,
- aggregate veya filter kodunda hardcoded liste var mı,
- Firestore rules davranışı uyumlu mu,
- rep mapper yeni analysis semantiğini taşıyabiliyor mu.

Session document summary-level olabilir; bu, rep-level persistence'ın olmadığı anlamına gelmez.

Kalıcı exercise ID'yi sonradan değiştirmek migration gerektirebilir.

---

## 14. Hedef Definition of Done test matrisi

Bu bölüm yeni veya yeniden etkinleştirilen hareketi `supported` yapmadan önce hedeflenen minimum doğrulamadır.

### 14.1 Catalog

- Definition var.
- ID/title doğru.
- `isAnalysisSupported` doğru.
- Engine kind doğru.
- Config path doğru.
- Range-rep ise contract doğru.
- Hold ise contract family doğru.

### 14.2 Resolver

- Supported seçim aktif exercise döndürüyor.
- Unsupported seçim `null` döndürüyor.
- Null seçim `null` döndürüyor.

### 14.3 Config parsing

- Asset yükleniyor.
- Landmark isimleri geçerli.
- Numeric alanlar parse ediliyor.
- Bilinmeyen signal key reddediliyor.
- Signal `source` ve angle triple'ı aynı anda kullanamıyor.
- Bilinmeyen transform reddediliyor.
- Eksik asset açık hata üretiyor.

### 14.4 Range-rep contract

- Required phases mevcut.
- `primaryMetric` ve `formMetric` mevcut.
- Pose acceptance seti supported signal setinin alt kümesi.
- Calibration policy egzersiz semantiğine uygun.
- Side mode doğru.

### 14.5 Metrics extractor

Selected-side range-rep:

- sol primary/form metric,
- sağ landmark mapping,
- optional signals,
- missing landmark,
- side confidence.

Bilateral range-rep:

- left metric,
- right metric,
- bilateral primary aggregation,
- bilateral form/sync davranışı,
- bir taraf eksikken davranış.

Hold:

- family'nin required signals'ı,
- reference-side parsing,
- paired landmark mirroring,
- right-only extraction,
- missing landmark davranışı.

### 14.6 Engine

Range-rep:

1. Neutral bekleme false rep üretmez.
2. Tam faz sırası tam bir rep üretir.
3. Peak'e ulaşmayan hareket rep üretmez.
4. Partial hareket neutral'a dönünce rep üretmez.
5. Confirmation süresinden kısa noise state değiştirmez.
6. Form metric feedback'i doğru etkiler.
7. Reset state'i temizler.

Hold:

1. Geçerli posture hold başlatır.
2. Geçersiz posture hold başlatmaz.
3. Family-specific signal ihlali doğru feedback üretir.
4. Grace içindeki kısa bozulma hemen kesmez.
5. Grace aşılırsa hold kesilir.
6. Best hold korunur.
7. Reset state'i temizler.

### 14.7 UI

- Guide kartı listeleniyor.
- Supported hareket analiz aktif gösteriyor.
- Unsupported hareket analiz ekranına geçmiyor.
- Selected exercise doğru `ExerciseType` değerini taşıyor.
- Kullanıcı copy'si engine jargonunu gereksiz taşımıyor.

### 14.8 Persistence

- Session document doğru exercise ID içeriyor.
- Analysis kind doğru.
- Range-rep rep documents yazılıyor.
- Displayed total ve session total tutarlı.
- Hold duration alanları doğru.

---

## 15. Yerel doğrulama

Değişen kapsam doğrultusunda en az:

```bash
dart format --set-exit-if-changed <değişen-dart-dosyaları>
flutter analyze --no-pub
flutter test --no-pub
```

Yeni config için hedefli testleri önce, full suite'i sonra çalıştır.

Profile cihaz build'i:

```bash
flutter build apk \
  --profile \
  --dart-define=PEA_COMMIT_SHA="$(git rev-parse HEAD)"
```

Windows PowerShell:

```powershell
$sha = git rev-parse HEAD
flutter build apk --profile --dart-define=PEA_COMMIT_SHA=$sha
```

Resmî ölçüm için mümkünse `Android Profile Beta Artifact` workflow'undan üretilen APK kullanılmalıdır.

---

## 16. Gerçek cihaz kabul kapısı

Unit testler yeni hareketi desteklenmiş saymak için yeterli değildir.

### Range-rep minimum senaryoları

- kontrollü tam tekrar seti,
- hareketsiz negatif test,
- partial/aborted hareket,
- kısa pose kaybı,
- uzun pose kaybı,
- pause/resume,
- selected-side ise sağ ve sol görünüm,
- bilateral ise iki taraf eş zamanlı görünürlük ve asimetri senaryoları,
- düşük ışık,
- ikinci kişi,
- uzun session,
- session save + rep docs + history karşılaştırması.

### Hold minimum senaryoları

- geçerli hold,
- geçersiz posture,
- family-specific form break,
- kısa ve uzun pose kaybı,
- pause/resume,
- sağ ve sol görünüm,
- düşük ışık,
- uzun session,
- session save ve history karşılaştırması.

### Her run için kaydedilecekler

```text
test_run_id
exercise_id
scenario
device/model
Android version
build mode
app version
commit SHA
ground truth
app result
false positive / false negative
diagnostics JSON
crash/freeze
persistence result
notes
```

Commit SHA veya build kimliği yoksa sonuç geçersizdir.

Catalog support, yalnız ilgili exercise'ın cihaz kabul kanıtı tamamlandığında device-validated olarak yorumlanabilir. Başka hareketin eski beta kanıtı otomatik olarak devralınmaz.

---

## 17. Diagnostics kullanımı

**Calibration/live debug yüzeyi** şu soruyu cevaplar:

> O anda hangi açı ve sinyal görülüyor?

**Beta Diagnostics paneli** şu soruyu cevaplar:

> Oturum boyunca frame, pose, side, visibility ve performans davranışı nasıldı?

Range-rep ve hold diagnostics aynı JSON schema içinde compatibility alanları taşıyabilir. Analysis kind bağlamı dışında `0`, `false` veya null değerleri performans sonucu gibi yorumlama.

Yeni egzersiz kalibrasyonunda anlık debug yüzeyi ve run-level diagnostics birlikte kullanılmalıdır.

---

## 18. Hızlı geliştirme akışı

```text
1. Egzersiz tasarım formunu doldur
2. Engine/family uyumluluğunu kararlaştır
3. Ground-truth ölçüm planını yaz
4. Kimlik ve guide kaydını ekle
5. Config ve contract ekle
6. Başlangıçta catalog kaydını gerekirse unsupported tut
7. Landmark requirement / extractor testlerini yaz
8. Engine veya posture-policy testlerini yaz
9. UI ve persistence testlerini tamamla
10. Full suite çalıştır
11. Profile APK üret
12. Diagnostics ile cihaz ölçümü yap
13. Kabul kriterleri geçerse supported yap
14. Draft PR incelemesi
```

En güvenli yaklaşım, enablement'i ayrı ve küçük bir PR olarak yapmaktır.

---

## 19. Anti-pattern'ler

1. Yalnız enum'a egzersiz eklemek.
2. Guide content ekleyip analizin hazır olduğunu varsaymak.
3. Catalog'u supported yapıp config veya contract eklememek.
4. Başka egzersizin threshold'larını kopyalamak.
5. Range-rep açı yönünü kontrol etmemek.
6. Contract ile JSON signal'larını uyumsuz bırakmak.
7. Pose acceptance ile supported signal kavramlarını aynı sanmak.
8. Bilateral mode'u alternating rep sanmak.
9. Selected-side hareketi yalnız sol tarafta test etmek.
10. Bilateral hareketi yalnız tek taraf görünürken doğrulanmış saymak.
11. Static-negative testi atlamak.
12. HoldEngine'i bütün statik hareketler için genel motor sanmak.
13. Plank signal setini Hollow Hold'a kopyalamak.
14. Yeni hold family gereken hareketi yalnız JSON ile zorlamak.
15. Commit SHA olmadan cihaz sonucu kaydetmek.
16. Diagnostics kanıtı olmadan threshold değiştirmek.
17. Catalog support'u device validation ile eşitlemek.
18. Kalıcı exercise ID'yi estetik gerekçeyle değiştirmek.
19. Session document summary-level diye rep persistence yok sanmak.

---

## 20. Sorun giderme

| Belirti | Olası neden | İlk kontrol |
| --- | --- | --- |
| Hareket listede görünüyor ama açılamıyor | Catalog unsupported veya ID uyuşmazlığı | `ExerciseCatalog`, guide ID |
| Hareket listede görünmüyor | Guide content eksik | `exercise_guide_contents.dart` |
| Açılışta config hatası | Yanlış asset path veya bozuk JSON | Catalog path, parser |
| Hiç rep saymıyor | Yanlış engine, landmark, pose acceptance veya threshold | Contract, calibration, extractor |
| Partial hareket rep oluyor | Faz gate'leri gevşek | Engine partial-rep testi |
| Neutral beklerken rep oluyor | Arming/confirmation/noise | Static-negative testi |
| Sağ tarafta çalışmıyor | Side mapping veya visibility | Right-side extractor testi |
| Bilateral curl tek kol hareketinde sayıyor | Bilateral aggregation/pose acceptance sorunu | Bilateral extractor ve contract |
| Hold hiç başlamıyor | Yanlış family veya required signal | Hold contract + posture policy |
| Hold yanlış feedback veriyor | Family signal mapping sorunu | `holdSignals`, mapper, policy |
| Hold geç kesiliyor | Grace fazla büyük | `breakGraceMillis` |
| FPS düşüyor | İşleme maliyeti veya cihaz sınırı | Diagnostics p95/max/FPS |
| Session doğru ama rep detayları yok | `session.reps` assembly/persistence sorunu | Rep mapper + subcollection |
| Dönüşümlü hareket yanlış sayılıyor | Uygulanmamış engine ailesi | `alternatingRep` tasarımı |

---

## 21. Egzersiz tasarım formu

Kod yazmadan önce bu bölümü issue veya PR açıklamasına kopyala.

```markdown
# Egzersiz Tasarım Formu

## Kimlik
- Kullanıcı başlığı:
- Kalıcı ID:
- Dart enum adı:
- Config dosyası:

## Ürün kapsamı
- Rehber içeriği hazır mı?
- Analiz ilk sürümde aktif mi, unsupported mı kalacak?
- Tıbbi/rehabilitasyon iddiası var mı? (Olmamalı)

## Engine kararı
- Engine kind:
- Range-rep side mode:
- Hold family:
- Mevcut engine/family'ye neden uyuyor?
- Neutral tanımı:
- Aktif faz tanımı:
- Peak veya geçerli hold tanımı:
- Tamamlanmış tekrar/hold bitişi:
- Geçersiz/yarım hareket tanımı:

## Landmark ve sinyaller
- Primary joint:
- Joint 1:
- Joint 2:
- Form metric:
- Supported signals:
- Pose-acceptance required signals:
- Hold required signals:
- Sol taraf desteği:
- Sağ taraf desteği:
- Bilateral semantik:
- Eksik landmark davranışı:

## Kalibrasyon
- Form threshold calibration policy:
- Neutral gözlenen aralık:
- Active geçiş gözlenen aralık:
- Peak gözlenen aralık:

## Ölçüm kanıtı
- Kullanılan cihaz:
- Kamera açısı:
- Ground truth yöntemi:
- Diagnostics kanıtı:

## Test planı
- Pozitif senaryo:
- Static-negative:
- Partial motion:
- Occlusion:
- Lifecycle:
- Low light:
- Long session:
- Persistence:

## Kabul kriterleri
- Rep/hold hata toleransı:
- False positive sınırı:
- Recovery beklentisi:
- Performans beklentisi:
```

Threshold veya landmark seçimi için ölçüm kanıtı yoksa değer uydurma. Hareketi unsupported tut.

---

## 22. Definition of Done

```markdown
- [ ] Engine/family uygunluğu yazılı olarak açıklandı
- [ ] Kalıcı ID tüm katmanlarda tutarlı
- [ ] Rehber içeriği mevcut
- [ ] Catalog tanımı doğru
- [ ] Config asset parse ediliyor
- [ ] Range-rep ise contract factory şartlarını karşılıyor
- [ ] Range-rep side mode doğru
- [ ] Pose-acceptance signal seti doğru
- [ ] Calibration policy doğru
- [ ] Hold ise doğru family contract kullanılıyor
- [ ] Family-specific posture policy test edildi
- [ ] Sol taraf extractor testi geçti
- [ ] Sağ taraf extractor testi geçti
- [ ] Bilateral ise bilateral aggregation testi geçti
- [ ] Eksik landmark testi geçti
- [ ] Neutral/static-negative testi geçti
- [ ] Tam tekrar veya hold testi geçti
- [ ] Partial/invalid hareket testi geçti
- [ ] Occlusion testi geçti
- [ ] Pause/resume testi geçti
- [ ] Reset testi geçti
- [ ] UI support durumu doğru
- [ ] Session persistence doğru
- [ ] Range-rep ise rep subcollection doğrulandı
- [ ] flutter analyze temiz
- [ ] Full test suite başarılı
- [ ] Profile APK üretildi
- [ ] APK commit SHA doğrulandı
- [ ] Diagnostics JSON alındı
- [ ] Gerçek cihaz kabul ölçümü tamamlandı
- [ ] PR CI başarılı
- [ ] Hareket yalnız kendi kanıtı tamamlandıysa supported yapıldı
```

---

## 23. PR kapsamı önerisi

Yeni egzersizi tek büyük PR'a sıkıştırmak yerine şu bölünme tercih edilir:

1. **Design/config PR:** engine/family kararı, contract, config parser testleri; hareket gerekirse hâlâ unsupported.
2. **Runtime/test PR:** extractor, posture policy veya engine davranışı, diagnostics, deterministic testler.
3. **Enablement PR:** catalog supported, UI, persistence, profile artifact ve cihaz kanıtı.

Mevcut engine/family'ye açıkça uyan küçük hareketlerde ilk iki adım birleştirilebilir. Cihaz kanıtı olmadan enablement yapılmaz.

---

## 24. Kılavuz bakım kuralı

Şunlardan biri değişirse bu belge aynı PR içinde güncellenmelidir:

- `ExerciseType` veya ID politikası,
- `ExerciseDefinition`,
- `EngineKind`,
- `RangeRepContract`,
- `HoldContract` veya `HoldAnalysisFamily`,
- config JSON şeması veya signal transform'ları,
- `ExerciseLandmarkRequirements`,
- `ExerciseMetricsExtractor`,
- range-rep/hold state machine varsayımları,
- diagnostics alanları,
- persistence modeli,
- profile artifact veya cihaz kabul süreci.

Mimari değişip kılavuz değişmezse geliştirme süreci kısa sürede kabile hafızasına dönüşür. Bu belge kaynak kodla birlikte yaşayan bir kontrattır.
