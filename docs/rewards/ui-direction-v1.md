# Hedefler, Madalyalar ve Başarımlar UI Yönü V1

## 1. Görsel ilke

PEA'nın profesyonel görünmesi bütün renklerden vazgeçmesi anlamına gelmez.
Arayüzde zemin ve günlük etkileşimler sakin; ödül nesneleri ve anlamlı durumlar
renkli olacaktır.

- **Zemin:** siyah ve mevcut nötr surface token'ları.
- **Metin:** mevcut foreground hiyerarşisi.
- **Marka vurgusu:** aktif hedef, seçili kontrol ve ana eylemlerde PEA yeşili.
- **Madalya rengi:** yalnızca madalya, seviye göstergesi ve kazanma anında.
- **Başarım kategori rengi:** ikon, ince vurgu veya rozet yüzeyinde; bütün kartı boyamaz.
- **Renk tek başına anlam taşımaz:** ikon, başlık ve seviye adı birlikte kullanılır.

## 2. Renk token adayları

Bu değerler implementation turunda kontrast ve dark-mode golden testleriyle doğrulanacaktır.

| Token | Ana ton | Açık vurgu | Derin ton | Kullanım |
|---|---|---|---|---|
| `medalBronze` | `#C77A44` | `#F0B27A` | `#6F351C` | Bronz madalya ve seviye izi |
| `medalSilver` | `#B8C2CC` | `#EEF3F7` | `#5D6874` | Gümüş madalya ve seviye izi |
| `medalGold` | `#F2C94C` | `#FFE7A3` | `#8F6500` | Altın madalya ve kazanma vurgusu |
| `achievementTrust` | `#61E6BE` | - | - | Güvenilirlik başarımları |
| `achievementExplore` | `#8B7CFF` | - | - | Keşif başarımları |
| `achievementRhythm` | `#FF9F43` | - | - | Ritim ve devamlılık |
| `achievementPlan` | `#C084FC` | - | - | Planlı antrenman |
| `achievementReturn` | `#52D273` | - | - | Geri dönüş |
| `achievementSecret` | `#F7D774` | - | - | Gizli ve özel başarımlar |

Madalya görselleri aynı ikonun yalnızca rengini değiştirerek üretilmez. Seviye başına
farklı dış çerçeve ve derinlik kullanılır; merkezde ortak PEA işareti korunur.

## 3. Hedefler ekranı bilgi mimarisi

### 3.1 Üst alan: tek aktif kişisel hedef

```text
Hedefler

┌──────────────────────────────────────┐
│ BU HAFTAKİ HEDEFİN                   │
│ 140 güvenilir tekrar                 │
│                                      │
│ 92 / 140                 48 kaldı    │
│ ███████████████░░░░░░░░              │
│                                      │
│ [ Düzenle ]              [ Duraklat ]│
└──────────────────────────────────────┘
```

Kurallar:

- Ekranın üstünde yalnızca bir aktif kişisel hedef bulunur.
- Hızlı düzenleme bottom sheet ile yapılır.
- Yeni hedef önerilerinde `averageScore` gösterilmez.
- İlerleme yoksa hata/uyarı kişisel hedef kartını yok etmez.

### 3.2 Madalya hedefleri

```text
Madalya hedefleri                 [Geçmiş]

[ Günlük ] [ Haftalık ] [ Aylık ]

┌──────────────────────────────────────┐
│ Şınav · Bugün                        │
│ 12 güvenilir tekrar                  │
│                                      │
│  ● Bronz 10   ○ Gümüş 20   ○ Altın 30│
│  ───────────────●──────────────      │
│                                      │
│ Gümüş için 8 tekrar                  │
└──────────────────────────────────────┘
```

Kurallar:

- Dönem seçici segmented control olur.
- Ana kartta tek egzersiz odaklanır; ilerleme otomatik çalışır.
- Egzersiz seçimi kart başlığından veya kompakt seçiciden yapılır.
- Bronz/gümüş/altın renkleri burada belirgin biçimde kullanılabilir.
- Altına ulaşıldığında bir sonraki sayı baskısı gösterilmez.

### 3.3 Yakın hedefler

```text
Sana yakın hedefler

Squat · Haftalık                    86 / 100
Plank · Günlük                  42 sn / 60 sn
Calf Raise · Aylık                 330 / 400
```

Kurallar:

- En fazla üç satır.
- Kart içinde kart kullanılmaz.
- Son 14 günde yapılan hareketler ve bir sonraki madalyaya yakınlık önceliklidir.
- Bütün egzersiz kataloğu ana ekrana dökülmez.

### 3.4 Tamamlanan ve duraklatılan

```text
Tamamlanan ve duraklatılan hedefler        ›
```

