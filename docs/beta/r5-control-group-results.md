# R5 Control-Group Results

Bu belge, `R5 Control-Group Device Revalidation` execution sonucunu kalıcı olarak kaydeder.

## 1. Build Kimliği

- Commit SHA: `f56d921c5e4a6672f3881d5408a0d81302051965`
- Build mode: `profile`
- Diagnostics schema: `6`
- Cihaz: TECNO CK6n
- Execution tarihi: 2026-07-22

Bütün referans JSON dosyaları aynı commit SHA ve profile build kimliğiyle üretilmiştir.

## 2. Closure Statüsü

**R5 Engineering Revalidated - protocol deviations documented**

Bu statü, kontrol grubunda regression sinyali bulunmadığını ve ana kullanıcı davranışlarının gerçek cihazda yeniden doğrulandığını ifade eder. Formal protokolde önceden yazılan exact run adetlerinin tamamı uygulanmadığı için `formal protocol-complete PASS` iddiası yapılmaz.

Başlıca execution sapmaları:

- Squat ve Push-up positive controlled run: plan 20 rep, gerçek execution 12 rep.
- Squat ve Push-up partial-motion run: plan 10 deneme, gerçek execution 5 deneme.
- Bazı occlusion/lifecycle senaryoları: plan 3 döngü, gerçek execution tek kontrollü döngü.

## 3. Squat Sonuçları

| Senaryo | Kanıt | Sonuç | Not |
| --- | --- | --- | --- |
| Positive controlled | `diagnostics_v6_squat_20260722_133833.json` | PASS | 12 ground-truth rep -> 12 app rep; 12/12 valid; `analysis_fps_p50=8.76`; processing p95 `76 ms` |
| Static negative | `diagnostics_v6_squat_20260722_134126.json` | PASS | 0 phantom rep; yalnız `acquireNeutral` |
| Partial motion | `diagnostics_v6_squat_20260722_135438.json` | PASS WITH QUALITY CAVEAT | 5 start -> 5 `abortToNeutral`; 0 complete rep; run boyunca belirgin no-pose/low-likelihood dalgalanması vardı |
| Brief occlusion | `diagnostics_v6_squat_20260722_134958.json` | PASS | 1 complete rep; recovery=1; abort=0; active-rep resync=0; rep `lowConfidence/coverageLoss` olarak dürüstçe downgrade edildi |
| Pause / resume | `diagnostics_v6_squat_20260722_135600.json` | PASS | 2 ground-truth rep -> 2 valid rep; iki neutral acquisition; phantom rep yok |
| Persistence | Real-device UI verification | PASS | Live=3, Summary=3, History=3 |

İlk daha kontrolsüz occlusion denemesi (`diagnostics_v6_squat_20260722_134735.json`) tek fiziksel kapatmayı 9 teknik episode'a böldü ve 7 abort üretti. Daha kontrollü tekrar bu davranışı yeniden üretmedi; bu run failure kanıtı olarak kullanılmadı ancak visibility flapping gözlemi olarak saklandı.

## 4. Push-up Sonuçları

| Senaryo | Kanıt | Sonuç | Not |
| --- | --- | --- | --- |
| Positive controlled | `diagnostics_v6_push_up_20260722_140024.json` | PASS WITH FINDING | 12 ground-truth rep -> 12 app rep; 9/12 `lowConfidence` nedeni `excessiveDescentSpeed`; sayım hatası 0 |
| Static negative | `diagnostics_v6_push_up_20260722_140357.json` | PASS | 0 phantom rep |
| Partial motion | `diagnostics_v6_push_up_20260722_140555.json` | PASS | 5 start -> 5 `abortToNeutral`; 0 complete rep |
| Brief occlusion | `diagnostics_v6_push_up_20260722_140907.json` | PASS | 1 complete rep; recovery=1; abort=0; active-rep resync=0; `coverageLoss` + `excessiveAscentSpeed` low-confidence notu |
| Pause / resume | `diagnostics_v6_push_up_20260722_141029.json` | PASS | 2 ground-truth rep -> 2 valid rep; phantom rep yok |
| Persistence | Real-device UI verification | PASS | Live=3, Summary=3, History=3 |

