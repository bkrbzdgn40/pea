# PEA Beta Measurement Contract

## 1. Belge Kimliği

| Alan | Değer |
| --- | --- |
| Tarih | 12 Temmuz 2026 (`Europe/Istanbul`) |
| Branch | `codex/beta-03-measurement-contract` |
| Kaynak commit SHA | `45b883bcd2302c68aea65f2b2b3bb7613bfcc88d` |
| Sözleşme sürümü | `1.0.0` |
| Desteklenen egzersizler | Squat, Plank, Push-up |
| Hedef beta platformu | Android internal beta |

iOS, bu ölçüm sözleşmesinin ilk sürümünde kapsam dışı ve ayrıca doğrulanması gereken platformdur. Bu bir ürün kapsamı kararıdır; teknik imkânsızlık veya desteklenmiyor iddiası değildir.

Güncel kaynak ve CI kanıtı baseline/freeze kontratının varlığını, üç desteklenen egzersizi ve Firestore/Auth güvenlik kapısının main üzerinde çalıştığını doğrular. Controller integration testi, telemetry, tekrarlanabilir beta build ve gerçek cihaz baseline'ı henüz tamamlanmamıştır.

## 2. Ölçümün Cevaplayacağı Kararlar

Ölçüm şu kararları destekler:

- Kamera formatı, orientation, rotation ve mirror yolu güvenilir mi?
- Squat ve Push-up tekrar sayımı yeterince doğru mu?
- Plank hold süresi yeterince doğru mu?
- Hareketsizlik veya ilgisiz hareket yanlış tekrar üretiyor mu?
- Kadraj veya pose kaybı phantom rep ya da şişmiş hold süresi oluşturuyor mu?
- Pause/resume engine veya session state'ini bozuyor mu?
- Side selection gerçek görüntü gürültüsü altında kararlı mı?
- Düşük ışıkta güvenilirlik kabul edilebilir mi?
- Low, Mid ve High cihaz sınıflarında performans yeterli mi?
- Ekrandaki sonuçlarla Firestore'a kaydedilen sonuçlar tutarlı mı?
- Likelihood, pose selection veya threshold değişikliğine gerçekten ihtiyaç var mı?

> Her kötü sonuç threshold problemi olarak yorumlanmayacaktır.

Kök neden önce şu sınıflardan biriyle etiketlenir: kamera formatı; rotation veya mirror; preview/overlay hizası; landmark kalitesi; pose seçimi; side selection; visibility/resync; engine state; lifecycle; performans; session assembly; persistence; kullanıcı kadraj yönlendirmesi; threshold veya config.

## 3. Kapsam Dışı Doğrulamalar

Tıbbi doğruluk, rehabilitasyon veya klinik kullanım, yaralanma riski, form skorunun uzman biyomekanik doğruluğu, kalori hesabı, sağlık durumu, yeni egzersiz, iOS release, store yayını ve release onayı bu sözleşmenin kapsamı dışındadır. Form skorları kaydedilebilir; ancak uzman etiketli bağımsız bir rubric olmadan beta kabul metriği değildir.

## 4. Ground Truth Tanımı

### Squat ve Push-up

Bir ground-truth tekrar; scripted başlangıç pozisyonu, aktif faz, görsel olarak tamamlanan hedef derinlik ve başlangıç pozisyonuna kontrollü dönüşten oluşan tek tamamlanmış hareket döngüsüdür. Her hareket `FULL_REP`, `PARTIAL_REP`, `ABORTED_REP`, `IRRELEVANT_MOTION` veya `AMBIGUOUS_REP` olarak etiketlenir. Belirsiz tekrar başarıya ya da başarısızlığa zorlanmaz; run gerekirse `INVALID` olur.

### Plank

