# Yeni Egzersiz Ekleme Kılavuzu

Bu kılavuz, PEA'ya yeni egzersiz ekleme sürecini hızlandırır. Biyomekanik doğruluk, uygun landmark seçimi veya güvenilir threshold değerleri üretmez. Bu değerler gerçek görüntü, diagnostics ve cihaz ölçümüyle belirlenmelidir.

> **Temel kural:** Bir egzersizin rehberde görünmesi, analiz için desteklendiği anlamına gelmez. Analiz desteğinin merkezi kaynağı `ExerciseCatalog` sınıfıdır.

## 1. Kapsam

Bu belge iki farklı işi kapsar:

1. `lunge` veya `sit_up` gibi projede kimliği ve rehber içeriği bulunan ancak analiz desteği kapalı bir hareketi etkinleştirmek.
2. Kimliği, rehber içeriği ve analiz tanımı henüz bulunmayan tamamen yeni bir hareket eklemek.

Şunlar ayrı mimari çalışmadır ve “hızlı egzersiz ekleme” kapsamında değildir:

- yeni pose modeli,
- yeni kamera pipeline'ı,
- çoklu kişi takibi,
- dönüşümlü sağ-sol tekrar state machine'i,
- mevcut sinyallere uymayan yeni hold geometrisi,
- yeni persistence şeması,
- yeni engine ailesi.

## 2. Mevcut destek durumu

| Egzersiz | Kalıcı ID | Rehber | Analiz | Engine |
| --- | --- | --- | --- | --- |
| Squat | `squat` | Var | Aktif | `rangeRep` |
| Plank | `plank` | Var | Aktif | `hold` |
| Lunge | `lunge` | Var | Kapalı | Belirlenmeli |
| Push-up | `push_up` | Var | Aktif | `rangeRep` |
| Sit-up | `sit_up` | Var | Kapalı | Belirlenmeli |

`lunge` ve `sit_up` için `ExerciseType` ve rehber içeriği zaten vardır. Bunları etkinleştirirken yeniden enum veya rehber kaydı eklenmez; önce engine uyumluluğu kanıtlanır.

## 3. Beş dakikalık karar ağacı

Yeni hareket için kod yazmadan önce aşağıdaki soruları sırayla cevapla.

```text
1. Hareket tek bir ana eklem açısıyla güvenilir biçimde izlenebiliyor mu?
   ├─ Hayır → Mevcut rangeRep yolu uygun değil.
   └─ Evet
       ↓
2. Başlangıçta açı yüksek, aktif fazda düşük, dönüşte tekrar yüksek mi?
   ├─ Hayır → Mevcut rangeRep state machine'i uygun değil.
   └─ Evet
       ↓
3. Hareket neutral → descending → peak → ascending → neutral sırasına uyuyor mu?
   ├─ Hayır → Yeni engine veya engine genişletmesi gerekir.
   └─ Evet
       ↓
4. Sol ve sağ tarafta aynı landmark üçlüsüyle ölçülebiliyor mu?
   ├─ Hayır → Metrics extractor tasarımı gerekir.
   └─ Evet → rangeRep hızlı yolu adayıdır.
```

Statik hareket için:

```text
1. Geçerli postür; omuz-kalça-ayak bileği, omuz-dirsek-bilek ve
   kalça-diz-ayak bileği açılarıyla anlamlı biçimde tanımlanabiliyor mu?
   ├─ Hayır → Mevcut hold yolu uygun değil.
   └─ Evet
       ↓
2. Plank benzeri aynı geometri ve form-break mantığı geçerli mi?
   ├─ Hayır → Yeni hold contract/metrics tasarımı gerekir.
   └─ Evet → hold hızlı yolu adayıdır.
```

Dönüşümlü tekrar, tek taraflı sıra takibi veya birden fazla bağımsız faz gerekiyorsa `EngineKind.alternatingRep` düşünülebilir; ancak bu engine factory'de henüz uygulanmamıştır. Yalnız enum değerinin bulunması, motorun çalıştığı anlamına gelmez.

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
ExerciseMetricsExtractor
    ↓
