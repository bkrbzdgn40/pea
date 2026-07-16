Bu görevde yalnızca mevcut `hold` analiz mimarisine typed bir alt-aile ayrımı ekle.

Repo kökündeki `AGENTS.md` kurallarını eksiksiz uygula.

## Amaç

Mevcut `EngineKind.hold` yapısının ileride birden fazla hold analiz ailesini destekleyebilmesi için `HoldContract` seviyesinde açık ve typed bir family discriminator eklemek.

Bu refactor sonucunda mevcut Plank analiz davranışı hiçbir şekilde değişmemeli.

## İstenen değişiklik

`HoldAnalysisFamily` adında bir enum oluştur.

İlk aşamada yalnızca mevcut aileyi tanımla:

```dart
enum HoldAnalysisFamily {
  plank,
}
```

`HoldContract` modeline zorunlu bir `family` alanı ekle.

Mevcut:

```dart
HoldContracts.plankFamily
```

contract'ını:

```dart
family: HoldAnalysisFamily.plank
```

ile açıkça işaretle.

Ardından `AnalysisEngineFactory.createHold(...)` içinde engine oluşturma kararını `holdContract.family` üzerinden ver.

Şimdilik yalnızca:

```dart
HoldAnalysisFamily.plank
```

desteklendiği için bu branch mevcut `HoldEngine` instance'ını üretmeye devam etmeli.

Mevcut Plank contract validation davranışını koru.

## Beklenen yapı

Kavramsal olarak sonuç şu yönde olmalı:

```text
EngineKind.hold
    ↓
HoldContract.family
    ↓
HoldAnalysisFamily.plank
    ↓
mevcut HoldEngine
```

Bu görev yalnızca gelecekte ikinci bir hold ailesinin eklenebileceği typed extension point'i oluşturmalıdır.

## Bu görevde yapılmaması gerekenler

Bu görev kapsamında:

* `ExerciseType.hollowHold` ekleme.
* Hollow Hold egzersizi ekleme.
* `HollowBodyHoldEngine` ekleme.
* `HoldSignal` enum'unu genişletme.
* `ExerciseConfig` yapısını değiştirme.
* JSON config dosyalarını değiştirme.
* `ExerciseMetrics` veya `AnalysisFrame` yapısını değiştirme.
* metrics extractor'ı değiştirme.
* landmark requirements sistemini değiştirme.
* `HoldEngine` davranışını refactor etme.
* `HoldPosturePolicy` davranışını değiştirme.
* Plank threshold'larını değiştirme.
* feedback veya diagnostics yapısını değiştirme.
* persistence katmanına dokunma.
* `WorkoutController` içine exercise-specific veya family-specific branching ekleme.
* unrelated cleanup veya rename yapma.

Özellikle mevcut `HoldEngine` sınıfını bu aşamada `PlankHoldEngine` olarak yeniden adlandırma.

## Test beklentileri

Mevcut testleri incele ve bu refactor için gerekli minimum testleri ekle veya güncelle.

En azından şu davranışları doğrula:

1. `HoldContracts.plankFamily.family == HoldAnalysisFamily.plank`.
2. `AnalysisEngineFactory.createHold(...)`, `plankFamily` verildiğinde mevcut `HoldEngine` üretmeye devam ediyor.
3. Mevcut Plank hold contract validation davranışı korunuyor.
4. Mevcut hold engine/factory testleri regression olmadan geçiyor.

Mümkünse production type üzerinden assertion yap. Sadece test geçsin diye davranışı gevşetme.

## Çalışma yöntemi

Önce ilgili dosyaları ve mevcut testleri incele.

Sonra yalnızca bu küçük refactor için gerekli değişiklikleri yap.

Değişiklik bittikten sonra:

* final diff'i incele,
* unrelated değişiklik olmadığını doğrula,
* ilgili focused testleri çalıştır,
* mümkün olan ilgili broader testleri çalıştır.

Sonuç raporunda yalnızca şunları belirt:

1. Değiştirilen dosyalar.
2. Yapılan mimari değişikliğin kısa özeti.
3. Çalıştırılan gerçek test komutları ve sonuçları.
4. Çalıştırılamayan bir doğrulama varsa nedeni.
5. Mevcut Plank davranışının neden değişmediğine dair kısa teknik açıklama.

Bu aşamanın sonunda repo test edilebilir ve tutarlı durumda kalmalı.
