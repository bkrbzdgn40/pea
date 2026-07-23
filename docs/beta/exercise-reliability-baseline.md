# Exercise Reliability Baseline

Bu belge, güncel `ExerciseCatalog` analiz kapsamını güvenilirlik çalışmaları için tek bir başlangıç matrisi halinde sabitler. Amaç `supported` durumunu cihazda doğrulanmış güvenilirlik kanıtıyla karıştırmamaktır.

Bu belge yaşayan güvenilirlik dokümantasyonudur. Catalog, contract, config, engine wiring veya device-validation kanıtı değiştiğinde aynı değişiklik kapsamında güncellenmelidir.

## 1. Kanıt Durumu Sözlüğü

- `Historical Device-Verified`: Tarihsel beta hardening programında gerçek cihaz baseline ve dataset değerlendirmesi bulunan hareket.
- `R5 Engineering Revalidated`: Diagnostics schema v6, SHA-pinned profile build ve gerçek cihaz regression run'larıyla yeniden doğrulanmış hareket. Bu statü, önceden tanımlanan formal R5 run adetlerinin eksiksiz uygulandığı anlamına gelmez; protokol sapmaları closure kaydında açıkça tutulur.
- `R6 Engineering Revalidated`: Exercise-specific R6 cihaz validation'ında gerçek failure bulunup minimal reliability hardening uygulandıktan sonra fix sonrası kritik positive/negative/lifecycle/persistence kanıtlarıyla yeniden doğrulanmış hareket. Formal protokol sapmaları closure kaydında ayrıca tutulur.
- `R6 Validation Blocked / Deferred`: Exercise-specific gerçek cihaz validation'ında blocker sınıfı failure kanıtlanmış, ancak güvenli çözümün geniş mimari/performance etkisi nedeniyle mevcut validation turunda bilinçli olarak ertelenmiş hareket. Bu statü PASS değildir ve engineering revalidation sayısına dahil edilmez.
- `Validation Pending`: Production analiz wiring'i ve otomatik test desteği bulunan, ancak exercise-specific güncel cihaz kanıtı bulunmayan hareket.

`Validation Pending`, hareketin bozuk olduğu anlamına gelmez. Yalnızca gerçek cihaz kabul kanıtının henüz bu baseline içinde kurulmadığını ifade eder.

## 2. Güncel Kapsam Özeti

- Toplam canonical ve catalog-supported egzersiz: **18**
- `rangeRep`: **14**
- `hold`: **4**
- Güncel engineering revalidation cihaz kanıtı bulunan: **13**
- `R6 Validation Blocked / Deferred`: **1**
- Ayrı exercise-specific cihaz validation bekleyen: **4**

