# R5 Control-Group Device Revalidation

Bu belge, tarihsel olarak device-verified kabul edilen **Squat, Push-up ve Plank** hareketlerinin Diagnostics schema v6 altında yeniden doğrulanması için minimum tekrar edilebilir cihaz protokolüdür.

R5 yeni bir doğruluk iddiası üretmez ve diğer 15 egzersize kanıt taşımaz. Amaç, R1-R4 sırasında eklenen contract audit, deterministic scenario harness ve diagnostics instrumentation değişikliklerinin tarihsel kontrol grubunda regression oluşturmadığını kanıtlamaktır.

## 1. R5 Çıkış Kriteri

R5 yalnız aşağıdaki koşullar birlikte sağlandığında tamamlanmış sayılır:

- Squat, Push-up ve Plank için bu belgedeki zorunlu run'lar tamamlanır.
- Her run, `app_commit_sha != unknown` ve `build_mode == profile` olan diagnostics JSON ile eşleştirilir.
- Diagnostics içindeki `exercise_type`, `config_asset_path` ve `contract_profile` beklenen hareketle uyuşur.
- `analysis_exception_count == 0` olur.
- Range-rep pozitif setlerde count gate geçer.
- Static/partial/lifecycle senaryolarında phantom rep görülmez.
- Plank hold ve form-break gate'leri geçer.
- Kısa occlusion recovery red-line ihlali üretmez.
- Persistence kontrolü başarısız olmaz.
- Performans değerlendirilen run'larda `fps_sample_count >= 10`, `analysis_fps_p50 >= 6` ve `frame_processing_ms_p95 <= 250` olur.

Bu kriterlerden biri ölçülemiyorsa run `NOT_MEASURABLE`; build kimliği veya protokol bütünlüğü bozuksa `INVALID` sayılır. `INVALID` ve `NOT_MEASURABLE`, `PASS` değildir.

## 2. SHA-Pinned Profile Build

R5 cihaz run'larında debug build kullanılmaz. Local CI kotası kapalı olduğu için aynı reproducibility kontratı yerel profile run ile korunabilir.

PowerShell:

```powershell
$sha = (git rev-parse HEAD).Trim()
flutter run --profile --dart-define=PEA_COMMIT_SHA=$sha
```

Diagnostics panelinde ve export edilen JSON'da:

- `app_commit_sha` tam 40 karakter Git SHA olmalı,
- `build_mode` `profile` olmalı,
- `config_version_fingerprint` ilgili config path + aynı SHA'yı taşımalı.

Bu üç koşuldan biri sağlanmıyorsa run `INVALID` olur.

## 3. Ortak Test Kurulumu

Her run öncesi:

1. Yeni Live Analysis session başlat.
2. İlgili egzersizi seç.
3. Tercih edilen kamera view kontratını uygula.
4. Cihazı sabitle; test sırasında kamera açısını değiştirme.
5. Mümkünse tüm gerekli vücut segmentlerini kadrajda tut.
6. Run sonunda Diagnostics panelini aç.
7. `JSON Dosyasını Paylaş` ile `.json` dosyasını dışa aktar.
8. Sonucu `docs/beta/r5-control-group-results-template.csv` kopyasına işle.
9. Persistence gerektiren run'da History/session detail ile UI toplamını karşılaştır.

Diagnostics export ham video veya raw landmark içermez. Ground-truth gerekiyorsa mevcut `measurement-contract.md` privacy kuralları geçerlidir.

## 4. Squat Zorunlu Run'ları

| Run ID | Senaryo | Uygulama | Beklenen |
| --- | --- | --- | --- |
| `R5-SQ-POS-20` | Kontrollü pozitif | 20 tam kontrollü squat | `absolute_count_error <= 1`; validation sonuçlarında beklenmeyen invalid çoğunluğu yok |
| `R5-SQ-STATIC-30` | Statik negatif | 30 sn neutral duruş | 0 phantom rep |
| `R5-SQ-PARTIAL-10` | Partial motion | Peak threshold'a ulaşmayan 10 yarım deneme | 0 completed rep |
| `R5-SQ-OCC-3` | Kısa occlusion | Aktif rep sırasında yaklaşık 1 sn pose kaybı, 3 kez | Phantom/auto-complete yok; recovery `<= 2.5 sn` |
| `R5-SQ-LIFE-3` | Lifecycle | PEAK/aktif rep bağlamında pause-resume, 3 döngü | Dönüşte phantom rep yok; neutral reacquisition korunur |
| `R5-SQ-PERSIST` | Persistence | Geçerli session bitir | Displayed rep = persisted rep docs = session total |

## 5. Push-up Zorunlu Run'ları

| Run ID | Senaryo | Uygulama | Beklenen |
| --- | --- | --- | --- |
| `R5-PU-POS-20` | Kontrollü pozitif | 20 tam kontrollü push-up | `absolute_count_error <= 1`; validation sonuçlarında beklenmeyen invalid çoğunluğu yok |
| `R5-PU-STATIC-30` | Statik negatif | 30 sn neutral/setup duruş | 0 phantom rep |
| `R5-PU-PARTIAL-10` | Partial motion | Peak threshold'a ulaşmayan 10 yarım deneme | 0 completed rep |
| `R5-PU-OCC-3` | Kısa occlusion | Aktif rep sırasında yaklaşık 1 sn pose kaybı, 3 kez | Phantom/auto-complete yok; recovery `<= 2.5 sn` |
| `R5-PU-LIFE-3` | Lifecycle | PEAK/aktif rep bağlamında pause-resume, 3 döngü | Dönüşte phantom rep yok; neutral reacquisition korunur |
| `R5-PU-PERSIST` | Persistence | Geçerli session bitir | Displayed rep = persisted rep docs = session total |

