# R6 Wave A - Front Raise Results

Bu belge Front Raise R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

Front Raise validation sırasında üç gerçek reliability problemi bulundu ve minimum doğru katmanda düzeltildi:

1. Side-view self-occlusion durumunda pose-quality taraf tercihi selected-side coordinator'a taşınmıyordu. `preferredRangeRepSide` coverage eşitliğinde tie-break olarak side selection'a bağlandı; coverage önceliği, hysteresis ve active-rep side-lock korundu.
2. Kabul edilebilir hafif dirsek fleksiyonunda false-positive teknik feedback görülüyordu. Front Raise `formThreshold` değeri `155° -> 145°` olarak gevşetildi; counting ve ROM gate'leri değiştirilmedi.
3. Kullanıcı açısından kabul edilebilir `78-81°` peak ölçümlerinin bir bölümü generic `+3°` peak-entry margin nedeniyle completed rep olmuyordu. Front Raise `thresholdPeak` değeri `80° -> 75°` olarak ayarlandı; efektif strict peak-entry gate `>78°` oldu.

Final production ayarları:

```text
thresholdNeutral = 15°
thresholdActive = 35°
thresholdPeak = 75°
formThreshold = 145°
selected-side quality tie-break = enabled
```

## Hızlandırılmış Final Validation Matrisi

Kullanıcı final fix setini hem video gözlemi hem gerçek hayat kullanımıyla doğruladı:

| Senaryo | Sonuç | Closure yorumu |
| --- | --- | --- |
| `PREFLIGHT-1` | PASS | Doğru side-view kurulumda natural neutral acquisition ve completed rep doğrulandı. |
| `POS-20` | PASS | Kontrollü tam tekrar sayımı kullanıcı tarafından video + gerçek hayat üzerinde doğrulandı. |
| `STATIC-30` | PASS | Natural neutral beklemede phantom rep görülmedi. |
| `PARTIAL / INVALID-ROM` | PASS | Shallow hareketlerin completed rep'e dönüşmediği doğrulandı. |
| `FORM` | PASS | Kabul edilebilir hafif dirsek fleksiyonunda false-positive feedback geriledi; belirgin kötü form senaryosu ayırt edildi. |
| `LIFE pause/resume` | PASS | Pause/resume sonrasında phantom/duplicate rep görülmedi. |
| `PERSIST` | PASS | Live/Summary/History persistence kullanıcı tarafından doğrulandı. |
| `OCC` | SKIPPED | Exercise-specific tekrar yapılmadı; shared reliability validation kapsamındaki ortak occlusion/visibility kanıtı kullanıldı. |

## Kanıt Sınırları ve Protocol Deviation

Final hızlandırılmış run seti için diagnostics JSON export'ları closure konuşmasında paylaşılmadı. Bu nedenle:

- final SHA ve run-bazlı diagnostics dosyaları manifestte kanıt olarak doldurulmaz,
- `analysis_fps_p50`, `frame_processing_ms_p95` ve `analysis_exception_count` final run seti için bağımsız telemetry kanıtı sayılmaz,
- closure sonucu formal protocol-complete olarak adlandırılmaz,
- sonuç kullanıcı tarafından video + gerçek hayat üzerinde doğrulanmış engineering revalidation olarak tutulur.

İlk exploratory preflight önden çekildiği için camera contract dışıydı ve kanıt olarak kullanılmadı. Doğru side-view retest natural neutral'ın `5-13°` civarında acquire edilebildiğini gösterdi; bu nedenle `thresholdNeutral = 15°` değiştirilmedi.

## Closure Kararı

Front Raise için kritik counting, negative-ROM, form-quality, lifecycle ve persistence kapıları final hardening sonrasında kullanıcı tarafından doğrulandı. Açık blocker yoktur.

**Final karar: `Front Raise = R6 Engineering Revalidated`.**