Push-up counting güvenilirliği bu execution'da güçlüdür. Tempo-confidence sinyalinin normal kullanıcı temposuna karşı fazla agresif olup olmadığı ayrı veriyle incelenmelidir; tek kullanıcı/tek run sonucuyla threshold tuning yapılmaz.

## 5. Plank Sonuçları

| Senaryo | Kanıt | Sonuç | Not |
| --- | --- | --- | --- |
| Valid hold | `diagnostics_v6_plank_20260722_141544.json` | PASS | Yaklaşık 30 sn ground truth -> 31 sn best/current; `+1 sn`, kabul aralığı içinde |
| Invalid posture | `diagnostics_v6_plank_20260722_141742.json` | PASS | 0 sn hold; phase `BROKEN`; `align_hips`; false hold start yok |
| Brief occlusion | `diagnostics_v6_plank_20260722_141940.json`, `diagnostics_v6_plank_20260722_142108.json` | NOT_MEASURABLE | Fonksiyonel continuity olumlu; `no_pose` ve reacquisition görüldü, fakat hold-specific suspend/recovery/abort history telemetry'si yok |
| Long occlusion | `diagnostics_v6_plank_20260722_142259.json` | PASS WITH TELEMETRY CAVEAT | `best_hold=6`, reacquisition sonrası `current_hold=4`; hidden duration'ın körlemesine eklenmediği davranışla uyumlu; doğrudan hold visibility event sayaçları yok |
| Permanent form break | `diagnostics_v6_plank_20260722_142513.json` | PASS | `best_hold=11`, `current_hold=0`, phase `BROKEN`, alignment/extension invalid |
| Pause / resume | `diagnostics_v6_plank_20260722_142822.json` | PASS | `best_hold=10`, yeni aktif hold `current_hold=6`; background hidden time'ın mevcut hold'a eklenmesine dair sinyal yok |
| Persistence | Real-device UI verification | PASS | 10 sn Live -> 10 sn persisted/history sonucu |

Plank static/form-break koşulunda kullanıcı tarafından kamera görüntüsünde sürekli bulanıklaşıp netleşme, yani autofocus hunting gözlendi. Aynı run'da pose pipeline `207` pose frame'i işledi, `206` accepted frame üretti ve exception/resync görülmedi; bu nedenle gözlem analiz failure'ı olarak değil kamera/UX hardening bulgusu olarak kaydedildi.

## 6. Performans Özeti

Değerlendirilen profile run'larda provisional gate'ler genel olarak geçti:

- `analysis_fps_p50 >= 6`
- `frame_processing_ms_p95 <= 250 ms`
- `analysis_exception_count == 0`

Örnek temiz run aralıkları:

- Squat positive: p50 `8.76 FPS`, processing p95 `76 ms`
- Push-up positive: p50 `7.91 FPS`, processing p95 `81 ms`
- Plank valid hold: p50 `7.94 FPS`, processing p95 `83 ms`

Static Push-up run processing p95 `206 ms` ile gate içinde kalmış ancak diğer run'lardan daha yüksek varyans göstermiştir. Tek başına performance failure sayılmaz.

## 7. Sonuç

- Squat: **R5 Engineering Revalidated**
- Push-up: **R5 Engineering Revalidated**, tempo-confidence finding açık
- Plank: **R5 Engineering Revalidated**, hold visibility telemetry ve autofocus findings açık

R5 closure, R6 Dalga A'ya geçişi engellemez. Ancak Hollow Hold ve Wall Sit gibi hold-family egzersizlerde occlusion/recovery kanıtı yorumlanmadan önce hold visibility telemetry açığı kapatılmalıdır.