- Varsayılan kapalıdır.
- Kişisel hedef geçmişini içerir.
- Uzun reward geçmişi bu bölümde değil ayrı geçmiş ekranında bulunur.

## 4. Başarımlar ekranı bilgi mimarisi

### 4.1 Kazanılanlar önce

```text
Başarımlar

Kazanılanlar · 4

[rozet] Güvenilir Başlangıç     6 Ağu 2026
        İlk güvenilir analiz

[rozet] Hareket Kaşifi          9 Ağu 2026
        3 farklı egzersiz
```

- Son kazanılan ilk sırada.
- Kazanılan tarih görünür.
- Rozet renkli olabilir; kart yüzeyi nötr kalır.
- Boş durumda kilitli rozet ızgarası gösterilmez.

### 4.2 Sıradaki anlamlı başarım

```text
Sıradaki başarım

┌──────────────────────────────────────┐
│ [rozet] Hareket Kaşifi               │
│ 3 farklı egzersizde güvenilir analiz │
│                                      │
│ 2 / 3                                │
│ Bir egzersiz daha                    │
└──────────────────────────────────────┘
```

- Tek ana kart.
- Yüzde yardımcı olabilir ancak ana dil kalan eylemdir.
- Streak başarımı kullanıcı yaklaşmadıysa ana kart yapılmaz.

### 4.3 Keşfedilecek başarımlar

```text
Keşfedilecek başka başarımlar var          ›
```

- Kilitli rozet mezarlığı yoktur.
- Gizli başarımların adı ve koşulu önceden açıklanmayabilir.
- Kapalı bölüm açılırsa en fazla birkaç görünür başarım sade liste olarak gösterilir.

## 5. Ödül geçmişi

```text
Ödül geçmişi

[ Tümü ] [ Madalya ] [ Başarım ]

Ağustos 2026

6 Ağustos
[ALTIN] Şınav · Günlük Altın
        30 güvenilir tekrar

4 Ağustos
[ROZET] Güvenilir Başlangıç
        İlk güvenilir analiz
```

- Madalya ve başarımlar aynı kronolojik ledger'dan gelir.
- Filtreler yatay ve kompakt olur.
- Günlük, haftalık ve aylık alt filtreler yalnızca madalya filtresinde görünür.
- Ödül ayrıntısında kazanma koşulu ve ilgili dönem gösterilir.

## 6. Madalya kazanma anı

Kazanma sunumu kısa ve kontrollü olmalıdır:

- 560 ms'yi aşmayan tek seferlik ölçek ve ışık geçişi.
- Hafif haptic geri bildirim.
- Bronzdan gümüşe yükselme yeni madalya seviyesi olarak gösterilir.
- Aynı reward uygulama tekrar açıldığında yeniden kutlanmaz.
- Konfeti varsayılan değildir; yalnızca altın veya nadir başarım için çok sınırlı kullanılabilir.
- Reduced motion tercihinde statik başarı yüzeyi gösterilir.

## 7. Metin dili

### Kullanılacak

- `8 tekrar kaldı`
- `Bir egzersiz daha`
- `Bugünün altın madalyası kazanıldı`
- `Ritmine geri döndün`
- `Bu oturum ödül ilerlemesine katılmadı; ölçüm güvenilirliği sınırlıydı`

### Kullanılmayacak

- `Başarısız oldun`
- `Serini kaybettin`
- `Hedefini kaçırdın`
- `Skorunu yükselt`
- `Yetersiz performans`
- Sürekli kırmızı geri sayım veya ceza tonu

## 8. Erişilebilirlik ve kalite kapıları

- Madalya seviyesi yalnızca renkle anlatılmaz.
- Text scale `1.3` altında bile ana kartlarda taşma olmayacaktır; daha büyük ölçeklerde layout dikeyleşir.
- Dokunma hedefleri en az 48 dp olur.
- Reduced motion desteklenir.
- Ödül görsellerinin semantics etiketi seviye ve başlığı içerir.
- Boş, loading, offline ve partial-data durumları tasarımın parçasıdır.
- Golden testler küçük telefon, geniş telefon ve tablet genişliğinde alınır.
- Kart içinde kart ve gereksiz kapsül kullanımı sınırlandırılır.

## 9. Uygulama sırası

Bu belge onaylandıktan sonra ikinci tur yalnızca saf domain ve unit testlerden oluşur:

1. `ChallengePeriod`
2. `ChallengeMetric`
3. `MedalTier`
4. `ChallengeThresholds`
5. `ChallengeDefinition`
6. dönem anahtarı hesaplayıcısı
7. eşik ve seviye değerlendiricisi
8. 34 egzersizin katalog kapsam testleri

Bu turda Firestore ve UI henüz değiştirilmez.
