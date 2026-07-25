# Beta Validation Archive

`docs/beta/` altındaki belgeler, belirli eski commit'ler, cihazlar ve validation turları için oluşturulmuş **tarihsel mühendislik kanıtlarıdır**.

Bu klasördeki `PASS`, `Blocked / Deferred`, `Validation Pending`, risk, destek sayısı veya roadmap ifadeleri güncel build'in otomatik ürün durumu değildir.

Güncel yorum sırası:

1. Runtime desteği için güncel `ExerciseCatalog` ve audit testleri
2. Güncel ürün çalışma beyanı için `docs/current_exercise_validation_matrix.md`
3. Eski failure ve closure bağlamı için bu klasördeki SHA-pinned belgeler

Tarihsel kayıtlar silinmemelidir. Eski bir failure güncel build üzerinde çözülmüş görünse bile eski belge kendi commit/tur bağlamında korunur; yeni sonuç ayrı tarih ve SHA ile kaydedilir.

## Özellikle Yanlış Okunmaması Gereken Kayıtlar

Aşağıdaki R6 belgeleri ait oldukları eski turda blocker kaydetmiştir:

- `r6-wave-c-jumping-jack-results.md`
- `r6-wave-c-sit-up-results.md`
- `r6-wave-c-triceps-dip-results.md`

Proje sahibinin 25 Temmuz 2026 tarihli güncel fonksiyonel kontrolünde Jumping Jack, Sit-up ve Bench Dip dahil 18 hareketin tamamı çalıştırılmış ve analiz doğru bulunmuştur. Bu iki kanıt kümesi çelişkili görünmemelidir: biri eski SHA/turun failure kaydı, diğeri metadata'sı eksik güncel fonksiyonel smoke check'tir.
