# R6 Wave C - Bench Dip Validation Results

> **Tarihsel kayıt:** Bu belge ait olduğu eski beta commit/validation turunu açıklar; güncel build durumunu tek başına belirlemez. Güncel hareket çalışma gerçeği için `docs/current_exercise_validation_matrix.md` dosyasını kullanın.

Bu belge internal exercise ID'si `triceps_dip` olarak korunan Bench Dip için gerçek cihaz validation sırasında bulunan blocker failure'ı, scope-conversion geçmişini, neden mevcut turda fixlenmediğini ve yeniden açılma kriterlerini kalıcı olarak kaydeder.

## 1. Güncel Durum

```text
Display / canonical scope: Bench Dip
Stable internal ID: triceps_dip

Status: R6 Validation Blocked / Deferred
Engineering Revalidated: No
Formal protocol-complete: No
```

Bu durum PASS değildir. Bench Dip engineering revalidation toplamına dahil edilmez.

## 2. Scope Conversion Geçmişi

İlk formal cihaz run'ı hareketi legacy parallel-bar-oriented contract ile değerlendirmiştir:

```text
app_commit_sha = 3270aa9ff66f0d5010d7a6a58c81d176f8f69ed5

acquireNeutral = 1
startDescending = 6
reachPeak = 0
abortToNeutral = 6
rep_count = 0
```

Video incelemesi kullanıcının bench/chair dip yaptığını ve doğal kontrollü alt pozisyonların yaklaşık `91°-96°` elbow-angle bandında örneklendiğini göstermiştir.

Product scope daha sonra canonical **Bench Dip** olarak değiştirilmiştir. Stable internal ID `triceps_dip` persistence/history uyumluluğu için korunmuştur.

Production config scope dönüşümünde:

```text
thresholdNeutral = 150°
thresholdActive = 130°

legacy thresholdPeak = 90°
legacy effective strict peak = <87°

Bench Dip thresholdPeak = 100°
Bench Dip effective strict peak = <97°
targetMinAngle = 90°
```

olarak hizalanmıştır.

Deterministik regression, yaklaşık-90° valid bottom path'in completed rep üretebilmesini ve `103°` shallow/partial path'in peak sayılmamasını korur.

## 3. Post-Scope Gerçek Cihaz Failure

Issue ID:

```text
R6-TD-001
Sparse-sampling / phase-transition peak loss
Severity: Validation blocker
Disposition: Deferred
```

Scope conversion sonrası SHA-pinned profile run:

```text
app_commit_sha = c39bee097b8860ef807fd74a6ea7c64b5322c709
build_mode = profile
exercise_type = triceps_dip

rep_count = 0

acquireNeutral = 1
startDescending = 3
reachPeak = 0
startAscending = 0
abortToNeutral = 2

range_rep_validation_count = 0
```

Diagnostics snapshot üçüncü hareket girişimi tamamlanmadan alınmıştır; bu nedenle 3 `startDescending` ve 2 `abortToNeutral` sayısı kendi içinde tutarlıdır.

Video incelemesinde UI overlay üzerinde kontrollü bottom bölgelerinde yaklaşık:

```text
96°
90°
```

primary elbow-angle örnekleri görülmüştür.

Bench Dip scope'undaki effective strict peak gate:

```text
primaryMetric < 97°
```

olduğundan bu örnekler en azından peak-entry geometrisini karşılayan sample'ların production run sırasında mevcut olduğunu gösterir.

Buna rağmen diagnostics:

```text
reachPeak = 0
```

olarak kalmıştır.

Bu nedenle post-scope failure yalnız threshold veya gerçek ROM yetersizliği ile açıklanmaz.

## 4. Pose / Side Bulgusu

Post-scope run:

```text
detected_pose_frame_count = 63
accepted_pose_frame_count = 62
rejected_pose_frame_count = 0
low_confidence_pose_frame_count = 0
analysis_exception_count = 0

side_switch_count = 2
active_rep_side_switch_count = 0
active_rep_resync_count = 0
resync_count = 0
```

Bu kanıt, ana counting failure'ın pose rejection veya active-rep side switching ile açıklanmasını desteklemez.

## 5. Temporal / Performance Bulgusu

Post-scope run:

```text
camera_fps_p50 = 20.6897
analysis_fps_p50 = 3.8278

frame_processing_ms_p50 = 170
frame_processing_ms_p95 = 473
frame_processing_ms_max = 1468

reentrant_drop_count = 274
```

