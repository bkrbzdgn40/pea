# R6 Wave C - Jumping Jack Validation Results

Bu belge Jumping Jack için gerçek cihaz validation sırasında bulunan blocker failure'ı, neden mevcut turda fixlenmediğini ve yeniden açılma kriterlerini kalıcı olarak kaydeder.

## 1. Güncel Durum

```text
Status: R6 Validation Blocked / Deferred
Engineering Revalidated: No
Formal protocol-complete: No
```

Bu durum PASS değildir. Jumping Jack, engineering revalidation toplamına dahil edilmez.

## 2. Kanıtlanan Ana Failure

Issue ID:

```text
R6-JJ-001
Fast-motion peak acquisition false-negative
Severity: Validation blocker
Disposition: Deferred
```

SHA-pinned profile gerçek cihaz run'ı:

```text
app_commit_sha = da18509861ff73309fd8fde2d00384a230341d8f
build_mode = profile
exercise_type = jumping_jack

rep_count = 0

acquireNeutral = 1
startDescending = 2
reachPeak = 0
startAscending = 0
abortToNeutral = 2

range_rep_validation_count = 0
```

Video incelemesinde birden fazla belirgin open-close Jumping Jack döngüsü görünmesine rağmen lifecycle hiçbir `reachPeak` transition'ı doğrulamamıştır.

Bu nedenle failure completed-rep validation veya persistence katmanında değildir. Engine completed rep üretemeden önce peak acquisition aşamasında başarısız olmuştur.

## 3. Pose / Visibility Bulgusu

Aynı run:

```text
detected_pose_frame_count = 96
accepted_pose_frame_count = 95
rejected_pose_frame_count = 0
low_confidence_pose_frame_count = 0
no_pose_frame_count = 0

resync_count = 0
side_switch_count = 0
active_rep_side_switch_count = 0
analysis_exception_count = 0
```

Bu kanıt, sıfır sayımın ana açıklamasının pose rejection, side switching veya visibility recovery olmadığını gösterir.

## 4. Temporal / Performance Bulgusu

Aynı run:

```text
camera_fps_p50 = 21.093
analysis_fps_p50 = 4.8077

frame_processing_ms_p50 = 162
frame_processing_ms_p95 = 568
frame_processing_ms_max = 1537

reentrant_drop_count = 373
```

Jumping Jack hızlı temporal hareket olduğu için seyrek analysis sampling fiziksel peak pozisyonunun analiz örnekleri arasında kaybolmasına neden olabilir.

Production lifecycle ayrıca active-entry ve peak-entry aşamalarını ayrı confirmation adımlarıyla ilerletir. Düşük analysis FPS ile birleştiğinde, fiziksel olarak geçerli bir peak sonraki lifecycle aşaması tarafından hiç gözlenmeden kullanıcının dönüş fazına geçmesi mümkündür.

Bu run tek başına global performance root-cause'u kanıtlamaz; ancak mevcut gerçek cihaz failure ile birlikte Jumping Jack counting güvenilirliği için blocker oluşturur.

## 5. Feedback Semantics Finding

Issue ID:

```text
R6-JJ-002
Neutral-phase leg-spread feedback
Severity: Product / UX correctness
Disposition: Deferred with R6-JJ-001
```

Gerçek cihaz videosunda kullanıcı doğru neutral pozisyonda:

```text
feet closed
arms down
```

iken `Open your legs farther` feedback'i gösterilebilmiştir.

Jumping Jack neutral fazında bacakların kapalı olması beklenen pozisyondur. Bu nedenle leg-spread corrective feedback'in neutral fazda gösterilmesi semantik olarak yanlıştır.

Beklenen gelecekteki davranış:

```text
NEUTRAL
-> no leg-spread corrective feedback

toward-open / peak evaluation
-> leg-spread semantics may be evaluated
```

Bu finding counting false-negative'in doğrudan nedeni olarak sınıflandırılmaz; ayrı phase-aware feedback problemidir.

## 6. Neden Şimdi Fixlenmedi?

Mevcut kanıta göre güvenli çözüm basit threshold tuning değildir.

Şu değişiklikler özellikle yapılmamıştır:

```text
thresholdPeak lowering
formThreshold lowering
min ROM lowering
```

Çünkü videoda bazı fiziksel peak'ler analysis pipeline tarafından yeterince örneklenmemiştir. Birkaç derece threshold gevşetmek kaçırılan bütün peak'leri güvenilir biçimde geri getirmez ve partial/arm-only false-positive riskini artırabilir.

Potansiyel çözüm alanları:

1. Generic multi-stage range-rep lifecycle'ın hızlı hareket acquisition davranışını değiştirmek.
2. Jumping Jack'e özel fast-motion lifecycle / temporal accumulator eklemek.
3. Analysis pipeline throughput ve reentrant-drop davranışını iyileştirmek.
4. Leg-spread feedback'i phase-aware hale getirmek.

İlk seçenek daha önce Engineering Revalidated edilmiş diğer range-rep hareketlerde regression riski taşır. İkinci ve üçüncü seçenekler küçük exercise-threshold fix'i değil, ayrı tasarım/performance çalışmasıdır.

Bu nedenle mevcut validation turunda Jumping Jack bilinçli olarak deferred bırakılmıştır.

## 7. Reopen / Acceptance Criteria

Jumping Jack yeniden açıldığında minimum kabul matrisi:

```text
POS-20
- kontrollü tam 20 Jumping Jack
- count ground truth ile uyumlu
- sistematik missed peak yok

STATIC-30
- neutral pozisyonda 0 phantom rep

PARTIAL-10
- gerçek partial arm excursion completed rep üretmez

ONE-ARM-10
- unilateral arm raise bilateral completed rep üretmez

COORD-10
- arm-only hareket tam valid Jumping Jack olarak sayılmaz
- leg-only hareket primary arm lifecycle üretmez

NEUTRAL FEEDBACK
- feet closed + arms down neutral pozisyonda
  "Open your legs farther" gösterilmez

LIFE
- pause sırasında phantom count yok
- resume sonrası temiz reacquire

PERSIST
- Live / Summary / History count tutarlı
```

Counting fix'i sonrası diagnostics'te ayrıca:

```text
reachPeak > 0 on valid repetitions
completeRep > 0 on valid repetitions
abortToNeutral predominantly limited to real partial attempts
analysis_exception_count = 0
```

aranır.

Performance tekrar ölçülür. Jumping Jack için hızlı peak'lerin güvenilir biçimde acquire edildiği gerçek cihaz kanıtı olmadan closure yapılmaz.

## 8. Yeni Sohbet İçin Devam Notu

Bu dosya mevcutsa Jumping Jack'i `Validation Pending` gibi sıfırdan ele alma.

Doğru durum:

```text
Jumping Jack = known blocker, intentionally deferred
```

Önce `R6-JJ-001` ve `R6-JJ-002` bulgularını oku. Generic engine'i yalnız Jumping Jack'i düzeltmek için doğrudan değiştirmeden önce daha önce revalidated range-rep hareketlerde regression etkisini değerlendir.

Aktif exercise-validation sırası Jumping Jack'ten sonra **Sit-up** ile devam eder.