Squat, Push-up ve Plank tarihsel device-validation kapsamına ek olarak R5'te aynı SHA-pinned profile build altında Diagnostics v6 ile yeniden doğrulanmıştır. Biceps Curl, R6 Dalga A sırasında shallow-ROM false count ve form-feedback semantik problemi bulunup minimal hardening uygulandıktan sonra fix sonrası cihaz run'larıyla yeniden doğrulanmıştır. Hollow Hold ise aynı dalgada hold visibility telemetry hardening'in gerçek cihaz exit gate'i ile birlikte valid hold, form-break, visibility, pause/resume, persistence ve performans kanıtlarıyla yeniden doğrulanmıştır. Lateral Raise, doğal bilateral neutral pozisyonun eski strict neutral gate tarafından reddedilmesi ve bilateral sync jitter'ının dirsek feedback semantiğine karışması sorunları minimal hardening ile düzeltildikten sonra positive, static, partial, one-arm, form, occlusion, pause/resume, persistence ve performans cihaz kanıtlarıyla yeniden doğrulanmıştır. Front Raise, side-view selected-side kalite seçimi, false-positive dirsek feedback'i ve aşırı sıkı peak-entry davranışı gerçek cihaz/video incelemesinde bulunup minimal hardening uygulandıktan sonra preflight, positive, static, partial/invalid-ROM, form, pause/resume ve persistence senaryolarının video + gerçek hayat doğrulamasıyla yeniden doğrulanmıştır. Front Raise final hızlandırılmış run setinde diagnostics JSON tutulmadığı için performans metrikleri ayrıca kanıtlanmış sayılmaz; formal protocol-complete iddiası yapılmaz. Wall Sit, hızlandırılmış hold matrisiyle iki farklı kullanıcıda yaklaşık 30 saniye valid hold, deliberate form-break feedback'i, pause/resume hidden-time güvenliği ve persistence üzerinden yeniden doğrulanmıştır. Wall Sit final run setinde diagnostics JSON tutulmadığı için performans metrikleri ayrıca kanıtlanmış sayılmaz; başın kameraya çevrilmesinde gözlenen form-break hassasiyeti P1 robustness finding olarak izlenir. Romanian Deadlift, büyük bumper plate kaynaklı ankle visibility bağımlılığının pose acceptance'tan çıkarılması ve knee-angle feedback semantiğinin gerçek absolute-threshold ölçümüyle hizalanması sonrasında kullanıcı tarafından gerçek cihazda repetition/counting, form-break, pause/resume lifecycle ve persistence kontrolleriyle yeniden doğrulanmıştır. Çok büyük barbell/bumper plate görünürlük problemi blocker olmayan robustness finding olarak açık bırakılmıştır; scoring cezası bu closure kapsamında değiştirilmemiştir. Shoulder Press, elbow-angle primary metriğinin aşağıda düz duran kol ile overhead düz kolu tek başına ayıramaması nedeniyle zero-overlap alternating-arm senaryosunda false bilateral rep ürettiği gerçek cihaz videosuyla doğrulandıktan sonra exercise-specific bilateral wrist-above-shoulder PEAK gate ile harden edilmiştir. Fix sonrasında normal 20 tekrar sayımı, pause/resume lifecycle, persistence ve unilateral/alternating negatif davranış gerçek cihazda doğrulanmıştır. Dedicated technique metriği bulunmadığı için Shoulder Press closure'ı scapular/shoulder form doğruluğu iddiası içermez. Stationary Lunge, gerçek cihazda temiz ana counting ve side-swap davranışı gösterirken completed-rep validation'da confirmation gecikmesi nedeniyle full-ROM tekrarları yapay olarak `insufficientRom` sınıflandırabildiği bulgusu sonrasında generic lifecycle'ın ilk kesintisiz active-crossing metriğini koruyacak şekilde harden edilmiştir. Fix sonrası 10 completed rep'in 9'u valid ve 1'i yalnız descent-speed low-confidence olarak sınıflanmış, `insufficientRom` sıfıra düşmüş; aynı run'daki sığ girişimler completed rep üretmeden abort edilmiştir. STATIC, pause/resume ve persistence için ayrı final run kanıtı sabitlenmediğinden closure formal protocol-complete değildir. Side Plank, temiz pose visibility altında ciddi geçersiz yan-yatma / yanlış destek pozisyonunun hold süresi üretebildiği gerçek cihaz false-positive'i sonrasında exercise-specific `supportStacking` validation sinyaliyle harden edilmiştir. Fix sonrası aynı ciddi yanlış destek yolu hold süresi üretmemiş, doğru forearm Side Plank SHA-pinned profile cihaz run'ında yeniden acquire edilerek `best_hold_seconds = 6` üretmiştir. Front-view 2D support-angle projection semantiği ve tam final SIDE-SWAP/LIFE/PERSIST kanıtlarının eksikliği blocker olmayan follow-up olarak ertelenmiştir; closure formal protocol-complete değildir. Lying Leg Raise, mixed full + partial gerçek cihaz run'ında fiziksel olarak geçerli bazı tekrarların `reachPeak` aşamasına hiç ulaşmadan abort edilmesiyle ortaya çıkan peak-acquisition false-negative'i sonrasında harden edilmiştir. Config `thresholdPeak = 105°` değiştirilmeden exercise-specific `peakEntryMargin = 0°` seçilmiş ve generic pending-peak confirmation exit-hysteresis ile hizalanmıştır. Deterministik regression'lar temiz local gate'ten geçmiş, kullanıcı fix sonrası cihaz davranışını yeterli bulup hareketi tamamlamıştır. Ayrı post-fix diagnostics JSON ile formal POS-20/STATIC/FORM/LIFE/PERSIST kanıtları sabitlenmediğinden closure formal protocol-complete değildir. Jumping Jack gerçek cihaz/video validation'ında görünür tam open-close döngülerine rağmen `rep_count = 0`, yalnız 2 hareket başlangıcı, 0 `reachPeak` ve 2 `abortToNeutral` üreterek fast-motion peak-acquisition false-negative göstermiştir. Aynı run'da `analysis_fps_p50 = 4.81`, `frame_processing_ms_p95 = 568` ve 373 reentrant drop görülmüş; pose confidence, resync ve side-selection ise ana failure'ı açıklamamıştır. Neutral fazda `Open your legs farther` feedback'inin gösterilmesi ayrıca phase-semantics finding'i olarak kaydedilmiştir. Güvenli çözüm generic multi-stage lifecycle davranışında regression riski veya Jumping Jack'e özel fast-motion detection/pipeline çalışması gerektirdiği için hareket `R6 Validation Blocked / Deferred` statüsünde bırakılmıştır; PASS veya Engineering Revalidated sayılmaz. Ayrıntılı issue ve reopen kriterleri `docs/beta/r6-wave-c-jumping-jack-results.md` dosyasında kalıcı olarak tutulur. R5 ve R6 execution sapmaları ilgili closure kayıtlarında açıkça tutulur. Diğer hareketler catalog desteğine sahiptir; bu destek tek başına eşdeğer cihaz güvenilirliği iddiası değildir.