Annotation geçerli hold başlangıç/bitişini, bilinçli form break başlangıcını, geçerli forma dönüşü ve kadraj/pose kaybını ayrı zamanlar olarak kaydeder. Ground truth uygulamanın mevcut açı threshold'larıyla tanımlanmaz; aksi halde algoritma kendi ölçütüyle doğrulanmış olur.

### Kanıt yöntemi

Tercih sırası:

1. Açık consent ile ikinci cihazdan dış video.
2. İki gözlemcili canlı annotation.
3. Tek gözlemcinin iki ayrı geçişte annotation'ı.

Dış video uygulamanın kamera akışından kaydedilmez; audio varsayılan olarak kapalıdır; yüz mümkünse kadraj dışıdır; repo, Firebase, GitHub veya paylaşılan Drive'a yüklenmez. CSV yalnız `evidence_id` taşır.

Event timestamp varsa app rep başlangıcı ground truth ile `±1.0 saniye` toleransında eşleştirilir. Timestamp yoksa yalnız count error hesaplanır; matched rep, false positive, false negative, precision ve recall güvenilir biçimde ayrıştırılamaz ve ilgili alanlar boş bırakılıp sonuç `NOT_MEASURABLE` olabilir.

## 5. Test Aşamaları

### E0: Engineering Baseline

Amaç protokolü doğrulamak; crash, lifecycle, camera ve persistence sorunlarını bulmak; telemetry ihtiyacını kesinleştirmektir. Minimum bir yetişkin internal tester, üç Android cihaz sınıfı, üç desteklenen egzersiz ve her temel senaryodan en az bir run gerekir. E0 beta başarısı iddiası değildir.

### E1: Closed Beta Readiness

En az üç yetişkin tester ve Low/Mid/High sınıflarını kapsayan en az üç Android cihaz gerekir. Farklı boy/kadraj oranları, kıyafet kontrastı ve arka planlar kapsanır; her pozitif senaryo en az üç kez koşulur. Demografik, sağlık veya biyometrik profil toplanmaz; tester yalnız pseudonymous ID ile tanımlanır.

## 6. Zorunlu Cihaz Matrisi

| Sınıf | Tanım |
| --- | --- |
| Low | Düşük CPU/GPU, sınırlı bellek veya eski Android |
| Mid | Güncel orta segment |
| High | Güncel üst segment |

Her cihaz için pseudonymous device ID, üretici/model, Android sürümü, mevcutsa CPU/SoC, RAM sınıfı, kamera lens yönü, uygulama commit SHA, app version/build, build type ve test tarihi kaydedilir. Commit SHA ve build kimliği bulunmayan sonuç `INVALID` olur.

## 7. Zorunlu Senaryo Matrisi

| ID | Senaryo | Zorunlu uygulama |
| --- | --- | --- |
| `POS-CONTROLLED` | Kontrollü geçerli hareket | Range-rep: 20 tekrar × 3 set; plank: 30 sn × 3 set |
| `STATIC-NEGATIVE` | Hareketsiz bekleme | Rep ve hold başlamamalı |
| `PARTIAL-MOTION` | Yarım/tamamlanmamış hareket | Tam rep sayılmamalı |
| `OCCLUSION` | Kısa pose kaybı | Yaklaşık 1 sn, en az 3 kayıp |
| `LONG-OCCLUSION` | Uzun pose kaybı | En az 3 sn, en az 3 kayıp |
| `LIFECYCLE` | Pause/resume ve ekran dönüşü | Aktif rep, aktif plank, neutral; en az 3 döngü |
| `MULTI-PERSON` | Kadrajda ikinci kişi | Pose seçimi ve phantom sonuç gözlenir |
| `LOW-LIGHT` | Düşük ışık | Doğruluk ve recovery ayrı raporlanır |
| `ANGLE-30-45` | 30–45° kamera açısı | Açı kaydedilir |
| `SIDE-VIEW` | Yan kamera açısı | Mirror/orientation dahil kaydedilir |
| `CROP` | Vücudun kısmı kadraj dışında | Eksik bölge kaydedilir |
| `LONG-SESSION` | En az 15 dakika | Crash/freeze/save/performance |
| `PERSISTENCE` | Session/rep tutarlılığı | Display, rep docs ve session total karşılaştırılır |

