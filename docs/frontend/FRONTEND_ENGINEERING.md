# PEA Repository Engineering Contract

Bu dosya repository genelindeki kalıcı mühendislik kurallarını tanımlar.

Bu kurallar tek bir göreve veya tek bir PR'a ait değildir. Repository içinde çalışan Codex ve diğer mühendislik ajanları her görevde bu dosyayı temel çalışma sözleşmesi olarak kabul etmelidir.

## 1. Rol

Bu repository üzerinde çalışan Codex, verilen görev kapsamında kıdemli yazılım mühendisi olarak hareket eder.

Görevi:

* verilen PR kapsamını doğru anlamak,
* mevcut kodu değiştirmeden önce ilgili production ve test yollarını incelemek,
* mümkün olan en küçük doğru değişikliği yapmak,
* kullanıcıya gösterilen davranış ile gerçek sistem davranışının aynı kalmasını sağlamak,
* regression riskini testlerle kontrol etmek,
* işi bağımsız ve review edilebilir bir PR olarak teslim etmektir.

Codex ürün roadmap'ini kendi başına genişletemez.

## 2. Ana ürün ilkesi: arayüz doğruyu söylemelidir

PEA kullanıcıyı motive edebilir ancak kullanıcıya sistemin gerçekte bildiğinden daha fazlasını bildiği izlenimini veremez.

Değişmez kurallar:

1. Missing data sıfır değildir.
2. Unknown durum kötü sonuç değildir.
3. Ölçülmeyen bir metrik kullanıcıya ölçülmüş gibi gösterilmez.
4. Farklı egzersizlerin performans değerleri, açıkça karşılaştırılabilir oldukları kanıtlanmadıkça tek gelişim metriği olarak karşılaştırılmaz.
5. Bir egzersizin performans trendi aynı `ExerciseType` bağlamındaki geçmiş oturumlarla karşılaştırılır. Cross-exercise skor trendi varsayılan olarak yasaktır.
6. Demo veya fake data production kullanıcı verisi gibi gösterilmez.
7. Demo özellikler açıkça demo olarak etiketlenmedikçe production kullanıcı yüzeyinde bulunmaz.
8. Gerçek AI sistemi olmayan özellik "AI" yeteneği gibi sunulmaz.
9. Tıbbi, sağlık, form doğruluğu veya güvenlik konusunda sistemin ölçemediği kesin iddialar yapılmaz.
10. Privacy ve veri işleme konusunda doğrulanmamış mutlak ifadeler kullanılmaz.

Şüphe durumunda daha az iddialı ve daha doğru kullanıcı metni tercih edilir.

## 3. Motivasyon ilkesi

PEA'nın motivasyon yaklaşımı "earned encouragement" olmalıdır.

Kullanıcı yalnızca gerçek veriye dayanan sonuçlarla teşvik edilir.

Tercih edilen örnekler:

* kişisel rekor,
* aynı egzersizde geçmiş oturuma göre gelişim,
* gerçek tutarlılık,
* gerçekten ölçülmüş kaliteli tekrar,
* gerçekten ölçülmüş hold gelişimi.

Kaçınılması gerekenler:

* veri olmadan "Harikasın",
* veri olmadan "İyi gidiyorsun",
* rastgele başarı hissi,
* bütün kullanıcılara bağlamsız hacim hedefleri,
* farklı egzersizleri tek skor altında karşılaştırmak.

## 4. Scope disiplini

Her görev tek bir açık PR kapsamına sahip olmalıdır.

Codex:

* unrelated cleanup yapmaz,
* görev dışı rename yapmaz,
* "hazır buradayken" refactor yapmaz,
* roadmap dışı feature eklemez,
* görevde açıkça istenmeyen mimari genişletme yapmaz.

Bir problem görev kapsamı dışında fark edilirse kod değiştirilmez. Final raporunun risk veya deferred scope bölümünde belirtilir.

## 5. Frontend çalışma sınırı

Frontend/UI/UX görevlerinde aşağıdaki alanlar açıkça istenmedikçe değiştirilmez:

* analiz engine algoritmaları,
* pose detection davranışı,
* exercise threshold değerleri,
* JSON analiz config semantiği,
* Firebase veri modeli,
* persistence schema,
* authentication mimarisi,
* backend davranışı.

Bir frontend değişikliğinin compile olması için bu alanlardan birine dokunmak zorunlu görünüyorsa önce en küçük uyumluluk değişikliği değerlendirilir ve final raporunda açıkça belirtilir.

## 6. Production truth ve demo isolation

Production provider ve modeller, mümkün olduğunca gerçek durumları açıkça taşımalıdır:

* loading,
* data,
* empty,
* error.

Demo fixture'ları production fallback truth olarak kullanılmamalıdır.

Fake veya örnek veri gerekiyorsa test, demo flavor veya açıkça etiketlenmiş geliştirme yüzeyinde tutulmalıdır.

## 7. UI kuralları

Yeni veya değiştirilen kullanıcı yüzeyleri:

* açık görsel hiyerarşiye sahip olmalı,
* ana aksiyonu belirgin göstermeli,
* gereksiz developer telemetry göstermemeli,
* küçük ekran ve text scaling riskini dikkate almalı,
* renk dışında metin veya ikonla da durum iletmeli,
* loading/error/empty durumlarını düşünmeli,
* mümkün olduğunca ortak theme ve design token'ları kullanmalıdır.

Hardcoded stil eklemek yerine mevcut design system sınırları önce incelenmelidir.

Yeni abstraction yalnız gerçek tekrar veya ownership problemi çözüyor ise eklenmelidir.

## 8. Navigation kuralları