## 3. Exercise Reliability Matrix

| Egzersiz | Runtime engine | Side / family | Primary metric yönü | Tercih edilen kamera | Device evidence |
| --- | --- | --- | --- | --- | --- |
| Squat | `rangeRep` | selected-side | decreasing-to-peak | side | R5 Engineering Revalidated |
| Plank | `hold` | plank family | n/a | side | R5 Engineering Revalidated |
| Hollow Hold | `hold` | hollow-hold family | n/a | side | R6 Engineering Revalidated |
| Stationary Lunge | `rangeRep` | selected-side | decreasing-to-peak | side | R6 Engineering Revalidated |
| Push-up | `rangeRep` | selected-side | decreasing-to-peak | side | R5 Engineering Revalidated |
| Sit-up | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Biceps Curl | `rangeRep` | bilateral | decreasing-to-peak | front | R6 Engineering Revalidated |
| Lying Leg Raise | `rangeRep` | selected-side | decreasing-to-peak | side | R6 Engineering Revalidated |
| Triceps Dip | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Romanian Deadlift | `rangeRep` | selected-side | decreasing-to-peak | side | R6 Engineering Revalidated |
| Lateral Raise | `rangeRep` | bilateral | increasing-to-peak | front | R6 Engineering Revalidated |
| Shoulder Press | `rangeRep` | bilateral | increasing-to-peak | front | R6 Engineering Revalidated |
| Calf Raise | `rangeRep` | selected-side | increasing-to-peak | side | Validation Pending |
| Front Raise | `rangeRep` | selected-side | increasing-to-peak | side | R6 Engineering Revalidated |
| Glute Bridge | `rangeRep` | selected-side | increasing-to-peak | side | Validation Pending |
| Wall Sit | `hold` | wall-sit family | n/a | side | R6 Engineering Revalidated |
| Side Plank | `hold` | side-plank family | n/a | front | R6 Engineering Revalidated |
| Jumping Jack | `rangeRep` | bilateral | increasing-to-peak | front | R6 Validation Blocked / Deferred |

## 4. Güvenilirlik Çalışmasının İlkeleri

1. `ExerciseCatalog.supported` bir runtime capability beyanıdır; `device-verified` ile eş anlamlı değildir.
2. Sayım/hold güvenilirliği ile form-analysis güvenilirliği ayrı değerlendirilir.
3. Threshold, likelihood, side selection, resync veya pose policy değişikliği başarısız scenario kanıtı olmadan yapılmaz.
4. Global aggregate, egzersiz veya cihaz bazındaki kötü sonucu gizlemek için kullanılmaz.
5. Gerçek cihaz validation sonucunda başarısızlık önce camera, landmark/pose quality, metric, lifecycle, side/bilateral, occlusion/recovery veya performance sınıfına ayrılır; sonra minimum doğru katmana müdahale edilir.

## 5. Validation Dalgaları

### Kontrol grubu

Mevcut güvenilirlik altyapısında regression kontrolü:

1. Squat
2. Plank
3. Push-up

### Dalga A: yüksek güvenilirleşme potansiyeli

1. Biceps Curl
2. Hollow Hold
3. Lateral Raise
4. Front Raise
5. Wall Sit

İlk hedef, tarihsel device-verified kapsamı **3 hareketten 8 harekete** çıkarmaktır. Bu hedef ancak exercise-specific cihaz kanıtıyla tamamlanmış sayılır.

### Dalga B: setup / observability bağımlılığı yüksek

1. Romanian Deadlift
2. Shoulder Press
3. Stationary Lunge
4. Side Plank
5. Lying Leg Raise