Squat ve Push-up kontrollü setleri 20 ground-truth tekrar, kontrollü tempo ve setler arasında engine/session reset içerir. Plank ayrıca 30 saniye geçersiz posture negatif senaryosu içerir. Occlusion aktif rep/hold sırasında da uygulanır.

## 8. Ölçüm Metrikleri

Sınıflar: `TODAY` mevcut UI/persistence ile doğrudan; `MANUAL` insan annotation'ıyla; `TELEMETRY` yeni accumulator/export ile; `TEST-SEAM` deterministic controller/integration seam'iyle; `BUILD` tekrarlanabilir beta artifact'iyle ölçülür.

| Grup | Metrik | Sınıf | Not / neden |
| --- | --- | --- | --- |
| Doğruluk | Ground truth reps/hold, full/partial/aborted/irrelevant | MANUAL | Bağımsız annotation gerekir |
| Doğruluk | App reps, app hold, displayed reps | TODAY | Ekrandan değişmeden kaydedilir |
| Doğruluk | Signed/absolute count error, hold absolute error | TODAY + MANUAL | App sonucu ve ground truth ile hesaplanır |
| Doğruluk | Matched reps, FP, FN, precision, recall | TELEMETRY + MANUAL | Güvenilir app event timestamp/export gerekir |
| Doğruluk | False hold start, form-break stop latency | TELEMETRY + MANUAL | Engine event timestamp'i gerekir |
| Güvenilirlik | Phantom rep, partial auto-completion, lifecycle phantom | MANUAL | Senaryo gözlemi; deterministic regresyon için TEST-SEAM |
| Güvenilirlik | Pose kaybında hold ilerlemesi, recovery seconds | MANUAL | Event zamanı için TELEMETRY önerilir |
| Güvenilirlik | Camera recovery, crash, freeze/ANR, session save | TODAY + MANUAL | Test run kaydıyla gözlenebilir |
| Persistence | Displayed/persisted/session total reps | TODAY | UI ve Firestore sayımları manuel karşılaştırılır |
| Kamera | Camera/analysis FPS anlık değer | TODAY | UI anlık değer verir; dağılım vermez |
| Kamera | Frame sayıları, FPS p50/p95 | TELEMETRY | Run boyunca örnek accumulator gerekir |
| Kamera | Processing p50/p95/max | TELEMETRY | Per-frame başlangıç/bitiş zamanı gerekir |
| Kamera | No-pose/invalid-frame oranları | TELEMETRY | Toplam ve sınıflandırılmış frame sayaçları gerekir |
| Kamera | Converter drop count | TELEMETRY | Converter `null` nedenleri bugün export edilmez |
| Kamera | Pose count dağılımı | TELEMETRY | Controller yalnız ilk pose'u işler; dağılım saklanmaz |
| Kamera | Landmark likelihood özeti | TELEMETRY | Likelihood bugün policy'de kullanılmaz veya saklanmaz |
| Analiz | Selected side anlık/rep özeti | TODAY | Debug/session rep yüzeyinde kısmen görünür |
| Analiz | Side switch/active-rep switch count | TELEMETRY | Session report kısmi sonuç verir; run sayacı/export gerekir |
| Analiz | Resync count | TELEMETRY | Anlık diagnostics var, kalıcı sayaç yok |
| Analiz | Calibration offset | TODAY | Debug yüzeyinde anlık; güvenilir dataset için diagnostic export gerekir |
| Analiz | Analysis exception count | TELEMETRY | Bugün yalnız debug print; sayaç/export gerekir |
| Kontrol | Frame→controller→engine/lifecycle davranışı | TEST-SEAM | Mevcut controller testleri helper-only |
| Build | Commit/build kimliği ve tekrarlanabilir artifact | BUILD | Cihazlar arası karşılaştırmanın ön koşulu |

