# PEA Beta Hardening Baseline

Bu belge, PEA'yı yeni özellik geliştirmeden güvenilir beta hazırlığına
geçirmek için alınmış, kanıta dayalı bir anlık görüntüdür. Runtime sınıfı
**R0**'dır: bu görev üretim, test, CI, Firebase veya yapılandırma davranışını
değiştirmez. Kaynak gerçekliği README yerine commit'teki kod, testler,
workflow'lar ve gerçekten çalıştırılan komutlardan çıkarılmıştır.

## 1. Baseline Kimliği

| Alan | Değer |
| --- | --- |
| Tarih | 12 Temmuz 2026 (`Europe/Istanbul`) |
| Analiz edilen ref | `origin/main` (12 Temmuz 2026 tarihinde `git fetch --prune origin` sonrasında) |
| Analiz edilen commit SHA | `17984be6309a63178f50a7704a565b199f2cf8d6` |
| Testlerin çalıştırıldığı SHA | `17984be6309a63178f50a7704a565b199f2cf8d6`, repo dışındaki temiz `git archive` kopyası |
| Yerel working tree branch / SHA | `main` / `183391e30b6aa31a66463ec4dc70486519d83985` |
| Yerel branch farkı | Fetch sonrasında `HEAD...origin/main = 0 4`: yerel branch 0 ahead, 4 behind |
| Flutter | `3.41.2`, stable, revision `90673a4eef` |
| Dart | `3.11.0` |
| DevTools | `2.54.1` |
| Yerel Java | Temurin OpenJDK `21.0.11` LTS |
| CI Java | Temurin `17` |
| CI workflow | `.github/workflows/flutter-ci.yml` |
| Test kökü | `test/`; kök `integration_test/` yok |

Başlangıçta çalışma ağacı temiz değildi:

```text
 D lib/features/workout_analysis/presentation/providers/pose_detector_notifier.dart
```

Bu kullanıcı değişikliğine dokunulmadı. Dosyanın commit'teki içeriği yalnızca
tek bir newline'dır, repo içinde referansı yoktur ve aktif detector
`pose_provider.dart` içindedir. Bu nedenle silmenin gözlenen runtime veya build
etkisi yoktur. Yine de final `git status` içinde belgeyle birlikte görünmeye
devam edecektir; görevin ürettiği değişiklik yalnızca bu belgedir.

Kirli çalışma ağacını korumak ve format komutunun dosya yazmasını engellemek
için baseline komutları `git archive origin/main` ile oluşturulan geçici,
temiz SHA arşivinde çalıştırıldı. Yerel branch merge/rebase/checkout ile
değiştirilmedi. Repo kökündeki `coverage/lcov.info` başlangıçta vardı,
Git tarafından izlenmiyordu, `.gitignore` ile dışlanmıştı ve önceki güne ait
eski bir sonuçtu. Coverage tablosunda bu eski dosya kullanılmadı; aynı temiz
SHA arşivinde yeni coverage üretildi.

## 2. Beta Kapsamı

### Bugünkü ürün gerçeği

Uygulama Firebase'i UI açılmadan başlatır; kullanıcı yoksa anonim
authentication akışını dener (`lib/main.dart`,
`auth_bootstrap_provider.dart`). Rehberde Squat, Plank, Lunge, Push-up ve
Sit-up görünür. Gerçek canlı analiz seçimi Squat, Plank ve Push-up için
açıktır. Kamera görüntüsü ML Kit ile pose'a dönüştürülür, sonuçlar yerel
engine'lerde işlenir ve bitirilen oturumun özet/rep türev metrikleri kullanıcı
UID'si altında Firestore'a kaydedilir. Ham frame ve landmark'lar traced
persistence payload'ında yoktur.

### Desteklenen egzersizler

- **Squat:** `rangeRep` engine, bilateral taraf seçimi,
  `assets/config/exercises/squat.json` ve `RangeRepContracts.squat`.
- **Plank:** `hold` engine, sol taraf body/arm/leg metrikleri ve
  `assets/config/exercises/plank.json`.
- **Push-up:** `rangeRep` engine, bilateral taraf seçimi,
  `assets/config/exercises/push_up.json` ve `RangeRepContracts.pushUp`.
- **Lunge, Sit-up:** rehber içeriği vardır; analiz desteği yoktur.

Bu destek listesi yalnızca analiz edilen `origin/main` SHA için geçerlidir.
Yerel `main` bu kodu henüz içermediğinden sonraki çalışmalar hem hedef ref'i
hem commit kimliğini yeniden sabitlemelidir.

### Özellik dondurma kontratı

| Beta sürecinde izin verilen | Beta sürecinde yasaklanan |
| --- | --- |
| Kanıt toplama, dokümantasyon ve ölçüm protokolü | Yeni egzersizi `supported` yapmak veya yeni config/contract/engine yolu eklemek |
| Emulator CI, controller test seam'leri, entegrasyon ve cihaz regresyon testleri | Lunge veya Sit-up'ı rehber görünürlüğüne bakarak destekleniyor ilan etmek |
| Davranışı değiştirmeyen gözlemlenebilirlik ve privacy onaylı shadow telemetry | Veri kapısı olmadan threshold, score, smoothing, calibration, side veya pose politikası değiştirmek |
| Release signing, tekrarlanabilir build, Firebase ortam ayrımı, privacy ve veri yaşam döngüsü çalışmaları | Config JSON'larını, dependency'leri veya persistence şemasını bu baseline içinde değiştirmek |
| Ölçüm verisi ve regresyon kanıtından sonra ayrı runtime sınıfıyla güvenilirlik düzeltmeleri | Test skip etmek, CI kapısını gevşetmek veya başarısız kontrolü başarılı raporlamak |
| Güvenlik/rules test kapsamını artırmak | Support matrisini enum veya guide ekranından türetmek |

Bu görevde yukarıdaki gelecekte izin verilen çalışmaların hiçbiri uygulanmadı;
yalnız baseline oluşturuldu.

## 3. Mevcut Runtime Akışı

