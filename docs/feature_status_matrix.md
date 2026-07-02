# Feature Status Matrix

Bu doküman uygulamadaki ürün yüzeylerinin teknik durumunu sınıflandırır. Amaç pazarlama anlatımı değil; hangi alanın gerçek kullanıcı verisiyle, hangi alanın yerel kürasyonla, hangi alanın hibrit yaklaşımla çalıştığını açık tutmaktır.

## A. Ürün Yüzeyleri Listesi

* Home
* How to Use
* Camera Permission
* Calibration
* Live Analysis
* Workout Summary
* Session History
* Session Detail
* Guide
* Chat
* Goals
* Achievements
* Settings

## B. Feature Durum Sınıflandırması

### Home

* `Status:` Hybrid
* `Purpose:` Uygulamanın ana giriş yüzeyidir. Kullanıcıyı zaman bazlı selamlama, ana aksiyonlar ve veri varsa özet görünümüyle karşılar.
* `Current data source:` Greeting ve action grid ekran içi UI mantığıyla çalışır. Dashboard alanı gerçek session verisi varsa kullanıcı oturumlarından beslenir. Session verisi yoksa sahte metrik gösterimi yerine sade placeholder/onboarding görünümü kullanılır.
* `Navigation entry points:` App startup sonrası ana giriş; drawer içinde Ana Sayfa; diğer ekranlardan geri dönüş.
* `Future integration notes:` Home artık kullanıcıya veri kaynağı etiketi göstermiyor. Bu nedenle fallback durumlarında sahte sayı, sahte chart veya sahte progress yüzeyi yeniden eklenmemeli.

### How to Use

* `Status:` Real
* `Purpose:` Uygulamanın ne yaptığını ve nasıl kullanılması gerektiğini kısa, sade ve ürün içi onboarding tonunda açıklar.
* `Current data source:` Yerel, kürasyonlu statik içerik.
* `Navigation entry points:` Drawer içindeki Nasıl Kullanılır.
* `Future integration notes:` Sayfa kısa ve yardımcı kalmalı; pazarlama broşürüne veya uzun kullanım kılavuzuna dönüşmemeli.

### Camera Permission

* `Status:` Real
* `Purpose:` Kamera izni durumunu yönetir ve analiz akışına girmeden önce kullanıcıyı güvenli şekilde yönlendirir.
* `Current data source:` Platform permission durumu ve mevcut auth hazırlık akışı.
* `Navigation entry points:` Home üzerinden Analize Başla; aktif egzersiz seçiminden analiz başlatma.
* `Future integration notes:` Anonymous sign-in davranışı burada kalmalı; Home veya statik onboarding yüzeylerine taşınmamalı.

### Calibration

* `Status:` Real
* `Purpose:` Canlı analiz öncesi kullanıcıyı kısa hazırlık adımlarıyla yönlendirir.
* `Current data source:` Ekran içi yerel rehber akışı ve kullanıcı etkileşimi.
* `Navigation entry points:` Camera Permission izni verildikten sonra.
* `Future integration notes:` Gerçek kalibrasyon profili veya hareket bazlı ayar eklenecekse mevcut hazırlık ekranından ayrı, ölçülebilir bir sözleşme ile ele alınmalı.

### Live Analysis

* `Status:` Real
* `Purpose:` Kamera görüntüsü üzerinden pose detection, egzersiz analizi, tekrar sayımı, skor ve feedback üretir.
* `Current data source:` Camera stream, ML Kit pose detection, workout controller, exercise engine.
* `Navigation entry points:` Calibration sonrası.
* `Future integration notes:` Çoklu egzersiz desteği eklenecekse `WorkoutController`, seçili hareket state’i ve egzersiz konfigürasyonu ayrı bir tasarım adımıyla ele alınmalı.

### Workout Summary

* `Status:` Real
* `Purpose:` Tamamlanan analiz oturumunun özetini gösterir.
* `Current data source:` Live Analysis sonunda oluşturulan completed session verisi.
* `Navigation entry points:` Live Analysis içinde Bitir akışı sonrası.
* `Future integration notes:` Özet görünümü, geçmiş oturum detaylarıyla ortak parçalar paylaşabilir; ancak canlı analiz bitiş akışından koparılmamalı.

