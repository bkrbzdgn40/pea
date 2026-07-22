# Exercise Reliability Baseline

Bu belge, güncel `ExerciseCatalog` analiz kapsamını güvenilirlik çalışmaları için tek bir başlangıç matrisi halinde sabitler. Amaç `supported` durumunu cihazda doğrulanmış güvenilirlik kanıtıyla karıştırmamaktır.

Bu belge yaşayan güvenilirlik dokümantasyonudur. Catalog, contract, config, engine wiring veya device-validation kanıtı değiştiğinde aynı değişiklik kapsamında güncellenmelidir.

## 1. Kanıt Durumu Sözlüğü

- `Historical Device-Verified`: Tarihsel beta hardening programında gerçek cihaz baseline ve dataset değerlendirmesi bulunan hareket.
- `Validation Pending`: Production analiz wiring'i ve otomatik test desteği bulunan, ancak tarihsel G6/G7 cihaz kanıtını otomatik olarak devralmayan hareket.

`Validation Pending`, hareketin bozuk olduğu anlamına gelmez. Yalnızca gerçek cihaz kabul kanıtının henüz bu baseline içinde kurulmadığını ifade eder.

## 2. Güncel Kapsam Özeti

- Toplam canonical ve catalog-supported egzersiz: **18**
- `rangeRep`: **14**
- `hold`: **4**
- Tarihsel gerçek cihaz kanıtı bulunan: **3**
- Ayrı exercise-specific cihaz validation bekleyen: **15**

Tarihsel device-validation kapsamı yalnız **Squat, Push-up ve Plank** için kanıtlanmıştır. Diğer hareketler catalog desteğine sahiptir; bu destek tek başına eşdeğer cihaz güvenilirliği iddiası değildir.

## 3. Exercise Reliability Matrix

| Egzersiz | Runtime engine | Side / family | Primary metric yönü | Tercih edilen kamera | Device evidence |
| --- | --- | --- | --- | --- | --- |
| Squat | `rangeRep` | selected-side | decreasing-to-peak | side | Historical Device-Verified |
| Plank | `hold` | plank family | n/a | side | Historical Device-Verified |
| Hollow Hold | `hold` | hollow-hold family | n/a | side | Validation Pending |
| Stationary Lunge | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Push-up | `rangeRep` | selected-side | decreasing-to-peak | side | Historical Device-Verified |
| Sit-up | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Biceps Curl | `rangeRep` | bilateral | decreasing-to-peak | front | Validation Pending |
| Lying Leg Raise | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Triceps Dip | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Romanian Deadlift | `rangeRep` | selected-side | decreasing-to-peak | side | Validation Pending |
| Lateral Raise | `rangeRep` | bilateral | increasing-to-peak | front | Validation Pending |
| Shoulder Press | `rangeRep` | bilateral | increasing-to-peak | front | Validation Pending |
| Calf Raise | `rangeRep` | selected-side | increasing-to-peak | side | Validation Pending |
| Front Raise | `rangeRep` | selected-side | increasing-to-peak | side | Validation Pending |
| Glute Bridge | `rangeRep` | selected-side | increasing-to-peak | side | Validation Pending |
| Wall Sit | `hold` | wall-sit family | n/a | side | Validation Pending |
| Side Plank | `hold` | side-plank family | n/a | front | Validation Pending |
| Jumping Jack | `rangeRep` | bilateral | increasing-to-peak | front | Validation Pending |

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

## 8. Sonraki Adım

R3 local gate temizlendikten sonra R4 kapsamında exercise-aware diagnostics v6 ele alınacaktır. Gerçek cihaz threshold tuning deterministic R3 baseline ve exercise-specific cihaz kanıtından önce yapılmayacaktır.