| # | Aşama | Doğrulanan davranış | Ana kanıt |
| ---: | --- | --- | --- |
| 1 | Kamera frame alımı | Varsayılan ön kamera/düşük kalite; izin kontrolü, tercih edilen lens veya ilk kamera, audio kapalı. `LiveAnalysisScreen` image stream callback'ini controller'a yollar. | `camera_provider.dart:8-67`, `settings_provider.dart:27-31`, `live_analysis_screen.dart:526-553,760-778` |
| 2 | Frame throttling | Her frame kamera FPS sayacına girer. Devam eden analizde frame düşer; analiz başlangıçları arasında en az 100 ms vardır. Hedef üst sınır yaklaşık 10 analiz başlangıcı/sn'dir. | `workout_controller.dart:61-70,161-177` |
| 3 | `CameraImage` dönüşümü | Android yalnız gerçek, tek-plane NV21; iOS yalnız tek-plane BGRA8888 kabul eder. Rotation, raw sensor orientation'dan alınır. Unsupported format, invalid stride/byte veya exception `null` döndürür. | `input_image_converter.dart:7-107` |
| 4 | ML Kit detection | Auto-dispose detector `PoseDetectionModel.base` ve `PoseDetectionMode.stream` kullanır, dispose'da kapanır. | `pose_provider.dart:4-17`, `workout_controller.dart:186-189` |
| 5 | Birden fazla pose | Yalnızca `poses.first` işlenir; diğer kişiler yok sayılır. Listenin kişi sıralama garantisi repo içinden **doğrulanamadı**. | `workout_controller.dart:191-198` |
| 6 | Landmark/metric extraction | Açı hesabı x/y ile 2D'dir; z kullanılmaz. Range-rep extraction config-driven'dır: Squat bilateral hip-knee-ankle primary ve shoulder-hip-knee form; Push-up bilateral shoulder-elbow-wrist primary ve shoulder-hip-ankle form üretir. İki config de posture/depth/alignment/end-range tanımlar. Plank sol body-line, arm-support ve leg-extension üretir. | `angle_calculator.dart:3-22`, `exercise_metrics_extractor.dart`, `squat.json`, `push_up.json` |
| 7 | Eksik landmark | Eksik üçlü `null` olur; side modelinde 180/90 placeholder yanında availability flag `false` kalır. Range-rep contract gereksinimi eksikse engine update bloke edilir. Pose var ama plank metriği eksikse HoldEngine null metrikle güncellenir; pose listesi tamamen boşsa engine hiç güncellenmez. | `exercise_metrics.dart:32-60`, `range_rep_frame_policy.dart:85-146`, `workout_controller.dart:429-475` |
| 8 | Landmark likelihood | `PoseLandmark.likelihood` uygulama kodunda kullanılmaz. `sideConfidence`, ML confidence değil, gerekli landmark varlığı ile signal availability ortalamasıdır. | `exercise_metrics_extractor.dart:90-163`; repo-geneli arama |
| 9 | Range-rep taraf seçimi | Coverage yalnız primary+form availability ile 0–2'dir. Önceki taraf herhangi bir coverage'a sahipse tutulur; alternatif daha yüksek coverage ile kazanır; ilk eşitlikte sol seçilir. | `range_rep_side_policy.dart:60-165` |
| 10 | Side stabilizasyonu | Genel switch varsayılan 2 frame/0,15 margin; aktif rep switch'i 2 frame/0,20 margin. Güçlü aday rep ortasında doğrulanmış switch yapabilir. Production `lockPreviousSide:false` geçirir. | `range_rep_side_stabilizer.dart:4-186`, `workout_controller.dart:501-521` |
| 11 | Smoothing | Primary, form, body, arm ve leg için ayrı 5 örnekli simple moving average vardır. Engine seçilmiş range-rep tarafının smoothed değerlerini alır; UI landmark overlay'i raw kalır. | `moving_average.dart:3-28`, `analysis_frame_builder.dart:5-39`, `workout_controller.dart:78-82,130-134` |
| 12 | Calibration | `CalibrationScreen` yalnız hazırlık talimatıdır. Runtime, geçerli neutral range-rep frame'lerinden otomatik baseline toplar; bu artık Squat ve Push-up için geçerlidir. Accumulator ilk analiz-kind+side'a kilitlenir. En az 3 örnekten sonra form offset'i ±5° clamp edilir; mutlak 0,5° altı uygulanmaz ve side eşleşmelidir. | `calibration_screen.dart:14-19,182-190`, `calibration_snapshot_builder.dart:9-53`, `session_calibration_baseline_accumulator.dart:18-63`, `range_rep_threshold_resolver.dart:5-94` |
| 13 | Visibility kaybı/resync | Yalnız range-rep için 4 invalid frame veya 450 ms invalid süre bir kez resync tetikler. Aktif rep context, primary/form filtreleri, seçili side, stabilizer ve active outcome resetlenir; geçmiş rep/score korunur. Frame hiç gelmezse policy çalışmaz. | `range_rep_visibility_policy.dart:1-86`, `workout_controller.dart:221-306,775-789` |
| 14 | Analysis engine update | Catalog'dan engine/config/contract çözülür. Range factory üç phase ve primary/form contract ister; hold doğrudan yaratılır; `alternatingRep` implement edilmemiştir. Geçerli smoothed/calibrated frame engine'e gider. | `analysis_engine_factory.dart:15-58`, `workout_controller.dart:108-157,309-355` |
| 15 | Rep tamamlama | Squat ve Push-up aynı neutral→descending→peak→ascending→neutral engine'ini farklı config eşikleriyle kullanır. Squat efektif gate'leri yaklaşık `<147°`, `<92°`, `>103°`, `>160°`; Push-up `<132°`, `<92°`, `>103°`, `>165°`; ikisi de 80/80/80/100 ms confirmation kullanır. Aborted descent sayılmaz. Count validation'dan önce artar; completion core data bir kez tüketilir. | `squat.json`, `push_up.json`, `range_rep_engine.dart:10-18,299-571,841-890`, `range_rep_rep_outcome_tracker.dart:62-90` |
| 16 | Hold süresi | Plank entry 168°, sustain 166°, arm 60–120°, leg ≥165°; body-only break grace 300 ms. Süre `DateTime` farkıyla hesaplanır. Pose kaybında engine update edilmediği için eski `_holdStartedAt` yaşamaya devam eder. | `plank.json:6-14`, `hold_posture_policy.dart:27-65`, `hold_engine.dart:77-141` |
| 17 | UI state | Geçerli frame raw landmark, engine output ve diagnostics yayınlar. Invalid range-rep frame engine'i dondurur, count/score'u korur, `isFormBad=false`, `WAITING` ve kadraj feedback'i üretir. No-pose hold UI current hold'u 0 ve `isHolding=false` gösterir, best değeri korur. | `workout_controller.dart:357-475`, `range_rep_blocked_state_builder.dart:27-64`, `live_analysis_screen.dart:555-723` |
| 18 | Rep assembly | `LiveAnalysisScreen` state transition dinler. Pozitif rep delta ve son summary varsa explicit/fallback index ile `WorkoutRep` üretir, rep index ile dedupe eder. `recordedAt`, UI'nin `DateTime.now` değeridir; engine completion timestamp'i değildir. | `live_analysis_screen.dart:95-100,133-243`, `workout_rep.dart` |
| 19 | Session assembly | Session saati ekran `initState` içinde kamera/config hazır olmadan başlar. Rep skorları, form warning edge'leri ve pozitif hold delta'ları ekran state'inde toplanır. Finish, mevcut UID ile `WorkoutSession` oluşturur. | `live_analysis_screen.dart:63-175,361-428` |
| 20 | Firestore persistence | Yol `users/{uid}/sessions/{sessionId}` ve `reps/{repId}` alt koleksiyonudur. Remote source eski rep dokümanlarını okur/siler, summary ve yeni repleri tek batch'e koyar. Session doc rep'leri inline etmez. | `firestore_paths.dart:1-26`, `firestore_session_remote_source.dart:23-55`, Firestore mapper'ları |
| 21 | Hata davranışı | Converter hatası sessiz `null` ve stale UI'dır. Detector/extractor/engine exception'ı yalnız `debugPrint` edilir. Config error retry sunar; izin/lifecycle kamera recovery UI'ı vardır. Save hatası generic snackbar verir; durable queue/otomatik retry yoktur. | `workout_controller.dart:478-482`, `live_analysis_screen.dart:430-444,510-523,725-784` |