## 9. Formüller

```text
signed_count_error = app_reps - ground_truth_reps
absolute_count_error = abs(signed_count_error)

precision = matched_reps / (matched_reps + false_positive_reps)
recall = matched_reps / (matched_reps + false_negative_reps)

hold_absolute_error_seconds =
  abs(app_hold_seconds - ground_truth_hold_seconds)

persistence_consistent =
  displayed_reps == persisted_rep_documents == session_total_reps
```

Precision paydası sıfırsa ve ground-truth pozitif yoksa precision boş bırakılır; sonuç senaryonun negatif beklentisiyle değerlendirilir. Recall paydası sıfırsa recall boş bırakılır. Hiçbir durumda `NaN` veya sonsuzluk yazılmaz. Eksik girdili türetilmiş metrik boş bırakılır.

Sonuçlar exercise, device class, device model, scenario, camera angle, lighting ve build SHA kırılımlarında ayrı raporlanır. Yalnız global aggregate sunmak yasaktır.

## 10. Provisional Beta Kabul Kriterleri

Bu kriterler **v1 provisional engineering gates**'tir; veri görülmeden nihai bilimsel doğruluk iddiası değildir. Kötü baseline görüldükten sonra sessizce gevşetilemez; değişiklik sürümlü sözleşme ve gerekçeli review gerektirir.

### Sert kırmızı çizgiler

Crash, ANR/geri dönmeyen kamera donması, session save kaybı, displayed/persisted/session rep uyuşmazlığı, static false rep, occlusion/lifecycle phantom rep, kamera görünmezken plank süresinin ilerlemesi, başka kullanıcının Firestore verisine erişim veya izinsiz ham video/landmark persistence build'i reddeder.

### Squat ve Push-up

Her kontrollü 20 tekrar setinde `absolute_count_error <= 1`. E1'de her egzersiz ve her cihaz sınıfı ayrı olmak üzere `precision >= 0.95` ve `recall >= 0.95`. Global ortalama kötü cihazı gizleyemez.

### Plank

30 saniye geçerli hold için `hold_absolute_error_seconds <= 2.0`. Geçersiz posture false hold başlatamaz. Bilinçli form break sonrası hold en fazla `1.5 saniye` içinde durur.

### Recovery

Kısa occlusion sonrası `recovery_seconds <= 2.5`; phantom rep, yarım rep auto-completion veya gizli sürede hold ilerlemesi olamaz.

### Performans

Telemetry gerektiren provisional hedefler: `analysis_fps_p50 >= 6` ve `frame_processing_ms_p95 <= 250`. On beş dakikalık session crash, kalıcı kamera durması veya sürekli 5 saniyeden uzun analiz durması içeremez ve save başarılı olmalıdır.

Her scenario sonucu yalnız `PASS`, `FAIL`, `INVALID` veya `NOT_MEASURABLE` olur. `NOT_MEASURABLE`, `PASS` sayılmaz.

## 11. Geçersiz Test Koşulları

Commit SHA veya build type bilinmiyorsa; ground truth belirsiz/evidence kayıpsa; tester protokol dışına çıktıysa; açı/mesafe kaydedilmediyse; app başka commit'teyse; run sırasında config/threshold değiştiyse; sonuç elle düzeltildiyse veya aynı session çakışan satırlarda yer alıyorsa run `INVALID` olur. Geçersiz run silinmez; `invalid_reason` ile saklanır.

## 12. Privacy, Consent ve Retention

Bu bölüm hukuki uygunluk iddiası değil, beta mühendislik veri minimizasyon kontratıdır.

