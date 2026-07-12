# Android Profile Beta Build

## Amaç

Bu workflow, E0 engineering baseline için Android profile APK üretir. Üretilen artifact bir production release veya Play Store paketi değildir; amaç commit SHA doğrulanabilir, indirilebilir bir engineering beta artifact sağlamaktır.

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

## Signing sınırı

- Bu production signing değildir.
- Bu Play Store artifact'i değildir.
- Farklı workflow run'larında kullanılan engineering signing sertifikası değişebilir.
- Signature uyuşmazlığında önceki uygulamanın kaldırılması gerekebilir.
- Gerçek production signing, final release hardening kapsamındadır.
