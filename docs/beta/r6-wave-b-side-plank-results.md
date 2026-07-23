# R6 Wave B - Side Plank Results

Bu belge Side Plank R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

**Follow-up: `Deferred`**

Side Plank validation sırasında ciddi bir false-positive bulundu: belirgin biçimde geçersiz yan-yatma / yanlış destek pozisyonu, pose visibility temiz olmasına rağmen hold süresi biriktirebiliyordu.

Bu failure exercise-specific support geometrisi boşluğu olarak sınıflandırıldı ve `supportStacking` derived validation sinyaliyle harden edildi.

## Bulgu ve Fix

İlk cihaz kanıtında yaklaşık 5 saniyelik yanlış hold gözlendi:

```text
best_hold_seconds = 5
```

Legacy validity yalnız şu açısal sinyallere dayanıyordu:

```text
alignment = shoulder -> hip -> ankle
support = shoulder -> elbow -> wrist
extension = hip -> knee -> ankle
```

Bu kombinasyon, selected taraftaki dirseğin gerçekten omuzun altında destek verdiğini tek başına kanıtlamıyordu.

Exercise-specific fix:

```text
supportStacking =
signed vertical component of shoulder -> elbow
normalized by shoulder-elbow length

valid when:
supportStacking >= 1 / sqrt(2)
```

Bu sinyal Side Plank için detection + validation rolüne eklendi. Generic hold lifecycle ve ortak visibility/occlusion davranışı değiştirilmedi.

Fix sonrası ciddi yanlış destek senaryosu hold süresi üretmedi.

## Feedback ve Support Semantiği

İlk hardening sonrasında doğru forearm Side Plank'in generic `adjust_elbow_support` feedback'iyle reddedilebildiği görüldü.

Feedback kodları Side Plank support problemlerini daha açık ayıracak şekilde genişletildi. Ardından generic `Side Plank` contract'ı iki stabil support-bandını kabul edecek şekilde genişletildi:

```text
configured forearm band = 60°-120°
extended-support band = >= 150°
```

İlk false-positive'i kapatan `supportStacking` gate'i her iki durumda da korunur.

Son başarılı gerçek cihaz run'ının kullanıcı tarafından **forearm Side Plank** olduğu ayrıca doğrulandı. Bu nedenle closure straight-arm Side Plank'in gerçek cihazda doğrulandığı iddiasını içermez.

Front-view 2D projection nedeniyle `shoulder -> elbow -> wrist` açısının gerçek dirsek fleksiyonunu her pozda birebir temsil etmeyebileceği semantik belirsizlik blocker olmayan robustness finding olarak ertelenmiştir. Mevcut davranış doğru forearm formu kabul ettiği ve eski ciddi false-positive yolu kapalı kaldığı için yeni threshold değişikliği yapılmamıştır.

## Fix Sonrası Gerçek Cihaz Kanıtı

SHA-pinned profile diagnostics run:

```text
app_commit_sha = 8de075f2237ff0c3e5ac108f91d48d83d21ae6e6
build_mode = profile
exercise_type = side_plank

best_hold_seconds = 6
analysis_exception_count = 0
analysis_fps_p50 = 7.789678675754625
frame_processing_ms_p95 = 235

detected_pose_frame_count = 223
accepted_pose_frame_count = 218
rejected_pose_frame_count = 4
low_confidence_pose_frame_count = 4
```

Bu run doğru forearm Side Plank'in yeniden hold acquire edip ölçülebilir süre biriktirdiğini gösterir.

Aynı diagnostics contract'ta `supportStacking` detection + validation sinyali olarak production wiring içinde görünür durumdadır.

## Execution Sapmaları

Aşağıdaki final run'lar ayrı ve açık closure kanıtı olarak sabitlenmedi:

- `R6-SPL-VALID-30`
- `R6-SPL-FORM-BREAK`
- `R6-SPL-SIDE-SWAP`
- `R6-SPL-LIFE`
- `R6-SPL-PERSIST`

Bu nedenle:

- formal protocol-complete iddiası yapılmaz,
- bu run'lar çalıştırılmış gibi yazılmaz,
- closure kritik false-positive'in bulunması, exercise-specific hardening sonrası negatif davranışın düzelmesi ve doğru forearm positive path'in yeniden cihazda acquire edilmesine dayanır.

Per-exercise occlusion testi ortak hold visibility reliability kanıtı nedeniyle tekrar edilmemiştir.

## Açık Finding'ler

1. Front-view 2D support-angle projection semantiği, gerçek dirsek fleksiyonunu her koşulda birebir temsil etmeyebilir. Non-blocking, deferred.
2. Önceki bir run'da yanlış pozisyonda çok kısa transient `HOLDING` acquisition gözlendi; tam saniye veya `best_hold` birikimi üretmedi. Non-blocking robustness finding.
3. Straight-arm Side Plank gerçek cihaz positive path'i bu closure kapsamında ayrıca doğrulanmadı.
4. SIDE-SWAP, pause/resume ve persistence için ayrı final-run kanıtı sabitlenmedi.

## Closure Kararı

Ciddi invalid-posture false-positive yolu exercise-specific `supportStacking` hardening ile kapatıldı. Doğru forearm Side Plank fix sonrası gerçek cihazda yeniden acquire edilerek `best_hold_seconds = 6` üretti. Son run'da exception oluşmadı ve provisional performans gate'leri karşılandı.

Açık robustness finding'ler ve execution sapmaları yukarıda açıkça tutulur.

**Final karar: `Side Plank = R6 Engineering Revalidated`, follow-up deferred.**