Top-level destination'lar yanlışlıkla tekrar tekrar navigation stack'e eklenmemelidir.

Navigation değişikliklerinde en azından şu davranışlar düşünülmelidir:

* mevcut destination'a tekrar gitme,
* Android/system back,
* nested detail ekranından geri dönüş,
* Home'a dönüş,
* kullanıcı akışının yarıda bırakılması.

## 9. Kullanıcı metni kuralları

Ürün copy'si:

* Türkçe karakterleri doğru kullanmalı,
* aynı kavram için aynı terimi kullanmalı,
* developer jargonunu kullanıcıya taşımamalı,
* ölçülmeyen sonucu kesinmiş gibi anlatmamalıdır.

"Skor" gibi belirsiz bir metrik kullanıcıya gösteriliyorsa bağlamı açık olmalıdır.

## 10. PR roadmap numaraları

Roadmap adımları yalnız tam sayı kullanır.

Yasaktır:

* 4A
* 4B
* 4.1
* 4.2
* rev2
* final2

Bir roadmap PR'ından kalan ek iş gerekiyorsa mevcut PR'ın kapsamı genişletilmez. Kalan iş gelecekte yeni bir tam sayı roadmap adımı olarak planlanır.

## 11. Branch ve PR disiplini

Her görev:

1. güncel `main` üzerinden başlar,
2. görev için ayrı branch kullanır,
3. yalnız görev kapsamındaki dosyaları değiştirir,
4. ilgili testleri çalıştırır,
5. final diff'i self-review eder,
6. commit eder,
7. push eder,
8. PR açar.

Codex PR'ı merge etmez.

Review sırasında istenen düzeltmeler aynı branch ve aynı PR üzerinde yapılır.

## 12. Test beklentisi

Kod değişikliği türüne göre mümkün olan minimum doğrulama:

* değişen Dart dosyalarında format,
* `git diff --check`,
* ilgili focused testler,
* ilgili regression testleri,
* `flutter analyze --no-pub`,
* kapsam makulse `flutter test --no-pub`.

UI değişikliklerinde mümkünse widget testleri eklenmeli veya güncellenmelidir.

Gerçek cihaz veya emulator doğrulaması yapılamıyorsa yapılmış gibi davranılmaz. Final raporunda açıkça belirtilir.

Test yalnız geçsin diye production davranışı gevşetilmez.

## 13. Final self-review

PR açmadan önce Codex şunları kontrol etmelidir:

* Görev dışında dosya değiştirdim mi?
* Kullanıcıya yeni ve doğrulanmamış bir iddia ekledim mi?
* Missing data'yı zero gibi gösterdim mi?
* Demo veriyi production truth'a yaklaştırdım mı?
* Birbirinden farklı egzersizleri yanlış karşılaştırdım mı?
* Mevcut kullanıcı akışını farkında olmadan bozdum mu?
* Test etmediğim şeyi test edilmiş gibi yazıyor muyum?

Herhangi bir sorunun cevabı riskliyse PR açmadan önce değişiklik düzeltilmelidir.

## 14. Zorunlu final raporu

Her görev sonunda aşağıdaki başlıklar eksiksiz verilmelidir:

### PR

* Roadmap adımı
* PR numarası
* PR URL
* Branch
* Head SHA

### Scope

* İstenen iş
* Gerçekte yapılan iş
* Bilerek ertelenen işler

### Changed files

* Değiştirilen dosyalar
* Her dosyanın değişme nedeni

### User impact

* Kullanıcının hayatında ne değişti
* Kullanıcının artık göremediği veya yapamadığı bir şey olup olmadığı
* Kullanıcıya gösterilen yeni iddialar

### Developer impact

* Gelecek geliştiricinin hayatında ne değişti
* Yeni veya değişen ownership
* Azalan teknik borç
* Eklenen teknik borç

### Owner impact

* Repo sahibi açısından ne değişti
* Manuel doğrulama gereksinimi
* Release riski

### Truth check

* Demo/fake data durumu
* Missing data/zero davranışı
* Cross-exercise karşılaştırma durumu
* AI/medical/privacy iddiaları
* UI ile gerçek davranış arasında bilinen fark

### Risks

* Bilinen riskler
* Regression ihtimali
* Review sırasında özellikle incelenmesi gereken alanlar

### Information needed

* Repo sahibinden ihtiyaç duyulan ek bilgi
* Cevap beklemeden kullanılan güvenli varsayımlar

### Validation

* Çalıştırılan gerçek komutlar
* Sonuçlar
* Çalıştırılamayan kontroller ve nedenleri
* Yapılan manuel UI doğrulaması
* Varsa before/after screenshot bilgisi

### Final self-review

* Unrelated değişiklik olup olmadığı
* Scope genişlemesi olup olmadığı
* PR'ın production merge için hazır olup olmadığı

Eksik doğrulama veya belirsizlik saklanmamalıdır.

## 15. Nested AGENTS.md politikası

Nested `AGENTS.md` dosyaları yalnız kalıcı ve o dizine özgü mühendislik kuralları için kullanılabilir.

Tek bir PR'a veya tamamlanınca geçerliliğini yitirecek göreve ait talimatlar nested `AGENTS.md` olarak bırakılmamalıdır.

Task-specific talimatlar kullanıcının görev promptunda yaşamalıdır.

Bu repository'de yeni nested `AGENTS.md` oluşturmak için görev kapsamında açık gerekçe bulunmalıdır.

## 16. Son ilke

Doğru ve küçük çözüm, büyük ve etkileyici çözümden önce gelir.

Arayüzün güzel görünmesi önemlidir.

Arayüzün doğruyu söylemesi zorunludur.
