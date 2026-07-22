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

## 7. Sonraki Adım

R2 gate temizlendikten sonra R3 kapsamında 14 `rangeRep` ve 4 `hold` hareket için standardize deterministic reliability scenario harness kurulacaktır. Gerçek cihaz threshold tuning bu deterministic baseline ve exercise-specific cihaz kanıtından önce yapılmayacaktır.
