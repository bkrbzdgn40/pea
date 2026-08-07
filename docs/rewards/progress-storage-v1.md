# Challenge İlerleme Depolama Sözleşmesi V1

## Amaç

Bu sözleşme, güvenilir oturum katkılarının Firestore'da iki kez sayılmadan
saklanmasını ve günlük ilerlemenin bütün oturum geçmişi indirilmeden okunmasını
tanımlar.

## Koleksiyonlar

```text
users/{uid}/progressContributions/{sessionId}
users/{uid}/activityDays/{YYYY-MM-DD}
```

### progressContributions

Her güvenilir oturum için en fazla bir belge bulunur. Belge kimliği oturum
kimliğidir. Aynı payload tekrar işlendiğinde yazım `unchanged` sonucu verir ve
günlük toplam değişmez.

Saklanan temel alanlar:

- Oturum ve kullanıcı kimliği
- Challenge ve katalog sürümü
- Egzersiz, metrik ve güvenilirlik seviyesi
- Katkı değeri
- Oturum bitiş zamanı
- Oturum anındaki timezone offset
- Sabit yerel gün anahtarı
- Oluşturulma ve güncellenme zamanları

Oturum verisi düzeltilirse aynı contribution belgesi değiştirilir. Eski günlük
katkı transaction içinde çıkarılır, yeni katkı eklenir. Yerel gün değişmişse iki
`activityDays` belgesi aynı transaction içinde uzlaştırılır.

### activityDays

Bir yerel takvim günündeki güvenilir aktivitenin aggregate belgesidir.

Saklanan alanlar:

- Güvenilir oturum sayısı
- Yalnızca `high` kalitedeki oturum sayısı
- Egzersiz bazlı geçerli rep toplamları
- Hold egzersizleri için güvenilir saniye toplamları
- O gün katkı veren farklı egzersizler
- Oluşturulma ve güncellenme zamanları

Sıfır toplamlı günlük belgeler kalıcı tutulmaz. Son contribution silindiğinde gün
belgesi de transaction içinde silinir.

## İdempotency kuralları

1. Deterministik contribution kimliği `sessionId` değeridir.
2. Aynı payload ikinci kez günlük toplamı artırmaz.
3. Değişen payload eski değeri çıkarıp yenisini ekler.
4. Silme işlemi contribution yoksa no-op olur.
5. Aynı silme ikinci kez günlük toplamı azaltmaz.
6. Contribution ve günlük aggregate aynı Firestore transaction'ında değişir.
7. Günlük aggregate eksik veya tutarsızsa sessiz veri kaybı yerine işlem hata verir.

## Güvenlik

Firestore rules:

- Yalnızca belge sahibinin okuma ve yazmasına izin verir.
- Alan listesini ve kimlik eşleşmelerini doğrular.
- `limited`, `insufficient` veya bilinmeyen kanıt seviyelerini kabul etmez.
- Rep katkılarında pozitif tam sayı, hold katkılarında pozitif sayı ister.
- Rep ve hold egzersizlerinin yanlış metrikle yazılmasını reddeder.
- Günlük aggregate haritalarında yalnızca katalogdaki 34 egzersize izin verir.
- Negatif ve sıfır aggregate değerlerini reddeder.

Bu istemci tarafı V1 altyapısı yanlışlıkla duplicate üretmeyi ve biçimsiz veri
yazmayı engeller. Reward ledger aynı güven sınırını kullanır; ekonomik değeri
olan ödüllerde otorite Admin SDK veya Cloud Functions tarafına taşınmalıdır.

## Bu turda bağlanmayan alanlar

- Oturum kaydetme akışı henüz contribution yazımını çağırmaz.
- Oturum silme akışı henüz contribution kaldırmayı çağırmaz.
- Reward ledger kurulmuştur ancak oturum yaşam döngüsü henüz evaluator'ı çağırmaz.
- UI ve Riverpod provider bağlantıları henüz yoktur.

Bu bağlantılar bir sonraki entegrasyon turunda reconciliation ile birlikte
yapılacaktır.
