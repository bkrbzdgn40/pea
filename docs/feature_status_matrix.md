# Feature Status Matrix

Bu doküman PEA içindeki kullanıcıya dönük ürün yüzeylerinin güncel teknik durumunu sınıflandırır. Amaç pazarlama anlatımı değil; hangi yüzeyin gerçek runtime veya kullanıcı verisiyle, hangisinin yerel kürasyonla, hangisinin kural tabanlı hibrit mantıkla ve hangisinin demo davranışıyla çalıştığını açık tutmaktır.

Bu belge yaşayan ürün dokümantasyonudur. Kod davranışı değiştiğinde aynı kapsamda güncellenmelidir.

## Durum Sözlüğü

- `Real`: Production akışında gerçek platform, runtime veya kullanıcı verisiyle çalışan yüzey.
- `Local`: Production içinde kullanılan ancak kaynağı yerel ve kürasyonlu/statik olan yüzey.
- `Hybrid`: Gerçek kullanıcı/runtime verisini yerel türetme veya kural tabanlı yorumla birleştiren yüzey.
- `Demo`: Gerçek capability gibi kabul edilmemesi gereken, bilerek demo veya placeholder olarak tutulan yüzey.

> **Önemli:** Bir egzersizin `ExerciseCatalog` içinde analiz için `supported` olması, o egzersizin bütün cihazlarda veya tarihsel beta ölçüm programında doğrulandığı anlamına gelmez. Catalog desteği ile device-validation kanıtı ayrı katmanlardır.

## A. Ürün Yüzeyleri Listesi

- Home
- How to Use
- Exercise Selection
- Camera Permission
- Preparation (`CalibrationScreen`)
- Live Analysis
- Workout Summary
- Session History
- Session Detail
- Guide
- Score Trend Detail
- Chat / AI Coach
- Goals
- Achievements
- Settings

## B. Feature Durum Sınıflandırması

### Home

- `Status:` Hybrid
- `Purpose:` Uygulamanın ana giriş yüzeyidir. Kullanıcıyı zaman bazlı selamlama, ana analiz aksiyonları ve güvenilir veri bulunduğunda oturum özetleriyle karşılar.
- `Current data source:` Dashboard yalnız gerçek session snapshot'ı geldiğinde gerçek oturum verisinden beslenir. `loading`, `noUser`, `empty` ve `error` durumlarında production provider'ları sahte analiz sayısı, skor, trend veya egzersiz dağılımı üretmez.
- `Score behavior:` Global ve cross-exercise score trend kullanılmaz. Trend yüzeyi, seçili `ExerciseType` için gerçek ve score-eligible geçmiş bulunduğunda gösterilir.
- `Goals / Achievements preview:` Yalnız gerçek provider verisi güvenilir preview ürettiğinde ilerleme gösterilir; aksi durumda sade başlangıç metni kullanılır.
- `AI Coach preview:` Kullanıcıya `Yakında` olarak gösterilir; tıklanınca açılan Chat yüzeyi hâlâ demo repository kullanır.
- `Navigation entry points:` App startup sonrası ana giriş; drawer içindeki Ana Sayfa; diğer top-level yüzeylerden dönüş.
- `Future integration notes:` Missing data yeniden sıfır performans veya demo ilerleme gibi sunulmamalı. Farklı egzersizlerin skorları tek gelişim metriğinde birleştirilmemeli.

### How to Use

- `Status:` Local
- `Purpose:` Uygulamanın ne yaptığını ve temel kullanım akışını kısa ürün içi onboarding diliyle açıklar.
- `Current data source:` Yerel, kürasyonlu statik içerik.
- `Navigation entry points:` Drawer içindeki Nasıl Kullanılır.
- `Future integration notes:` Sayfa kısa ve yardımcı kalmalı; pazarlama broşürüne veya uzun teknik kılavuza dönüşmemeli.

### Exercise Selection

- `Status:` Hybrid
- `Purpose:` Kullanıcının analiz edeceği hareketi seçmesini ve analiz desteği kapalı hareketleri açık biçimde ayırt etmesini sağlar.
- `Current data source:` Yerel `ExerciseGuideCatalog` içeriği + merkezi `ExerciseCatalog` support metadata'sı.
- `Current support truth:` Squat, Plank, Hollow Hold, Stationary Lunge, Push-up, Sit-up, Biceps Curl, Lying Leg Raise, Triceps Dip, Romanian Deadlift, Lateral Raise ve Shoulder Press catalog içinde analiz için aktiftir. Yeni batch için gerçek cihaz kabul kanıtı ayrıca toplanmalıdır.
- `Behavior:` Catalog içinde unsupported bırakılan gelecekteki hareketler analiz akışını başlatmaz; mevcut canonical hareketlerin tamamı şu anda supported tanımlıdır.
- `Navigation entry points:` Home ana aksiyonları; drawer içindeki Hareket Seç; geçerli analiz seçimi gerektiğinde recovery akışları.
- `Future integration notes:` Kartın `Analiz aktif` olması yalnız catalog desteğini ifade eder. Device validation veya biyomekanik kabul kanıtı gibi sunulmamalıdır.

