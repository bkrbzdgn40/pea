# Android Profile Beta Build

## Amaç

Bu workflow, Android üzerinde commit SHA'sı doğrulanabilir ve indirilebilir bir engineering profile APK üretir. İlk olarak E0 engineering baseline ve beta hardening kanıtı için kullanılmıştır; güncel kullanımda da gerçek cihaz doğrulaması gereken mühendislik çalışmalarında aynı artifact sözleşmesini sağlar.

Üretilen artifact bir production release veya Play Store paketi değildir. Tek başına bir egzersizin device-validation kabulünü veya beta release onayını kanıtlamaz; yalnız belirli commit için yeniden üretilebilir ve kimliği doğrulanabilir test artifact'i sağlar.

## Manuel çalıştırma

GitHub Actions içinden `Android Profile Beta Artifact` workflow'u yalnız `main` branch için manuel olarak çalıştırılır.

CLI örneği:

```bash
gh workflow run android-profile-beta.yml --ref main
```

## Run izleme

```bash
gh run watch <RUN_ID> --exit-status
```

## Artifact indirme

```bash
gh run download <RUN_ID> \
  --name pea-android-profile-<FULL_SHA> \
  --dir downloaded-profile-beta
```

## Checksum doğrulama

Linux/macOS:

```bash
cd downloaded-profile-beta
sha256sum -c SHA256SUMS.txt
```

Windows PowerShell:

```powershell
$expected = (Get-Content .\SHA256SUMS.txt).Split(' ')[0].Trim()
$apk = Get-ChildItem .\pea-profile-*.apk | Select-Object -First 1
$actual = (Get-FileHash $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

if ($actual -ne $expected.ToLowerInvariant()) {
  throw "APK checksum uyuşmuyor."
}
```

## Telefona kurulum

```bash
adb install -r pea-profile-<SHORT_SHA>.apk
```

## Diagnostics doğrulama

Panelde görünen Commit SHA, `build-metadata.txt` içindeki `commit_sha` değeri ile tam olarak aynı olmalıdır.

Eşleşmiyorsa test sonucu `INVALID` sayılmalıdır.

Bu eşleşme artifact'in hangi commit'ten üretildiğini doğrular; analiz doğruluğunu veya ilgili egzersizin cihaz kabulünü tek başına kanıtlamaz.

## Signing sınırı

- Bu production signing değildir.
- Bu Play Store artifact'i değildir.
- Farklı workflow run'larında kullanılan engineering signing sertifikası değişebilir.
- Signature uyuşmazlığında önceki uygulamanın kaldırılması gerekebilir.
- Gerçek production signing, final release hardening kapsamındadır.