## 6. Plank Zorunlu Run'ları

| Run ID | Senaryo | Uygulama | Beklenen |
| --- | --- | --- | --- |
| `R5-PL-POS-30` | Geçerli hold | 30 sn geçerli plank | `hold_absolute_error_seconds <= 2.0` |
| `R5-PL-INVALID-30` | Geçersiz posture | 30 sn açıkça geçersiz plank posture | False hold start yok |
| `R5-PL-OCC-3` | Kısa occlusion | Aktif hold sırasında yaklaşık 1 sn pose kaybı, 3 kez | Gizli sürede hold ilerlemez; recovery `<= 2.5 sn` |
| `R5-PL-LONG-OCC` | Uzun occlusion | Aktif hold sırasında en az 3 sn pose kaybı | Hold sonlanır; best hold korunur |
| `R5-PL-FORM-BREAK` | Kalıcı form break | Aktif hold sırasında bilinçli kalıcı body-line bozulması | Hold en geç `1.5 sn` içinde durur |
| `R5-PL-LIFE-3` | Lifecycle | Aktif hold sırasında pause-resume, 3 döngü | Hidden time eklenmez; phantom hold continuation yok |
| `R5-PL-PERSIST` | Persistence | Geçerli hold session bitir | Gösterilen ve persisted hold sonucu tutarlı |

## 7. Diagnostics Kontrol Listesi

Her JSON için minimum kontrol:

```text
schema_version == 6
app_commit_sha != "unknown"
build_mode == "profile"
exercise_type == beklenen hareket
analysis_exception_count == 0
fps_sample_count >= 10  # performans gate'i değerlendirilecek run'larda
analysis_fps_p50 != null
frame_processing_ms_p95 != null
```

Range-rep için ayrıca:

```text
range_rep_transition_counts
range_rep_validation_status_counts
range_rep_abort_count
active_rep_resync_count
```

Plank için ayrıca:

```text
hold_analysis_family == "plank"
hold_engine_phase
hold_is_visibility_suspended
best_hold_seconds
```

## 8. Performans Yorumu

R5 performans gate'i tek bir `current_analysis_fps` değerinden değerlendirilmez. Diagnostics accumulator yaklaşık saniyelik controller FPS güncellemelerini session boyunca örnekler ve şu run-level alanları export eder:

- `fps_sample_count`
- `camera_fps_p50`
- `camera_fps_p95`
- `analysis_fps_p50`
- `analysis_fps_p95`

Performans sonucu yalnız `fps_sample_count >= 10` ise değerlendirilir. Daha kısa run'lar doğruluk/lifecycle için kullanılabilir ancak performans için `NOT_MEASURABLE` sayılır.

## 9. PASS / FAIL Kararı

Bir hareket R5 kontrol grubu içinde yeniden doğrulanmış sayılmak için kendi zorunlu run'larının tamamında red-line ihlali olmadan geçmelidir.

Global ortalama kullanılmaz. Squat PASS, Push-up FAIL ise "kontrol grubu PASS" denemez.

R5 sonucu threshold tuning gerekçesi değildir. Bir FAIL varsa önce şu sınıflardan biri atanır:

- camera/setup,
- pose quality/landmark,
- metric,
- range-rep veya hold lifecycle,
- side selection,
- occlusion/recovery,
- persistence,
- performance.

Sonra yalnız kanıtlanan failure sınıfına minimum değişiklik yapılır.

## 10. 2026-07-22 Execution Closure

R5 gerçek cihaz execution'ı commit `f56d921c5e4a6672f3881d5408a0d81302051965` üzerinde `profile` build ile yürütüldü. Diagnostics JSON'larında build SHA, config fingerprint ve run-level performans telemetry'si doğrulandı.

Engineering sonucu:

- Squat: counting, static negative, partial-motion safety, controlled brief occlusion, pause/resume, persistence ve performance davranışları olumlu.
- Push-up: counting, static negative, partial-motion safety, controlled brief occlusion, pause/resume, persistence ve performance davranışları olumlu.
- Plank: valid hold timing, invalid posture rejection, long-occlusion safety, permanent form break, pause/resume, persistence ve performance davranışları olumlu.

Bu execution, bu belgede önceden tanımlanan bütün run adetlerini birebir uygulamamıştır. Özellikle:

- range-rep positive run'ları 20 yerine 12 ground-truth rep ile yürütüldü,
- partial-motion run'ları 10 yerine 5 deneme ile yürütüldü,
- bazı occlusion ve lifecycle senaryoları 3 tekrar yerine tek kontrollü run ile yürütüldü.

Bu nedenle sonuç **formal protocol-complete PASS** değildir. Kapanış statüsü **`R5 Engineering Revalidated - protocol deviations documented`** olarak tutulur.

Brief Plank occlusion sırasında fonksiyonel continuity olumlu görünmesine rağmen mevcut Diagnostics v6, hold visibility suspend/recovery/abort geçmişini session-level sayaçlarla taşımadığı için bu alt senaryo formal olarak `NOT_MEASURABLE` kabul edilir. Bu telemetry açığı R6 hold-family validation öncesi kapatılmalıdır.

Tam sonuç özeti:

- `docs/beta/r5-control-group-results.md`
- `docs/beta/r5-control-group-findings.md`

`r5-control-group-results-template.csv` planlanan protokol şablonu olarak korunur; gerçek execution sapmalarını gizlemek için geriye dönük olarak doldurulmaz veya run ID anlamı değiştirilmez.