### Camera Permission

- `Status:` Real
- `Purpose:` Kamera izni durumunu yönetir ve analiz akışına girmeden önce kullanıcıyı gerekli platform permission adımından geçirir.
- `Current data source:` Platform kamera izin durumu ve mevcut auth hazırlık akışı.
- `Navigation entry points:` Desteklenen bir egzersiz seçildikten sonra analiz başlatma akışı.
- `Future integration notes:` Permission ve auth hazırlık davranışı statik onboarding veya Home içine gizlice taşınmamalı; analiz giriş sınırında açık kalmalıdır.

### Preparation (`CalibrationScreen`)

- `Status:` Local
- `Purpose:` Canlı analiz öncesi seçili egzersiz config'inin hazır olmasını bekler ve kullanıcıya kamera/ortam için kısa hazırlık kontrol listesi gösterir.
- `Current data source:` Seçili/aktif egzersiz state'i, `exerciseConfigProvider` yükleme durumu ve yerel hazırlık metinleri.
- `Important limitation:` Dosya/sınıf adı `CalibrationScreen` olsa da bu ekran bugün ölçüm yapan gerçek bir kalibrasyon profili üretmez, kullanıcıya özel threshold öğrenmez ve kalıcı calibration state'i oluşturmaz. Ürün açısından bir hazırlık/guidance ekranıdır.
- `Navigation entry points:` Camera Permission sonrası.
- `Future integration notes:` Gerçek kalibrasyon eklenirse mevcut hazırlık checklist'inden ayrı, ölçülebilir ve test edilebilir bir domain sözleşmesiyle tasarlanmalıdır.

### Live Analysis

- `Status:` Real
- `Purpose:` Kamera görüntüsü üzerinden pose detection çalıştırır ve seçilen egzersizin analiz contract/config bilgisine göre gerçek zamanlı tekrar veya hold analizi üretir.
- `Current data source:` Camera stream, ML Kit Pose Detection, pose-quality/side-selection katmanları, `WorkoutController`, exercise config/contract ve ilgili analysis engine.
- `Current range-rep support:` Squat, Stationary Lunge, Push-up, Sit-up, Lying Leg Raise, Triceps Dip ve Romanian Deadlift selected-side; Biceps Curl, Lateral Raise ve Shoulder Press bilateral `rangeRep` kullanır. Primary metric yönü decreasing-to-peak veya increasing-to-peak olabilir.
- `Current hold support:` Plank ve Hollow Hold ortak `HoldEngine` state machine'ini family-specific contract ve posture policy ile kullanır.
- `Unsupported engine note:` `EngineKind.alternatingRep` tanımlıdır ancak factory içinde uygulanmış bir motor değildir.
- `Navigation entry points:` Preparation ekranı sonrası.
- `Future integration notes:` Yeni hareket enablement'ı yalnız UI/catalog değişikliği değildir; contract, config, extractor, engine davranışı, diagnostics, persistence ve cihaz kanıtı birlikte değerlendirilmelidir.

### Workout Summary

- `Status:` Real
- `Purpose:` Tamamlanan analiz oturumunun egzersiz türüne uygun özetini gösterir.
- `Current data source:` Live Analysis sonunda oluşturulan completed `WorkoutSession` ve session report verisi.
- `Behavior:` Range-rep ve hold oturumları aynı metrikmiş gibi sunulmaz; hold oturumlarında hold süresi/form-break, range-rep oturumlarında tekrar/skor semantiği kullanılır.
- `Navigation entry points:` Live Analysis içindeki bitirme akışı sonrası.
- `Future integration notes:` Özet yüzeyi gerçek session contract'ından koparılmamalı ve ölçülmeyen metrikler tahmin edilmemelidir.

### Session History

- `Status:` Real
- `Purpose:` Kullanıcının Firestore'a kaydedilmiş analiz oturumlarını listeler.
- `Current data source:` `SessionRepository` üzerinden owner-scoped Firestore session list read.
- `Navigation entry points:` Home action grid; drawer içindeki Geçmiş Oturumlar.
- `Future integration notes:` Yeni filtreleme, export, realtime listener veya lifecycle davranışları ayrı kapsam ve veri sözleşmesiyle ele alınmalıdır.

### Session Detail