### Runtime açısından önemli ayrımlar

- Test edilen `shouldLockRangeRepSideSelection` helper'ı production'da
  çağrılmıyor. Gerçek kontrat “strict rep-side lock” değil, stabilizer ile
  doğrulanmış switch ve outcome'da low-confidence işaretlemesidir.
- Range-rep invalid-frame resync'i yalnız gelen invalid frame'lerle çalışır.
  Lifecycle pause veya durmuş stream kendi başına resync üretmez.
- Plank no-pose akışı HoldEngine'i durdurmaz. Sonraki geçerli frame eski
  başlangıç timestamp'inden süre hesaplayabildiği için background/görünmez
  zamanın sayılması ve ekran accumulator'ında önceki sürenin yeniden eklenmesi
  kaynak akışından türetilen ciddi bir risktir; nicel cihaz etkisi
  doğrulanmamıştır.

## 4. Egzersiz Destek Matrisi

| Egzersiz | Rehberde | Analiz desteği | Engine | Config | Contract | Metric extraction | Test kapsamı | Bilinen runtime kısıtı |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Squat | Evet | **Destekleniyor** | `rangeRep` | `assets/config/exercises/squat.json` | `RangeRepContracts.squat`: descending/peak/ascending; primary/form/posture/depth/alignment/end-range | Bilateral config-driven knee primary ve torso/form sinyalleri. Stability ve bottom-control `null`. | Catalog/resolver/config/factory/extractor, RangeRepEngine, validation, side/stabilizer/visibility | Likelihood yok; first-pose; controller/camera E2E yok; otomatik calibration test edilmemiş |
| Plank | Evet | **Destekleniyor** | `hold` | `assets/config/exercises/plank.json` | Ayrı typed hold contract yok; JSON `holdPosture` config'i var | Yalnız sol body-line/arm/leg | Resolver, config parser, HoldEngine, hold SessionReport | Bilateral side seçimi ve visibility resync yok; no-pose/lifecycle süre riski |
| Lunge | Evet | Desteklenmiyor | Yok | Yok | Yok | Üretim yoluna erişmez | Resolver'ın unsupported testi | Seçim kartı yalnız snackbar verir |
| Push-up | Evet | **Destekleniyor** | `rangeRep` | `assets/config/exercises/push_up.json` | `RangeRepContracts.pushUp`: descending/peak/ascending; primary/form/posture/depth/alignment/end-range | Bilateral config-driven elbow primary; shoulder-hip-ankle posture/alignment; elbow end-range. Stability ve bottom-control `null`. | Catalog/resolver/config/factory, 5 push-up extractor senaryosu ve bir engine rep testi; ortak validation/side/visibility | Likelihood yok; first-pose; controller/camera/device E2E yok; gerçek hareket güvenilirliği ölçülmedi |
| Sit-up | Evet | Desteklenmiyor | Yok | Yok | Yok | Üretim yoluna erişmez | Resolver'ın unsupported testi | Seçim kartı yalnız snackbar verir |

Kanıt: `exercise_catalog.dart:10-41`,
`range_rep_contract.dart`,
`exercise_guide_contents.dart:4-147`,
`exercise_selection_screen.dart:29-65`. `ExerciseType` enum'unda bulunmak veya
Guide ekranında görünmek analiz desteği kanıtı değildir.

## 5. Test Envanteri

`test/` altında 19 Dart dosyasında 102 test tanımı vardır. Normal ortamda 85'i
çalışır, 17 rules testi emulator host değişkenleri yoksa skip olur.

