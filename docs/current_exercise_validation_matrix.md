# Current Exercise Validation Matrix

Bu belge, PEA içindeki **güncel hareket çalışma gerçeğinin tek giriş noktasıdır**. Runtime catalog desteğini, proje sahibinin güncel fonksiyonel cihaz kontrollerini ve eski SHA-pinned beta kayıtlarını birbirine karıştırmadan gösterir.

Son güncelleme: **1 Ağustos 2026**

## 1. Kanıt seviyeleri

| Seviye | Anlamı | Sınırı |
| --- | --- | --- |
| Runtime support | Hareket güncel `ExerciseCatalog` içinde supported olarak kayıtlıdır ve production analiz yoluna bağlanır. | Tek başına gerçek cihaz başarı kanıtı değildir. |
| Current owner functional check | Proje sahibi güncel bir build üzerinde hareketi çalıştırmış ve sonucu işlevsel bulmuştur. | Cihaz, OS, build SHA ve senaryo metadata'sı yoksa tekrarlanabilir formal kabul değildir. |
| Historical SHA-pinned beta evidence | Belirli eski commit, cihaz ve protokol turuna ait validation kaydıdır. | Güncel build'in sonucunu otomatik belirlemez. |
| Multi-device formal acceptance | Build SHA, cihaz sınıfı, kamera yönü ve pozitif/negatif senaryolarla tekrarlanabilir kabul kaydıdır. | Henüz bütün catalog için tamamlanmış değildir. |

## 2. Güncel kaynak anlık görüntüsü

- İncelenen baseline: `pose_estimation_app.tar(167).gz`
- Baseline tarihi: **1 Ağustos 2026**
- Git metadata: Arşiv `.git` dizini içermediği için commit SHA çıkarılamadı.
- Canonical hareket sayısı: **34**
- Runtime catalog durumu: **34/34 supported**
- Range-rep hareket: **30**
- Hold hareket: **4**
- Güncel owner functional check kaydı bulunan hareket: **18/34**
- Bu 18 hareket için bildirilen kontrol tarihi: **25 Temmuz 2026**
- Kalan 16 hareket için bu belgede güncel owner check kaydı yoktur.
- Bütün 34 hareket için multi-device formal acceptance tamamlanmış sayılmaz.

Güncel doğru ürün ifadesi:

> Tar167 runtime catalog içinde 34 hareket production analiz yoluna bağlıdır. Bunların 18'i için proje sahibinin daha önce bildirdiği fonksiyonel cihaz kontrolü bulunur; bu kayıt multi-device formal acceptance anlamına gelmez.

Bu belgeden çıkarılmaması gereken ifade:

> 34 hareket bütün desteklenen cihazlarda, kamera koşullarında ve kullanıcı tiplerinde formal olarak doğrulanmıştır.

## 3. Güncel hareket matrisi

`Owner check` sütunundaki "Başarılı bildirildi" ifadesi, 25 Temmuz 2026 tarihli fonksiyonel smoke beyanını korur. `Kayıt yok` ifadesi hareketin çalışmadığını değil, tar167 için bu belgede yeni cihaz kanıtı bulunmadığını belirtir.

| Canonical ID | Egzersiz | Engine / family | Runtime | Owner check | Formal multi-device kabul |
| --- | --- | --- | --- | --- | --- |
| `squat` | Squat | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `plank` | Plank | `hold / plank` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `hollow_hold` | Hollow Hold | `hold / hollowHold` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `lunge` | Stationary Lunge | `rangeRep + alternating sidecar` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `push_up` | Push-up | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `sit_up` | Sit-up | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `crunch` | Crunch | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `reverse_crunch` | Reverse Crunch | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `biceps_curl` | Biceps Curl | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `lying_leg_raise` | Lying Leg Raise | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `bent_knee_leg_raise` | Bent-Knee Leg Raise | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `standing_hamstring_curl` | Standing Hamstring Curl | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `standing_hip_abduction` | Standing Hip Abduction | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `triceps_dip` | Bench Dip | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `romanian_deadlift` | Romanian Deadlift | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `good_morning` | Good Morning | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `lateral_raise` | Lateral Raise | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `shoulder_press` | Shoulder Press | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `overhead_triceps_extension` | Overhead Triceps Extension | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `upright_row` | Upright Row | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `calf_raise` | Calf Raise | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `front_raise` | Front Raise | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `glute_bridge` | Glute Bridge | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `wall_sit` | Wall Sit | `hold / wallSit` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `side_plank` | Side Plank | `hold / sidePlank` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `jumping_jack` | Jumping Jack | `rangeRep` | Aktif | Başarılı bildirildi | Tamamlanmadı |
| `standing_hip_extension` | Standing Hip Extension | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `standing_knee_raise` | Standing Knee Raise | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `standing_straight_leg_raise` | Standing Straight-Leg Raise | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `v_up` | V-Up | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `frog_pump` | Frog Pump | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `lying_triceps_extension` | Lying Triceps Extension | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `floor_chest_press` | Floor Chest Press | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |
| `y_raise` | Y Raise | `rangeRep` | Aktif | Kayıt yok | Tamamlanmadı |

## 4. Tarihsel kayıtların kullanımı

Tarihsel beta bağlamının giriş noktaları:

- `docs/beta/README.md`
- `docs/beta/exercise-reliability-baseline.md`

Eski blocker, pending veya revalidated sonuçları geçmiş commit ve protokolün kanıtıdır. Tar167 sonucu gibi yeniden etiketlenmez. Yeni kanıt yeni tarih, build SHA ve cihaz metadata'sıyla eklenir.

## 5. Formal cihaz kaydı şablonu

| Alan | Değer |
| --- | --- |
| Tarih |  |
| Tester |  |
| Commit SHA |  |
| Build mode | `profile` / `release` |
| Cihaz modeli |  |
| OS ve sürüm |  |
| Kamera | front / back |
| Cihaz yönü | portrait / landscape |
| Egzersiz |  |
| Pozitif senaryo |  |
| Negatif senaryo |  |
| Beklenen sonuç |  |
| Gerçek sonuç |  |
| Diagnostics artifact |  |
| Sonuç | PASS / FAIL / BLOCKED |

Bu metadata doldurulmadan yapılan kontrol faydasız değildir; yalnızca formal kabul yerine fonksiyonel smoke check seviyesinde kalır.

## 6. Güncelleme kuralı

Bu belge aşağıdaki durumlardan biri olduğunda aynı PR içinde güncellenmelidir:

- `ExerciseType` listesi değişirse
- Bir hareket supported / unsupported olarak değiştirilirse
- Primary engine veya hold family değişirse
- Yeni owner functional check yapılırsa
- Yeni SHA-pinned formal cihaz sonucu eklenirse
- Tarihsel bir finding güncel build üzerinde yeniden açılırsa

Catalog ile doküman arasındaki canonical ID farkı test hatasıdır. Eski beta kayıtları güncel build'e göre yeniden yazılmaz.