AnalysisEngineFactory
    ↓
RangeRepEngine veya HoldEngine
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
| Bir hareketin engine/config metadata'sı | `ExerciseDefinition` |
| Aktif analiz hareketini çözme | `ExerciseAnalysisResolver` |
| Config asset yükleme | `ExerciseConfigResolver` |
| Pose → motor sinyali dönüşümü | `ExerciseMetricsExtractor` |
| Motor oluşturma | `AnalysisEngineFactory` |
| Range tekrar state machine'i | `RangeRepEngine` |
| Statik hold state machine'i | `HoldEngine` |
| Kullanıcıya aktif/pasif gösterim | Guide content + catalog |
| Oturum diagnostics | `WorkoutDiagnosticsSnapshot` |
| Persist edilen egzersiz kimliği | `WorkoutSession.exerciseType` string alanı |

### Selection ekranının önemli davranışı

`ExerciseSelectionScreen`, kartları `exerciseGuideContents` listesinden üretir. Daha sonra aynı `id` ile katalog kaydını arar.

Bunun sonucu:

- Yalnız guide content eklersen hareket listede görünür ama analiz kapalı olur.
- Yalnız catalog kaydı eklersen guide content yoksa hareket listede görünmez.
- Guide ID, catalog ID ve `ExerciseType.id` birebir aynı olmalıdır.

## 5. Kimlik ve isimlendirme

Örnek:

```text
Dart enum:      pushUp
Kalıcı ID:      push_up
Config dosyası: push_up.json
Guide ID:       push_up
Başlık:         Push-up
```

Kurallar:

1. Kalıcı ID `snake_case` olmalıdır.
2. Dart enum değeri `camelCase` olmalıdır.
3. `ExerciseType.id`, guide content `id`, catalog `id` ve config dosya adı aynı kökten gelmelidir.
4. Kullanıcıya gösterilen başlık değişebilir; kalıcı ID yalnız yazım güzelleştirmek için değiştirilmez.
5. Persist edilen oturumlar `exerciseType` değerini string olarak saklar. ID değişikliği geçmiş veriyi parçalayabilir.
6. Tamamen yeni hareket için enum'a kayıt eklenir. `lunge` ve `sit_up` gibi mevcut hareketlerde eklenmez.

## 6. Hızlı yol A: Mevcut unsupported hareketi etkinleştirme

Bu yol `lunge` ve `sit_up` gibi enum ve rehber kaydı hazır olan hareketler içindir.

### Adımlar

1. Engine uyumluluk belgesi hazırla.
2. Hareketi `rangeRep`, `hold` veya yeni engine olarak sınıflandır.
3. Gerekli config JSON'unu ekle.
4. `rangeRep` ise `RangeRepContract` tanımla.
5. `ExerciseCatalog` içindeki kaydı `unsupported` yerine `supported` yap.
6. Config path ve engine kind ekle.
7. Extractor ve engine testlerini yaz.
8. Selection ekranında “Analiz aktif” durumunu test et.
9. Profile APK üret.
10. Diagnostics ile gerçek cihaz kabul testlerini çalıştır.

### Catalog örüntüsü

Range-rep hareket için yapı şu biçimdedir:

```dart
ExerciseDefinition.supported(
  type: ExerciseType.example,
  id: ExerciseType.example.id,
  title: ExerciseType.example.title,
  engineKind: EngineKind.rangeRep,
  configAssetPath: 'assets/config/exercises/example.json',
  rangeRepContract: RangeRepContracts.example,
),
```

Hold hareket için:

```dart
ExerciseDefinition.supported(
  type: ExerciseType.example,
  id: ExerciseType.example.id,
  title: ExerciseType.example.title,
  engineKind: EngineKind.hold,
  configAssetPath: 'assets/config/exercises/example.json',
),
```

Catalog kaydını yalnız config ve testler hazır olduğunda `supported` yap. Geçici olarak aktif gösterip sonra motoru düzeltmek, false-rep üretimini doğrudan kullanıcı yüzeyine taşır.

## 7. Hızlı yol B: Tamamen yeni range-rep egzersiz