| Katman | Mevcut / sayı | Koruduğu kritik davranış | Production yolu mu? | En büyük boşluk |
| --- | ---: | --- | --- | --- |
| Domain engine | Evet / 13 | Squat range rep count/abort/form-phase penalty/context clear/one-shot core; Push-up bir tamamlanmış rep; hold entry/time/best/grace/break/reset | Gerçek engine, fakat sentetik `AnalysisFrame` ve fake clock | Kamera, controller, gürültü ve lifecycle bileşimi yok |
| Metric extractor | Evet / 13 | Config-driven signal/contract gating, asset config'leri, bilateral substitution, missing landmark, presence tabanlı side confidence ve Push-up sinyalleri | Gerçek extractor + gerçek JSON config; sentetik `Pose` | CameraImage→ML Kit→extractor bileşimi ve likelihood davranışı yok |
| Side selection/stabilizer/visibility | Evet / 12 | Coverage seçimi, hysteresis, rep anchor/switch ve 4-frame/450-ms resync | Gerçek policy sınıfları; fabricated metrics/zaman | Extractor→policy→stabilizer→controller bileşimi yok |
| Controller | Görünürde evet / 6 | Yalnız `shouldLockRangeRepSideSelection` boolean helper'ı | **Helper-only; production helper'ı çağırmıyor** | `WorkoutController` kurulumu ve `processCameraImage` state akışının tamamı açık |
| Widget | Evet / 1 | Auth-ready override ile home ekranının iki etiketle açılması | Root widget; auth/Firebase bypass | Live analysis, izin, lifecycle, hata, finish ve summary UI yok |
| Repository ve mapper | Evet / 11 | Session/rep mapping, summary/subcollection ayrımı, liste sırası ve silme | Production mapper/remote source; `FakeFirebaseFirestore` | Gerçek rules/network/index, hata dönüşümü, pagination/filter ve batch sınırı yok |
| Firestore rules emulator | Evet / 17 | Owner isolation, create/read, ID/owner mismatch, ekstra alan ve bazı numeric bounds | Emulator açıksa gerçek rules; ham REST client | Normal CI'da komple skip; update/delete/query/parent/enum tutarlılığı yok |
| Integration | **Hayır / 0** | Yok | Yok | Kamera→ML Kit→controller→UI→persistence zinciri açık |
| Gerçek cihaz | **Hayır / 0** | Yok | Yok | Format/orientation/overlay, izin/lifecycle, thermal, FPS ve doğruluk açık |
| Diğer application/model | Evet / 29 | Factory 4, resolver 4, catalog 2, validation 5, config parser 10, SessionReport 4 | Gerçek sınıflar; config testleri gerçek asset JSON'larını da okur | Controller/live production bileşimi yok |

Özellikle controller gerçeği:

- İki controller test dosyası controller'ı instantiate etmez.
- `workoutControllerProvider`, `CameraImage`, `PoseDetector`,
  `LiveAnalysisScreen` ve
  `processCameraImage` kullanılmaz.
- Altı testin tamamı `workout_controller.dart:46-56` helper'ını sınar.
- Üretim frame akışı `workout_controller.dart:160-482` test edilmez.

`integration_test/`, `test_driver/` ve Android `androidTest/` yoktur.
`ios/RunnerTests/RunnerTests.swift` assertionsız varsayılan şablondur ve
gerçek cihaz testi sayılmamıştır.

## 6. Coverage Baseline

Kaynak: 12 Temmuz 2026'da temiz
`17984be6309a63178f50a7704a565b199f2cf8d6` (`origin/main`) arşivinde gerçekten çalıştırılan
`flutter test --coverage`. Sonuç: 85 passed, 17 skipped. Aşağıdaki oranlar
yeni geçici `coverage/lcov.info` içindeki `LH/LF` line kayıtlarıdır.

| Alan / dosya | Hit | Found | Line coverage |
| --- | ---: | ---: | ---: |
| Genel proje | 1756 | 5856 | **%29,99** |
| Domain | 932 | 1255 | **%74,26** |
| Application | 332 | 706 | **%47,03** |
| Infrastructure | 184 | 295 | **%62,37** |
| Presentation | 290 | 3561 | **%8,14** |
| `WorkoutController` | 3 | 344 | **%0,87** |
| `LiveAnalysisScreen` | 3 | 702 | **%0,43** |
| `ExerciseMetricsExtractor` | 123 | 136 | **%90,44** |
| `RangeRepEngine` | 307 | 367 | **%83,65** |
| `HoldEngine` | 69 | 78 | **%88,46** |
| Firestore session remote source | 49 | 70 | **%70,00** |
| `SessionReport` | 167 | 177 | **%94,35** |

Coverage LCOV'un instrument ettiği/yüklediği Dart dosyaları için bir line
baseline'dır; gerçek cihaz veya native plugin coverage'ı değildir. CI coverage
artefaktı üretir fakat minimum coverage threshold'u uygulamaz. Repo kökündeki
önceden mevcut eski LCOV bu tablo için kullanılmadı ve değiştirilmedi.

Extractor artık gerçek asset config'leri ve sentetik pose'larla güçlü doğrudan
coverage'a sahiptir. Buna rağmen yüksek engine/extractor coverage'ı üretim
zincirinin korunduğu anlamına gelmez: controller ve live screen neredeyse
tamamen açıktır; CameraImage, ML Kit, lifecycle ve persistence bileşimi yoktur.

## 7. CI Baseline

Workflow: `.github/workflows/flutter-ci.yml`.

| Kontrol | CI gerçeği | Yerel temiz-SHA sonucu |
| --- | --- | --- |
| Tetikleyici | Tüm `pull_request`; yalnız `main` push | Yapılandırma okundu |
| Permission | `contents: read` | — |
| Dependency | `flutter pub get` | Başarılı; 31 daha yeni fakat constraint dışı paket bildirildi |
| Format | `dart format --set-exit-if-changed .` | Başarılı; 134 dosya, 0 değişiklik |
| Static analysis | `flutter analyze` | Başarılı; `No issues found` |
| Unit/widget suite | `flutter test` | Başarılı; 85 passed, 17 skipped |
| Coverage | `flutter test --coverage` | Başarılı; 85 passed, 17 skipped; fresh LCOV üretildi |
| Coverage artifact | `coverage-lcov`, dosya yoksa error | Workflow'da var; historical Actions artifact'i doğrulanmadı |
| Android debug | `flutter build apk --debug` | Başarılı; `app-debug.apk` üretildi |
| Debug APK artifact | Yok | Build geçici dizindeydi |
| Release build | **Yok** | Çalıştırılmadı |
| Emulator job | **Yok** | Ayrı yerel emulator komutu çalıştırıldı |
| Job timeout | Quality 25 dk; Android debug 30 dk | Yerel timeout'lara ulaşılmadı |