### Dalga C: daha yüksek temporal, occlusion veya düşük-ROM riski

1. Jumping Jack
2. Sit-up
3. Triceps Dip
4. Glute Bridge
5. Calf Raise

Bu dalga sırası bir doğruluk sonucu değildir; mevcut 2D gözlemlenebilirlik ve cihaz-validation maliyetine göre engineering önceliğidir.

## 6. R2 Contract Audit Gate

Her catalog-supported egzersiz için otomatik audit şu zinciri korumalıdır:

`ExerciseCatalog`
→ config asset mevcut ve parse edilebilir
→ camera contract en az bir desteklenen ve bir preferred view içerir
→ engine kind ile tracking type/contract uyumludur
→ gerçek asset config production `AnalysisEngineFactory` doğrulamasından geçer
→ range-rep threshold sırası primary metric yönüyle uyumludur
→ increasing-to-peak validation delta tabanlı ROM floor kullanır
→ pose-acceptance signal kümesi supported signal kümesinin alt kümesidir
→ supported ve pose-acceptance landmark requirements iki tarafta çözülebilir
→ bilateral contract birleşik landmark gereksinimi üretebilir
→ hold required signal geometrisi iki tarafta çözülebilir

Bu gate runtime threshold veya engine davranışını değiştirmez. Ama yeni exercise/config eklenirken katalog ile gerçek analiz wiring'inin sessizce ayrışmasını test aşamasında durdurur.

## 7. R3 Deterministic Reliability Scenario Gate

R3, production threshold veya runtime davranışını değiştirmeden bütün engine aileleri için ortak deterministic davranış kontratı kurar. Gate iki ayrı test paketine ayrılır:

### 14 `rangeRep` hareket

Her catalog-supported range-rep egzersizi gerçek asset config ve production `AnalysisEngineFactory` ile şu senaryolardan geçmelidir:

- peak pozisyonunda session başlangıcı arming veya phantom rep üretmez,
- active-threshold çevresindeki jitter ve yanlış yöndeki hareket rep başlatmaz,
- neutral -> active -> peak -> return -> neutral tam lifecycle tam bir rep üretir,
- peak'e ulaşmayan partial excursion abort edilir ve rep sayılmaz,
- kısa ve phase-compatible visibility gap aktif rep context'ini korur,
- hard resync yalnız aktif rep context'ini temizler ve tamamlanmış session rep sayısını korur,
- reset session rep sayısını temizler ve neutral reacquisition zorunluluğunu geri getirir,
- exercise-specific validation config yeterli ROM'u kabul eder ve yetersiz ROM'u `insufficientRom` ile reddeder.

R3 ayrıca catalog side-mode kapsamını **10 selected-side + 4 bilateral** olarak sabitler. Selected-side seçim/hysteresis ve aktif-rep side consistency davranışları mevcut `range_rep_side_policy_test.dart` ve `range_rep_side_stabilizer_test.dart` katmanlarında korunur; deterministic engine harness bu policy testlerini kopyalamaz.

### 4 `hold` hareket

Plank, Hollow Hold, Wall Sit ve Side Plank gerçek asset config ve production hold policy ile şu senaryolardan geçmelidir:

- invalid başlangıç posture'u hold süresi başlatmaz,
- valid posture deterministik olarak süre biriktirir,
- grace-window içindeki geçici form bozulması recovery ile hold'u korur,
- kalıcı grace-eligible form bozulması hold'u sonlandırır,
- kısa visibility gap gizli süreyi toplam hold süresine eklemeden resume eder,
- 1200 ms visibility freeze sınırındaki kayıp aktif hold'u sonlandırır ve best hold'u korur,
- gerekli hold signal'larının kaybı aktif hold'u güvenli biçimde durdurur,
- reset current/best hold state'ini temizler.

Bu gate gerçek cihaz doğruluğu iddiası değildir. Ama cihaz dataset'ine çıkmadan önce lifecycle, threshold topology, validation ve hold-time semantiğinin bütün catalog üzerinde aynı regression kontratıyla korunmasını sağlar.

## 8. R4 Exercise-Aware Diagnostics v6

R4, gerçek cihaz run'larının yalnız `rangeRep` veya `hold` olarak değil, hangi egzersiz ve hangi analiz kontratıyla üretildiğinin tek JSON snapshot'tan anlaşılabilmesini sağlar.

Diagnostics schema v6 şu run-level bağlamı taşır:

- `exercise_type`,
- `config_asset_path`,
- build commit SHA ile birlikte `config_version_fingerprint`,
- `contract_profile`,
- range-rep için side mode, primary metric kind ve primary metric direction,
- hold için analysis family ve varsa Hollow Hold variation,
- gerçek kullanılan camera lens direction, sensor orientation ve device orientation,
- pose rejection reason sayaçları,
- minimum/mean required-landmark likelihood percentile'ları,
- pose-quality score percentile'ları,
- range-rep confirmed transition sayaçları,
- abort sayısı,
- completed-rep validation status/reason sayaçları,
- aktif rep context'i sırasında gerçekleşen resync sayısı.

Config fingerprint bir içerik hash'i değildir. Reproducible build içindeki config asset path ile app commit SHA'yı birlikte adresleyerek cihaz kaydının hangi config revision'ına ait olduğunu belirler.

Bu telemetry privacy-minimized kalır: raw frame, raw landmark, kullanıcı kimliği, e-posta, session id, exception message veya stack trace export edilmez.

R4 runtime rep/hold threshold'larını veya feedback kararlarını değiştirmez. Değişiklik yalnız diagnostics gözlemlenebilirliğini genişletir.

## 9. R5 Control-Group Device Revalidation

R5, tarihsel device-verified kontrol grubunu Diagnostics schema v6 altında yeniden doğrular:

1. Squat
2. Push-up
3. Plank

R5 cihaz kanıtı `docs/beta/r5-control-group-device-validation.md` protokolünü izler ve sonuçlar `docs/beta/r5-control-group-results-template.csv` şablonuna işlenir.

R5 öncesinde diagnostics performans telemetry'si run-level FPS percentile'larıyla tamamlanmıştır:

- `fps_sample_count`,
- `camera_fps_p50`,
- `camera_fps_p95`,
- `analysis_fps_p50`,
- `analysis_fps_p95`.

Bu alanlar controller'ın yaklaşık saniyelik FPS hesaplama pencerelerinden örneklenir. Tek bir `current_analysis_fps` değeri provisional `analysis_fps_p50 >= 6` gate'ini değerlendirmek için yeterli kabul edilmez.

R5 run'ları SHA-pinned profile build ile yapılmalıdır. `app_commit_sha == unknown` veya `build_mode != profile` olan run'lar mevcut measurement contract gereği `INVALID` sayılır.

R5 production threshold veya analiz engine semantiğini değiştirmez. Fail sonucu önce camera/setup, pose-quality, metric, lifecycle, side, occlusion, persistence veya performance sınıfına ayrılır; sonra minimum doğru katmana müdahale edilir.

### R5 closure durumu

R5 engineering revalidation, commit `f56d921c5e4a6672f3881d5408a0d81302051965` üzerinde profile build ile tamamlandı. Squat, Push-up ve Plank için positive, negative, partial/lifecycle, persistence ve performans davranışları gerçek cihazda yeniden doğrulandı. Ayrıntılı kanıt `docs/beta/r5-control-group-results.md` dosyasındadır.

Önceden tanımlanan formal protokol ile gerçek execution arasında planlı run adedi sapmaları vardır: 20 yerine 12 kontrollü range-rep, 10 yerine 5 partial deneme ve bazı occlusion/lifecycle senaryolarında 3 yerine tek kontrollü run uygulanmıştır. Bu nedenle closure sonucu **`R5 Engineering Revalidated`** olarak kaydedilir; **formal protocol-complete** olarak adlandırılmaz.

R5 sırasında üç açık engineering bulgusu kaydedildi:

1. Hold visibility lifecycle geçmişini ölçen telemetry eksikliği. R6 implementation hardening ile session-level suspend/recovery/abort ve gap-duration telemetry'si eklendi; 701 ms short-gap recovery ve 1669 ms long-gap abort gerçek cihazda doğrulanarak finding kapatıldı.
2. Static Plank/form-break koşulunda gözlenen camera autofocus hunting.
3. Push-up positive run'da 12 rep'in 9'unun `excessiveDescentSpeed` nedeniyle `lowConfidence` işaretlenmesi.

Bu bulguların sahipliği ve exit kriterleri `docs/beta/r5-control-group-findings.md` dosyasında tutulur.

## 10. Sonraki Adım

Engineering revalidation kapsamı **13 / 18** harekette kalır.

R6 Dalga C durumu:

