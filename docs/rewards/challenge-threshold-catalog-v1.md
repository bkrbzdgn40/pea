# Dönemsel Madalya Eşik Kataloğu V1

## 1. Amaç

PEA, desteklenen egzersizlerde güvenilir hacmi günlük, haftalık ve aylık dönemlerde
bronz, gümüş ve altın madalyalarla ödüllendirir. Madalya sistemi performans skoru
kovalatmaz; düzenli ve güvenilir hareket hacmini görünür kılar.

## 2. Değişmez değerlendirme kuralları

### 2.1 Uygun oturum

Bir oturum yalnızca aşağıdaki koşullarda challenge ilerlemesine katkı verir:

- `measurementQuality` değeri `high` veya `moderate` olmalıdır.
- Rep egzersizlerinde katkı değeri `validReps` olmalıdır.
- Hold egzersizlerinde katkı değeri `totalHoldSeconds` olmalıdır.
- `limited`, `insufficient` ve `unknown/legacy` kanıt kalitesindeki oturumlar katkı vermez.
- `lowConfidenceReps`, `invalidReps` ve yarım denemeler katkı vermez.
- Negatif, sıfır veya veri sözleşmesiyle çelişen değerler yok sayılır ve tanılama kaydı üretir.

Bu kural mevcut istatistik ekranlarındaki legacy uyumluluğundan bilinçli olarak daha
katıdır. Yeni ve kalıcı ödül, belirsiz geçmiş veriden üretilmez.

### 2.2 Dönem sınırları

- **Günlük:** kullanıcının oturum tamamlanırken geçerli yerel saatine göre 00.00–23.59.
- **Haftalık:** pazartesi 00.00–sonraki pazartesi 00.00.
- **Aylık:** takvim ayının ilk günü 00.00–sonraki ayın ilk günü 00.00.
- Oturumun dönemi `endedAt` anından türetilir.
- Ödül kaydı UTC kazanılma zamanını, yerel dönem anahtarını ve timezone offset'ini saklar.

### 2.3 Seviye yükseltme

Aynı egzersiz ve dönem için tek challenge kaydı vardır.

- Bronz eşiği geçilince bronz zamanı yazılır.
- Gümüş eşiği geçilince aynı kayıt gümüşe yükselir; bronz zamanı korunur.
- Altın eşiği geçilince aynı kayıt altına yükselir; önceki iki zaman korunur.
- Aynı eşik ikinci kez geçildiğinde duplicate ödül yazılmaz.
- Dönem sonlandıktan sonra kazanılan en yüksek madalya kalıcı ödül geçmişinde kalır.

### 2.4 Oturum silme

- Aktif dönem ilerlemesi, silinen oturum katkısı çıkarılarak yeniden hesaplanabilir.
- Daha önce kazanılmış bir madalya geri alınmaz.
- Aynı dönem içinde ilerleme tekrar eşiğe ulaşsa bile aynı deterministik ödül kaydı yeniden oluşturulmaz.

## 3. Eşik profilleri

Eşikler her egzersizde rastgele tekrar edilmez. Benzer yük ve hacim davranışları
profil altında toplanır. Uygulama kataloğunda egzersiz doğrudan profile bağlanır.

### 3.1 Rep profilleri

| Profil | Kullanım amacı | Günlük B/G/A | Haftalık B/G/A | Aylık B/G/A |
|---|---|---:|---:|---:|
| `R1_LOW_VOLUME` | Daha zor veya ekipman yüküne duyarlı hareketler | 5 / 10 / 20 | 25 / 50 / 100 | 80 / 160 / 320 |
| `R2_STANDARD` | Standart kuvvet ve kontrol hareketleri | 10 / 20 / 30 | 70 / 140 / 210 | 200 / 400 / 600 |
| `R3_MEDIUM_HIGH` | Orta-yüksek tekrar hacmine uygun hareketler | 15 / 30 / 50 | 100 / 200 / 350 | 300 / 600 / 1000 |
| `R4_HIGH_VOLUME` | Doğal olarak yüksek tekrarlı hareketler | 20 / 40 / 60 | 140 / 280 / 420 | 400 / 800 / 1200 |
| `R5_CARDIO_VOLUME` | Hızlı ve yüksek hacimli tam vücut hareketleri | 25 / 50 / 100 | 175 / 350 / 700 | 500 / 1000 / 2000 |