### Session History

* `Status:` Real
* `Purpose:` Kullanıcının kaydedilmiş analiz oturumlarını listeler.
* `Current data source:` `SessionRepository` üzerinden Firestore one-shot list read; auth ownerId ile çalışır.
* `Navigation entry points:` Home action grid; drawer içindeki Geçmiş Oturumlar.
* `Future integration notes:` Filtreleme, export, soft delete veya realtime listener ayrı kapsam olarak ele alınmalı.

### Session Detail

* `Status:` Hybrid
* `Purpose:` Seçilen geçmiş oturumun mevcut session alanlarını daha düzenli gösterir ve kısa öneri özeti sunar.
* `Current data source:` Session History listesinden geçirilen gerçek `WorkoutSession` verisi + ekran içi basit kural tabanlı recommendation metni.
* `Navigation entry points:` Session History kart tıklaması.
* `Future integration notes:` Recommendation yüzeyi hâlâ hafif kurallıdır; ölçülmüş veya klinik tavsiye gibi genişletilmemeli. Daha ayrıntılı rep-level breakdown eklenirse bu ekran ayrı veri alanlarıyla güçlendirilebilir.

### Guide

* `Status:` Hybrid
* `Purpose:` Egzersizler için kısa, daha güvenilir ve daha pratik teknik rehber sunar; zorluk filtresi ve küratörlü video yönlendirmesi sağlar.
* `Current data source:` Yerel kürasyonlu `exerciseGuideContents` içeriği, zorluk enum’u, yerel rehber metinleri ve hareket başına sabit dış YouTube linkleri.
* `Navigation entry points:` Home action grid; drawer içindeki Hareket Rehberi.
* `Future integration notes:` Bu yüzey artık demo metin alanı değil, kürasyonlu ürün içi rehberdir. Ancak içerik hâlâ yereldir ve embedded video player kullanılmaz; kullanıcı güvenilir dış videoya yönlendirilir. İçerik CMS’ye taşınacaksa kısa, pratik ve broşür olmayan ton korunmalı.

### Chat

* `Status:` Demo
* `Purpose:` AI Coach sohbet kabuğunu ve ileride backend’e bağlanabilecek mesaj akışını gösterir.
* `Current data source:` `DemoChatRepository` içinde kural tabanlı local cevaplar.
* `Navigation entry points:` Home içindeki AI Coach preview kartı.
* `Future integration notes:` Gerçek AI entegrasyonu eklenirken repository arayüzü korunmalı; UI doğrudan network client’a bağlanmamalı.

### Goals

* `Status:` Hybrid
* `Purpose:` Kullanıcının oturum verisinden türetilen hedef görünümünü sunar.
* `Current data source:` Gerçek session verisi varsa hedefler session geçmişinden türetilir. Veri yoksa kullanıcıya sahte progress yüzeyi göstermek yerine sade boş durum/placeholder yaklaşımı tercih edilir.
* `Navigation entry points:` Home içindeki Haftalık Hedef preview kartı.
* `Future integration notes:` Hedef mantığı session verisine bağlı ürün yüzeyi olmaya devam etmeli. Eski demo-progress davranışı kullanıcıya geri getirilmemeli. Tam ürünleşme için hedef tanımı ve persistence ayrı ele alınmalı.

### Achievements

* `Status:` Hybrid
* `Purpose:` Kullanıcının session geçmişinden türetilen başarı/rozet yüzeyini sunar.
* `Current data source:` Gerçek session verisi varsa başarıların bir bölümü session geçmişinden hesaplanır. Veri yoksa kullanıcıya sahte ilerleme hissi veren demo-rozet yüzeyi yerine daha sade boş durum yaklaşımı kullanılır.
* `Navigation entry points:` Home içindeki Başarılar preview kartı.
* `Future integration notes:` Achievement evaluation katmanı ayrılaştırılmadan tam ürünleşmiş sayılmamalı. Kullanıcı görünen fallback artık sahte unlock/progress hissi yaratmamalı.

