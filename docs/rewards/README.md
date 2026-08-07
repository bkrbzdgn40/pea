# PEA Ödül, Madalya ve Başarım Sistemi V1

Bu klasör, hedef ekranı refactor'ından önce kilitlenen ürün sözleşmelerini içerir.
Saf challenge domain'i ve Firestore ilerleme altyapısı uygulanmıştır; henüz oturum
yaşam döngüsüne, Riverpod'a veya kullanıcı arayüzüne bağlanmamıştır. Mevcut
`UserWorkoutGoal` domain modeli değişmeden kalır.

## Belgeler

- [`challenge-threshold-catalog-v1.md`](challenge-threshold-catalog-v1.md)
  - Günlük, haftalık ve aylık madalya eşikleri
  - Güvenilir ilerleme kuralları
  - Egzersizlerin hacim profilleri
- [`achievement-catalog-v1.md`](achievement-catalog-v1.md)
  - İlk sürüm başarım kataloğu
  - Kesin kazanma koşulları
  - Geriye dönük açılma politikası
- [`progress-storage-v1.md`](progress-storage-v1.md)
  - Idempotent contribution ve günlük aggregate Firestore sözleşmesi
  - Transaction, düzeltme ve silme davranışı
- [`reward-ledger-v1.md`](reward-ledger-v1.md)
  - Madalya kazanma, seviye yükseltme ve duplicate önleme
  - Ödül geçmişi sorguları ve geriye dönük migration politikası
- [`ui-direction-v1.md`](ui-direction-v1.md)
  - Hedefler, başarımlar ve ödül geçmişi ekranlarının hiyerarşisi
  - Renk, madalya ve rozet görsel dili
  - Baskı üretmeyen metin kuralları

## Uygulama durumu

- **Tamamlandı:** V1 eşik kataloğu, dönem hesapları, madalya seviye değerlendirmesi,
  güvenilir oturum katkısı, idempotent `progressContributions`, günlük
  `activityDays` aggregate altyapısı, dönemsel madalya reward ledger'ı, geçmiş
  sorguları ve güvenlik kuralları.
- **Sonraki tur:** oturum yaşam döngüsü entegrasyonu ve reconciliation.
- **Henüz yok:** otomatik oturum bağlantısı, achievement reward'ları, provider ve
  ekran bağlantıları.

## Kilitlenen ana kararlar

1. Mevcut `UserWorkoutGoal` kişisel hedef domain'i değişmez.
2. Dönemsel madalyalar ayrı bir challenge domain'inde değerlendirilir.
3. Challenge ilerlemesi kullanıcı tarafından etkinleştirilmeyi beklemeden otomatik çalışır.
4. Bir oturum günlük, haftalık ve aylık döneme aynı anda katkı sağlayabilir.
5. Rep challenge'larında yalnızca `validReps`, hold challenge'larında yalnızca güvenilir `totalHoldSeconds` kullanılır.
6. `limited`, `insufficient` ve legacy-belirsiz oturumlar yeni ödül üretmez.
7. Aynı dönemde bronzdan altına yükselme tek ödül kaydında tutulur.
8. Dönem bittiğinde ilerleme sıfırlanır; kazanılan ödül silinmez.
9. Skor eşiğine bağlı yeni hedef veya başarım oluşturulmaz.
10. Kilitli rozet duvarı gösterilmez; kazanılanlar ve tek bir anlamlı sonraki adım öne çıkarılır.

## Yayın yaklaşımı

Katalog değerleri kullanıcıya antrenman reçetesi sunmaz. Bunlar uygulama içi hacim
ödülleri için muhafazakâr V1 ürün eşikleridir. Gerçek kullanım telemetrisi ve cihaz
doğrulama bulguları geldikçe katalog sürümlenerek güncellenir; geçmiş ödüllerin
koşulları sonradan geriye dönük değiştirilmez.