- Yalnız yetişkin, açık rıza veren tester; pseudonymous tester/device ID.
- İsim, e-posta, sağlık bilgisi, biyometrik profil veya kesin konum yoktur.
- Audio varsayılan olarak yoktur; yüz mümkünse kadraj dışıdır.
- Ham video repo, GitHub, Firebase veya paylaşılan Drive'a yüklenmez; yalnız yerel ve erişim kontrollü tutulur.
- Video annotation tamamlandıktan sonra en geç 14 gün içinde silinir. Consent geri çekilirse ilgili evidence daha erken silinir.
- CSV video yolu taşımaz; yalnız `evidence_id` ve `evidence_delete_after` taşır.
- Ham landmark x/y/z koordinatları saklanmaz.
- Pseudonymous run CSV'leri ve aggregate raporlar en fazla 90 gün tutulur; süre sonunda maintainer yeniden onayı yoksa silinir veya geri döndürülemez aggregate'a indirgenir.
- Gerçek cihaz ölçümü başlamadan maintainer privacy onayı gerekir.

## 13. Test Uygulama Prosedürü

1. Cihaz ve uygulama kimliğini kaydet.
2. Önceki session state'ini temizle veya yeni session başlat.
3. Kamera lensi ve orientation'ı kaydet.
4. Mesafe ve açıyı kaydet.
5. Işık sınıfını kaydet.
6. Ground truth evidence başlat.
7. Scripted senaryoyu uygula.
8. App sonucunu değiştirmeden kaydet.
9. Session persistence sonucunu doğrula.
10. Evidence annotation yap.
11. Metrikleri hesapla.
12. Sonuç enum'unu ata.
13. Evidence retention tarihini kaydet.

Uygulama sonucu “makul görünüyor” gerekçesiyle elle düzeltilemez.

## 14. Değerlendirme ve Değişiklik Kapısı

Threshold, likelihood, side selection, resync veya pose policy değişikliği ancak başarısız scenario ID'leri, egzersiz ve cihaz sınıfı, FP/FN yönü, önceki/önerilen davranış, hedef metrik, beklenen yan etki, feature flag/rollback, aynı dataset üzerinde before/after replay ve gerçek cihaz regression sonucu ile önerilebilir. “Daha iyi hissettiriyor” kanıt değildir.

## 15. Ölçülebilirlik ve Bağımlılık Matrisi

| Metrik / kabiliyet | Bugün ölçülebilir mi? | Gerekli sonraki altyapı | Önerilen görev |
| --- | --- | --- | --- |
| App rep/hold ve anlık FPS | Evet, UI üzerinden | Standard run capture | Device protocol runner |
| Ground truth ve count/hold error | Evet, manuel | Annotation rubric | E0 runner |
| Persistence count consistency | Kısmen, manuel | Persistence consistency verifier | Controller sonrası verifier |
| Phantom rep/hold ve lifecycle | Kısmen, cihazda manuel | Controller test seam'i | GÖREV 04 |
| Deterministic engine/controller regresyonu | Hayır | Controller integration tests | Seam sonrası integration |
| Frame/FPS/latency dağılımları | Hayır | Telemetry accumulator | Controller seam sonrası telemetry |
| No-pose/invalid/converter/pose dağılımı | Hayır | Telemetry accumulator | Observability görevi |
| Likelihood shadow değerlendirmesi | Hayır | Shadow likelihood policy + telemetry | Veri kapısından sonra |
| Side/resync/calibration/exception run özeti | Hayır | Diagnostic export | Telemetry sonrası export |
| Cihazlar arası karşılaştırılabilir build | Hayır | Reproducible beta build | Ölçüm öncesi build görevi |
| E0/E1 veri toplama | Hayır | Real-device runner | G2–G5 sonrası |

Bağımlılık sırası: controller test seam'i → controller integration tests → telemetry accumulator → diagnostic export → reproducible beta build → persistence verifier/real-device runner → dataset değerlendirmesi. Shadow likelihood policy ancak ölçüm verisi ve ayrı runtime değişiklik kapısıyla ele alınır.
