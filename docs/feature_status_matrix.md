# Feature Status Matrix

Bu doküman uygulamadaki mevcut ürün yüzeylerinin teknik durumunu sınıflandırır. Amaç pazarlama anlatımı değil; hangi alanın gerçek veriyle, hangi alanın karma veya demo veriyle çalıştığını açık tutmaktır.

## A. Ürün Yüzeyleri Listesi

- Home
- Camera Permission
- Calibration
- Live Analysis
- Workout Summary
- Session History
- Session Detail
- Guide
- Chat
- Goals
- Achievements
- Settings

## B. Feature Durum Sınıflandırması

### Home

- `Status:` Hybrid
- `Purpose:` Uygulamanın ana giriş yüzeyi, dashboard özeti ve önemli alanlara hızlı erişim sağlar.
- `Current data source:` `homeDashboardProvider` üzerinden gerçek session verisi denenir; veri yoksa fallback dashboard verisi kullanılır. Goals, Achievements ve Chat preview alanları demo/local kaynaklara bağlıdır.
- `Navigation entry points:` App startup sonrası ana giriş; drawer içinde Ana Sayfa; bazı ekranlardan geri dönüş.
- `Future integration notes:` Preview sayısı kontrollü tutulmalı. Yeni preview eklenmeden önce primary/secondary yüzey kararı belgelenmeli.

### Camera Permission

- `Status:` Real
- `Purpose:` Kamera izni durumunu yönetir ve analiz akışına girmeden önce kullanıcıyı güvenli şekilde yönlendirir.
- `Current data source:` Platform permission durumu ve mevcut auth hazırlık akışı.
- `Navigation entry points:` Home üzerinden Analize Başla; aktif egzersiz seçiminden analiz başlatma.
- `Future integration notes:` Anonymous sign-in davranışı burada kalmalı; startup veya dashboard akışına taşınmamalı.

### Calibration

- `Status:` Hybrid
- `Purpose:` Live Analysis öncesi kullanıcıyı hazırlayan geçiş/guidance ekranıdır.
- `Current data source:` Ekran içi mevcut akış ve kullanıcı etkileşimi.
- `Navigation entry points:` Camera Permission izni verildikten sonra.
- `Future integration notes:` Gerçek kalibrasyon profili veya hareket bazlı ayar eklenecekse analiz motorundan ayrı, ölçülebilir bir sözleşme ile tasarlanmalı.

### Live Analysis

- `Status:` Real
- `Purpose:` Kamera görüntüsü üzerinden pose detection, egzersiz analizi, tekrar sayımı, skor ve feedback üretir.
- `Current data source:` Camera stream, ML Kit pose detection, workout controller, exercise engine.
- `Navigation entry points:` Calibration sonrası.
- `Future integration notes:` Çoklu egzersiz desteği eklenirse `WorkoutController` ve exercise selection state ayrı bir tasarım adımıyla ele alınmalı.

### Workout Summary

- `Status:` Real
- `Purpose:` Tamamlanan analiz oturumunun özetini gösterir.
- `Current data source:` Live Analysis sonunda oluşturulan completed session verisi.
- `Navigation entry points:` Live Analysis içinde Bitir akışı sonrası.
- `Future integration notes:` Geçmiş oturum detaylarıyla ortak görsel parçalar ileride ayrıştırılabilir; summary akışı canlı analiz bitiş davranışından koparılmamalı.

### Session History

- `Status:` Real
- `Purpose:` Kullanıcının kaydedilmiş analiz oturumlarını listeler.
- `Current data source:` `SessionRepository` üzerinden Firestore one-shot list read; auth ownerId ile çalışır.
- `Navigation entry points:` Home preview/action; drawer içindeki Geçmiş Oturumlar.
- `Future integration notes:` Filtreleme, silme, export veya realtime listener ayrı kapsam olarak ele alınmalı.

### Session Detail

- `Status:` Hybrid
- `Purpose:` Seçilen geçmiş oturumun mevcut session alanlarını daha düzenli gösterir.
- `Current data source:` Session History listesinden geçirilen `WorkoutSession` nesnesi.
- `Navigation entry points:` Session History kart tıklaması.
- `Future integration notes:` Öneri özeti şu an basit kural tabanlı yorumdur; ölçülmüş veri gibi genişletilmemeli.

### Guide