Workflow Java 17 ve unpinned `stable` Flutter kullanır; yerel baseline Java 21
ve Flutter 3.41.2'dir. `ubuntu-latest` de pinli değildir.

`continue-on-error` yoktur. Shell veya test komutu non-zero dönerse ilgili job
kırılır; Android job quality'ye `needs` ile bağlıdır. Ancak Firestore testleri
skip'i bir test başarısızlığı saymadığı için workflow yeşil kalabilir.

Normal iki test komutunda `test/firestore_rules_test.dart` içindeki 17 test,
`FIRESTORE_EMULATOR_HOST` veya `FIREBASE_AUTH_EMULATOR_HOST` eksikse skip
edildi. Ayrı olarak şu komut gerçekten çalıştırıldı:

```text
firebase emulators:exec --project pose-estimation-app-dd06c --only auth,firestore "flutter test test/firestore_rules_test.dart"
```

Sonuç: **17/17 passed**. Bu yerel başarı rules testlerinin çalışabildiğini
kanıtlar; CI'da çalıştığını kanıtlamaz. Güncel GitHub Actions run geçmişi bu
görevde doğrulanmadı.

## 8. Firestore ve Güvenlik Baseline'ı

### Persistence kontratı

- Session yolu: `users/{ownerId}/sessions/{sessionId}`.
- Rep yolu:
  `users/{ownerId}/sessions/{sessionId}/reps/{rep_0001}`.
- Session belgesi owner, exercise/analysis kind, zaman/süre, rep sayıları,
  skor istatistikleri, form warning ve hold özetleri taşır.
- Rep belgesi score, validation status/reasons, timing, primary/form
  metrikleri, coverage/side/phase bayrakları, selected side ve feedback taşır.
- Ham kamera bytes, görüntü, landmark listesi ve calibration baseline
  Firestore mapper payload'ında yoktur.
- Save, eski rep dokümanlarını okuyup siler, session ve yeni repleri tek batch
  ile yazar. Firebase exception `FirestoreFailure` olarak sarılır.

Kanıt: `firestore_paths.dart`, `workout_session_firestore_mapper.dart`,
`workout_rep_firestore_mapper.dart`,
`firestore_session_remote_source.dart:23-55`.

### Rules ve test durumu

Doğrulanan güçlü taraflar:

- Authentication ve path owner eşleşmesi zorunludur.
- Session/rep alanları `hasOnly` whitelist ile sınırlandırılır.
- ID/owner/session eşleşmeleri, non-negative counters ve 0–100 skorlar
  doğrulanır.
- Owner dışı erişim ve catch-all erişim reddedilir.
- Yerel Auth+Firestore emulator'da 17 rules testi geçti.

Bilinen boşluklar:

- `exerciseType`, `analysisKind`, `validationStatus` ve `selectedSide`
  enum/değerleri doğrulanmaz.
- `validationReasons` eleman tipi/uzunluğu, string uzunlukları ve parent
  session varlığı korunmaz.
- Client-controlled timestamp'ler `request.time` ile bağlanmaz.
- Update/delete/list/query ve parent-child tutarlılığı rules testlerinde yoktur.
- Parent silme, Firestore tarafından alt koleksiyonu otomatik silmez.
- Deployed rules/indexes sürümü bu repo incelemesiyle doğrulanamadı.

### Firebase ortamı ve privacy

Android, iOS ve web için yalnız
`pose-estimation-app-dd06c` projesi yapılandırılmıştır. Debug/release flavor
ayrımı, `.firebaserc`, runtime emulator wiring ve repo içinde App Check
aktivasyonu yoktur. Uygulama varsayılan `FirebaseAuth.instance` ve
`FirebaseFirestore.instance` kullanır.

Repo içinde privacy/gizlilik, rıza, retention, data export veya account
deletion kontratı/ekranı bulunamadı. Session delete ve sign-out repository
seviyesinde bulunmasına rağmen production UI call site'i doğrulanamadı.
Anonim UID kaybı halinde eski cloud verisine erişim ve temizleme davranışı
**doğrulanamadı**.

ML Kit SDK'nın repo dışındaki veri işleme davranışı, backend App Check
enforcement, API key restrictions, Firebase region/backup/TTL ve Auth provider
durumu bu denetimle doğrulanamadı.

## 9. Kamera Güvenilirliği Baseline'ı

| Alan | Mevcut koruma | Test kanıtı | Açık risk |
| --- | --- | --- | --- |
| Permission/init | Kamera izni kontrolü, tercih edilen lens, ilk kameraya fallback | Widget/integration yok | Permission revoke ve boş kamera listesi cihazda ölçülmedi |
| Format | Android NV21, iOS BGRA8888 açıkça istenir; unsafe frame reddedilir | Converter testi yok | Android tek-plane NV21 olmayan cihaz/back-end sessiz stale UI üretir |
| Rotation | Raw `sensorOrientation` ML Kit rotation'a çevrilir | Yok | Device rotation, front/back mirror ve crop/aspect doğruluğu bilinmiyor |
| ML Kit yükü | Stream/base model; controller yaklaşık 10 Hz ve reentrancy drop | Yok | FPS, thermal, latency ve düşük seviye cihaz davranışı bilinmiyor |
| Çoklu kişi | `poses.first` | Yok | Hangi kişinin seçildiği ve kişi takibi bilinmiyor |
| Landmark kalitesi | Varlık/coverage kontrolü | Yok | Likelihood yok; düşük güvenli landmark tam geçerli sayılabilir |
| Range-rep side | Squat/Push-up için coverage policy + hysteresis + aktif-rep consistency | Saf policy testleri; extractor ayrıca testli | Extractor→controller gerçek gürültü bileşimi yok; strict lock yok |
| Visibility | Range-rep 4-frame/450-ms resync | Saf policy testleri | Stream tamamen durunca çalışmaz; plank için yok |
| Plank | Hold posture + 300-ms body grace | Sentetik engine testleri | Sol tarafla sınırlı; no-pose/lifecycle timer riski |
| Lifecycle | Stream stop, camera provider invalidate ve recovery view | Yok | Engine/session clock/collector resetlenmez |
| Error UX | Permission/config/save için UI; bazı transient recovery | Yok | Analysis exception ve converter drop kullanıcıya görünmez |
| Overlay | Raw landmarks `PosePainter` ile çizilir | Yok | Preview crop, aspect, mirror ve orientation hizası cihazda ölçülmedi |

