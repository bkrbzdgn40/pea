# R6 Wave B - Lying Leg Raise Results

Bu belge Lying Leg Raise R6 gerçek cihaz closure sonucunu kaydeder.

## Sonuç

**Status: `R6 Engineering Revalidated`**

**Follow-up: `Deferred`**

**Formal protocol-complete: `No`**

Lying Leg Raise gerçek cihaz validation'ında ilk preflight run'ı lifecycle'ın çalışabildiğini gösterdi. Daha sonraki mixed full + partial run'da ise fiziksel olarak geçerli bazı tekrarların hiç `reachPeak` transition'ına ulaşamadığı bir false-negative bulundu.

## İlk Preflight Kanıtı

SHA-pinned profile diagnostics:

```text
app_commit_sha = 6c02accca39740ef86b941e27e9cac7c057b8e8c
build_mode = profile
exercise_type = lying_leg_raise

rep_count = 4
startDescending = 5
reachPeak = 5
startAscending = 5
completeRep = 4

range_rep_validation_count = 4
valid = 2
lowConfidence = 2
invalid = 0

analysis_exception_count = 0
```

Snapshot beşinci hareketin `ASCENDING` fazında alındığı için 4 completed rep ile 5 lifecycle başlangıcının birlikte görünmesi kayıp-rep kanıtı olarak değerlendirilmedi.

Bu run'da completed-rep validation tarafında `insufficientRom` görülmedi.

## Device Finding - Peak Acquisition False Negative

İkinci gerçek cihaz run'ında kullanıcı aynı set içinde hem düzgün tam tekrarlar hem de gerçekten partial hareketler yaptı.

Video kare incelemesi ile diagnostics birlikte değerlendirildiğinde:

- bazı gerçek partial hareketlerin sayılmaması doğruydu,
- ancak birkaç fiziksel olarak geçerli tam tekrar da sayılmadı,
- engine yedi kez active lifecycle başlatmasına rağmen hiçbirinde `reachPeak` onaylamadı.

Failure diagnostics:

```text
app_commit_sha = 6c02accca39740ef86b941e27e9cac7c057b8e8c
build_mode = profile

startDescending = 7
reachPeak = 0
startAscending = 0
completeRep = 0
abortToNeutral = 6

rep_count = 0
range_rep_validation_count = 0
```

Bu nedenle kök alan completed-rep validation veya `minAcceptableRomDelta` değil, peak acquisition olarak sınıflandırıldı.

## Hardening

Production config'teki `thresholdPeak = 105°` değiştirilmedi.

Lying Leg Raise contract'ı generic `3°` peak-entry marjı yerine configured peak threshold'u literal giriş sınırı olarak kullanacak şekilde ayrıştırıldı:

```text
peakEntryMargin = 0°
```

Generic peak confirmation lifecycle'ı da gerçek hysteresis semantiğiyle hizalandı:

1. strict peak entry bir kez görülür,
2. pending peak confirmation başlar,
3. sonraki sparse analysis sample'ı strict entry bandından çıkmış olsa bile peak-exit hysteresis bandını aşmadığı sürece pending confirmation korunur,
4. exit hysteresis aşılırsa pending peak iptal edilir.

Regression kapsamı:

```text
104° -> 110° sparse-sample sequence
=> peak confirmation korunur

109° shallow partial
=> strict peak entry yok
=> rep yok

pending peak -> 120° exit-hysteresis breach
=> pending peak iptal
```

## Fix Sonrası Cihaz Sonucu

Hardening ve temiz local gate sonrasında kullanıcı gerçek cihaz retest'inde hareketin tamamlandığını ve mevcut davranışın yeterli olduğunu bildirdi.

Bu closure için fix sonrası ayrı diagnostics JSON sağlanmadı. Bu nedenle post-fix kesin rep adedi, transition sayaçları veya performance percentile'ları closure kanıtı olarak uydurulmaz.

## Execution Sapmaları

Aşağıdaki planlı run'lar ayrı final kanıt olarak sabitlenmedi:

- `R6-LLR-POS-20` formal 20-rep run
- `R6-LLR-STATIC-30`
- `R6-LLR-PARTIAL-10` bağımsız formal run
- `R6-LLR-FORM-5`
- `R6-LLR-LIFE`
- `R6-LLR-PERSIST`

Mixed investigation videosunda gerçek partial hareketlerin reddedildiği gözlendi; ancak bu, planlı bağımsız `PARTIAL-10` run'ının eksiksiz uygulandığı anlamına gelmez.

Per-exercise occlusion testi ortak range-rep visibility reliability kanıtı nedeniyle tekrar edilmedi.

## Açık Finding'ler

1. Final post-fix diagnostics JSON sabitlenmedi.
2. Formal POS-20 / STATIC / FORM / LIFE / PERSIST run seti tamamlanmadı.
3. Pre-fix run'larda performans provisional gate'leri tam karşılanmadı; post-fix performance closure kanıtı yoktur.
4. Mixed investigation run'ındaki side-switch ve kısa visibility/resync olayları ayrı robustness finding olarak tutulur.

## Closure Kararı

Lying Leg Raise, doğal tam tekrarları kaçıran peak-acquisition false-negative'i sonrasında config threshold'u değiştirilmeden minimum doğru katmanda harden edilmiştir. Deterministik regression'lar temiz local gate'ten geçmiş, kullanıcı fix sonrası gerçek cihaz davranışını yeterli bulup hareketi tamamlamıştır.

Formal protokol eksiksiz uygulanmadığı ve fix sonrası diagnostics JSON sabitlenmediği için closure formal protocol-complete değildir.

**Final karar: `Lying Leg Raise = R6 Engineering Revalidated`, follow-up deferred.**