### Settings

* `Status:` Real
* `Purpose:` Uygulama ayarlarını düzenleme yüzeyidir.
* `Current data source:` `settingsControllerProvider`.
* `Navigation entry points:` Home AppBar ayarlar aksiyonu; drawer içindeki Ayarlar.
* `Future integration notes:` Yeni ayar eklenirse mevcut async loading/error/data davranışı korunmalı; özellikle kamera kalite ve lens tercihleri analiz performansını etkilediği için kontrollü genişletilmeli.

## C. Teknik Gerçeklik Notları

* Analiz çekirdeği gerçek ürün akışının parçasıdır: kamera, pose detection, workout controller, exercise engine, session oluşturma ve Firestore save akışı vardır.
* Home artık kullanıcıya “gerçek veri / örnek veri” etiketi göstermez. Bunun yerine veri yoksa sahte dashboard sayıları yerine sade placeholder/onboarding görünümü kullanılır.
* Guide yüzeyi artık yalnızca demo metin alanı değil; yerel kürasyonlu kısa rehber, zorluk filtresi ve dış güvenilir video yönlendirmesi içerir.
* Guide içindeki video deneyimi embedded player değildir; uygulama dışı YouTube açılışı tercih edilir.
* Chat hâlâ demo repository ile çalışır; gerçek AI, HTTP veya backend entegrasyonu yoktur.
* Goals ve Achievements ürün yönü olarak gerçek session verisine bağlanır; ancak bu yüzeyler hâlâ tam kurallı değerlendirme/persistence katmanına sahip değildir.
* Kullanıcı görünen veri kaynağı rozetleri kaldırılmıştır; bu nedenle fallback davranışları rakamsal taklit değil, boş durum/placeholder mantığında kalmalıdır.
* HomeScreen görsel hiyerarşisi greeting card + action grid önceliğiyle yeniden düzenlenmiştir.
* Responsive dayanıklılık için Session Detail, Score Trend Detail, Exercise Distribution ve Live Analysis üst metrik satırında dar ekran uyumluluğu iyileştirilmiştir.

## D. Navigasyon Politikası

* Primary surfaces:

  * Home
  * How to Use
  * Exercise Selection
  * Session History
  * Guide
  * Settings
* Analysis flow surfaces:

  * Camera Permission
  * Calibration
  * Live Analysis
  * Workout Summary
* Secondary surfaces:

  * Chat
  * Goals
  * Achievements
  * Session Detail
* Drawer şu an ana gezinme yüzeylerini taşır.
* Drawer içindeki yüzeyler:

  * Home
  * How to Use
  * Exercise Selection
  * Session History
  * Guide
  * Settings
* Home’dan preview/action ile açılan yüzeyler:

  * Goals
  * Achievements
  * Chat
* Session Detail yalnızca Session History üzerinden açılır; doğrudan drawer entry değildir.

## E. Sonraki Geliştirme İlkeleri

* Kullanıcı görünen etiketler kaldırıldıysa fallback davranışı rakamsal taklit üretmemeli.
* Demo feature verisi widget içine gömülmemeli; ancak kullanıcıya gerçekmiş gibi de sunulmamalı.
* Yerel kürasyonlu rehber içeriği kısa, pratik ve ürün içi tonunu korumalı.
* Dış video yönlendirmesi, rehber yüzeyinin video platformuna dönüşmesine neden olmamalı.
* Goals ve Achievements için gerçek evaluation mantığı ayrılaştırılmadan bu yüzeyler tam ürünleşmiş kabul edilmemeli.
* Home’a yeni preview eklenmeden önce primary/secondary yüzey kararı yeniden belgelenmeli.
* Responsive düzenlemeler tek seferlik piksel itme yaklaşımıyla değil, esnek layout mantığıyla korunmalı.
* Eğer çoklu egzersiz analizi eklenirse Guide, Exercise Selection ve Live Analysis arasında veri sözleşmesi açık biçimde yeniden tanımlanmalı.
