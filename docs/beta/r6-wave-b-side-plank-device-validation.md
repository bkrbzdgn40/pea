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

Required hold signals:

```text
alignment
support
extension
```

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

Form-break doğrudan zorunlu hold sinyallerinden gelir:

```text
alignment bozulması
support angle bozulması
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
