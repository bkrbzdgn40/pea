<div align="center">

# PEA

### AI Destekli Mobil Spor Hareket Analizi Uygulaması

Mobil cihaz kamerası üzerinden egzersiz formunu gerçek zamanlı izlemeyi, tekrar saymayı, temel skor üretmeyi ve oturum geçmişi sunmayı hedefleyen Flutter tabanlı bir hareket analizi uygulaması.

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

PEA, egzersiz sırasında kullanıcının hareketini kamera üzerinden izleyerek daha akıllı bir mobil antrenman deneyimi üretmeyi amaçlar.

Uygulama temel olarak şunları yapar:

* kamera akışından pose landmark çıkarır
* hareket fazını takip eder
* tekrarları otomatik sayar
* temel skor ve kısa geri bildirim üretir
* oturumları kaydedip geçmiş görünümü sunar
* rehber ve yardımcı içeriklerle kullanıcıyı destekler

> Bu repo yalnızca fikir gösterimi yapan bir arayüz değil, çalışan bir analiz çekirdeği üzerine kurulu gelişen bir ürün prototipidir.

---

## Öne Çıkanlar

| Alan                   | Durum | Açıklama                                                       |
| ---------------------- | ----: | -------------------------------------------------------------- |
| Canlı analiz           |     ✅ | Kamera akışı üzerinden pose detection ve hareket takibi        |
| Tekrar sayımı          |     ✅ | Hareket fazına göre tekrar sayımı                              |
| Temel skor üretimi     |     ✅ | ROM, tempo ve form tabanlı temel skor yaklaşımı                |
| Session geçmişi        |     ✅ | Kaydedilen oturumları listeleme ve detay görüntüleme           |
| Hareket rehberi        |     ✅ | Zorluk filtresi, kısa rehber içerikleri ve video yönlendirmesi |
| Nasıl Kullanılır       |     ✅ | Uygulama içinde kısa kullanım yardımı                          |
| Çoklu egzersiz analizi |    ⚠️ | Gelişiyor                                                      |
| Sesli geri bildirim    |     ⏳ | Planlanıyor                                                    |
| Gelişmiş AI Coach      |     ⏳ | Planlanıyor                                                    |

---

## Projenin Amacı

PEA’in hedefi, kullanıcıya yalnızca tekrar sayan bir sayaç değil, hareket kalitesine dokunan daha akıllı bir yardımcı sunmaktır.

Beklenen deneyim:

* hareketi kamera ile takip etmek
* temel eklem noktalarını çıkarmak
* açı ve faz değişimlerinden hareket kalitesi üretmek
* tekrarları otomatik saymak
* kısa ve anlaşılır geri bildirim vermek
* oturumları kaydedip gelişimi görünür hale getirmek

Bu yaklaşım, özellikle evde veya bireysel antrenman yapan kullanıcılar için daha erişilebilir bir form takip deneyimi üretmeyi hedefler.

---

## Uygulama Deneyimi

### Home

Kullanıcıyı zaman bazlı greeting card ve hızlı aksiyon grid’i ile karşılar. Gerçek oturum verisi varsa özet görünümü sunar; veri yoksa sahte metriklerle yanıltmak yerine sade bir başlangıç yüzeyi gösterir.

### Live Analysis

Kamera akışı üzerinden pose detection çalışır. Hareket fazı, tekrar sayısı, temel skor ve kısa geri bildirim üretilir.

### Workout Summary & History

Tamamlanan oturum özetlenir, kaydedilir ve geçmiş ekranında yeniden incelenebilir.

### Guide

Hareketler için kısa amaç açıklamaları, kurulum adımları, teknik ipuçları, yaygın hatalar ve güvenilir dış video bağlantıları sunar.

### How to Use

Uygulamanın ne yaptığını ve nasıl kullanılması gerektiğini kısa, sade ve ürün içi onboarding tonunda açıklar.

---

## Teknik Yığın

### Mobil

* Flutter
* Dart

### Durum Yönetimi

* Riverpod

### Bilgisayarlı Görü

* Google ML Kit Pose Detection

### Backend / Veri

* Firebase Core
* Firebase Auth
* Cloud Firestore

### Yardımcı Paketler

* Shared Preferences
* fl_chart
* url_launcher

---

## Mimari Yaklaşım

Proje, feature odaklı ve katmanlı bir yapıyla ilerler.

```text
lib/
├── app/
├── core/
├── features/
│   ├── auth/
│   ├── workout_analysis/
│   ├── goals/
│   ├── achievements/
│   └── chat/
```

### Temel prensipler

* analiz mantığını UI katmanından ayırmak
* Firebase erişimini repository katmanında toplamak
* feature bazlı yapıyı korumak
* kullanıcıyı sahte veriyle etkilemeye çalışmamak
* ürün yüzeylerini adım adım olgunlaştırmak

---

## Analiz Akışı

```text
Camera Stream
   ↓
InputImage dönüşümü
   ↓
ML Kit Pose Detection
   ↓
Landmark çıkarımı
   ↓
Açı hesaplama
   ↓
Hareket fazı / tekrar takibi
   ↓
Skor ve feedback üretimi
   ↓
Session kaydı (Firestore)
```

Bu akış, canlı analiz ekranının temel omurgasını oluşturur.