Gerçek cihaz ölçümüne geçmeden önce emulator CI, ölçüm protokolü, test
seam'leri, controller entegrasyonu, privacy onaylı telemetry/shadow policy ve
tekrarlanabilir beta build tamamlanmalıdır. Aksi halde cihazdaki sonucu
yeniden üretmek, ground truth ile karşılaştırmak ve regression'a çevirmek
mümkün değildir.

## 10. Release Baseline'ı

| Alan | Mevcut durum | Beta değerlendirmesi |
| --- | --- | --- |
| Paket/proje adı | `pose_estimation_app`; açıklama hâlâ `A new Flutter project.` | Ürün metadata'sı hazır değil |
| Görünen ad | Android `pose_estimation_app`; iOS `Pose Estimation App`; Flutter title `Pose Analysis` | Tutarsız |
| Android ID | namespace/application ID `com.bekir.pose_estimation_app` | Firebase Android app ile eşleşiyor |
| iOS bundle ID | `com.bekir.poseEstimationApp` | Firebase iOS app ile eşleşiyor |
| Version/build | `1.0.0+1` | Beta build numarası otomasyonu yok |
| Android release signing | `release` doğrudan `signingConfigs.debug` kullanıyor | **Beta dağıtımı için kabul edilemez** |
| iOS signing | Release'te developer identity; team/distribution provisioning doğrulanmadı | Archive hazır değil |
| Manifest | Main `CAMERA`; camera/autofocus feature'ları required varsayımıyla; debug/profile açıkça `INTERNET` ekler | Efektif release merged manifest doğrulanmadı |
| Debug merged izinler | Eski debug artefaktında INTERNET, CAMERA, RECORD_AUDIO, network/wakelock vb.; runtime `enableAudio:false` | Yalnız debug kanıtı; release için sonuç çıkarılamaz |
| CI build | Yalnız Android debug APK | Release APK/AAB/iOS archive ve signing kapısı yok |
| Artifact | Yalnız LCOV upload edilir | Dağıtılabilir APK/AAB artifact'i yok |
| Firebase environment | Debug/release tek proje/app | Beta verisi ve maliyetleri ayrışmıyor |
| Privacy/veri kullanımı | Repo içi politika/retention/delete-account akışı bulunamadı | Beta öncesi zorunlu |
| Kamera verisi saklama | App persistence yolunda raw frame/landmark yok | Privacy-positive; SDK dış davranışı doğrulanmadı |

Android main manifestte camera ve autofocus feature'larında
`android:required="false"` yoktur; varsayılan required davranışı uyumlu cihaz
havuzunu daraltabilir. Release build çalıştırılmadığı için merged release
permission set'i başarılı kabul edilmemiştir.

## 11. Kritik Riskler

| ID | Risk | Kanıt | Olasılık | Etki | Öncelik | Önerilen sonraki görev |
| -- | ---- | ----- | -------- | ---- | ------- | ---------------------- |
| R-01 | Rules güvenlik testleri normal CI'da sessizce skip olabilir | Workflow plain `flutter test`; 17 test env yoksa skip | Yüksek | Yüksek | P0 | Auth+Firestore emulator CI job ve skip=fail kapısı |
| R-02 | Kamera→controller→UI→persistence üretim zinciri test edilmemiş | Controller yalnız kullanılmayan helper; coverage %0,87/%0,43; integration 0 | Yüksek | Yüksek | P0 | Controller seam'leri ve production-yol entegrasyon testleri |
| R-03 | Gerçek cihaz format/orientation/overlay uyumluluğu bilinmiyor | Tek-plane NV21/BGRA kısıtı; converter/device testi yok | Yüksek | Yüksek | P0 | Ölçüm protokolü ve cihaz matrisi baseline'ı |
| R-04 | Plank pose/lifecycle kaybı hold süresini şişirebilir veya yeniden sayabilir | No-pose engine'i update etmez; timestamp ve collector reset akışı | Orta | Yüksek | P0 | Önce controller/device testi, sonra veri kapılı timer düzeltmesi |
| R-05 | Squat/Push-up pause veya stream-stop aktif phase ve tempo zamanını korur | Range-rep resync yalnız gelen invalid frame'lerle çalışır | Orta | Yüksek | P0 | Lifecycle entegrasyon testi ve shadow-mode politika |
| R-06 | Yanlış kişi veya düşük güvenli landmark engine'e girebilir | `poses.first`; likelihood kullanılmıyor | Yüksek | Yüksek | P1 | Telemetry ile pose/likelihood dağılımı, sonra shadow policy |
| R-07 | Otomatik calibration hızla ve ilk side'a kilitli threshold etkisi uygular | 3 sample, ±5°, ilk-side accumulator; doğrudan test yok | Orta | Yüksek | P1 | Calibration telemetry ve kontrollü veri değerlendirme kapısı |
| R-08 | Android beta build güvenli/tekrarlanabilir değil | Release debug key; CI release build/artifact yok; Flutter stable pinli değil | Yüksek | Yüksek | P0 | Signed, pinned, tekrarlanabilir beta build |
| R-09 | Beta/debug aynı Firebase'e yazar; privacy/retention/App Check kontratı yok | Tek project config; anonim auth; repo içi privacy yok | Yüksek | Yüksek | P0 | Beta Firebase ortamı ve veri kullanım kontratı |
| R-10 | Analysis hataları stale UI ile görünmez kalır; telemetry yok | Controller catch yalnız `debugPrint`; converter silent return | Yüksek | Yüksek | P1 | Privacy onaylı hata/drop/FPS telemetry |
| R-11 | Session zamanı ve retry davranışı ölçümü bozabilir | Clock kamera hazır olmadan başlar; background durmaz; summary retry state resetlemez | Orta | Orta | P1 | Session lifecycle entegrasyon testi |
| R-12 | Firestore batch operasyon sınırı uzun/yeniden yazılan session'da aşılabilir | Eski rep delete + session set + tüm rep set tek batch | Orta | Orta | P2 | Batch sınırı testi ve persistence tasarım görevi |
| R-13 | Rules veri bütünlüğü bazı enum/parent/time ilişkilerini korumuyor | Rules whitelist var; value/parent/request-time kontrolleri yok | Orta | Orta | P2 | Rules negatif test genişletmesi |
| R-14 | Yerel working tree üretim kodu, belgenin analiz ettiği remote SHA'dan 4 commit geride | Fetch sonrası `HEAD...origin/main = 0 4`; kullanıcı değişikliği nedeniyle merge yapılmadı | Yüksek | Orta | P1 | Her görevde analiz ref/SHA pinleme; kullanıcı değişikliği çözüldükten sonra ayrı sync kararı |