Mevcut `RangeRepEngine` şu temel varsayımlara sahiptir:

- neutral durumda ana açı yüksektir,
- descending sırasında ana açı düşer,
- peak düşük açı bölgesidir,
- ascending sırasında açı tekrar yükselir,
- neutral konuma dönüş tekrarın tamamlanmasıdır,
- peak'e ulaşmayan iniş tamamlanmış tekrar değildir.

Bu hareket yönüne uymayan bir egzersizi threshold'ları ters çevirerek zorla bağlama. State machine semantiği de değişiyorsa yeni engine veya açık bir engine genişletmesi gerekir.

### Minimum dosya seti

Tamamen yeni, mevcut range-rep ailesine uyan hareket için genellikle şunlar değişir:

```text
lib/features/workout_analysis/domain/models/exercise_type.dart
lib/features/workout_analysis/domain/models/range_rep_contract.dart
lib/features/workout_analysis/application/exercise_catalog.dart
lib/features/workout_analysis/presentation/data/exercise_guide_contents.dart
assets/config/exercises/<exercise_id>.json
ilgili test dosyaları
```

`pubspec.yaml`, şu anda `assets/config/exercises/` klasörünü topluca asset olarak ekler. JSON bu klasör altında kaldığı sürece dosyayı tek tek `pubspec.yaml` içine yazma.

### RangeRepContract

Factory, mevcut range-rep motoru için aşağıdaki fazların tamamını ister:

```dart
RangeRepPhase.descending
RangeRepPhase.peak
RangeRepPhase.ascending
```

Ayrıca şu sinyaller zorunludur:

```dart
RangeRepSignal.primaryMetric
RangeRepSignal.formMetric
```

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

Opsiyonel signal yalnız JSON config gerçekten değer üretiyorsa contract'a eklenmelidir.

- Contract'ta signal var, JSON'da tanımı yoksa diagnostics ve scoring eksik veri görebilir.
- JSON'da signal var, contract'ta yoksa extractor o sinyali kullanmaz.

## 8. Range-rep config referansı

Çalışan örnekler:

```text
assets/config/exercises/squat.json
assets/config/exercises/push_up.json
```

### Temel alanlar

| Alan | Anlam | Durum |
| --- | --- | --- |
| `name` | İnsan tarafından okunabilir config adı | Zorunlu |
| `primaryJoint` | Ana açının orta landmark'ı | Zorunlu |
| `joint1` | Ana açının ilk landmark'ı | Zorunlu |
| `joint2` | Ana açının son landmark'ı | Zorunlu |
| `thresholdNeutral` | Neutral ve neutral'a dönüş bölgesi | Range-rep için gerekli |
| `thresholdActive` | Aktif inişe geçiş bölgesi | Range-rep için gerekli |
| `thresholdPeak` | Peak/derinlik bölgesi | Range-rep için gerekli |
| `idealDescentSeconds` | İdeal iniş süresi | Skor için kullanılır |
| `idealAscentSeconds` | İdeal çıkış süresi | Skor için kullanılır |
| `formThreshold` | Form metriği sınırı | Form değerlendirmesi için kullanılır |
| `targetMinAngle` | ROM skor hedefi | Skor için kullanılır |
| `tempoPenaltyPerSecond` | Tempo sapması cezası | Skor için kullanılır |
| `rangeRepSignals` | Ek ölçüm sinyalleri | Yeni hareketlerde açık tanım önerilir |
| `rangeRepScoreWeights` | Skor bileşen ağırlıkları | Opsiyonel |
| `rangeRepPhaseQuality` | Minimum faz süreleri | Opsiyonel ama noise kontrolü için önemlidir |

Parser bazı eksik numerik alanlara `0.0` fallback verebilir. Bu, eksik alanın doğru olduğu anlamına gelmez. Yeni range-rep config'te temel threshold, tempo ve skor alanlarını açıkça yaz.

### Ana açı örneği

```json
{
  "primaryJoint": "leftElbow",
  "joint1": "leftShoulder",
  "joint2": "leftWrist"
}
```

