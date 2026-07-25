# R6 Wave C - Sit-up Validation Results

> **Tarihsel kayıt:** Bu belge ait olduğu eski beta commit/validation turunu açıklar; güncel build durumunu tek başına belirlemez. Güncel hareket çalışma gerçeği için `docs/current_exercise_validation_matrix.md` dosyasını kullanın.

Bu belge Sit-up gerçek cihaz validation sırasında bulunan orientation-dependent neutral-acquisition blocker'ını, neden mevcut turda fixlenmediğini ve yeniden açılma kriterlerini kalıcı olarak kaydeder.

## 1. Güncel Durum

```text
Status: R6 Validation Blocked / Deferred
Engineering Revalidated: No
Formal protocol-complete: No
```

Bu durum PASS değildir. Sit-up engineering revalidation toplamına dahil edilmez.

## 2. Ana Failure

Issue ID:

```text
R6-SU-001
Orientation-dependent neutral acquisition / image-plane primary metric
Severity: Validation blocker
Disposition: Deferred
```

Production contract:

```text
camera = side preferred
sideMode = selectedSide
primaryMetricKind = imagePlaneInclination
primaryMetricDirection = decreasingToPeak

neutral = 120°
active = 113°
peak = 83°
```

Sit-up primary metriği selected shoulder -> selected hip segmentinin image-plane orientation'ından türetilir.

Gerçek cihaz/video validation'da kullanıcı doğru fiziksel sırtüstü Sit-up başlangıcını ve Sit-up hareketini uyguladığı halde lifecycle neutral pozisyonu acquire edememiştir.

İkinci SHA-pinned profile evidence run:

```text
app_commit_sha = 53904154b61f0f9355722c043e110330808269d4
build_mode = profile
exercise_type = sit_up

rep_count = 0
range_rep_transition_count = 0
range_rep_validation_count = 0
range_rep_abort_count = 0

current_phase = WAITING
```

Bu failure completed-rep validation katmanında değildir. Engine ilk neutral acquisition aşamasından range-rep lifecycle'a geçememiştir.

## 3. Pose ve Side Bulgusu

İkinci run:

```text
detected_pose_frame_count = 364
accepted_pose_frame_count = 296
rejected_pose_frame_count = 0
low_confidence_pose_frame_count = 0
invalid_pose_geometry_frame_count = 0
analysis_exception_count = 0

side_switch_count = 8
active_rep_side_switch_count = 0
active_rep_resync_count = 0
```

Session boyunca visibility/resync olayları bulunmasına rağmen yüzlerce accepted pose frame içinde tek bir range-rep transition oluşmaması, ana failure'ın yalnız pose rejection veya active-rep side switching ile açıklanamayacağını gösterir.

## 4. Orientation Kanıtı ve Root Area

Kullanıcı ikinci evidence videosunda telefonu fiziksel olarak yatay tuttuğunu açıkça doğrulamıştır.

Aynı diagnostics:

```text
sensor_orientation_degrees = 90
device_orientation = portraitUp
```

kaydetmiştir.

Production camera frame conversion yolu ML Kit `InputImage` rotation metadata'sını `sensorOrientation` üzerinden üretir. `deviceOrientation` diagnostics'e kaydedilir ancak `InputImageConverter.convert(...)` çağrısının rotation girdisi değildir.

Sit-up primary metriği image-plane eksenlerine bağlı olduğundan, fiziksel cihaz/video orientation ile analiz koordinatlarının canonical orientation'ı arasında uyumsuzluk bulunması neutral metric topolojisini değiştirebilir.

Bu kanıt aşağıdaki root area'yı yeterince güçlü biçimde açar:

```text
camera/device orientation normalization
+
pose image-plane coordinate interpretation
+
Sit-up imagePlaneInclination primary metric
```

Ancak bu belge kesin fix katmanının yalnız converter, yalnız metric veya yalnız UI orientation state olduğunu iddia etmez. Bu ayrım ayrı mimari inceleme ve regression testi gerektirir.

## 5. Neden Threshold Değiştirilmedi?

Şu değişiklikler özellikle yapılmamıştır:

```text
neutralThreshold lowering
activeThreshold lowering
peakThreshold lowering
```

Çünkü orientation değiştiğinde aynı fiziksel torso geometrisinin image-plane metriği farklı eksen topolojisinde yorumlanması mümkünse threshold tuning yalnız bir orientation'ı yamayıp diğerini bozabilir.

Threshold değişikliği gerçek root cause'u maskeleyebilir.

## 6. Neden Şimdi Fixlenmedi?

Güvenli çözüm seçenekleri şunları içerebilir:

1. Pose koordinatlarını exercise metric extraction öncesinde canonical orientation'a normalize etmek.
2. Camera sensor + device orientation + lens direction ilişkisini ML Kit input rotation yolunda açıkça çözmek.
3. Sit-up primary metric'ini orientation-invariant bir geometric representation'a taşımak.
4. Sit-up özelinde orientation-aware metric adapter eklemek.

İlk iki seçenek camera/pose pipeline seviyesinde daha geniş regression yüzeyine sahiptir.

Üçüncü ve dördüncü seçenek Sit-up contract ve deterministic production testlerinin yeniden tasarlanmasını gerektirir.

Bu nedenle mevcut validation turunda Sit-up bilinçli olarak deferred bırakılmıştır.

## 7. Reopen / Acceptance Criteria

Sit-up yeniden açıldığında minimum kabul matrisi:

```text
ORIENTATION-PREFLIGHT
- desteklenen cihaz orientation'larında doğru fiziksel Sit-up neutral pozisyonu acquire edilmeli
- aynı fiziksel başlangıç orientation nedeniyle AWAITING_NEUTRAL/WAITING'de kilitlenmemeli

POS-20
- 20 kontrollü tam Sit-up
- count ground truth ile uyumlu

STATIC-30
- doğru neutral pozisyonda 0 phantom rep

PARTIAL-10
- sığ curl-up completed rep üretmemeli

SETUP-ROBUSTNESS
- makul diz bükümü / ayak mesafesi primary torso counting'i bloklamamalı

LIFE
- pause sırasında phantom count yok
- resume sonrası temiz neutral reacquire

PERSIST
- Live / Summary / History count tutarlı
```

Fix sonrası diagnostics'te en az:

```text
acquireNeutral > 0
reachPeak > 0 on valid repetitions
completeRep > 0 on valid repetitions
analysis_exception_count = 0
```

aranır.

Orientation normalization fix'i pipeline seviyesinde yapılırsa daha önce revalidated image-plane measurement kullanan davranışlar için regression etkisi ayrıca değerlendirilir.

## 8. Yeni Sohbet İçin Devam Notu

Bu dosya mevcutsa Sit-up'ı `Validation Pending` gibi sıfırdan ele alma.

Doğru durum:

```text
Sit-up = known orientation-dependent blocker, intentionally deferred
```

Önce `R6-SU-001` bulgusunu oku.

Doğru fiziksel Sit-up başlangıcı test edilmiştir; kullanıcı formunu yeniden suçlamadan önce camera/device orientation normalization ve image-plane primary metric zincirini incele.

Aktif exercise-validation sırası Sit-up'tan sonra **Bench Dip** ile devam eder.
