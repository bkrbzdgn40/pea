# Başarım Kataloğu ve Kazanma Kuralları V1

## 1. Ürün ilkeleri

- Başarımlar skor eşiği değil, güvenilir davranış ve ürün keşfi üzerinden kazanılır.
- Bir başarım yalnızca bir kez açılır ve kalıcı reward ledger'a yazılır.
- `limited`, `insufficient` veya legacy-belirsiz oturum hiçbir oturum tabanlı başarımı açmaz.
- Ekranda kazanılanlar önce gösterilir.
- Kilitli bütün rozetler listelenmez.
- Kullanıcıya aynı anda yalnızca bir anlamlı sonraki başarım önerilir.
- Seri bozulduğunda cezalandırıcı veya suçluluk üreten metin kullanılmaz.

## 2. Ortak terimler

### 2.1 Güvenilir oturum

Aşağıdakilerden biri bulunan `high` veya `moderate` kanıt kalitesindeki tamamlanmış oturum:

- Rep egzersizinde en az 1 `validRep`.
- Hold egzersizinde en az 5 güvenilir saniye.

### 2.2 Nitelikli gün

Yerel takvim gününde aşağıdakilerden en az biri:

- Toplam en az 5 güvenilir geçerli tekrar.
- Toplam en az 20 güvenilir hold saniyesi.
- En az bir planlı antrenman tamamlama olayı.

Bir günde kaç oturum yapılırsa yapılsın seri ilerlemesi en fazla bir gün artar.

### 2.3 Kontrollü tempo oturumu

- Oturum güvenilir olmalıdır.
- Egzersizin mevcut katalog sözleşmesinde tempo coaching açık olmalıdır.
- En az 5 `valid` ve `tempoMeasurementStatus == eligible` tekrar bulunmalıdır.
- Bu tekrarların en az `%80`'i `tempoQuality == target` olmalıdır.
- Payda yalnızca tempo ölçümü uygun geçerli tekrarları içerir.

V1 mevcut katalogda bu başarım için aday hareketler: `squat`, `push_up`,
`crunch`, `biceps_curl`, `glute_bridge`, `standing_hip_extension`.

## 3. İlk sürüm başarım kataloğu

| ID | Başlık | Görünürlük | Kesin koşul | İlerleme dili | Geriye dönük |
|---|---|---|---|---|---|
| `first_reliable_analysis` | Güvenilir Başlangıç | açık | 1 güvenilir oturum | `İlk güvenilir analizini tamamla` | evet |
| `reliable_sessions_5` | Sağlam Temel | açık | 5 güvenilir oturum | `X / 5 güvenilir oturum` | evet |
| `exercise_explorer_3` | Hareket Kaşifi | açık | 3 farklı `exerciseType` için güvenilir oturum | `Bir farklı egzersiz daha` | evet |
| `guide_completed` | Hazır Başla | açık | Nasıl Kullanılır ekranındaki 6 adımın tamamı en az bir kez açılmış olmalı | `X / 6 adım incelendi` | hayır |
| `controlled_tempo` | Kontrollü Ritim | açık | 1 kontrollü tempo oturumu | `En az 5 tekrarı kontrollü tempoyla tamamla` | hayır |
| `planned_workout_completed` | Plan Tamamlandı | açık | `totalSets > 0` ve `completedSets == totalSets`; ilgili oturum kayıtları başarıyla tamamlanmış olmalı | `İlk planlı antrenmanını tamamla` | hayır |
| `planned_workouts_5` | Planına Sadık | açık | 5 benzersiz plan tamamlama olayı | `X / 5 plan tamamlandı` | hayır |
| `balanced_explorer` | Dengeli Kaşif | açık | Alt vücut, üst vücut ve core bölgelerinin her birinde en az 1 güvenilir oturum | `Bir bölge daha keşfet` | evet |
| `return_after_14_days` | Geri Dönüş | gizli | İki güvenilir aktivite günü arasında en az 14 boş yerel gün sonrası yeni nitelikli gün | keşif ekranında ilerleme gösterilmez | hayır |
| `rhythm_30_days` | Otuz Günlük Ritim | gizli | 30 ardışık nitelikli yerel gün | 21. günden önce sıradaki başarım olarak önerilmez | hayır |
| `golden_week` | Altın Hafta | gizli | Aynı haftada 3 farklı egzersizde haftalık en az bronz madalya | keşif ekranında ilerleme gösterilmez | hayır |

## 4. Başarım ayrıntıları

### 4.1 Güvenilir Başlangıç

- Herhangi bir tamamlanmış oturum yeterli değildir.
- `limited`, `insufficient` ve legacy-belirsiz oturumlar açamaz.
- Geriye dönük taramada yalnızca açıkça `high` veya `moderate` kayıtlar kullanılır.

### 4.2 Sağlam Temel