---

## Mevcut Durum

Bu repo aktif geliştirme altındadır. Bazı alanlar çalışır durumdadır, bazı yüzeyler ise kontrollü biçimde gelişmektedir.

### Şu anda çalışan ana akışlar

* Firebase bootstrap
* anonim kullanıcı oturumu
* kamera izin akışı
* hazırlık ekranı
* canlı analiz akışı
* pose detection
* tekrar sayımı
* temel skor üretimi
* canlı geri bildirim
* session kaydı
* oturum özeti
* geçmiş oturum listesi
* geçmiş oturum detayı
* ayarlar ekranı
* nasıl kullanılır ekranı
* hareket rehberi
* rehberde zorluk filtresi
* rehberde güvenilir dış video yönlendirmesi

### Şu anda gelişen alanlar

* çoklu egzersiz analizi
* daha derin skor açıklaması
* sesli geri bildirim
* hedef ve başarı mantığının derinleşmesi
* gerçek AI Coach entegrasyonu
* rep-level veri saklama
* daha güçlü test kapsamı

---

## Rehber Yaklaşımı

Guide ekranı, uzun ve sıkıcı açıklamalardan oluşan bir broşür sayfası olarak değil, uygulama içi hızlı referans yüzeyi olarak tasarlanmıştır.

Her hareket için:

* kısa açıklama
* zorluk seviyesi
* amaç
* kurulum adımları
* teknik ipuçları
* yaygın hatalar
* güvenilir video yönlendirmesi

sunulur.

İlk sürümde video oynatımı uygulama içine gömülmemiştir. Bunun yerine kullanıcı, küratörlü YouTube bağlantısına yönlendirilir. Bu tercih, deneyimi hafif ve bakım maliyetini daha düşük tutar.

---

## Veri Saklama Modeli

Session verileri kullanıcı bazlı saklanır:

```text
users/{uid}/sessions/{sessionId}
```

Kaydedilen temel alanlar şunları içerir:

* egzersiz tipi
* başlangıç zamanı
* bitiş zamanı
* süre
* toplam tekrar
* ortalama skor
* en iyi skor
* form uyarısı sayısı

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

* Firebase projesi oluşturun
* Android / iOS uygulamalarını ekleyin
* `flutterfire configure` çalıştırın
* `firebase_options.dart` dosyasını üretin

### 4. Uygulamayı başlatın

```bash
flutter run
```

---

## Güçlü Yanlar

* Çalışan bir canlı analiz çekirdeği var
* Mobil ürün akışı yalnızca demo arayüzden ibaret değil
* Firebase ve session yapısı ürünleşmeye uygun bir temel sunuyor
* Rehber ekranı gerçekten kullanışlı hale getirildi
* Home, canlı analiz, özet ve geçmiş arasında anlamlı bir kullanıcı akışı bulunuyor
* Koyu tema içinde daha düzenli ve modern bir mobil deneyim hedefleniyor

---

## Mevcut Sınırlamalar

Bu aşamada bilinçli olarak kabul edilen bazı sınırlar vardır:

* analiz motoru henüz tam çoklu egzersiz ürününe dönüşmüş değildir
* session verisi özet seviyesindedir
* rep-level detaylar persist edilmez
* sesli geri bildirim henüz yoktur
* AI Coach gerçek servis entegrasyonuna bağlı değildir
* bazı ürün yüzeyleri hâlâ gelişim aşamasındadır
* test ve emulator tabanlı doğrulamalar daha da güçlendirilebilir

---

## Yol Haritası

| Öncelik   | Başlık                                 | Not                                                       |
| --------- | -------------------------------------- | --------------------------------------------------------- |
| Yüksek    | Çoklu egzersiz desteği                 | Egzersiz seçimi ile analiz motorunun daha sıkı bağlanması |
| Yüksek    | Daha güçlü skor açıklaması             | Neden bu skor üretildiğini daha anlaşılır göstermek       |
| Orta      | Sesli geri bildirim                    | Anlık koçluk deneyimini güçlendirmek                      |
| Orta      | Hedef / başarı mantığını derinleştirme | Daha gerçek ürün hissi için                               |
| Orta      | Rehber içeriğini genişletme            | Daha fazla hareket ve daha iyi içerik                     |
| Orta      | Test kapsamını artırma                 | Daha güvenli geliştirme süreci için                       |
| Uzun vade | Daha zengin AI Coach deneyimi          | Gerçek servis ve kişiselleştirme ile                      |

---

## Katkı Notu

Bu repo aktif geliştirme altındadır. Katkı verirken özellikle şu prensiplere dikkat edilmesi önerilir:

* analiz çekirdeği ile UI düzenlemelerini karıştırmamak
* kullanıcıya gerçek olmayan veri göstermemek
* kısa ve açık ürün dili kullanmak
* küçük ekran düzenlerini bozmamak
* feature bazlı yapının bütünlüğünü korumak

---

## Lisans

Bu repo için lisans bilgisi henüz eklenmemiştir. Lisans tercihi netleştiğinde bu bölüm güncellenecektir.

---

<div align="center">

**PEA, daha akıllı ve daha erişilebilir bir mobil egzersiz analizi deneyimi oluşturmak için geliştiriliyor.**

</div>