- `Status:` Demo
- `Purpose:` Egzersizler için teknik ipuçları ve yaygın hataları gösterir.
- `Current data source:` Local `exerciseGuideContents` içeriği.
- `Navigation entry points:` Home action; drawer içindeki Hareket Rehberi; pasif egzersiz uyarılarında kullanıcı yönlendirmesi.
- `Future integration notes:` İçerik CMS veya backend kaynağına bağlanacaksa model korunmalı; analiz motoruna doğrudan bağlanmamalı.

### Chat

- `Status:` Demo
- `Purpose:` AI Coach sohbet kabuğunu ve ileride backend'e bağlanabilecek mesaj akışını gösterir.
- `Current data source:` `DemoChatRepository` içinde kural tabanlı local cevaplar.
- `Navigation entry points:` Home içindeki AI Coach preview kartı.
- `Future integration notes:` Gerçek AI entegrasyonu eklenirken repository arayüzü korunmalı; UI doğrudan network client'a bağlanmamalı.

### Goals

- `Status:` Demo
- `Purpose:` Haftalık hedef ve ilerleme hissi veren hedef kabuğunu gösterir.
- `Current data source:` Local `demoWorkoutGoals`.
- `Navigation entry points:` Home içindeki Haftalık Hedef preview kartı.
- `Future integration notes:` Gerçek hedef hesaplama session verisine bağlanmadan önce hedef modeli ve güncelleme kuralları netleştirilmeli.

### Achievements

- `Status:` Demo
- `Purpose:` Rozet ve başarı yüzeyi için ileride gerçeklenebilir kabuk sağlar.
- `Current data source:` Local `demoAchievements`.
- `Navigation entry points:` Home içindeki Başarılar preview kartı.
- `Future integration notes:` Unlock koşulları gerçek session verisine bağlanmadan önce ayrı bir achievement evaluation katmanı tasarlanmalı.

### Settings

- `Status:` Real
- `Purpose:` Uygulama ayarlarını düzenleme yüzeyidir.
- `Current data source:` `settingsControllerProvider`.
- `Navigation entry points:` Home AppBar ayarlar aksiyonu; drawer içindeki Ayarlar.
- `Future integration notes:` Yeni ayar eklenirse provider sözleşmesi bozulmadan ve mevcut async loading/error/data davranışı korunarak eklenmeli.

## C. Teknik Gerçeklik Notları

- Analiz çekirdeği gerçek ürün akışının parçasıdır: kamera, pose detection, workout controller, exercise engine, session oluşturma ve Firestore save akışı vardır.
- Dashboard hibrittir: gerçek session verisi okunmaya çalışılır, veri/auth yoksa fallback dashboard verisi gösterilir.
- Guide local content ile çalışır; analiz motoruna bağlı değildir.
- Chat şu an demo repository ile çalışır; gerçek AI, HTTP veya backend entegrasyonu yoktur.
- Goals local demo data ile çalışır; gerçek hedef motoru veya persistence yoktur.
- Achievements local demo data ile çalışır; gerçek unlock hesaplama yoktur.
- HomeScreen bilinçli olarak özel ekran olarak shell dışında bırakılmıştır.
- Secondary feature ekranları şu an drawer yerine Home preview kartlarından açılır.

## D. Navigasyon Politikası

- Primary surfaces:
  - Home
  - Exercise Selection
  - Session History
  - Guide
  - Settings
- Analysis flow surfaces:
  - Camera Permission
  - Calibration
  - Live Analysis
  - Workout Summary
- Secondary surfaces:
  - Chat
  - Goals
  - Achievements
  - Session Detail
- Drawer şu an ana gezinme yüzeylerini taşır. Chat, Goals, Achievements ve Session Detail drawer'a eklenmemiştir çünkü bunlar secondary surface olarak Home preview veya liste detayı üzerinden açılır.
- Home'dan preview ile açılan ekranlar:
  - Chat
  - Goals
  - Achievements
- Session Detail yalnızca Session History üzerinden açılır; doğrudan drawer entry değildir.

## E. Sonraki Geliştirme İlkeleri

- Yeni feature eklenmeden önce `Real`, `Hybrid` veya `Demo` durumu belirlenmeli.
- Demo feature verisi widget içine gömülmemeli; local data/model dosyasında tutulmalı.
- Mümkünse model, repository ve provider sözleşmesi küçük ama açık şekilde kurulmalı.
- HomeScreen'e gelişigüzel yeni preview eklenmemeli; primary/secondary yüzey kararı önce belgelenmeli.
- Secondary surface kararları bu dokümanda güncellenmeli.
- Demo alanlar kullanıcıya gerçek veri gibi sunulmamalı; UI metni ve teknik notlar bu ayrımı korumalı.
