# R6 Wave A Findings

Bu belge, R6 Dalga A cihaz validation'ında bulunan ve closure kararlarını bloklamayan açık engineering konularını tutar.

## F1 - Biceps Curl tempo-confidence sensitivity

- Öncelik: **P1**
- Katman: Rep validation / confidence
- Etkilenen alan: Biceps Curl
- Closure etkisi: Counting reliability'yi bloklamaz
- Ana kanıt: `diagnostics_v6_biceps_curl_20260722_162317(2).json`
- Fix sonrası SHA: `db33f6243dd16c1cbaefc5b15231d9f4ba96053d`

### Gözlem

Fix sonrası controlled POS-20 run'ında:

- ground truth = 20
- `rep_count = 20`
- `valid = 6`
- `lowConfidence = 14`
- `excessiveDescentSpeed = 8`
- `excessiveAscentSpeed = 10`
- `persistentFormBreak = 1`

Counting doğru ve lifecycle eksiksizdir. Ancak normal kontrollü kullanıcı temposunun önemli bölümü tempo nedenleriyle low-confidence işaretlenmektedir.

`persistentFormBreak` sayısının önceki controlled run'daki 11'den fix sonrası 1'e düşmesi, form metric / feedback ayrıştırmasının olumlu çalıştığını gösterir. Kalan ana belirsizlik tempo-confidence calibration'dır.

### Risk

Confidence katmanı normal kullanıcı temposunu fazla agresif cezalandırıyorsa kullanıcıya gereksiz düşük teknik kalite sinyali üretilebilir. Tek kullanıcı ve tek cihaz verisi threshold tuning için yeterli değildir.

### Minimum doğru çözüm yönü

Production threshold değiştirmeden önce:

1. en az slow / normal / fast kontrollü tempo run'ları topla,
2. mümkünse birden fazla kullanıcı ve cihaz ekle,
3. persisted descent/ascent süre dağılımlarını mevcut `250 ms` phase-quality floor ve ideal tempo ayarlarından ayrı değerlendir,
4. detector FPS ile ölçülen tempo arasındaki ilişkiyi kontrol et,
5. counting ve coaching-confidence kabul kriterlerini ayrı tut.

### Exit kriteri

Normal kontrollü Biceps Curl temposunda false low-confidence oranı tekrarlanabilir biçimde yüksek kalırsa yalnız ilgili tempo validation katmanı minimal patch ile güncellenir. Sonrasında full positive, shallow negative ve one-arm regression tekrar edilir.

## F2 - R6 Biceps Curl protocol execution sapması

- Öncelik: **P2 - process**
- Katman: Validation process
- Closure etkisi: Formal protocol-complete iddiasını engeller; engineering revalidation'ı engellemez

### Gözlem

Validation sırasında gerçek shallow-ROM failure bulunup production fix uygulandığı için run'lar birden fazla SHA üzerinde yürütüldü. Ayrıca occlusion ve lifecycle için planlanan üçer döngünün yalnız birer kontrollü run'ı uygulandı; persistence 3 yerine 5 rep ile doğrulandı.

### Çözüm

Canlı manifest gerçek execution ile doldurulmuş, her run'ın SHA, diagnostics filename, actual units ve deviation reason alanları kaydedilmiştir.

### Exit kriteri

Sonraki exercise validation'larında closure öncesi planlanan repeat/cycle adetleri eksiksiz uygulanmalı veya sapma oluştuğu anda manifestte işaretlenmelidir.


## F3 - Lateral Raise pause/resume occlusion-resync telemetry inflation

- Öncelik: **P1**
- Katman: Diagnostics / lifecycle observability
- Etkilenen alan: Range-rep pause/resume telemetry
- Closure etkisi: Lateral Raise counting ve lifecycle closure'ını bloklamaz
- Ana kanıt: `diagnostics_v6_lateral_raise_20260722_233003.json`
- SHA: `d1120a32e870ee4c8efa466e9b0fda3593a2b69d`

### Gözlem

Pause/resume validation run'ında runtime sonucu doğrudur:

- ground truth = 3
- `rep_count = 3`
- `completeRep = 3`
- `valid = 3`
- `range_rep_abort_count = 0`
- `analysis_exception_count = 0`

Buna rağmen global visibility/lifecycle telemetry'si:

- `brief_occlusion_count = 20`
- `brief_occlusion_recovery_count = 1`
- `brief_occlusion_abort_count = 18`
- `resync_count = 18`
- `no_pose_frame_count = 1`
- `rejected_pose_frame_count = 0`

üretmiştir.

Bu kombinasyon, pause/suspend veya lifecycle reset akışlarının fiziksel occlusion olmayan event'leri global occlusion/resync sayaçlarına taşıyor olabileceğini düşündürür. Tek JSON event zaman çizelgesi taşımadığı için kök neden henüz kanıtlanmış değildir.

### Risk

Runtime rep güvenliği etkilenmemiştir; ancak diagnostics export'u pause/resume run'ını gerçek visibility kaybı gibi gösterebilir. Bu durum gelecekte occlusion reliability analizi ve aggregate telemetry yorumunu yanıltabilir.

### Minimum doğru çözüm yönü

1. pause, resume ve camera lifecycle event'lerinin global occlusion/resync sayaçlarına hangi kod yolundan ulaştığını izole et,
2. fiziksel pose loss ile intentional lifecycle suspension event'lerini ayrı event sınıflarıyla temsil et,
3. mevcut range-rep occlusion regression'larını koru,
4. fix sonrası gerçek `OCC-3` ve `LIFE-3` run'larını karşılaştır.

### Exit kriteri

Pause/resume sırasında fiziksel pose loss yoksa `brief_occlusion_abort_count` ve `resync_count` yalnız gerçek visibility/resync event'lerini yansıtmalı; intentional lifecycle suspension ayrı telemetry ile izlenmelidir.
