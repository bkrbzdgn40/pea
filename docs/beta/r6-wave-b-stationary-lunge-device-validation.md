# R6 Wave B - Stationary Lunge Device Validation

Bu protokol R6 Dalga B kapsamında `Stationary Lunge` exercise-specific gerçek cihaz validation'ını tanımlar.

Shared visibility/occlusion davranışı ortak reliability validation kapsamında daha önce doğrulandığı için per-exercise occlusion varsayılan olarak tekrarlanmaz.

## 1. Production Contract

Production kaynaklarına göre Stationary Lunge:

```text
camera = side preferred
front = unsupported
sideMode = selectedSide
primaryMetricDirection = decreasingToPeak
primaryMetric = hip -> knee -> ankle
poseAcceptanceRequiredSignals = primaryMetric
minAcceptableRomDelta = 20°
```

Config:

```text
thresholdNeutral = 160°
thresholdActive = 145°
thresholdPeak = 115°
formThreshold = 0°
targetMinAngle = 100°
```

Exercise guide setup contract'ı:

```text
keep the leg closest to the camera in front
```

Bu nedenle formal device run'larda kameraya yakın bacak ön bacak olacak şekilde sabit split stance kullanılmalıdır.

## 2. Counting ve Alternating Sidecar Ayrımı

Stationary Lunge runtime'da iki ayrı katman kullanır:

1. Ana session rep sayımı: `selected-side rangeRep`
2. Left/right symmetry metrikleri: ayrı `AlternatingRepEngine` sidecar

Ana `state.repCount` selected-side coordinator tarafından üretilir. Alternating sidecar ana rep sayımını sürmez; left/right rep ve symmetry/asymmetry session metriklerini besler.

Bu nedenle validation'da:

- counting doğruluğu,
- side selection,
- left/right symmetry sidecar davranışı

aynı şeymiş gibi raporlanmaz.

## 3. Form-Signal Sınırı

Mevcut Stationary Lunge config'inde:

```text
formThreshold = 0°
```

ve ayrı bir exercise-specific technique form metriği tanımlı değildir.

Dolayısıyla bu dalgada generic bir `FORM` testi ile:

- knee valgus,
- trunk tilt,
- balance,
- front-knee tracking

algılanıyormuş gibi kanıt üretilmez.

Negatif counting kapıları:

```text
STATIC
PARTIAL / INVALID-ROM
```

olacaktır.

## 4. Threshold Tuning Kuralı

İlk gerçek cihaz videosunda tek gözleme göre threshold değiştirilmez.

Önce şu sınıflandırma yapılır:

1. side-view framing,
2. kameraya yakın ön bacak setup'ı,
3. hip/knee/ankle landmark coverage,
4. selected-side kararlılığı,
5. primary knee-angle lifecycle,
6. tekrarlanan gerçek ROM failure.

Threshold değişikliği için mümkün olduğunca kod/contract gerekçesi, birden fazla tekrar/koşul ve negatif test korumasından en az iki kanıt aranır.

## 5. Hızlandırılmış Validation Matrisi

| Run ID | Senaryo | Uygulama | PASS kriteri |
| --- | --- | --- | --- |
| `R6-SL-PREFLIGHT-1` | Preflight | Side view, kameraya yakın bacak önde, 1 kontrollü tam Stationary Lunge | Natural top neutral acquire olur; 1 tam down/up lifecycle = 1 rep |
| `R6-SL-POS-20` | Positive counting | Aynı sabit split stance'ta 20 kontrollü tam tekrar | Ground truth ile app count eşleşir; duplicate/phantom rep yok |
| `R6-SL-STATIC-30` | Static negative | Yaklaşık 30 sn sabit split stance / top pozisyon | `rep_count = 0` |
| `R6-SL-PARTIAL-10` | Partial / invalid ROM | 10 sığ lunge denemesi; gerçek alt pozisyona inmeden geri dön | Completed rep üretilmez |
| `R6-SL-SIDE-SWAP` | Opposite-side sanity | 5 tekrar bir side-view yönünde; sonra vücut yönünü değiştirip diğer fiziksel taraf kameraya yakın olacak şekilde 5 tekrar | Ana toplam count her iki blokta da güvenilir çalışır; selected-side kilitlenip kaybolmaz |
| `R6-SL-LIFE` | Pause/resume | Rep seti içinde kontrollü pause/resume | Pause sırasında phantom rep yok; resume sonrası temiz reacquire |
| `R6-SL-PERSIST` | Persistence | Ölçülebilir rep setiyle session bitir | Live/Summary/History aynı persisted total rep değerini gösterir |