### 3.2 Hold profilleri

Bütün değerler saniyedir.

| Profil | Kullanım amacı | Günlük B/G/A | Haftalık B/G/A | Aylık B/G/A |
|---|---|---:|---:|---:|
| `H1_ADVANCED_SHORT` | İleri seviye kısa merkez bölge tutuşu | 15 / 30 / 45 | 90 / 180 / 300 | 300 / 600 / 900 |
| `H2_SIDE_HOLD` | Tek taraflı izometrik tutuş | 20 / 40 / 60 | 120 / 240 / 360 | 400 / 800 / 1200 |
| `H3_STANDARD_HOLD` | Standart izometrik dayanıklılık | 30 / 60 / 90 | 180 / 360 / 540 | 600 / 1200 / 1800 |
| `H4_ENDURANCE_HOLD` | Daha uzun sürdürülebilen destekli tutuş | 30 / 60 / 120 | 210 / 420 / 840 | 600 / 1200 / 2400 |

## 4. Egzersiz eşleştirme kataloğu

`exerciseType` değerleri mevcut `ExerciseType.id` sözleşmesiyle birebir aynıdır.
Ekrandaki başlıklar yerelleştirme katmanından alınır.

| exerciseType | Takip | Rehber seviyesi | Profil | Ürün gerekçesi |
|---|---|---|---|---|
| `squat` | rep | orta | `R3_MEDIUM_HIGH` | Temel alt vücut hareketi; kontrollü yüksek hacim desteklenebilir. |
| `plank` | saniye | başlangıç | `H3_STANDARD_HOLD` | Standart merkez bölge tutuşu. |
| `hollow_hold` | saniye | ileri | `H1_ADVANCED_SHORT` | Teknik olarak zor, kısa kaliteli tutuş daha anlamlı. |
| `lunge` | rep | orta | `R2_STANDARD` | Tek taraf odaklı alt vücut hareketinde standart hacim. |
| `push_up` | rep | ileri | `R2_STANDARD` | Ürün örneğiyle kilitli: günlük 10/20/30, haftalık 70/140/210. |
| `sit_up` | rep | başlangıç | `R2_STANDARD` | Kontrollü standart gövde fleksiyonu. |
| `crunch` | rep | başlangıç | `R3_MEDIUM_HIGH` | Daha kısa hareket açıklığı nedeniyle doğal tekrar hacmi daha yüksek. |
| `reverse_crunch` | rep | başlangıç | `R2_STANDARD` | Standart kontrollü core hacmi. |
| `biceps_curl` | rep | başlangıç | `R2_STANDARD` | Yük bilinmediği için eşik bilinçli olarak orta tutulur. |
| `lying_leg_raise` | rep | orta | `R2_STANDARD` | Core kontrolü nedeniyle yüksek hacim teşvik edilmez. |
| `bent_knee_leg_raise` | rep | başlangıç | `R2_STANDARD` | Lying leg raise'a göre erişilebilir, ancak core kontrolü korunur. |
| `standing_hamstring_curl` | rep | başlangıç | `R3_MEDIUM_HIGH` | İzole ve kontrollü yüksek hacme uygun. |
| `standing_hip_abduction` | rep | başlangıç | `R3_MEDIUM_HIGH` | İzole kalça hareketi; orta-yüksek hacme uygun. |
| `triceps_dip` | rep | orta | `R1_LOW_VOLUME` | Vücut ağırlığı ve omuz yükü nedeniyle düşük hacim profili. |
| `romanian_deadlift` | rep | orta | `R2_STANDARD` | Yük bilinmediği ve hinge tekniği önemli olduğu için standart profil. |
| `good_morning` | rep | orta | `R2_STANDARD` | Hinge tekniği nedeniyle yüksek hacim ödüllendirilmez. |
| `lateral_raise` | rep | başlangıç | `R2_STANDARD` | Ekipman yüküne duyarlı omuz hareketi. |
| `shoulder_press` | rep | orta | `R1_LOW_VOLUME` | Yük bilinmediği ve overhead yorgunluğu nedeniyle düşük hacim. |
| `overhead_triceps_extension` | rep | orta | `R2_STANDARD` | Ekipman yüküne duyarlı standart hacim. |
| `upright_row` | rep | orta | `R2_STANDARD` | Omuz tekniği nedeniyle standart hacim sınırı. |
| `calf_raise` | rep | başlangıç | `R4_HIGH_VOLUME` | Doğal olarak yüksek tekrarlı ayak bileği hareketi. |
| `front_raise` | rep | başlangıç | `R2_STANDARD` | Ekipman yüküne duyarlı omuz hareketi. |
| `glute_bridge` | rep | başlangıç | `R3_MEDIUM_HIGH` | Kontrollü yüksek hacme uygun kalça hareketi. |
| `wall_sit` | saniye | orta | `H4_ENDURANCE_HOLD` | Duvar destekli olduğundan plank'e göre daha uzun tutuş. |
| `side_plank` | saniye | orta | `H2_SIDE_HOLD` | Tek taraf yükü nedeniyle daha kısa tutuş profili. |
| `jumping_jack` | rep | başlangıç | `R5_CARDIO_VOLUME` | Tam vücut, ritmik ve yüksek hacimli hareket. |
| `standing_hip_extension` | rep | başlangıç | `R3_MEDIUM_HIGH` | İzole kalça hareketi; kontrollü yüksek hacim. |
| `standing_knee_raise` | rep | başlangıç | `R4_HIGH_VOLUME` | Ritmik ve yüksek hacimli kalça fleksiyonu. |
| `standing_straight_leg_raise` | rep | orta | `R2_STANDARD` | Düz diz kontrolü nedeniyle standart hacim. |
| `v_up` | rep | ileri | `R1_LOW_VOLUME` | İleri seviye core hareketi; düşük hacim daha anlamlı. |
| `frog_pump` | rep | başlangıç | `R4_HIGH_VOLUME` | Kısa açıklıklı, doğal olarak yüksek tekrarlı kalça hareketi. |
| `lying_triceps_extension` | rep | orta | `R1_LOW_VOLUME` | Ekipman yükü ve dirsek kontrolü nedeniyle düşük hacim. |
| `floor_chest_press` | rep | başlangıç | `R2_STANDARD` | Ekipman yükü bilinmediğinden standart hacim. |
| `y_raise` | rep | orta | `R2_STANDARD` | Omuz kontrolü nedeniyle standart hacim. |

## 5. Kullanıcıya gösterim kuralları

- İlerleme metni skor değil, güvenilir hacim dili kullanır.
- Örnek: `12 güvenilir tekrar` veya `48 güvenilir saniye`.
- Kullanıcıya aynı anda yalnızca seçili dönemin üç eşiği gösterilir.
- Ulaşılan seviyeler madalya görseli ve seviye adıyla belirtilir; yalnızca renge güvenilmez.
- Bir sonraki eşik için kalan değer gösterilir: `Gümüş için 8 tekrar`.
- Altın tamamlandıysa baskı üreten bir sonraki sayı gösterilmez: `Bugünün altın madalyası kazanıldı.`
- Dönem sonunda “başarısız” veya “kaçırdın” dili kullanılmaz.

## 6. Katalog sürümleme

- İlk runtime katalog sürümü `1` olacaktır.
- Her reward kaydı `catalogVersion` saklar.
- Bir eşik daha sonra değişirse eski ödül yeni eşikle tekrar değerlendirilmez.
- Yeni katalog sürümü yalnızca yeni dönemlere uygulanır.
- Bir egzersiz cihaz doğrulamasında güvenilir bulunmazsa challenge görünürlüğü katalogdan kapatılabilir; eski ödüller korunur.