## 12. Test Edilmemiş Varsayımlar

- ML Kit'in ilk pose'u hedef kullanıcı olarak sıraladığı varsayımı.
- Android ve iOS cihazların converter'ın istediği tek-plane formatı verdiği
  varsayımı.
- Raw sensor orientation'ın front/back, portrait/landscape ve device rotation
  kombinasyonlarında doğru olduğu varsayımı.
- Preview crop/mirror/aspect dönüşümünün landmark overlay'iyle hizalı olduğu
  varsayımı.
- 10 Hz analiz ve 5-sample smoothing'in farklı cihazlarda yeterli/kararlı
  olduğu varsayımı.
- Landmark varlığının likelihood kontrolü olmadan güvenilir ölçüm olduğu
  varsayımı.
- `poses.first` ile kişi değişiminin rep/hold state'ini bozmadığı varsayımı.
- Squat/Push-up side stabilizer'ın gerçek gürültü altında rep boyunca tutarlı olduğu
  varsayımı.
- Plank'in yalnız sol landmark'larla tüm kamera yerleşimlerinde çalıştığı
  varsayımı.
- Pose ve lifecycle kaybında hold/tempo/session zamanlarının doğru olduğu
  varsayımı.
- Üç neutral frame'in güvenilir calibration baseline'ı olduğu varsayımı.
- Baseline threshold ve skorların biyomekanik doğruluğu; kod değeri doğrulandı,
  saha doğruluğu doğrulanmadı.
- Push-up elbow/body-line sinyallerinin, 132°/92°/103°/165° efektif phase
  gate'lerinin ve ortak validation politikasının gerçek tekrarları güvenilir
  saydığı varsayımı.
- Aynı otomatik calibration offset yaklaşımının Squat ve Push-up form metrikleri
  için semantik olarak güvenli olduğu varsayımı.
- Engine rep count ile UI'da assembled/persisted rep listelerinin her zaman
  eşleştiği varsayımı.
- Offline/yeniden deneme, uzun session ve Firestore 500-op sınırı davranışı.
- Composite index/rules'ın Firebase'e gerçekten deploy edilmiş olduğu
  varsayımı.
- Anonymous Auth, App Check, API key restrictions, retention ve privacy/store
  beyanlarının repo dışı üretim ortamında doğru yapılandırıldığı varsayımı.
- Android/iOS release signing, merged permission ve store-upgrade zincirinin
  çalıştığı varsayımı.

## 13. Beta Öncesi Zorunlu Çıkış Kapıları

| Kapı | Zorunlu kanıt | Bugünkü durum |
| --- | --- | --- |
| G0 — Baseline ve freeze | SHA pinli baseline, yalnız Squat/Plank/Push-up support claim'i, feature-freeze onayı | Bu belgeyle tanımlı; yerel/remote fark nedeniyle her görev başında yeniden kimlik doğrulaması gerekli |
| G1 — Güvenlik CI | Auth+Firestore emulator job; 17 rules testinin çalıştığı ve skip'in fail olduğu kanıt | **Kapalı** |
| G2 — Veri ve ölçüm kontratı | Ground-truth tanımı, cihaz/ışık/mesafe/pozisyon matrisi, kabul metrikleri, consent/privacy/retention | **Kapalı** |
| G3 — Test edilebilir runtime | Detector/converter/clock/repository seam'leri ve controller production-yol testleri | **Kapalı** |
| G4 — Gözlemlenebilirlik | Privacy onaylı frame-drop/format/pose-count/likelihood/FPS/lifecycle/error telemetry ve shadow policy | **Kapalı** |
| G5 — Tekrarlanabilir beta build | Pinli toolchain, release build, benzersiz signing, build number, artifact, beta Firebase ayrımı | **Kapalı** |
| G6 — Gerçek cihaz baseline | Önceden tanımlı cihaz matrisi ve protokolle ölçüm; raw evidence ve tekrar üretilebilir build kimliği | **Başlatılmamalı** |
| G7 — Veri değerlendirme | Threshold/policy değişikliğini onaylayan nicel kapı; false-positive/negative ve timing kriterleri | **Kapalı** |
| G8 — Runtime ve regression | Onaylı güvenilirlik düzeltmeleri, aynı cihazlarda regression ve rules/release tekrarları | **Kapalı** |
| G9 — Final beta release | Privacy/release checklist, signed artifact hash, rollback ve operasyonel owner | **Kapalı** |

Gerçek cihaz ölçümünden **önce** G1–G5 tamamlanmalıdır. Özellikle telemetry
şeması privacy/retention kararı olmadan eklenmemeli; cihaz ölçümü tek üretim
Firebase projesine kontrolsüz veri yazmamalıdır.

## 14. Önerilen Görev Sırası

Repo bulguları verilen temel sırayı büyük ölçüde doğruluyor. Tek gerekli ek,
tek Firebase ortamı ve privacy kontratı bulunmadığı için veri/ortam kararını
gerçek kullanıcı veya cihaz telemetry'sinden önce ayrı kapı yapmaktır.