Bu tanım, `joint1 → primaryJoint → joint2` açısını üretir.

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

Bir signal aynı anda hem `source` hem açı üçlüsü içeremez. Açı tanımında yalnız `first`, `middle` ve `last` anahtarları bulunmalıdır.

Desteklenen ek signal adları:

```text
postureAngle
depthMetric
alignmentMetric
stabilityMetric
endRangeMetric
bottomControlMetric
```

### Threshold belirleme

Yeni egzersiz threshold'ları squat veya push-up değerleri kopyalanarak belirlenmez.

Önerilen sıra:

1. Profile build üret.
2. Live Analysis ekranında mevcut calibration/debug yüzeyini aç.
3. Neutral, aktif geçiş, gerçek peak ve dönüş açılarını farklı tekrarlar boyunca gözle.
4. Sol ve sağ görünüm için ayrı gözlem yap.
5. Kısa video veya canlı annotation ile ground truth tut.
6. Başlangıç config'i oluştur.
7. Static-negative, partial-rep ve occlusion testleri çalıştır.
8. Diagnostics JSON'daki frame drop, no-pose, side switch ve processing değerlerini incele.
9. Threshold'u yalnız gözlenen hatanın gerçekten threshold kaynaklı olduğu kanıtlandıysa değiştir.

“Rep saymıyor” sonucu tek başına threshold düşürme gerekçesi değildir. Sorun kamera dönüşü, landmark kaybı, yanlış taraf, yanlış engine veya peak'e hiç ulaşmama olabilir.

## 9. Hold egzersizi ekleme

Çalışan örnek:

```text
assets/config/exercises/plank.json
```

### Mevcut implementasyon

Bugünün aktif hold örneği `plank`tir. `ExerciseCatalog` içinde `EngineKind.hold` ile desteklenir ve `HoldContracts.plankFamily` contract'ını taşır; ancak bu, hold ailesinin tüm statik egzersizler için otomatik genellenmiş bir şablona dönüştüğü anlamına gelmez.

`HoldContract`, motorun beklediği semantik signal setini tanımlar:

```text
alignment
support
extension
```

`holdSignals` ise her semantik signal için reference geometry angle triple tanımlar. Metrics extractor ile pose quality aynı landmark requirement kaynağını bu contract + config kombinasyonundan türetir.

Mevcut plank config örneği:

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

Bu yüzden:

- plank aktif hold örneğidir
- `EngineKind.hold`, her statik egzersiz için genel amaçlı bir motor değildir
- hold signal geometry artık production Dart içindeki sabit landmark listelerinden değil, config'teki `holdSignals` tanımından gelir
- config, tek bir `referenceSide` üzerinden canonical geometriyi tanımlar
- karşı taraf requirement ve extraction landmark'ları paired landmark mirroring ile türetilir
- center landmark'lar, örneğin `nose`, mirroring sırasında değişmeden kalır
- mixed-side triplet'lerde bütün paired landmark'lar swap edilir; yalnız `left*` alanlarını sağa çevirmek yeterli değildir
- pose quality left ve right requirement setlerini ayrı değerlendirir, daha yüksek quality tarafını seçer ve exact tie durumunda left tarafını tercih eder
- controller seçilen hold side'ı stabilize eder, aktif attempt boyunca lock eder ve kısa visibility gap süresince korur
- hold engine typed feedback code üretir; kullanıcıya gösterilen metin `hold_feedback_ui_mapper.dart` içinde map edilir
- controller hold session sırasında presented feedback code ile engine phase gerçeğini ayrı taşıyabilir; visibility gap sırasında `WAITING` UI etiketi korunurken engine phase `holding` kalabilir
- hold diagnostics `lastVisiblePosture` alanını son görünür analiz frame'i için taşır; bu alanı anlık kamera gerçeği gibi yorumlama
- domain logic kullanıcı metnini karşılaştırmamalı; JSON config kullanıcı mesajı taşımamalı; yeni hold code gerekiyorsa enum, stable code, family, mapper ve test birlikte eklenmeli
- missing-metric semantics bu adımda düzeltilmedi; missing body bugün `preparePosition`, missing arm/leg ise production karakterizasyonunu koruyarak `alignHips` surface'ine düşebilir
- yeni hareket bu üç signal'in anlamlı olduğu plank benzeri geometriye uymuyorsa yalnız JSON config ekleme
- yeni hold hareketi yalnız JSON eklenince otomatik desteklenmiş sayılmaz
- yeni hold hareketi, mevcut üç signal'in aynı biyomekanik anlamı taşıdığını ayrıca kanıtlamalıdır
- ikinci production hold fixture hâlâ yoktur