- Aynı gün yapılan oturumlar ayrı güvenilir oturum olarak sayılabilir.
- Duplicate session ID ikinci kez sayılmaz.
- Bu başarım bir seri başarımı değildir; gün kaçırmak ilerlemeyi azaltmaz.

### 4.3 Hareket Kaşifi

- Aynı egzersizin farklı tarihlerde tekrarı çeşitlilik sayısını artırmaz.
- Egzersiz yalnızca güvenilir oturumla keşfedilmiş sayılır.
- Hold ve rep hareketleri aynı katalogda eşit biçimde farklı egzersiz sayılır.

### 4.4 Hazır Başla

- Ekranı yalnızca açmak yeterli değildir.
- Altı adımın her biri en az bir kez genişletilmelidir.
- Adımların açılma sırası önemli değildir.
- Tamamlanma cihazda geçici state yerine kullanıcı ilerleme olayına yazılır.

### 4.5 Kontrollü Ritim

- Ortalama skor koşulu kullanılmaz.
- Tempo ölçümü olmayan veya coaching kapalı egzersizler bu başarımı açamaz.
- Tempo sonucu eksik tekrarlar paydaya katılmaz; en az 5 uygun tekrar şartı korunur.
- Güçlü tempo ihlali içeren tekrar `target` sayılmadığı için oranı doğal olarak düşürür.

### 4.6 Plan Tamamlandı ve Planına Sadık

- Özet ekranına ulaşmak tek başına event değildir.
- Plan motoru tamamlandı durumuna geçtiğinde ve son egzersiz oturumu kalıcı olarak kaydedildiğinde completion event üretilir.
- Aynı plan yürütme kimliği iki kez sayılamaz.
- Planın adı veya şablon kimliği başarı koşulunu etkilemez.

### 4.7 Dengeli Kaşif

Gerekli bölgeler:

- `lowerBody`
- `upperBody`
- `core`

`fullBody` tek başına eksik bölgelerden birinin yerine geçmez; ayrı bir bonus bağlamdır.

### 4.8 Geri Dönüş

- Aradaki günlerde nitelikli gün olmamalıdır.
- Kullanıcıya “serini kaybettin” denmez.
- Başarım metni geri dönmeyi olumlu biçimde kutlar.

### 4.9 Otuz Günlük Ritim

- Tarih farkı UTC değil yerel dönem anahtarı üzerinden hesaplanır.
- Bir günde yalnızca bir seri adımı oluşur.
- Timezone değişikliği eski gün anahtarlarını yeniden yazmaz.
- Kullanıcı 21 güne ulaşmadan ana “sıradaki başarım” kartında baskı unsuru olarak gösterilmez.

### 4.10 Altın Hafta

- Üç madalya aynı egzersizden gelemez.
- Günlük veya aylık madalya sayılmaz; yalnızca haftalık madalya kullanılır.
- Bronz, gümüş veya altın seviyelerinin tamamı koşulu karşılar.

## 5. Emekliye ayrılan mevcut başarımlar

Mevcut presentation-only başarımlar kalıcı reward olmadığı için migration gerektirmeden
katalogdan çıkarılır:

- `score_90_plus`: skor avcılığı ürettiği için kaldırılır.
- `hundred_reps`: dönem ve güvenilirlik bağlamı olmayan ham toplam olduğu için kaldırılır.
- `ten_sessions`: güvenilirlik ayrımı yapmadığı için `reliable_sessions_5` ile değiştirilir.
- `first_analysis`: `first_reliable_analysis` ile değiştirilir.

Kullanıcı daha önce bu UI kartlarını açık görmüş olsa bile kalıcı bir ödül kaydı bulunmadığından
sahte bir kazanılma tarihi üretilmez.

## 6. Sıradaki anlamlı başarım seçimi

Sistem yalnızca bir başarım önerir. Seçim sırası:

1. Açık görünürlükte ve henüz kazanılmamış olmalı.
2. İlerlemesi güvenilir veriyle hesaplanabilir olmalı.
3. Kalan eylem kullanıcı diline çevrilebilmeli.
4. Öncelik sırası: onboarding → keşif → plan → tempo → genel tutarlılık.
5. Seri başarımları kullanıcı anlamlı biçimde yaklaşmadıkça önerilmez.
6. Aynı kart anlamsız biçimde uzun süre sabit kalırsa ikinci uygun aday seçilebilir.

Örnek metinler:

- `Bir farklı egzersiz daha`
- `İki güvenilir oturum daha`
- `Rehberde iki adım kaldı`

Yüzde tek başına ana metin olarak kullanılmaz.

## 7. Reward kimliği

Başarım reward kimliği deterministiktir:

```text
achievement:first_reliable_analysis
achievement:controlled_tempo
```

Her kayıt en az şu alanları saklar:

- `achievementId`
- `unlockedAtUtc`
- `qualifyingEventId`
- `definitionVersion`
- geriye dönük açıldıysa `isBackfilled`