```text
Jumping Jack = R6 Validation Blocked / Deferred
Sit-up       = Active Validation Target
Triceps Dip  = Validation Pending
Glute Bridge = Validation Pending
Calf Raise   = Validation Pending
```

Jumping Jack PASS sayılmaz ve engineering revalidation toplamına eklenmez. Gerçek cihazda fast-motion peak-acquisition false-negative ve neutral-faz leg-spread feedback semantik problemi kanıtlanmıştır. Geniş generic lifecycle regression riski veya exercise-specific fast-motion detection/pipeline çalışması gerektirdiği için mevcut turda bilinçli olarak ertelenmiştir.

Kalıcı issue / reopen kaydı:

```text
docs/beta/r6-wave-c-jumping-jack-results.md
```

Aktif sıradaki çalışma:

```text
Sit-up
```

Cihaz validation protokolü:

```text
docs/beta/r6-wave-c-sit-up-device-validation.md
```

Per-exercise occlusion testi varsayılan hızlandırılmış matriste tekrar edilmez. Shared range-rep visibility/occlusion davranışı mevcut ortak reliability kanıtıyla kapsanır. Occlusion yalnız exercise-specific visibility mantığı, yeni regression veya diagnostics'te visibility-specific failure görülürse yeniden açılır.

Yeni exercise threshold tuning, deterministic R3 baseline ve exercise-specific gerçek cihaz failure kanıtından önce yapılmayacaktır. Tek kullanıcı veya tek video threshold değişikliğine tek başına gerekçe değildir.

## 11. R6 Dalga A - Biceps Curl Closure

R6 Dalga A'nın ilk exercise-specific cihaz validation hedefi Biceps Curl tamamlanmıştır. Protokol `docs/beta/r6-wave-a-biceps-curl-device-validation.md`, canlı execution kaydı `docs/beta/r6-wave-a-run-manifest.csv`, ayrıntılı closure kanıtı ise `docs/beta/r6-wave-a-biceps-curl-results.md` dosyasında tutulur.

Biceps Curl validation başlamadan önce setup rehberi production camera contract ile hizalanmıştır: `front` preferred, `side` unsupported. Önceki 30-45 derece çapraz kamera önerisi kaldırılmıştır. Bu değişiklik engine threshold'larını veya bilateral counting semantiğini değiştirmez; yalnız test ve kullanıcı kurulumunun gerçek analysis contract ile aynı olmasını sağlar.

Biceps Curl, shallow-ROM false count bulgusunun secondary shoulder-wrist closure PEAK gate ile düzeltilmesi ve fix sonrası 10 shallow → 0, 20 full → 20, one-arm → 0, occlusion, pause/resume ve 5 → 5 persistence kanıtları sonrasında **`R6 Engineering Revalidated`** olarak kapatılmıştır. Tempo-confidence hassasiyeti counting closure'ını bloklamayan açık R6 finding olarak izlenir.

## 12. R6 Dalga A - Hold Visibility ve Hollow Hold Closure

Hold visibility telemetry hardening ve Hollow Hold cihaz validation'ı commit `036a81f4b65dbd78fb197e5a6f807c7178d90da0` üzerinde profile build ile tamamlandı. Ayrıntılı closure kanıtı `docs/beta/r6-wave-a-hollow-hold-results.md`, telemetry tasarım/exit gate'i ise `docs/beta/r6-hold-visibility-telemetry-hardening.md` içinde tutulur.

Gerçek cihazda kısa visibility gap 701 ms olarak `suspend + recovery`, uzun visibility gap ise 1669 ms olarak `suspend + abort` şeklinde ölçüldü. İlk long-gap denemesinde hold continuity kırılmasına rağmen yeni event sayaçları oluşmadığı için run `INCONCLUSIVE` olarak saklandı; aynı SHA'da tekrarlanan ikinci long-gap run exit kriterini karşıladı. Bu nedenle R5 F1 hold visibility observability finding'i **CLOSED** olarak işaretlenmiştir.

Hollow Hold için 30 saniye ground-truth hold tam 30 saniye ölçüldü; invalid/form-break run'ında aktif hold sıfırlandı ve `straighten_knees` feedback'i üretildi; pause/resume sonrasında best hold korunup yeni aktif hold ayrı devam etti; 10 saniyelik persistence kullanıcı tarafından doğrulandı. Protokol execution'ı formal çoklu-run seti değildir; bu nedenle statü **`R6 Engineering Revalidated`** olarak tutulur, formal protocol-complete iddiası yapılmaz.