| Sıra | Görev | Neden şimdi / çıkış kanıtı |
| ---: | --- | --- |
| 1 | **Emulator CI** | Mevcut 17 test yerelde geçiyor fakat CI'da skip. Job iki emulator'ı başlatmalı ve sıfır skip'i kanıtlamalı. |
| 2 | **Beta Firebase ortamı + privacy/veri yaşam döngüsü kontratı** | Debug/beta tek projede; anonim UID, retention, consent ve deletion belirsiz. Ölçüm verisinden önce çözülmeli. |
| 3 | **Ölçüm protokolü** | Ground truth, cihaz matrisi, kamera yerleşimi, ışık, tekrar/hold, acceptance ve veri formatı sabitlenmeli. |
| 4 | **Controller test seam'leri** | Detector, converter, clock, lifecycle ve repository deterministik enjekte edilebilir olmalı; runtime değişimi ayrı sınıflandırılmalı. |
| 5 | **Controller entegrasyon testleri** | Frame→metric→engine→state→rep/session zinciri, pose/missing landmark/error/lifecycle senaryolarıyla korunmalı. |
| 6 | **Telemetry** | Format reject, pose count, likelihood dağılımı, FPS/drop, side, calibration, lifecycle ve persistence sonuçları privacy kontratına göre ölçülmeli. |
| 7 | **Shadow-mode kamera politikaları** | First-pose, likelihood, format fallback, side/lifecycle adayları karar vermeden gözlenmeli. |
| 8 | **Tekrarlanabilir beta build** | Flutter/runner pin, release build, gerçek signing, build number, artifact hash ve beta Firebase app'i. |
| 9 | **Gerçek cihaz baseline'ı** | Aynı signed build ile önceden tanımlı cihaz/protokol ölçümü. |
| 10 | **Veri değerlendirme kapısı** | Runtime değişiklikleri yalnız nicel false-count, timing, occlusion, accuracy ve performance sonucu ile onaylanmalı. |
| 11 | **Runtime güvenilirlik değişiklikleri** | Hold/lifecycle, pose selection, likelihood, converter ve calibration düzeltmeleri yalnız onaylanan sırada uygulanmalı. |
| 12 | **Regresyon cihaz testleri** | Aynı cihaz ve senaryolarda baseline karşılaştırması; Squat, Plank ve Push-up ayrı raporlanmalı. |
| 13 | **Final beta release hardening** | Rules, privacy, signed artifact, rollback, monitoring ve release checklist'in birlikte kapanması. |

Bu sıradaki en küçük ve güvenli ilk görev yalnızca **Emulator CI**'dır. Runtime
davranışına dokunmaz, mevcut 17 güvenlik testinin sessiz skip edilmesini
engeller ve sonraki tüm beta çalışmalarının güvenilir tabanını güçlendirir.

## 15. Baseline Yenileme Notu

Bu tablo, önceki yarım çalışmanın temel aldığı yerel
`183391e30b6aa31a66463ec4dc70486519d83985` ile fetch sonrası güncel
`origin/main` commit'i
`17984be6309a63178f50a7704a565b199f2cf8d6` arasındaki önemli farkları gösterir.

| Konu | Eski SHA bulgusu | Güncel origin/main bulgusu | Plan etkisi |
|---|---|---|---|
| Baseline kimliği | Yerel `main` / `183391e`; fetch yapılmadan yerel remote referansına göre 4 behind | `git fetch --prune origin` sonrası analiz ref'i `origin/main` / `17984be`; yerel branch farkı kesin olarak `0 4` | Tüm kanıt ve test sonuçları güncel remote SHA'ya bağlandı; working tree sync edilmedi |
| Desteklenen egzersizler | Squat ve Plank; Push-up unsupported | Squat, Plank ve **Push-up** supported; Lunge ve Sit-up unsupported | Feature-freeze ve cihaz matrisi Push-up'ı da kapsamalı |
| Push-up engine/config/contract | Yok | `rangeRep`, `push_up.json`, `RangeRepContracts.pushUp`; bilateral elbow primary ve config-driven form signals | Push-up için ölçüm protokolü, controller ve gerçek cihaz kapıları zorunlu |
| Range-rep extraction | Squat'a özel extraction; stability/bottom-control yok | Squat ve Push-up için typed JSON signal tanımları kullanan generic extractor; stability/bottom-control hâlâ config/contract'ta yok | Yeni egzersiz ekleme dondurulmalı; generic şablonun genişletilmesi feature work sayılmalı |
| Extractor testleri | 0 doğrudan test; fresh coverage `1/129 = %0,78` | 13 doğrudan test; gerçek asset config'leri, bilateral substitution, contract gating ve missing landmark; `123/136 = %90,44` | Extractor birim-test boşluğu büyük ölçüde kapandı; CameraImage→ML Kit→controller boşluğu kapanmadı |
| Test suite | 75 tanım; normal run 58 passed + 17 skipped | 102 tanım; normal run 85 passed + 17 skipped | Test artışı Push-up/config/extractor katmanında; controller/integration/device sırası değişmiyor |
| Genel coverage | `1504/5749 = %26,16`; Application `%25,93` | Fresh `1756/5856 = %29,99`; Application `%47,03` | Coverage iyileşti; Presentation `%8,14`, controller `%0,87`, live screen `%0,43` kritik kalıyor |
| CI workflow | Format/analyze/test/coverage + Android debug; emulator/release yok | Son dört committe değişmedi; aynı komutlar güncel SHA'da geçti | İlk görev hâlâ Emulator CI |
| Rules skip davranışı | Normal suite'de 17 skip; ayrı emulator run 17 passed | Aynı; güncel SHA'da normal suite 17 skip, ayrı emulator run 17 passed | Güvenlik kapısı hâlâ CI'ya bağlanmalı |
| Firestore/rules/index | Owner-scoped persistence/rules; bilinen integrity boşlukları | Son dört committe değişmedi | Güvenlik ve environment riskleri aynı |
| Android release | Debug signing, yalnız debug CI build, release artifact yok | Son dört committe değişmedi; güncel debug APK build başarılı | Tekrarlanabilir signed beta build kapısı aynı |
| Kamera/controller/lifecycle | First-pose, likelihood yok, tek-plane format, controller E2E yok, hold/range lifecycle riskleri | İlgili üretim dosyaları son dört committe değişmedi | Push-up aynı risk yüzeyine eklendi; runtime düzeltmesi veri kapısından önce yapılmamalı |

Yenileme sonucu görev sırasının omurgası değişmedi. Değişen esas kapsam,
Push-up'ın artık gerçek destek matrisi ve gerçek cihaz regresyon planına dahil
olmasıdır. Extractor test/coverage açığı iyileşmiştir; controller, kamera,
lifecycle, CI emulator ve release kapıları aynı öncelikle açıktır.
