# Reward Ledger Sözleşmesi V1

## Amaç

Bu sözleşme, dönemsel madalyaların tek bir kalıcı kayıtta kazanılmasını,
bronzdaki bir ödülün gümüş ve altına güvenli biçimde yükselmesini ve aynı ödülün
ağ veya reconciliation tekrarlarında çoğalmamasını tanımlar.

## Koleksiyon

```text
users/{uid}/rewards/{rewardId}
```

V1'de ledger yalnızca `challengeMedal` kayıtlarını yazar. Domain'deki ortak
`UserReward` sözleşmesi ve generic geçmiş sayfası, başarım kayıtları eklenirken
aynı koleksiyonun yeni bir `kind` ayrımıyla genişletilmesini sağlar; mevcut
madalya belgelerinin şekli değiştirilmez.

## Deterministik kimlik

Bir egzersiz ve dönem için yalnızca tek madalya belgesi bulunur:

```text
medal:{challengeId}:{period}:{periodKey}
```

Örnek:

```text
medal:push_up_volume:daily:2026-08-07
medal:push_up_volume:weekly:2026-08-10
medal:plank_volume:monthly:2026-09
```

Belge kimliği madalya seviyesini içermez. Bronz, gümüş ve altın aynı belgeyi
kullanır. Böylece seviye yükseltme ödül geçmişinde üç kopya üretmez.

## Saklanan alanlar

Her madalya kaydı en az şunları saklar:

- Schema ve challenge katalog sürümü
- Egzersiz, metrik, dönem ve sabit dönem anahtarı
- Oturum anındaki timezone offset
- Ulaşılan en yüksek seviye
- En yüksek seviye kazanılırken görülen ilerleme değeri
- Ödül anındaki bronz, gümüş ve altın eşiklerinin immutable snapshot'ı
- Bronz, gümüş ve altın için ayrı kazanılma zamanları
- İlk ve en yüksek seviye kazanılma zamanı
- Ortak geçmiş sıralaması için `historyAt` zamanı
- Son seviyeyi açan event/session kimliği
- Oluşturulma ve güncellenme zamanları
- `isBackfilled` işareti

V1 istemci yazımlarında `isBackfilled` daima `false` olmak zorundadır.

## Kazanma ve seviye yükseltme

1. İlerleme bronz eşiğin altındaysa ledger yazımı yapılmaz.
2. İlk kez bronz veya daha yüksek seviyeye ulaşılırsa belge oluşturulur.
3. Kullanıcı bir oturumda doğrudan altına ulaşırsa üç seviye de aynı kazanılma
   zamanıyla belgeye yazılır.
4. Mevcut seviyeden daha yüksek bir seviye gelirse belge transaction içinde
   güncellenir.
5. Daha önce yazılmış tier zamanları değiştirilemez.
6. Aynı veya daha düşük seviye tekrar değerlendirilirse sonuç `unchanged` olur;
   Firestore yazımı yapılmaz.
7. Kazanılmış ödül düşürülmez veya istemci tarafından silinmez.
8. Challenge katalog sürümü dönem ortasında değiştirilmez. Farklı katalog
   sürümüyle aynı reward kimliğine yazım veri tutarsızlığı sayılır.
9. Eşik snapshot'ı seviye yükseltmelerinde değişmez; geçmiş ekranı gelecekteki
   katalog sürümlerine bağımlı kalmadan ödülün özgün koşulunu gösterebilir.

## İdempotency

Duplicate önleme iki katmandadır:

- Deterministik belge kimliği aynı dönem için ikinci belgeyi engeller.
- Repository transaction'ı mevcut ödülü okuyup yalnızca daha yüksek seviyede
  yazar.

Aynı event tekrar işlendiğinde, farklı bir event aynı seviyeyi yeniden
ürettiğinde veya aktif dönem ilerlemesi sonradan azaldığında yeni ödül oluşmaz.

## Ödül geçmişi sorguları

Geçmiş ortak `historyAt` alanına göre okunur. Madalyalarda bu alan en yüksek
seviyenin kazanılma zamanına eşittir; böylece seviye yükseltmesi kronolojide güncel
ödül olayı olarak görünür. Aynı zamanda oluşan
ödüller immutable reward kimliğiyle deterministik sıralanır.

Desteklenen sorgular:

- Bütün dönemsel madalyalar
- Yalnızca günlük madalyalar
- Yalnızca haftalık madalyalar
- Yalnızca aylık madalyalar
- Cursor tabanlı sayfalama, sayfa başına en fazla 50 kayıt

Gerekli iki birleşik `rewards` indeksi `firestore.indexes.json` içinde tanımlıdır.

## Geriye dönük migration politikası

Dönemsel madalyalar geçmiş oturumlara topluca dağıtılmaz.

Her yayın için üç açık sınır anahtarı tanımlanır:

- İlk ödüllendirilebilir günlük tarih
- İlk ödüllendirilebilir haftanın pazartesi tarihi
- İlk ödüllendirilebilir ay

`live` ve `reconciliation` işlemleri yalnızca bu anahtarlardan başlayan dönemleri
onarabilir. `historicalBackfill` kaynağı madalyalar için her koşulda reddedilir.
Bu yaklaşım, V1 öncesi eksik veya legacy güvenilirlik verilerinden sahte ödül
tarihleri üretmemeyi sağlar.

Bazı başarımlar ileride geriye dönük açılabilir. O migration istemci kurallarıyla
değil, açık allowlist kullanan ayrı ve ayrıcalıklı bir işlemle yürütülür.

## Güvenlik sınırı

Firestore rules belge şeklini, sahipliği, deterministik kimliği ve yalnızca yukarı
seviye güncellemeyi doğrular. Kazanılmış kayıtların client tarafından silinmesine
izin vermez.

Bu V1 istemci mimarisi duplicate ve biçimsiz kayıtları engeller; hileye dayanıklı
sunucu otoritesi değildir. Ürün ekonomik değere sahip ödüller sunarsa reward
üretimi Admin SDK veya Cloud Functions tarafına taşınmalıdır.

## Bu turda bağlanmayan alanlar

- Oturum kaydetme akışı henüz madalya evaluator'ını çağırmaz.
- Uygulama açılış reconciliation işi henüz yoktur.
- Hedef ve başarım ekranları ledger'ı henüz okumaz.
- Achievement reward türü henüz yazılmaz.
