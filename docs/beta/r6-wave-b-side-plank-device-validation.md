# R6 Wave B - Side Plank Device Validation

Bu protokol R6 Dalga B kapsamında `Side Plank` exercise-specific gerçek cihaz validation'ını tanımlar.

Shared hold visibility/occlusion davranışı merkezi reliability validation kapsamında doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Side Plank:

```text
tracking = hold
family = sidePlank
camera = front preferred
side = unsupported
```

Required extracted hold signals:

```text
alignment
support
extension
```

Side Plank ayrıca exercise-specific derived validation sinyali kullanır:

```text
supportStacking
```

`supportStacking`, selected-side `shoulder -> elbow` segmentinin görüntü düzlemindeki normalize dikey bileşenidir. Pozitif değer dirseğin omuzun altında olduğunu gösterir. Hold validity için segmentin en az yatay kadar dikey olması gerekir (`>= 1/sqrt(2)`).

Config:

```text
activePostureAngle = 155°
bodyLineEntryAngle = 165°
bodyLineSustainAngle = 162°
armSupportMinAngle = 60°
armSupportMaxAngle = 120°
legExtensionMinAngle = 160°
breakGraceMillis = 350
```

Geometri:

```text
alignment = shoulder -> hip -> ankle
support = shoulder -> elbow -> wrist
extension = hip -> knee -> ankle
```

Hold contract bu üç sinyali detection + validation için zorunlu tutar.

## 2. Kamera ve Setup

Catalog contract:

```text
front = preferred
side = unsupported
```

Exercise guide kameranın gövdenin önünden veya arkasından body line'ı görecek şekilde konumlandırılmasını ister.

Formal validation için varsayılan setup:

```text
front-view
tüm gövde kadrajda
destek omzu-dirsek-bilek görünür
kalça-diz-ayak bileği görünür
```

Yan açıyla formal PASS verilmez.

## 3. Form / Break Semantiği

Side Plank için ayrı exercise-specific technique analyzer yoktur.

Form-break / hold rejection şu validity sinyallerinden gelir:

```text
alignment bozulması
support angle bozulması
support stacking bozulması
leg extension bozulması
```

Bu nedenle deliberate invalid-posture testinde bu üç family'den en az biri kontrollü biçimde bozulmalıdır.

Önerilen en temiz form-break:

```text
kalçayı belirgin şekilde aşağı bırak
```

Bu, shoulder-hip-ankle alignment sinyalini bozmayı hedefler.

İkinci sanity varyasyonu olarak destek dirseğini omuz altından belirgin şekilde kaçırmak veya dizi bükmek kullanılabilir; ancak closure için tek temiz ve tekrarlanabilir break yeterlidir.

## 4. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-SPL-PREFLIGHT-1` | Preflight | Front view, 5-10 sn temiz Side Plank | Hold acquire olur, saniye artar, yanlış blocking feedback yok |
| `R6-SPL-VALID-30` | Valid hold | 30 sn kontrollü Side Plank | Hold sürekliliği korunur; yaklaşık ground-truth süre ölçülür |
| `R6-SPL-FORM-BREAK` | Invalid posture | Aktif hold sırasında kalçayı belirgin düşür | Grace sonrası aktif hold kırılır/sıfırlanır veya uygun invalid feedback üretilir |
| `R6-SPL-SIDE-SWAP` | Opposite-side sanity | Sol fiziksel taraf ve sağ fiziksel taraf için ayrı kısa hold | Her iki tarafta da hold acquire olabilir; tek tarafa kilitli görünürlük/selection bug yok |
| `R6-SPL-LIFE` | Pause/resume | Aktif hold içinde pause/resume | Hidden time eklenmez; resume sonrası temiz reacquire davranışı |
| `R6-SPL-PERSIST` | Persistence | Ölçülebilir completed/best hold ile session bitir | Live/Summary/History persisted hold değeri uyumlu |

`OCC` **SKIPPED - covered by shared reliability validation**.

## 5. Side-Swap Neden Ayrı Kapı?

Side Plank unilateral bir egzersizdir. Config sinyalleri nominal olarak left-landmark isimleriyle tanımlansa da runtime hold side-selection/mirroring katmanı accepted pose quality'ye göre fiziksel taraf seçebilir.

Bu nedenle yalnız tek fiziksel tarafta PASS almak, opposite-side runtime davranışını kanıtlamaz.

`SIDE-SWAP` run'ında amaç skor veya symmetry ölçmek değil, iki tarafta da:

```text
pose accepted
hold side selected
valid hold acquired
```

olduğunu doğrulamaktır.

## 6. Threshold Tuning Kuralı

Tek kişi veya tek run nedeniyle threshold değiştirilmez.

İlk failure şu sırayla sınıflandırılır:

1. camera contract / framing,
2. selected hold side,
3. landmark visibility,
4. alignment/support/extension sinyal geometrisi,
5. hold lifecycle / grace,
6. tekrarlanan gerçek threshold mismatch.

Exercise-specific tekrar eden kanıt olmadan generic hold engine değiştirilmez.

## 7. İlk Cihaz Adımı

İlk run:

```text
R6-SPL-PREFLIGHT-1
```

Setup:

```text
front view
tüm gövde görünür
bir fiziksel tarafta temiz Side Plank
5-10 saniye
```

Gözlenecekler:

```text
current hold seconds
selected hold side
alignment signal
support signal
extension signal
unexpected feedback
```

