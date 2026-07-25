# Current Exercise Validation Matrix

Bu belge, PEA içindeki **güncel hareket çalışma gerçeğinin tek giriş noktasıdır**. Runtime catalog desteğini, proje sahibinin güncel fonksiyonel cihaz kontrolünü ve eski SHA-pinned beta validation kayıtlarını birbirine karıştırmadan gösterir.

Son güncelleme: **25 Temmuz 2026**

## 1. Kanıt Seviyeleri

| Seviye | Anlamı | Sınırı |
| --- | --- | --- |
| Runtime support | Hareket güncel `ExerciseCatalog` içinde `ExerciseDefinition.supported(...)` olarak kayıtlıdır ve production analiz yoluna bağlanır. | Tek başına gerçek cihazda başarı kanıtı değildir. |
| Current owner functional check | Proje sahibi güncel build üzerinde hareketi çalıştırmış ve analiz sonucunu doğru bulmuştur. | Cihaz, işletim sistemi, build SHA ve senaryo metadata'sı kaydedilmediyse tekrarlanabilir formal kabul kanıtı değildir. |
| Historical SHA-pinned beta evidence | Belirli eski commit, cihaz ve protokol turuna ait ayrıntılı validation kaydıdır. | Güncel build'in durumunu otomatik olarak belirlemez; tarihsel regresyon ve mühendislik bağlamı sağlar. |
| Multi-device formal acceptance | Low/Mid/High cihaz sınıfları, build SHA, kamera yönü ve pozitif/negatif senaryolarla tekrarlanabilir kabul matrisi. | Henüz bu belge kapsamında tamamlanmış sayılmaz. |

## 2. Güncel Kaynak Anlık Görüntüsü

- İncelenen arşiv: `pose_estimation_app.tar(105).gz`
- Git metadata: Arşiv `.git` dizini içermediği için commit SHA bu anlık görüntüden çıkarılamadı.
- Canonical hareket sayısı: **18**
- Runtime catalog durumu: **18/18 supported**
- Güncel proje sahibi fonksiyonel cihaz kontrolü: **18/18 başarılı olarak bildirildi**
- Kontrol tarihi: **25 Temmuz 2026**
- Cihaz modeli: **Kaydedilmedi**
- İşletim sistemi/sürümü: **Kaydedilmedi**
- Build SHA: **Kaydedilmedi**
- Kamera lensi/yönü ve scenario manifesti: **Kaydedilmedi**

Bu nedenle güncel doğru ürün ifadesi şudur:

> Güncel build üzerinde proje sahibi tarafından 18 hareketin tamamı fonksiyonel olarak çalıştırılmış ve analiz sonuçları doğru bulunmuştur.

Bu belgeden çıkarılmaması gereken ifade:

> 18 hareket bütün desteklenen cihazlarda ve bütün kamera koşullarında formal olarak kabul edilmiştir.

## 3. Güncel Hareket Matrisi

| Egzersiz | Primary engine / family | Tercih edilen kamera | Runtime support | 25 Temmuz 2026 owner check | Tarihsel beta kaydı |
| --- | --- | --- | --- | --- | --- |
| Squat | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R5 Engineering Revalidated |
| Plank | `hold`, plank family | side | Aktif | Başarılı bildirildi | R5 Engineering Revalidated |
| Hollow Hold | `hold`, hollow-hold family | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Stationary Lunge | `rangeRep` + alternating sidecar | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Push-up | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R5 Engineering Revalidated |
| Sit-up | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 turunda Blocked / Deferred |
| Biceps Curl | `rangeRep`, bilateral | front | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Lying Leg Raise | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Bench Dip | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 turunda Blocked / Deferred |
| Romanian Deadlift | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Lateral Raise | `rangeRep`, bilateral | front | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Shoulder Press | `rangeRep`, bilateral | front | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Calf Raise | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 turunda Validation Pending |
| Front Raise | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Glute Bridge | `rangeRep`, selected-side | side | Aktif | Başarılı bildirildi | R6 turunda Validation Pending |
| Wall Sit | `hold`, wall-sit family | side | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Side Plank | `hold`, side-plank family | front | Aktif | Başarılı bildirildi | R6 Engineering Revalidated |
| Jumping Jack | `rangeRep`, bilateral | front | Aktif | Başarılı bildirildi | R6 turunda Blocked / Deferred |

`Tarihsel beta kaydı` sütunu, eski turun sonucunu korur. Örneğin Sit-up, Bench Dip ve Jumping Jack için eski R6 blocker belgelerinin bulunması, güncel owner check sonucunu geçersiz kılmaz. Aynı biçimde güncel owner check, eski failure'ın hangi commit ve koşulda oluştuğunu silmez.

## 4. Güncel Gerçeklik Kaynakları

Runtime support için kaynak sırası:

1. `lib/features/workout_analysis/domain/models/exercise_type.dart`
2. `lib/features/workout_analysis/application/exercise_catalog.dart`
3. Catalog ve resolver audit testleri

Güncel fonksiyonel cihaz sonucu için kaynak:

- Proje sahibinin 25 Temmuz 2026 tarihli beyanı: 18 hareketin tamamı güncel build üzerinde çalıştırıldı ve analiz doğru bulundu.

Tarihsel beta bağlamı için giriş noktası:

- `docs/beta/README.md`
- `docs/beta/exercise-reliability-baseline.md`

## 5. Sonraki Formal Cihaz Kaydı Şablonu

Yeni gerçek cihaz kontrolünde aşağıdaki alanlar doldurulmalıdır:

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

Bu alanlar dolmadan yeni kontrol değersiz değildir; yalnız **fonksiyonel smoke check** seviyesinde kalır.

## 6. Güncelleme Kuralı

Bu belge aşağıdaki durumlardan biri olduğunda aynı PR içinde güncellenmelidir:

- `ExerciseType` listesi değişirse
- Bir hareket `supported` / `unsupported` olarak değiştirilirse
- Primary engine, family veya preferred camera contract değişirse
- Yeni güncel owner functional check yapılırsa
- Yeni SHA-pinned formal cihaz validation sonucu eklenirse
- Tarihsel bir beta finding güncel build üzerinde yeniden açılırsa

Eski beta sonuçları güncel build'e göre yeniden yazılmaz. Yeni kanıt yeni tarih ve yeni SHA ile eklenir; geçmiş kayıt korunur.