- `Status:` Hybrid
- `Purpose:` Seçilen geçmiş oturumu yeniden yükler, session raporu oluşturur ve mevcutsa rep-level detayları gösterir.
- `Current data source:` Firestore session summary document + `users/{uid}/sessions/{sessionId}/reps/{repId}` rep subcollection kayıtları.
- `Behavior:` Ekran session'ı `getSessionById` ile yeniler ve rep kayıtlarını `listSessionReps` ile yükler. Eski veya rep kaydı bulunmayan oturumlarda yalnız özet veri bulunabileceğini açıkça belirtir.
- `Recommendation note:` Rapor özeti ve öneriler domain içindeki kural tabanlı `SessionReport` yorumlarıdır; klinik, tıbbi veya uzman doğrulamalı tavsiye değildir.
- `Navigation entry points:` Session History kart seçimi.
- `Future integration notes:` Rep-level kayıtlar artık gerçek persistence contract'ının parçasıdır; yeni breakdown alanları eklenirken eski summary-only oturumlarla geriye uyumluluk korunmalıdır.

### Guide

- `Status:` Local
- `Purpose:` Egzersizler için kısa amaç, kurulum, teknik ipucu, yaygın hata ve dış video yönlendirmesi sunar.
- `Current data source:` Yerel kürasyonlu exercise guide içeriği ve hareket başına dış video bağlantıları.
- `Navigation entry points:` Home action grid; drawer içindeki Hareket Rehberi; unsupported analiz hareketleri için kullanıcı yönlendirmesi.
- `Future integration notes:` Guide görünürlüğü analiz desteği değildir. İçerik CMS/backend'e taşınsa bile analysis support politikasının kaynağı `ExerciseCatalog` olarak kalmalıdır.

### Score Trend Detail

- `Status:` Real
- `Purpose:` Seçili tek bir egzersizin geçmiş score trendini ayrıntılı gösterir.
- `Current data source:` `exerciseScoreTrendProvider(ExerciseType)`; session snapshot önce açık bir `ExerciseType` ile filtrelenir, ardından score-eligible session'lar hesaplanır.
- `Behavior:` Farklı egzersizlerin skorları aynı trendde birleştirilmez. Hold-only geçmiş sıfır skor örnekleri olarak trend içine sokulmaz.
- `Navigation entry points:` Home üzerindeki seçili egzersize ait gerçek Score Trend kartı.
- `Future integration notes:` Cross-exercise skor karşılaştırması ancak skorların karşılaştırılabilirliği ayrıca kanıtlanırsa düşünülebilir.

### Chat / AI Coach

- `Status:` Demo
- `Purpose:` İleride gerçek bir coach/backend entegrasyonuna bağlanabilecek sohbet UI ve repository sınırını gösterir.
- `Current data source:` `DemoChatRepository` içindeki yerel, kural tabanlı cevaplar.
- `Navigation entry points:` Home içindeki `AI Coach` / `Yakında` preview kartı.
- `Important limitation:` Gerçek AI model çağrısı, HTTP backend veya üretim coach servisi yoktur. Demo cevaplar AI yeteneği gibi belgelenmemeli veya pazarlanmamalıdır.
- `Future integration notes:` Gerçek entegrasyon eklenirse repository sınırı korunmalı ve UI doğrudan network client'a bağlanmamalıdır.

### Goals

- `Status:` Hybrid
- `Purpose:` Gerçek session geçmişinden türetilen yerel hedef kurallarını kullanıcıya gösterir.
- `Current data source:` Gerçek `UserSessionsSnapshot` geldiğinde `WorkoutStatisticsCalculator` sonuçlarından yerel hedefler türetilir. `noUser`, `empty` ve `error` durumlarında production provider boş koleksiyon döndürür; demo progress üretmez.
- `Current limitation:` Hedef tanımları ve eşikleri yerel ürün kurallarıdır; ayrı kullanıcı hedef persistence'ı veya tam ürünleşmiş goal-management domain'i yoktur. Aggregate skor kullanan hedefler doğrulanmış cross-exercise performans standardı olarak yorumlanmamalıdır.
- `Navigation entry points:` Home içindeki Haftalık Hedef preview kartı.
- `Future integration notes:` Hedef semantiği, kullanıcı tarafından düzenlenebilir hedefler ve persistence ayrı ürün/mimari çalışmasıdır.

### Achievements

- `Status:` Hybrid
- `Purpose:` Gerçek session geçmişinden türetilen yerel başarı/rozet kurallarını gösterir.
- `Current data source:` Gerçek `UserSessionsSnapshot` geldiğinde `WorkoutStatisticsCalculator` sonuçlarından achievement state üretilir. `noUser`, `empty` ve `error` durumlarında demo unlock/progress üretilmez.
- `Current limitation:` Achievement kuralları yerel ve sabittir; ayrı kalıcı unlock/evaluation domain'i yoktur. Skor temelli rozetler uzman doğrulamalı form veya cross-exercise biyomekanik standardı anlamına gelmez.
- `Navigation entry points:` Home içindeki Başarılar preview kartı.
- `Future integration notes:` Kalıcı unlock geçmişi veya daha karmaşık değerlendirme eklenirse ayrı achievement evaluation/persistence sözleşmesi oluşturulmalıdır.