İlk run başarılıysa doğrudan `VALID-30` ve `FORM-BREAK` ile devam edilir.

## 8. Closure Kriteri

Side Plank şu kapılarla `R6 Engineering Revalidated` statüsüne aday olur:

1. valid hold,
2. deliberate form-break,
3. opposite-side sanity,
4. pause/resume lifecycle,
5. persistence.

Per-exercise occlusion tekrar edilmez; yalnız Side Plank'e özgü visibility regression görülürse yeniden açılır.

## 9. Preflight False-Positive Finding ve Hardening

İlk gerçek cihaz kanıtında pose visibility son derece temiz olmasına rağmen ciddi biçimde geçersiz bir yan-yatma / yanlış destek pozisyonu yaklaşık 5 saniyelik hold olarak kabul edildi. İlgili diagnostics snapshot'ta:

```text
best_hold_seconds = 5
detected_pose_frame_count = 243
accepted_pose_frame_count = 242
rejected_pose_frame_count = 0
low_confidence_pose_frame_count = 0
analysis_exception_count = 0
```

Bu nedenle failure visibility veya landmark confidence kaynaklı değil, hold validity contract boşluğu olarak sınıflandırıldı.

Kök neden:

```text
support = shoulder -> elbow -> wrist angle
```

tek başına destek kolunun gerçekten zemine doğru ve omuz altında konumlandığını kanıtlamıyordu. Seçilen tarafta yere temas etmeyen üst kol yaklaşık uygun elbow angle üretebildiği için body-line + support-angle + leg-extension kombinasyonu false hold başlatabiliyordu.

Exercise-specific fix:

```text
supportStacking = signed vertical component of shoulder -> elbow
normalized by shoulder-elbow length

valid when:
supportStacking >= 1 / sqrt(2)
```

Bu gate şu iki koşulu birlikte ister:

1. selected support elbow görüntü düzleminde omuzun altında olmalı,
2. shoulder-elbow segmenti en az yatay kadar dikey olmalı.

Side Plank side selection da accepted iki taraf arasında yalnız landmark quality'ye bakmaz; support-stacking kanıtı daha güçlü olan fiziksel tarafı tercih eder. Böylece görünürlüğü yüksek fakat yere destek vermeyen üst kolun seçilmesi engellenir.

Eşik tek kullanıcı videosuna göre kalibre edilmedi. `1/sqrt(2)` geniş bir 45° vertical-dominance geometrik sınırıdır. Generic hold lifecycle ve mevcut angular threshold'lar değiştirilmedi. `supportStacking` validity içindir; stability örneklemesi mevcut required hold sinyalleriyle sınırlandırıldığı için Side Plank stability skoruna yeni bir boyut olarak eklenmez.

Regression kapsamı:

```text
VALID: elbow directly below shoulder -> hold may start
INVALID: elbow above shoulder while legacy angles remain valid -> hold must not start
INVALID: missing stacking evidence -> hold must not start
```

Fix sonrası `R6-SPL-PREFLIGHT-1` ve `R6-SPL-FORM-BREAK` gerçek cihazda yeniden çalıştırılmalıdır. Diagnostics export'ta `supportStacking` current/target/validity değerleri ayrıca tutulur.

## Feedback Semantics Hardening

Side Plank support failures artık tek bir generic `adjust_elbow_support` mesajına sıkıştırılmaz.

Exercise-specific feedback kodları korunur ancak kullanıcıya gösterilen copy iki geçerli support varyasyonunu da kapsar.

İkinci gerçek cihaz incelemesinde generic `Side Plank` egzersizinin forearm-only kabul edilmesinin yanlış bir ürün contract daraltması olduğu görüldü. Side Plank artık iki stabil support mode'u kabul eder:

```text
FOREARM SUPPORT
support angle = configured 60°-120° band

STRAIGHT-ARM / HAND SUPPORT
support angle >= midpoint(configured forearm max, anatomical full extension)
              >= (120° + 180°) / 2
              >= 150°
```

`150°` sınırı cihazdaki tek kareye göre kalibre edilmedi; mevcut forearm üst sınırı ile anatomik tam ekstansiyonun orta noktası olarak türetilir. İki mod arasında kalan kısmi bükülü support açısı geçersiz bırakılır. Her iki mod da `supportStacking` gate'ini geçmek zorundadır; dolayısıyla ilk false-positive'i kapatan support-side geometri koruması kaldırılmaz.

User-facing feedback de varyasyon bağımsız hale getirildi:

```text
supportStacking invalid
-> "Desteğini omzunun altında hizala."

stable support mode invalid
-> "Ön kol desteği kullan veya destek kolunu tamamen düzleştir."
```

Regular Plank için mevcut `adjust_elbow_support` davranışı değiştirilmez.

## 10. Closure Status

Side Plank cihaz validation'ı kritik invalid-posture false-positive'in `supportStacking` hardening ile kapatılması ve doğru forearm Side Plank'in fix sonrası yeniden hold acquire etmesi temelinde tamamlanmıştır.

Final status:

```text
R6 Engineering Revalidated
follow-up = deferred
formal protocol-complete = no
```

Ayrıntılı closure ve execution sapmaları:

```text
docs/beta/r6-wave-b-side-plank-results.md
```

SIDE-SWAP, LIFE ve PERSIST ayrı final-run kanıtları olarak sabitlenmediği için bu protokolün bütün planlı satırlarının PASS olduğu iddia edilmez.