### Hold config alanları

| Alan | Anlam |
| --- | --- |
| `activePostureAngle` | Hareketin aktif postür bölgesi |
| `bodyLineEntryAngle` | Hold başlatmak için gereken gövde hattı |
| `bodyLineSustainAngle` | Hold başladıktan sonra sürdürülebilir gövde hattı |
| `armSupportMinAngle` | Minimum kol destek açısı |
| `armSupportMaxAngle` | Maksimum kol destek açısı |
| `legExtensionMinAngle` | Minimum bacak uzatma açısı |
| `breakGraceMillis` | Kısa landmark/form bozulmasına tolerans |
| `referenceSide` | Config triplet'lerinin tanımlandığı canonical taraf |

Entry ve sustain değerlerinin ayrı olması hysteresis sağlar. Çok büyük grace süresi gerçek form break'i sırasında hold süresini şişirebilir.

Hold motoru tekrar üretmez; `repCount` güvenli biçimde `0` kalır ve sonuç hold diagnostics üzerinden taşınır.

> Bilateral hold extraction ve side locking artık mevcuttur; yine de sağ taraftan görünüm gerçek cihazda ayrıca doğrulanmadan production kabulü tamamlandı sayma.

### Hold roadmap

Aşağıdakiler bugünün implementasyonu değil, sonraki mimari adımlardır:

- ikinci hold-family fixture ile template doğrulaması
- real-device right-side acceptance kanıtını genişletme

Bu hedefler gelmeden `hold` ailesini bütün statik egzersizler için tam genellenmiş gibi belgeleme.

## 10. Yeni engine ailesi ne zaman gerekir?

Aşağıdaki durumlardan biri varsa config-only yol kullanma:

- hareketin ana metriği önce yükselip sonra düşüyorsa,
- sağ ve sol taraf sırayla tekrar sayılıyorsa,
- bir tekrar birden fazla bağımsız eklem fazına bağlıysa,
- adım/denge yönü state'in parçasıysa,
- iki uzvun eşzamanlı veya sıralı durumu gerekiyorsa,
- statik postür mevcut plank sinyalleriyle tanımlanamıyorsa,
- mevcut neutral/descending/peak/ascending sırası anlamsızsa.

Yeni engine çalışması en az şunları içerir:

1. Domain contract.
2. Engine implementation.
3. Metrics modeli ve extractor.
4. Factory kaydı.
5. Controller sonuç uyarlaması.
6. Diagnostics yüzeyi.
7. Persistence anlamı.
8. Deterministic testler.
9. Profile build ve gerçek cihaz ölçümü.

## 11. Rehber içeriği

Yeni bir egzersiz için `ExerciseGuideContent` şu alanları ister:

```text
id
title
subtitle
purpose
difficulty
setupSteps
tips
commonMistakes
youtubeUrl
youtubeSourceLabel
```

Kurallar:

- Guide `id`, kalıcı exercise ID ile aynı olmalıdır.
- Tıbbi doğruluk, rehabilitasyon veya “yaralanmayı önler” iddiası yazma.
- Rahatsızlık durumunda zorlamama yönlendirmesi kullanılabilir.
- Video kaynağı gerçek, ilgili ve sürdürülebilir olmalıdır.
- Rehber metni, catalog desteği kapalı bir hareket için “analiz aktif” iddiası oluşturmamalıdır.

## 12. Persistence ve geriye uyumluluk

`WorkoutSession.exerciseType` Firestore'a string olarak yazılır. Yeni ID eklemek genellikle mapper değişikliği gerektirmez; fakat şu kontroller zorunludur:

- session save içinde yeni ID yazılıyor mu,
- history/detail ekranları yeni ID'yi anlaşılır gösteriyor mu,
- filtre veya aggregate kodunda sabit egzersiz listesi var mı,
- Firestore rules belirli değerleri whitelist ediyor mu,
- rep-level belgeler yeni analysis kind ile uyumlu mu.

Kalıcı ID'yi sonradan değiştirmek migration gerektirebilir. Bir enum başlığını güzelleştirmek ile persisted ID değiştirmek aynı şey değildir.

## 13. Hedef Definition of Done test matrisi

Bu bölüm, yeni veya yeniden etkinleştirilen bir hareketi `supported` yapmadan önce tamamlanması hedeflenen doğrulama listesidir. Repository'de bu listedeki her maddenin bugün her hareket için zaten kanıtlandığı varsayılmaz.

Özellikle sağ taraf testi, bilateral hold kapsamı veya ikinci hold-family fixture; ilgili test ve kanıt eklenmeden "mevcut" diye yazılmamalıdır. Mevcut hareketler de bu checklist'e göre ayrıca doğrulanmalıdır.

### 13.1 Catalog

- Tanım bulunuyor.
- ID ve title doğru.
- `isAnalysisSupported` doğru.
- Engine kind doğru.
- Config path doğru.
- Range-rep ise contract doğru.

### 13.2 Analysis resolver

- Supported seçim aktif exercise döndürüyor.
- Unsupported seçim `null` döndürüyor.
- Null seçim `null` döndürüyor.

### 13.3 Config parsing ve resolver

- Asset doğru path'ten yükleniyor.
- Zorunlu landmark isimleri geçerli.
- Sayısal alanlar parse ediliyor.
- Bilinmeyen signal key reddediliyor.
- Bir signal içinde `source` ve angle triple birlikte reddediliyor.
- Eksik asset açık hata üretiyor.

### 13.4 Metrics extractor

Range-rep:

- sol landmark'lardan primary metric,
- sağ landmark mapping,
- form metric,
- contract'taki ek sinyaller,
- eksik landmark davranışı,
- side confidence.

Hold:

- body line,
- arm support,
- leg extension,
- `referenceSide` parsing ve paired landmark mirroring,
- right-only extraction,
- mixed-side triplet mirroring,
- eksik landmark davranışı.

### 13.5 Engine

Range-rep minimum testleri:

1. Neutral bekleme false rep üretmez.
2. Tam faz sırası tam bir rep üretir.
3. Peak'e ulaşmayan iniş rep üretmez.
4. Yarım inişten neutral'a dönüş rep üretmez.
5. Confirmation süresinden kısa gürültü faz değiştirmez.
6. Form metriği geri bildirimi doğru etkiler.
7. Reset tüm aktif rep state'ini temizler.

Hold minimum testleri:

1. Geçerli postür hold başlatır.
2. Geçersiz postür hold başlatmaz.
3. Grace içindeki kısa bozulma hold'u hemen kesmez.
4. Grace aşılırsa hold kesilir.
5. Best hold korunur.
6. Reset state'i temizler.

### 13.6 UI

- Rehber kartı listeleniyor.
- Supported hareket “Analiz aktif” gösteriyor.
- Unsupported hareket analiz ekranına geçmiyor.
- Supported hareket doğru `ExerciseType` değerini seçiyor.

### 13.7 Persistence

- Session document doğru exercise ID içeriyor.
- Analysis kind doğru.
- Range-rep için displayed total ve persisted total aynı.
- Hold için hold duration alanları doğru.

## 14. Yerel doğrulama

Değişen kapsam doğrultusunda en az:

```bash
dart format --set-exit-if-changed <değişen-dart-dosyaları>
flutter analyze
flutter test
```

Yeni config için hedefli testler önce çalıştırılmalıdır. Ardından full suite çalıştırılır.

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

## 15. Gerçek cihaz kabul kapısı

Unit testler yeni hareketi desteklenmiş saymak için yeterli değildir.

### Range-rep minimum senaryoları