### Settings

- `Status:` Real
- `Purpose:` Uygulamanın kullanıcı tarafından değiştirilebilen ayarlarını yönetir.
- `Current data source:` `settingsControllerProvider` ve mevcut settings persistence/state akışı.
- `Navigation entry points:` Home AppBar ayarlar aksiyonu; drawer içindeki Ayarlar.
- `Future integration notes:` Kamera kalitesi ve lens gibi analiz davranışını etkileyen ayarlar değiştirilirken runtime etkisi ayrıca test edilmelidir.

## C. Teknik Gerçeklik Notları

- Güncel `ExerciseCatalog` on iki aktif analiz hareketi taşır. Yeni range-rep batch'i device-validation kanıtını tarihsel beta PASS sonuçlarından otomatik olarak devralmaz.
- Catalog desteği, otomatik test geçişi ve gerçek cihaz kabul kanıtı aynı şey değildir. Tarihsel beta device-validation kapsamı daha dardır ve sonradan enable edilen hareketlere otomatik olarak aktarılmaz.
- `rangeRep` ailesi selected-side ve bilateral çalışma modlarını destekler. Bilateral çalışma, dönüşümlü sağ-sol tekrar state machine'i değildir.
- `hold` ailesi ortak state machine üzerinde Plank ve Hollow Hold için farklı contract/posture policy kullanır.
- Production Home, Goals ve Achievements provider'ları veri yokken demo kullanıcı ilerlemesi üretmez.
- Global/cross-exercise score trend kaldırılmıştır; score trend açık bir `ExerciseType` bağlamında hesaplanır.
- Firestore session document'i summary-level alanları taşır; rep-level kayıtlar ayrı `reps` subcollection altında persist edilir ve Session Detail tarafından okunur.
- `CalibrationScreen` bugün gerçek bir calibration ölçümü değil, analiz öncesi preparation/guidance yüzeyidir.
- Chat hâlâ demo repository kullanır; gerçek AI capability yoktur.
- Beta Diagnostics ve canlı debug/calibration telemetry yüzeyleri engineering/debug amaçlıdır; normal kullanıcı ürün capability'si gibi sınıflandırılmamalıdır.

## D. Navigasyon Politikası

### Primary surfaces

- Home
- How to Use
- Exercise Selection
- Session History
- Guide
- Settings

### Analysis flow surfaces

```text
Exercise Selection
  -> Camera Permission
  -> Preparation
  -> Live Analysis
  -> Workout Summary
```

### Secondary/detail surfaces

- Goals
- Achievements
- Chat / AI Coach
- Session Detail
- Score Trend Detail

### Drawer

Drawer ana gezinme yüzeylerini taşır:

- Home
- How to Use
- Exercise Selection
- Session History
- Guide
- Settings

### Contextual navigation

- Goals, Achievements ve Chat Home üzerindeki preview kartlarından açılır.
- Session Detail yalnız Session History içinden açılır.
- Score Trend Detail yalnız seçili egzersiz için gerçek score trend verisi mevcut olduğunda Home içindeki trend kartından açılır.
- Gelecekte unsupported tanımlanacak bir exercise seçimi analiz akışını başlatmamalıdır.

## E. Sonraki Geliştirme İlkeleri

- Missing data sıfır performans değildir; fallback davranışı rakamsal taklit üretmemelidir.
- Demo feature verisi production kullanıcı gerçeği gibi gösterilmemelidir.
- Aynı score trend içinde yalnız aynı `ExerciseType` geçmişi karşılaştırılmalıdır.
- `supported` etiketi device-validation kanıtı gibi yorumlanmamalıdır.
- Preparation ekranı gerçek calibration capability'si eklenmeden kalibrasyon yaptığı iddiasında bulunmamalıdır.
- Kural tabanlı Session Report, Goals ve Achievements yorumları klinik veya uzman doğrulamalı değerlendirme gibi genişletilmemelidir.
- Chat gerçek backend/model entegrasyonu olmadan AI capability olarak sunulmamalıdır.
- Guide içeriği kısa, pratik ve kürasyonlu ürün içi tonunu korumalı; analysis support kaynağına dönüşmemelidir.
- Yeni egzersiz enablement'ı UI kartı açmakla tamamlanmış sayılmamalı; engine/config/contract/test/diagnostics/persistence/device-validation kapsamı ayrıca ele alınmalıdır.
- Yeni top-level surface eklenmeden önce primary/secondary/navigation ownership kararı bu belgede güncellenmelidir.
