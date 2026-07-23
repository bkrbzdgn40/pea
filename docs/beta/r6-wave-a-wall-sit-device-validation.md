# R6 Wave A - Wall Sit Device Validation

Bu protokol R6 Dalga A kapsamında `Wall Sit` exercise-specific gerçek cihaz validation'ını tanımlar. Zaman kısıtı ve daha önce tamamlanan shared hold visibility hardening nedeniyle hızlandırılmış hold matrisi kullanılır. Per-exercise occlusion tekrarı varsayılan olarak yapılmaz.

## 1. Production Contract Özeti

Production kaynaklarına göre Wall Sit:

- `exercise_type = wall_sit`
- engine: `hold`
- hold family: `wallSit`
- preferred camera: `side`
- unsupported camera: `front`
- required signals: `kneeFlexion`, `hipFlexion`, `torsoAlignment`
- `kneeFlexion`: detection + validation + technique
- `hipFlexion`: validation + technique
- `torsoAlignment`: validation + technique

Production posture config:

```text
activeKneeMaxAngle = 130°
knee valid range = 80°..120°
hip valid range = 70°..120°
torso minimum = 155°
breakGrace = 500 ms
```

Hold visibility suspend/recovery/abort telemetry daha önce shared hardening kapsamında gerçek cihazda doğrulandığı için Wall Sit için ayrı occlusion run'ı planlanmaz. Yalnız Wall Sit'e özgü visibility regression görülürse bu test geri açılır.

## 2. Kamera ve Setup

Cihaz kullanıcıyı **tam yandan** görmelidir.

Kadrajda aynı anda görünmesi gereken bölgeler:

- baş/kulak,
- omuz,
- kalça,
- diz,
- ayak bileği.

Kullanıcı sırtını duvara verir, ayaklarını duvardan kontrollü mesafeye alır ve Wall Sit pozisyonuna iner. Önden kurulum bu validation için kullanılmaz.

Guide ile production camera contract aynı yöndedir: `side preferred`, `front unsupported`.

## 3. Hızlandırılmış Zorunlu Test Matrisi

| Run ID | Senaryo | Uygulama | Beklenen |
| --- | --- | --- | --- |
| `R6-WS-VALID-30` | Valid hold | Kontrollü doğru Wall Sit pozisyonunda yaklaşık 30 sn kal | Hold süresi ground truth ile uyumlu; form valid; exception yok |
| `R6-WS-FORM-BREAK` | Invalid posture / form break | Önce valid hold, sonra belirgin depth veya torso hatası oluştur | Hold grace sonrasında durur/kırılır; `adjustWallSitDepth` veya `alignWallSitTorso` doğru bağlamda görülür |
| `R6-WS-LIFE` | Pause/resume | Hold sırasında pause, birkaç saniye bekle, resume ve yeniden pozisyona gir | Pause süresi hold'a eklenmez; phantom hidden-time yok; resume sonrası temiz reacquire |
| `R6-WS-PERSIST` | Persistence | Ölçülebilir bir hold ile session bitir | Live/Summary/History aynı persisted hold değerini gösterir |

Per-exercise `OCC` testi bu matriste **SKIPPED by policy**. Shared hold visibility validation short-gap recovery ve long-gap abort davranışını zaten kapsar.

## 4. Kırmızı Çizgiler

Aşağıdakilerden biri görülürse validation durdurulur ve ilgili katman incelenir:

- doğru side-view setup'ta valid Wall Sit'in hold olarak acquire edilememesi,
- belirgin depth/torso form break'in hold'u kesmemesi,
- 500 ms grace davranışının açık form break sırasında sürekli hidden-time üretmesi,
- pause sırasında hold süresinin artması,
- resume sonrasında eski hidden-time'ın yeni hold'a eklenmesi,
- persistence değerlerinin Live/Summary/History arasında ayrışması,
- analysis exception.

## 5. Diagnostics Alanları

Diagnostics JSON varsa özellikle:

```text
exercise_type = wall_sit
analysis_kind = hold
hold_analysis_family = wallSit
camera_view_contract.side = preferred
camera_view_contract.front = unsupported
current_hold_seconds
best_hold_seconds
hold_engine_phase
hold_current_signals
hold_signal_validity
hold_is_form_break_grace_active
analysis_exception_count
analysis_fps_p50
frame_processing_ms_p95
```

Shared visibility telemetry alanları gözlemlenebilir, ancak exercise-specific occlusion acceptance gate'i değildir.

## 6. Performans Gate'i

Yeterli örnek varsa:

```text
analysis_fps_p50 >= 6
frame_processing_ms_p95 <= 250
analysis_exception_count == 0
```

Ana performans kanıtı tercihen `R6-WS-VALID-30` run'ından alınır.

## 7. Closure Kriteri

Wall Sit şu dört kapı geçildiğinde `R6 Engineering Revalidated` statüsüne aday olur:

1. valid hold,
2. invalid posture / form break,
3. pause/resume lifecycle safety,
4. persistence.

Occlusion tekrar testi shared coverage nedeniyle zorunlu değildir. Exercise-specific yeni visibility problemi görülürse closure öncesi yeniden açılır.

## 8. Execution Closure

Hızlandırılmış gerçek cihaz execution sonucu:

- `R6-WS-VALID-30`: PASS, yaklaşık 30 saniye ve iki farklı kullanıcı,
- `R6-WS-FORM-BREAK`: PASS, deliberate kötü pozisyonda derinlik ve duvara yaslanma/hizalanma feedback'i görüldü,
- `R6-WS-LIFE`: PASS, yaklaşık 5 saniyelik hold sonrası pause/resume ile current hold `0`'a döndü ve hidden pause-time eski hold'a taşınmadı,
- `R6-WS-PERSIST`: PASS, kullanıcı tarafından gerçek cihazda doğrulandı,
- per-exercise occlusion: SKIPPED by policy, shared hold visibility coverage kullanıldı.

Başın kameraya çevrilmesi sırasında görülen form break formal form-break kanıtı olarak kullanılmaz. Bu gözlem torso-alignment geometrisinin head/neck rotasyonuna hassas olabileceğini düşündüren ayrı bir robustness finding olarak tutulur.

Final run seti için diagnostics JSON paylaşılmadığı için performans percentile'ları ve exception count bağımsız telemetry kanıtı sayılmaz.

**Closure status: `R6 Engineering Revalidated`.**