- 20 kontrollü tekrar,
- 30 saniye hareketsiz negatif test,
- yarım/tamamlanmamış hareket,
- kısa pose kaybı,
- uzun pose kaybı,
- pause/resume,
- sağ görünüm,
- sol görünüm,
- düşük ışık,
- ikinci kişi,
- en az 15 dakika oturum,
- session save ve history karşılaştırması.

### Hold minimum senaryoları

- 30 saniye geçerli hold,
- 30 saniye geçersiz postür,
- kısa form break,
- uzun form break,
- kısa ve uzun pose kaybı,
- pause/resume,
- sağ ve sol görünüm,
- düşük ışık,
- en az 15 dakika oturum,
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

### İki debug yüzeyinin kullanımı

**Calibration/live debug yüzeyi** şu soruyu cevaplar:

> O anda hangi açı ve sinyal görülüyor?

**Beta Diagnostics paneli** şu soruyu cevaplar:

> Oturum boyunca kaç frame işlendi, kaç pose kayboldu, side kaç kez değişti ve performans nasıldı?

Hold session'larında bu panel artık presented hold feedback code, engine hold feedback code, engine phase, selected side ve `lastVisiblePosture` booleans yüzeyini de gösterir.

Yeni egzersiz kalibrasyonunda ikisi birlikte kullanılmalıdır. Biri anlık geometriyi, diğeri oturum sağlığını gösterir.

## 16. Hızlı geliştirme akışı

```text
1. Egzersiz tasarım formunu doldur
2. Engine uyumluluğunu kararlaştır
3. Ground-truth ölçüm planını yaz
4. Kimlik ve guide kaydını ekle
5. Config ve gerekiyorsa contract ekle
6. Catalog kaydını ekle, başlangıçta gerekirse unsupported tut
7. Extractor testlerini yaz
8. Engine testlerini yaz
9. UI ve persistence testlerini tamamla
10. Full suite çalıştır
11. Profile APK üret
12. Diagnostics ile cihaz ölçümü yap
13. Kabul kriterleri geçerse supported yap
14. Draft PR incelemesi
```

En güvenli yaklaşım, catalog kaydını ilk PR'da `unsupported` tutup config/extractor/engine doğrulamasını tamamlamak; kullanıcıya açmayı ayrı ve küçük bir PR yapmak olabilir. Böylece “kart yeşil ama hareket yanlış” ara durumu main'e girmez.

## 17. Anti-pattern'ler

1. Yalnız enum'a egzersiz eklemek.
2. Yalnız guide content ekleyip analizin hazır olduğunu varsaymak.
3. Catalog'u supported yapıp config eklememek.
4. Squat veya push-up threshold'larını başka harekete kopyalamak.
5. Range-rep açı yönünü kontrol etmemek.
6. Contract ile JSON sinyallerini uyumsuz bırakmak.
7. Yalnız sol tarafta test yapmak.
8. Eksik landmark davranışını test etmemek.
9. Static-negative testi atlamak.
10. Yeni hareketi mevcut engine'e zorla uydurmak.
11. Commit SHA olmadan cihaz sonucu kaydetmek.
12. Diagnostics JSON almadan threshold değiştirmek.
13. Test edilmeyen hareketi `supported` yapmak.
14. Kalıcı exercise ID'yi sonradan estetik gerekçeyle değiştirmek.
15. Hold motorunu bütün statik hareketler için genel motor sanmak.

## 18. Sorun giderme

