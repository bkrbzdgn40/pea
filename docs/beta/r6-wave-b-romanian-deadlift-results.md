# R6 Wave B - Romanian Deadlift Results

Bu belge Romanian Deadlift R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

Romanian Deadlift validation sırasında iki exercise-specific reliability problemi bulundu ve minimum doğru katmanda düzeltildi:

1. Büyük bumper plate kullanılan side-view senaryosunda ankle landmark visibility düşebildiği için technique-only `formMetric` pose acceptance'ı gereksiz yere blokluyordu. RDL `poseAcceptanceRequiredSignals` yalnız `primaryMetric` olacak şekilde daraltıldı. Counting için gereken shoulder-hip-knee hip-hinge metriği güvenilir olduğunda lifecycle devam edebilir; ankle mevcutsa knee-angle technique feedback'i yine çalışır.
2. Knee form feedback'i gerçekte ölçülmeyen bir “stability” problemi söylüyordu. Sistem absolute knee-angle threshold kontrol ettiği için RDL feedback semantiği “Dizlerini biraz daha az bük.” / “Bend your knees a little less.” olarak ölçümle hizalandı.

Threshold'lar ve generic engine değiştirilmedi. Scoring cezası bu closure kapsamında değiştirilmedi.

## Hızlandırılmış Final Validation Özeti

Kullanıcı final production build'i gerçek cihazda doğruladı:

| Alan | Sonuç | Closure yorumu |
| --- | --- | --- |
| Repetition / counting | PASS | Tekrar testlerinin düzgün çalıştığı kullanıcı tarafından doğrulandı. |
| Form-break / corrective behavior | PASS | Form-break davranışlarının düzgün çalıştığı kullanıcı tarafından doğrulandı. |
| `LIFE pause/resume` | PASS | Pause/resume lifecycle davranışı düzgün çalıştı. |
| `PERSIST` | PASS | Persistence davranışı düzgün çalıştı. |
| `OCC` | SKIPPED | Per-exercise occlusion policy gereği tekrar edilmedi. Büyük bumper plate senaryosu exercise-specific robustness finding olarak ayrıca tutulur. |

## Büyük Barbell / Bumper Plate Finding

Çok büyük barbell veya bumper plate, side-view'da özellikle knee/ankle landmark görünürlüğünü bozabilir.

RDL hardening sonrasında ankle-only technique metriğinin kaybı counting'i doğrudan bloklamaz. Buna rağmen aşırı büyük plakaların daha geniş landmark visibility kaybı oluşturduğu koşullar tamamen çözülmüş sayılmaz.

Bu durum şimdilik:

```text
P1 robustness finding
non-blocking
deferred
```

olarak tutulur.

Bu closure, çok büyük barbell/bumper plate koşullarının güvenilir şekilde desteklendiği iddiasını içermez.

## Scoring Finding

Kısa veya sınırlı knee-angle violation durumunda `hadFormViolation = true` nedeniyle skorun kullanıcı algısına göre aşırı sert düşebildiği gözlenmiştir.

Kullanıcı kararı gereği scoring sistemi bu aşamada değiştirilmemiştir. Finding backlog'da tutulur ve RDL counting/lifecycle closure'ını bloklamaz.

## Kanıt Sınırları

Final gerçek cihaz kontrolleri kullanıcı tarafından PASS olarak doğrulandı; ancak closure konuşmasında her run için exact `ground_truth_reps`, `app_reps`, SHA-pinned diagnostics export veya performans telemetry değerleri sabitlenmedi.

Bu nedenle:

- exact run-level sayılar uydurulmaz,
- `analysis_fps_p50`, `frame_processing_ms_p95` ve `analysis_exception_count` için bağımsız final-run PASS iddiası yapılmaz,
- sonuç formal protocol-complete olarak adlandırılmaz,
- closure kullanıcı tarafından gerçek cihazda doğrulanmış engineering revalidation olarak tutulur.

## Closure Kararı

Repetition/counting, form-break behavior, pause/resume lifecycle ve persistence gerçek cihazda doğrulandı. Exercise-specific iki reliability problemi minimum kapsamlı RDL düzeltmeleriyle giderildi. Threshold tuning veya generic engine değişikliği yapılmadı.

Çok büyük bumper plate görünürlük senaryosu ve sert scoring cezası blocker olmayan açık finding olarak bırakıldı.

**Final karar: `Romanian Deadlift = R6 Engineering Revalidated`.**
