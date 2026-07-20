<div align="center">

# PEA

### Kamera tabanlı gerçek zamanlı egzersiz analizi uygulaması

Mobil cihaz kamerası üzerinden seçili egzersizlerde canlı analiz, oturum özeti, geçmiş görünümü ve egzersiz rehberi sunan Flutter tabanlı bir hareket analizi uygulaması.

<br/>

<p align="center">
  <img src="./docs/assets/pea-banner.png" alt="PEA README Banner" width="100%" />
</p>

<br/>

<img src="https://skillicons.dev/icons?i=flutter,dart,firebase" height="52" alt="Flutter, Dart ve Firebase ikonları" />

<br/>
<br/>

![Flutter](https://img.shields.io/badge/Flutter-Mobile-00C853?style=for-the-badge\&logo=flutter\&logoColor=white\&labelColor=111111)
![Dart](https://img.shields.io/badge/Dart-3.x-00C853?style=for-the-badge\&logo=dart\&logoColor=white\&labelColor=111111)
![Firebase](https://img.shields.io/badge/Firebase-Backend-00C853?style=for-the-badge\&logo=firebase\&logoColor=white\&labelColor=111111)
![ML Kit](https://img.shields.io/badge/ML_Kit-Pose_Detection-00C853?style=for-the-badge\&logo=google\&logoColor=white\&labelColor=111111)
![Riverpod](https://img.shields.io/badge/Riverpod-State_Management-00C853?style=for-the-badge\&labelColor=111111)
![Firestore](https://img.shields.io/badge/Cloud_Firestore-Session_Storage-00C853?style=for-the-badge\&logo=firebase\&logoColor=white\&labelColor=111111)

<br/>

![Real Time Analysis](https://img.shields.io/badge/Real--Time-Analysis-00E676?style=for-the-badge\&labelColor=111111)
![Rep Counting](https://img.shields.io/badge/Rep-Counting-00E676?style=for-the-badge\&labelColor=111111)
![Session History](https://img.shields.io/badge/Session-History-00E676?style=for-the-badge\&labelColor=111111)
![Exercise Guide](https://img.shields.io/badge/Exercise-Guide-00E676?style=for-the-badge\&labelColor=111111)
![Status](https://img.shields.io/badge/Status-Active_Development-00E676?style=for-the-badge\&labelColor=111111)

</div>

---

## Proje Özeti

PEA, Google ML Kit pose landmarks kullanarak seçili egzersizlerde canlı analiz yapan bir Flutter uygulamasıdır. Güncel `ExerciseCatalog` Squat, Plank, Hollow Hold, Stationary Lunge, Push-up, Sit-up, Biceps Curl, Lying Leg Raise, Triceps Dip, Romanian Deadlift, Lateral Raise ve Shoulder Press hareketlerini canlı analiz için tanımlar. Catalog desteği, yeni hareketlerin bütün cihazlarda doğrulandığı anlamına gelmez.

## Aktif Analiz Desteği

| Egzersiz | Engine ailesi | Analiz | Temel çıktı |
| --- | --- | --- | --- |
| Squat | `rangeRep` | Aktif | Tekrar, form skoru, form sinyalleri |
| Plank | `hold` / `plank` family | Aktif | Anlık hold, en iyi hold, form-break |
| Hollow Hold | `hold` / `hollowHold` family | Aktif | Anlık hold, en iyi hold, form-break |
| Stationary Lunge | `rangeRep` | Aktif | Tekrar, ROM, tempo |
| Push-up | `rangeRep` | Aktif | Tekrar, form skoru, form sinyalleri |
| Sit-up | `rangeRep` | Aktif | Tekrar, form skoru, form sinyalleri |
| Biceps Curl | `rangeRep` / bilateral | Aktif | Eş zamanlı iki kol tekrar takibi, form skoru, form sinyalleri |
| Lying Leg Raise | `rangeRep` | Aktif | Tekrar, hip ROM, diz-ekstansiyon uyarısı |
| Triceps Dip | `rangeRep` | Aktif | Tekrar, dirsek ROM, omuz-ekstansiyon uyarısı |
| Romanian Deadlift | `rangeRep` | Aktif | Tekrar, hip-hinge ROM, diz-açısı uyarısı |
| Lateral Raise | `rangeRep` / bilateral | Aktif | Eş zamanlı iki kol, omuz ROM, dirsek uyarısı |
| Shoulder Press | `rangeRep` / bilateral | Aktif | Eş zamanlı iki kol, dirsek ekstansiyon ROM |

## Engine Aileleri

### `rangeRep`

Temel hareket akışı:

```text
neutral -> descending -> peak -> ascending -> neutral
```

Güncel katalogda Squat, Stationary Lunge, Push-up, Sit-up, Biceps Curl, Lying Leg Raise, Triceps Dip, Romanian Deadlift, Lateral Raise ve Shoulder Press bu aileyi kullanır.

`RangeRepContract`, bir hareketin:

- desteklediği fazları,
- analiz sinyallerini,
- pose kabulü için zorunlu sinyalleri,
- form-threshold kalibrasyon politikasını,
- selected-side veya bilateral çalışma modunu

belirler.

Squat, Stationary Lunge, Push-up, Sit-up, Lying Leg Raise, Triceps Dip ve Romanian Deadlift selected-side akışını kullanır. Biceps Curl, Lateral Raise ve Shoulder Press iki tarafı aynı tekrar içinde birlikte değerlendiren `bilateral` side mode kullanır. Bilateral analiz, sağ-sol dönüşümlü tekrar anlamına gelmez.

### `hold`

Temel hold state akışı:

```text
ready -> holding -> broken
```

Güncel kodda ortak `HoldEngine`, family-specific contract ve posture policy ile iki aktif hold ailesini çalıştırır:

- `plank`: `alignment`, `support`, `extension`
- `hollowHold`: `compression`, `armExtension`, `kneeExtension`

Bu yapı, `hold` engine'inin bütün statik egzersizler için otomatik olarak genel amaçlı bir motor olduğu anlamına gelmez. Yeni bir statik hareket mevcut family semantiğine uymuyorsa yeni contract ve posture-policy tasarımı gerekir.

### `alternatingRep`

`EngineKind.alternatingRep` enum olarak tanımlıdır, ancak `AnalysisEngineFactory` içinde henüz uygulanmamıştır. Enum değerinin varlığı çalışan bir analiz motoru anlamına gelmez.

## Destek Seviyeleri ve Doğrulama

| Katman | Ne anlama gelir | Ne anlama gelmez |
| --- | --- | --- |
| Rehber içeriği | Hareket kartı, açıklama ve video yönlendirmesi vardır | Canlı analiz otomatik olarak aktiftir |
| Catalog desteği | `ExerciseCatalog` hareketi canlı analiz için destekli işaretler | Hareketin her cihazda biyomekanik olarak kabul edildiği |
| Otomatik doğrulama | `flutter analyze`, `flutter test` ve PR CI kod yolunu doğrular | Gerçek cihaz kabulü veya saha doğrulaması |
| Cihaz doğrulaması | Belirli build, cihaz ve senaryoda ölçüm kanıtı üretir | Başka egzersizlerin veya başka cihazların otomatik olarak doğrulandığı |

Catalog desteği ile cihaz kabul kanıtı aynı şey değildir. Tarihsel beta hardening belgeleri belirli commit ve egzersiz kapsamlarına bağlıdır; daha sonra `supported` yapılan bir hareket eski cihaz kanıtını otomatik olarak devralmaz.

Repository ayrıca `main` branch üzerinde elle tetiklenen `Android Profile Beta Artifact` workflow'una sahiptir. Bu yol profile APK ve commit SHA metadata'sı üretir; PR CI ile aynı şey değildir ve tek başına gerçek cihaz kabulü yerine geçmez.

---

## Uygulama Deneyimi

### Home

Home yüzeyi kullanıcıyı zaman bazlı greeting card ve hızlı aksiyonlarla karşılar. Gerçek oturum verisi varsa yalnız güvenilir ve egzersizler arasında anlamlı olan özetleri gösterir.

Production provider'ları `loading`, `noUser`, `empty` ve `error` durumlarında sahte analiz, skor, hedef veya başarı verisi üretmez. Missing data kullanıcıya düşük performans veya sıfır başarı gibi sunulmaz.

Global ve cross-exercise skor yüzeyleri kaldırılmıştır. Form skoru trendleri tek bir `ExerciseType` bağlamında hesaplanır; hold-only geçmiş sıfır form skoru trendi gibi gösterilmez.

### Live Analysis

Kamera akışı üzerinden ML Kit pose detection çalışır. Pose verisi seçilen hareketin catalog tanımı, config'i ve contract'ı üzerinden ilgili engine ailesine yönlendirilir.

- Squat, Stationary Lunge, Push-up, Sit-up, Lying Leg Raise, Triceps Dip ve Romanian Deadlift: selected-side `rangeRep`
- Biceps Curl, Lateral Raise ve Shoulder Press: bilateral `rangeRep`
- Plank: `hold` + plank posture policy
- Hollow Hold: `hold` + hollow-hold posture policy

Range-rep oturumları tekrar, skor ve form sinyalleri; hold oturumları anlık hold, en iyi hold ve form-break telemetrisi üretir.

### Workout Summary & History

Tamamlanan oturum özetlenir, Firestore'a kaydedilir ve geçmiş ekranında yeniden incelenebilir. Range-rep oturumlarında rep-level kayıtlar ayrı subcollection altında tutulabilir.

### Guide

Hareketler için kısa amaç açıklamaları, kurulum adımları, teknik ipuçları, yaygın hatalar ve dış video bağlantıları sunar. Guide görünürlüğü canlı analiz desteğinden bağımsızdır; support politikasının kaynağı `ExerciseCatalog` sınıfıdır.

### How to Use

Uygulamanın ne yaptığını ve nasıl kullanılması gerektiğini kısa, sade ve ürün içi onboarding tonunda açıklar.

---

## Teknik Yığın

### Mobil

- Flutter
- Dart

### Durum Yönetimi

- Riverpod

### Bilgisayarlı Görü

- Google ML Kit Pose Detection

### Backend / Veri

- Firebase Core
- Firebase Auth
- Cloud Firestore

### Yardımcı Paketler

- Shared Preferences
- fl_chart
- url_launcher

## Mimari Yaklaşım

Proje, feature odaklı ve katmanlı bir yapıyla ilerler.

```text
lib/
|-- app/
|-- core/
`-- features/
    |-- auth/
    |-- workout_analysis/
    |-- goals/
    |-- achievements/
    `-- chat/
```

### Temel prensipler

- analiz mantığını UI katmanından ayırmak
- Firebase erişimini repository ve infrastructure katmanlarında toplamak
- `ExerciseCatalog` ile analiz desteğini tek merkezden yönetmek
- engine family contract'larını config semantiğinden açık biçimde ayırmak
- kullanıcıyı sahte veriyle etkilemeye çalışmamak
- missing data'yı zero gibi göstermemek
- farklı egzersizlerin skorlarını doğrulanmamış bir global gelişim metriğinde birleştirmemek
- ürün yüzeylerini adım adım ve kanıtla olgunlaştırmak

---

## Analiz Akışı

```text
Camera stream
  -> InputImage dönüşümü
  -> ML Kit Pose Detection
  -> Pose quality / landmark requirements
  -> ExerciseMetricsExtractor
  -> ExerciseCatalog + ExerciseDefinition
  -> RangeRepContract veya HoldContract
  -> RangeRepEngine veya HoldEngine + family posture policy
  -> Skor / feedback / hold diagnostics
  -> Session summary + opsiyonel rep documents (Firestore)
```

Bu akış, canlı analiz ekranının temel omurgasını oluşturur.

## Rehber Yaklaşımı

Guide ekranı, uzun bir broşür sayfası yerine uygulama içi hızlı referans yüzeyi olarak tasarlanmıştır.

Her hareket için:

- kısa açıklama
- zorluk seviyesi
- amaç
- kurulum adımları
- teknik ipuçları
- yaygın hatalar
- dış video yönlendirmesi

sunulur.

Video oynatımı uygulama içine gömülmemiştir. Kullanıcı, küratörlü dış video bağlantısına yönlendirilir.

---

## Veri Saklama Modeli

Session ve rep verileri kullanıcı bazlı saklanır:

```text
users/{uid}/sessions/{sessionId}
users/{uid}/sessions/{sessionId}/reps/{repId}
```

### Session document

Session document özet seviyesindedir. Başlıca alanlar:

- egzersiz tipi
- `analysisKind`
- başlangıç ve bitiş zamanı
- süre
- toplam tekrar
- geçerli ve geçersiz tekrar sayıları
- ortalama, en iyi ve en kötü skor
- form uyarısı sayısı
- hold oturumları için toplam geçerli hold süresi
- hold oturumları için en iyi hold süresi
- hold form-break sayısı

### Rep subcollection

Range-rep oturumlarında `WorkoutRep` kayıtları `reps` subcollection'ına ayrı dokümanlar olarak yazılır. Rep dokümanları, mevcut runtime'ın üretebildiği ölçüde:

- rep index
- exercise ve analysis kind
- skor
- validation status ve validation reasons
- minimum primary metric
- worst form metric
- descent/ascent süreleri
- form violation ve coverage-drop bilgileri
- rep sırasında side switch bilgisi
- tamamlanan faz sırası
- selected side
- feedback

gibi alanlar taşır.

Session document'ın summary-level olması, rep-level verinin hiç persist edilmediği anlamına gelmez.

---

## Mevcut Sınırlamalar

Bu aşamada bilinçli olarak kabul edilen bazı sınırlar vardır:

- Stationary Lunge canlı analiz için `rangeRep` olarak tanımlıdır; dönüşümlü lunge hâlâ `alternatingRep` motoru gerektirir.
- `alternatingRep` engine ailesi henüz uygulanmamıştır.
- `hold` ailesi Plank ve Hollow Hold ile iki gerçek family örneğine sahiptir; yine de bütün statik egzersizler için config-only genel motor olarak kabul edilmemelidir.
- Catalog desteği gerçek cihaz kabulü anlamına gelmez; yeni veya sonradan etkinleştirilen egzersizler ayrı cihaz kanıtı gerektirir.
- Çoklu cihaz Low/Mid/High genellemesi tarihsel beta kapsamının açık risklerinden biridir.
- Hold sırasında kısa visibility gap için koruma vardır; görünmeyen süre geçerli hold toplamına eklenmez.
- Beta Diagnostics JSON schema version `3`, range-rep ve hold alanlarını geriye uyumluluk amacıyla birlikte taşıyabilir; `0` veya `false` değerler her zaman ölçülen performans anlamına gelmez, analysis kind bağlamında yorumlanmalıdır.
- Form skoru trendleri yalnız skor üretmeye uygun range-rep oturumlarından ve tek egzersiz bağlamından oluşturulur.
- Otomatik testler ve CI, gerçek cihaz kabulünün yerine geçmez.

---

## Kurulum

### 1. Depoyu klonlayın

```bash
git clone https://github.com/bkrbzdgn40/pea.git
cd pea
```

### 2. Bağımlılıkları yükleyin

```bash
flutter pub get
```

### 3. Firebase yapılandırmasını hazırlayın

Projeyi çalıştırmadan önce Firebase tarafında gerekli yapılandırmayı tamamlayın:

- Firebase projesi oluşturun
- Android / iOS uygulamalarını ekleyin
- `flutterfire configure` çalıştırın
- `firebase_options.dart` dosyasını üretin

### 4. Uygulamayı başlatın

```bash
flutter run
```

## Yol Haritası

| Öncelik | Başlık | Not |
| --- | --- | --- |
| Yüksek | Yeni egzersiz enablement | Yeni hareketler yalnız engine uyumu, test ve cihaz kanıtı tamamlandığında aktif edilmeli |
| Yüksek | Gerçek cihaz kabul kapsamını genişletme | Sonradan etkinleştirilen hareketler ve Low/Mid/High cihaz çeşitliliği için ayrı kanıt üretmek |
| Orta | Daha güçlü skor açıklaması | Egzersiz-bazlı form skorunun neden üretildiğini daha anlaşılır göstermek |
| Orta | Sesli geri bildirim | Anlık yönlendirme yüzeyini genişletmek |
| Orta | Hold family genellemesini güçlendirme | Yeni statik hareketlerde family/contract/posture-policy sınırlarını kanıtla genişletmek |
| Orta | Test kapsamını artırma | Yeni enablement ve regression işlerini daha güvenli hale getirmek |

---

## Katkı Notu

Bu repo aktif geliştirme altındadır. Katkı verirken özellikle şu prensiplere dikkat edilmesi önerilir:

- analiz çekirdeği ile UI düzenlemelerini karıştırmamak
- kullanıcıya gerçek olmayan veri göstermemek
- missing data'yı zero gibi sunmamak
- kısa ve açık ürün dili kullanmak
- bir hareketi kanıt tamamlanmadan `supported` yapmamak
- catalog support ile device validation kavramlarını karıştırmamak
- küçük ekran düzenlerini bozmamak
- feature bazlı yapının bütünlüğünü korumak

Yeni egzersiz geliştirmeleri için `docs/development/adding-exercises.md`, repository genelindeki kalıcı mühendislik kuralları için `docs/frontend/FRONTEND_ENGINEERING.md`, beta kanıt kapsamı için `docs/beta/` altındaki belgeler esas alınmalıdır.

---

## Lisans

Bu repo için lisans bilgisi henüz eklenmemiştir. Lisans tercihi netleştiğinde bu bölüm güncellenecektir.

---

<div align="center">

**PEA, kullanıcıya yalnız gerçekten ölçtüğü şeyi göstermeyi ve analiz kapsamını kanıtla genişletmeyi hedefler.**

</div>