| Belirti | Olası neden | İlk kontrol |
| --- | --- | --- |
| Hareket listede görünüyor ama açılamıyor | Catalog unsupported veya ID uyuşmazlığı | `ExerciseCatalog`, guide ID |
| Hareket listede hiç görünmüyor | Guide content eksik | `exercise_guide_contents.dart` |
| Açılışta config hatası | Yanlış asset path veya bozuk JSON | Catalog path, config parser |
| Hiç rep saymıyor | Yanlış engine, landmark veya threshold yönü | Calibration paneli, extractor testi |
| Yarım hareket rep oluyor | Active/peak geçişleri fazla gevşek | Engine partial-rep testi |
| Neutral beklerken rep oluyor | Noise ve confirmation/threshold sorunu | Static-negative testi |
| Sağ tarafta çalışmıyor | Side mapping veya landmark görünürlüğü | Extractor right-side testi |
| Side sürekli değişiyor | Confidence yakın veya pose gürültülü | Diagnostics side switch count |
| Hold hiç başlamıyor | Mevcut plank geometrisi harekete uymuyor | Hold signal ölçümleri |
| Hold geç kesiliyor | Grace süresi fazla büyük | `breakGraceMillis` |
| FPS düşüyor | Fazla işleme, no-pose veya cihaz sınırı | Diagnostics p95/max/FPS |
| Session doğru görünmüyor | ID/analysis kind/persistence uyumsuzluğu | Session mapper ve saved document |
| Dönüşümlü hareket yanlış sayılıyor | Yanlış engine ailesi | Yeni alternating engine tasarımı |

## 19. Egzersiz tasarım formu

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
- Mevcut engine'e neden uyuyor?
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
- Ek range-rep signals:
- Sol taraf desteği:
- Sağ taraf desteği:
- Eksik landmark davranışı:

## Ölçüm kanıtı
- Kullanılan cihaz:
- Kamera açısı:
- Neutral gözlenen aralık:
- Active geçiş gözlenen aralık:
- Peak gözlenen aralık:
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

Threshold veya landmark seçimi için ölçüm kanıtı yoksa değer uydurma. Hareketi unsupported tut ve görevi bloke et.

## 20. Definition of Done

```markdown
- [ ] Engine ailesi uygunluğu yazılı olarak açıklandı
- [ ] Kalıcı ID kurallara uygun ve tüm katmanlarda tutarlı
- [ ] Rehber içeriği mevcut
- [ ] Catalog tanımı doğru
- [ ] Config asset parse ediliyor
- [ ] Range-rep ise contract factory şartlarını karşılıyor
- [ ] Sol taraf extractor testi geçti
- [ ] Sağ taraf extractor testi geçti
- [ ] Eksik landmark testi geçti
- [ ] Neutral/static-negative testi geçti
- [ ] Tam tekrar veya hold testi geçti
- [ ] Partial/invalid hareket testi geçti
- [ ] Occlusion testi geçti
- [ ] Pause/resume testi geçti
- [ ] Reset testi geçti
- [ ] UI support durumu doğru
- [ ] Persistence sonucu doğru
- [ ] flutter analyze temiz
- [ ] Full test suite başarılı
- [ ] Profile APK üretildi
- [ ] APK commit SHA doğrulandı
- [ ] Diagnostics JSON alındı
- [ ] Gerçek cihaz kabul ölçümü tamamlandı
- [ ] PR CI başarılı
- [ ] Hareket yalnız kanıt tamamlandıysa supported yapıldı
```

## 21. PR kapsamı önerisi

Yeni egzersizi tek dev PR'a sıkıştırmak yerine aşağıdaki bölünme tercih edilir:

1. **Design/config PR:** engine kararı, contract, config parser testleri; hareket hâlâ unsupported.
2. **Runtime/test PR:** extractor ve engine davranışı, diagnostics, deterministic testler.
3. **Enablement PR:** catalog supported, UI, profile artifact ve cihaz kanıtı.

Mevcut engine'e açıkça uyan küçük hareketlerde ilk iki adım birleştirilebilir. Cihaz kanıtı olmadan enablement yapılmaz.

## 22. Kılavuz bakım kuralı

Şunlardan biri değişirse bu belge aynı PR içinde güncellenmelidir:

- `ExerciseType` veya ID politikası,
- `ExerciseDefinition`,
- `EngineKind`,
- config JSON şeması,
- `ExerciseMetricsExtractor`,
- range-rep/hold state machine varsayımları,
- diagnostics alanları,
- profile artifact veya cihaz kabul süreci.

Mimari değişip kılavuz değişmezse hızlı geliştirme süreci tekrar kabile hafızasına dönüşür. Bu belge kaynak kodla birlikte yaşayan bir kontrattır.