`OCC` **SKIPPED - covered by shared reliability validation**.

## 6. Symmetry Sidecar Gözlemi

`R6-SL-SIDE-SWAP` sırasında şu alanlar ayrıca gözlenmelidir:

```text
leftRepCount
rightRepCount
symmetry
asymmetryScore
selectedRangeRepSide
```

Ancak left/right sidecar değerleri gerçek lead-leg semantiğiyle açıkça uyuşmadan yalnızca toplam counting PASS olduğu için symmetry doğruluğu PASS ilan edilmez.

Gerçek side-view lunge'da iki diz de hareket edebildiği için sidecar'ın hangi fiziksel tarafı aktif rep olarak sınıflandırdığı özellikle gözlenmelidir. Burada tutarsızlık bulunursa ana counting ile ayrı bir reliability finding olarak ele alınır.

## 7. İlk Cihaz Adımı

İlk çalışma:

```text
R6-SL-PREFLIGHT-1
```

Setup:

```text
side view
kameraya yakın bacak önde
ayaklar sabit split stance
1 kontrollü tam tekrar
```

İlk run'da mümkünse şu değerleri not et:

```text
top knee angle
bottom knee angle
selected side
rep_count
unexpected visibility / low-confidence feedback
```

Amaç ilk videoda calibration yapmak değil, production contract'ın gerçek geometriyle uyumlu olup olmadığını doğrulamaktır.

## 8. Closure Kriteri

Stationary Lunge şu ana counting kapıları geçildiğinde `R6 Engineering Revalidated` statüsüne aday olur:

1. preflight,
2. positive counting,
3. static negative,
4. partial / invalid-ROM rejection,
5. opposite-side sanity,
6. pause/resume lifecycle safety,
7. persistence.

Dedicated technique metriği olmadığı için form-analysis doğruluğu bu closure'ın kanıt kapsamına dahil edilmez.

Symmetry sidecar'da gerçek cihaz finding'i çıkarsa, finding'in ana counting'i bloke edip etmediği ayrıca sınıflandırılır; summary'de yanlış left/right/asymmetry üretimi doğrulanırsa ayrı reliability bug olarak kapatılmadan symmetry capability doğrulanmış sayılmaz.

## 9. Device Finding - Confirmation-Lag ROM Underestimation

İkinci gerçek cihaz run'ında ana lifecycle `10` completed rep üretirken validation dağılımı:

```text
valid = 6
invalid = 3
lowConfidence = 1
insufficientRom = 3
excessiveDescentSpeed = 1
```

olarak gözlendi.

Kod incelemesinde `startTowardPeak` debounce confirmation sırasında ROM başlangıç metriğinin ilk active-threshold crossing frame'inden değil, yaklaşık 80 ms sonra transition'ın confirm edildiği frame'den alındığı doğrulandı. Düşük/orta analysis FPS ve hızlı inişte confirmation frame'i peak'e çok yaklaşabildiği için gerçek full-ROM hareketin `primaryRom` değeri yapay olarak küçülebiliyordu.

Fix yaklaşımı:

- threshold değiştirilmedi,
- `minAcceptableRomDelta = 20°` korunuyor,
- generic lifecycle ilk kesintisiz active-crossing metriğini confirmation boyunca koruyor,
- completed-rep detection `startAngle` ve `primaryRom` için canonical `GenericRepCompletedRep` verisini kullanıyor,
- regression testleri confirmation gecikmesi sırasında 140° -> 108° -> 90° ilerleyen full-ROM lunge benzeri akışı kapsıyor.

Fix sonrası formal retest'te özellikle:

```text
R6-SL-POS-20
R6-SL-PARTIAL-10
```

tekrar çalıştırılmalıdır. Positive run'da sahte `insufficientRom` oranının kaybolması, partial run'da ise gerçek sığ hareketlerin hâlâ reddedilmesi beklenir.