Bu değerler provisional performans gate'lerinin belirgin biçimde dışındadır.

Sparse analysis sampling altında aynı physical sample hem active-entry hem peak-entry koşullarını karşılayabilir. Generic lifecycle mevcut phase transition'ını onayladığında aynı sample bir sonraki phase için yeniden değerlendirilmezse, peak sample'ı `startDescending` geçişinde tüketilip sonraki analysis update gelene kadar kullanıcı return phase'e geçmiş olabilir.

Post-scope video + diagnostics şu root area'yı açar:

```text
sparse analysis sampling
+
multi-stage generic range-rep lifecycle
+
one confirmed phase transition per analysis update
=
valid peak sample can be lost between phases
```

Bu problem ailesi Jumping Jack'teki fast-motion acquisition failure ile akrabadır; ancak Bench Dip'te effective peak gate'i geçen UI-overlay sample'larının gözlenmesi nedeniyle temporal phase-transition kaybı daha doğrudan görünür hale gelmiştir.

## 6. Neden Şimdi Fixlenmedi?

Şu değişiklikler özellikle yapılmamıştır:

```text
thresholdPeak'i daha da gevşetmek
minAcceptableRomDelta'yı düşürmek
form/setup threshold'larını değiştirmek
```

Çünkü post-scope run'da `<97°` gate'i karşılayan sample'lar zaten görülmüştür.

Potansiyel çözüm alanları:

1. Generic range-rep lifecycle'ın aynı analysis sample'ında ardışık phase koşullarını güvenli biçimde değerlendirmesi.
2. Confirmed active-entry sample'ı peak-range içindeyse peak evidence'ın sonraki phase'e taşınması.
3. Exercise-specific temporal accumulator / pending-peak adapter.
4. Analysis pipeline throughput ve reentrant-drop davranışının iyileştirilmesi.

İlk iki seçenek daha önce `R6 Engineering Revalidated` olmuş range-rep hareketlerde regression riski taşır ve geniş retest borcu doğurabilir.

Üçüncü seçenek yeni exercise-specific temporal contract tasarımıdır.

Dördüncü seçenek ayrı performance/analysis-pipeline çalışmasıdır.

Bu nedenle mevcut validation turunda Bench Dip bilinçli olarak deferred bırakılmıştır.

## 7. Reopen / Acceptance Criteria

Bench Dip yeniden açıldığında minimum kabul matrisi:

```text
PREFLIGHT
- valid bench-dip bottom peak acquire edilmeli
- completeRep > 0

POS-20
- 20 kontrollü tam Bench Dip
- count ground truth ile uyumlu
- sistematik missed peak yok

STATIC-30
- top-support neutral pozisyonda 0 phantom rep

PARTIAL-10
- shallow 100°+ bottom girişimleri completed rep üretmemeli

SIDE-2x5
- iki fiziksel tarafta selected-side counting güvenilir olmalı

FORM
- shoulder-depth technique feedback counting validity'den ayrı değerlendirilir

LIFE
- pause sırasında phantom count yok
- resume sonrası temiz neutral reacquire

PERSIST
- Live / Summary / History count tutarlı
```

Fix sonrası diagnostics'te:

```text
reachPeak > 0 on valid repetitions
completeRep > 0 on valid repetitions
abortToNeutral predominantly limited to real partial attempts
analysis_exception_count = 0
```

aranır.

Temporal lifecycle fix'i generic engine seviyesinde yapılırsa revalidated range-rep exercise setinde regression etkisi ayrıca değerlendirilir.

## 8. Yeni Sohbet İçin Devam Notu

Bu dosya mevcutsa Bench Dip'i `Validation Pending` gibi sıfırdan ele alma.

Doğru durum:

```text
Bench Dip = known temporal lifecycle blocker, intentionally deferred
```

Scope dönüşümü tamamlanmıştır:

```text
display scope = Bench Dip
stable internal ID = triceps_dip
```

Threshold'u tekrar legacy bar-dip değerine döndürme ve post-scope failure'ı salt ROM yetersizliği olarak sınıflandırma.

Önce `R6-TD-001` bulgusunu ve generic lifecycle / analysis throughput ilişkisini incele.

Aktif exercise-validation sırası Bench Dip'ten sonra **Glute Bridge** ile devam eder.
