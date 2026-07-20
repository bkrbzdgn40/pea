import '../models/exercise_guide_content.dart';
import '../../domain/models/exercise_type.dart';

/// Static product copy for the guide; analysis support policy lives in ExerciseCatalog.
const exerciseGuideContents = [
  ExerciseGuideContent(
    type: ExerciseType.squat,
    subtitle: 'Alt vücut kuvveti ve diz-kalça kontrolü için temel hareket.',
    purpose:
        'Bacak, kalça ve gövde stabilitesini birlikte çalıştırır. Kontrollü derinlik ve düzgün hat önceliklidir.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayaklarını omuz genişliğine yakın yerleştir.',
      'Ağırlığını topuk ve orta ayakta dengede tut.',
      'Göğsünü açık, bakışını doğal seviyede koru.',
      'İnişe başlamadan gövdeni sıkı ve dengeli hazırla.',
    ],
    tips: [
      'Kalçanı geriye ve aşağı kontrollü yönlendir.',
      'Dizlerin ayak hattını takip etsin.',
      'Ağrısız ve kontrol edebildiğin derinlikte çalış.',
      'Yukarı kalkarken zemini güçlü ama kontrollü it.',
    ],
    commonMistakes: [
      'Dizlerin içe kapanması.',
      'Topukların yerden ayrılması.',
      'Gövdenin kontrolsüz öne düşmesi.',
      'İnişi hızlı, kalkışı savruk yapmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=aclHkVaku9U',
    youtubeSourceLabel: 'Bowflex',
  ),
  ExerciseGuideContent(
    type: ExerciseType.plank,
    subtitle: 'Core dayanıklılığı ve gövde stabilitesi için izometrik hareket.',
    purpose:
        'Gövdenin sabit kalma becerisini geliştirir. Süreden çok pozisyon kalitesi önemlidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Dirseklerini omuzlarının altına hizala.',
      'Ayaklarını kalça genişliğine yakın konumla.',
      'Başından topuğuna kadar uzun bir çizgi kur.',
      'Nefesini tutmadan pozisyona yerleş.',
    ],
    tips: [
      'Karın ve kalçayı hafif aktif tut.',
      'Belinin aşağı çökmesine izin verme.',
      'Omuzlarını kulaklarından uzak tut.',
      'Süre uzadıkça form bozuluyorsa kısa dinlen.',
    ],
    commonMistakes: [
      'Kalçanın fazla yükselmesi.',
      'Belin çukurlaşması.',
      'Boynu yukarı kaldırmak.',
      'Nefesi tutarak gereksiz gerginlik oluşturmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=pSHjTRCQxIw',
    youtubeSourceLabel: 'ScottHermanFitness',
  ),
  ExerciseGuideContent(
    type: ExerciseType.hollowHold,
    subtitle:
        'Sirt ustu core gerilimi, govde kontrolu ve izometrik dayaniklilik icin ileri seviye hareket.',
    purpose:
        'Karni aktif tutmayi, omuzlari yerden ayirmayi, kollari bas ustune uzatmayi ve bacaklari duz tutarken govde kontrolunu korumayi hedefler.',
    difficulty: ExerciseDifficulty.advanced,
    setupSteps: [
      'Sirt ustu uzan ve belini kontrollu sekilde zemine yaklastir.',
      'Karni sıkmadan aktiflestir, kaburgalari asiri disari acma.',
      'Omuzlarini yerden hafif ayir ve kollari bas ustune uzat.',
      'Bacaklarini kaldirirken dizleri duz ve govdeyi sabit tutmaya odaklan.',
    ],
    tips: [
      'Form bozuluyorsa bacak yuksekligini azalt veya dizleri hafif buk.',
      'Kollari kulaklara yakin uzat ve boynu gereksiz kasma.',
      'Hareket boyunca nefesi tutmadan core gerilimini surdur.',
      'Sureyi zorlamak yerine duzgun compression ve duz bacaklari koru.',
    ],
    commonMistakes: [
      'Bel kontrolunu kaybedip govdeyi gevsetmek.',
      'Kollari bas ustunde tutamadan omuzlari dusurmek.',
      'Dizleri bikip bacak hattini bozmak.',
      'Bacaklari fazla indirmek pahasina formu kaybetmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=u6vuP12rdJY',
    youtubeSourceLabel: 'FITTR',
  ),
  ExerciseGuideContent(
    type: ExerciseType.lunge,
    subtitle:
        'Sabit adim pozisyonunda tek bacak kontrolu ve alt vucut kuvveti icin hareket.',
    purpose:
        'Sabit split stance pozisyonunda on bacagin kontrollu fleksiyon-ekstansiyonunu ve dengeyi calistirir.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta uzun ve dengeli başla.',
      'Ayaklarini rahat bir split stance pozisyonuna al ve adim boyunu sabitle.',
      'Kameraya yakin bacagini onde tut ve ayagini zemine saglam yerlestir.',
      'Gövdeni dik, bakışını ileriye yakın tut.',
    ],
    tips: [
      'Aşağı inerken hareketi dikey ve kontrollü tut.',
      'Ön diz ayak hattını takip etsin.',
      'Arka dizi zemine yaklaştırırken acele etme.',
      'Yukarı kalkarken dengeyi bozmadan it.',
    ],
    commonMistakes: [
      'Tekrarlar arasinda ayak pozisyonunu degistirmek.',
      'Ön dizin içe kaçması.',
      'Gövdenin yana devrilmesi.',
      'Zeminden hızlı ve kontrolsüz sekmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=D7KaRcUTQeE',
    youtubeSourceLabel: 'Bowflex',
  ),
  ExerciseGuideContent(
    type: ExerciseType.pushUp,
    subtitle:
        'Üst vücut kuvveti, core kontrolü ve omuz stabilitesi için temel hareket.',
    purpose:
        'İtme kuvvetini, omuz kontrolünü ve gövde hattını birlikte geliştirir.',
    difficulty: ExerciseDifficulty.advanced,
    setupSteps: [
      'Ellerini omuz genişliğinden biraz açık yerleştir.',
      'Başından topuğuna kadar düz bir hat kur.',
      'Karın ve kalçayı aktif tut.',
      'Gerekirse yüksek bir yüzeyde daha kolay varyasyonla başla.',
    ],
    tips: [
      'İnişi ve kalkışı kontrollü tamamla.',
      'Dirseklerini aşırı yana açma.',
      'Göğsünü zemine yaklaştırırken hattını koru.',
      'Bilek rahatsızsa el pozisyonunu nazikçe ayarla.',
    ],
    commonMistakes: [
      'Kalçanın aşağı düşmesi.',
      'Boynun öne uzaması.',
      'Dirseklerin tamamen yana açılması.',
      'Yarım ve acele tekrar yapmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=IODxDxX7oi4',
    youtubeSourceLabel: 'Calisthenicmovement',
  ),
  ExerciseGuideContent(
    type: ExerciseType.sitUp,
    subtitle: 'Gövde fleksiyonu için kontrollü core hareketi.',
    purpose:
        'Karın kaslarını dinamik olarak çalıştırır. Kontrol ve rahatlık, tekrar sayısından önemlidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Dizlerini bük, ayaklarını rahatça yere yerleştir.',
      'Ellerini boynunu çekmeyecek şekilde konumla.',
      'Hareket alanını rahat ve kontrollü tut.',
      'Bel veya boyun rahatsızlığı varsa zorlamadan dur.',
    ],
    tips: [
      'Yukarı kalkarken boynunu çekiştirme.',
      'Hızı değil kontrolü öne al.',
      'Aşağı inerken gövdeni yavaşça bırak.',
      'Rahatsızlık hissedersen daha kısa aralıkta çalış.',
    ],
    commonMistakes: [
      'Boynu ellerle çekmek.',
      'Momentumla hızlı kalkmak.',
      'Bel bölgesini zorlayacak kadar savrulmak.',
      'Nefesi tutarak hareket etmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=UMaZGY6CbC4',
    youtubeSourceLabel: 'Beginner technique video',
  ),
  ExerciseGuideContent(
    type: ExerciseType.bicepsCurl,
    subtitle:
        'Eş zamanlı iki kol curl kontrolü için ayakta üst vücut hareketi.',
    purpose:
        'İki kolun birlikte, kontrollü ve simetrik çalışmasını hedefler. Dirseklerin gövdeye yakın kalması ve salınımın sınırlanması önceliklidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Ayakta dengeli dur ve iki kolunu başlangıçta aşağıda uzat.',
      'Omuz, dirsek, bilek ve kalçaların kadrajda net görünmesini sağla.',
      'İlk kalibrasyon için kamerayı yaklaşık 30-45 derece çapraz açıyla yerleştir.',
      'Hareket boyunca iki kolun birlikte başlayıp birlikte bitmesine hazırlan.',
    ],
    tips: [
      'Her iki kolu aynı anda yukarı çek.',
      'Dirseklerini gövdeye yakın ve sabit tut.',
      'Omuz veya üst kol savurmak yerine ön kol hareketini öne çıkar.',
      'Aşağı dönüşü yavaş ve kontrollü tamamla.',
    ],
    commonMistakes: [
      'Kolları sırayla veya farklı hızlarda kaldırmak.',
      'Dirsekleri yana açmak ya da öne savurmak.',
      'Gövdeden momentum alarak sallanmak.',
      'Bir kolu erken indirip diğerini tepede bırakmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=ykJmrZ5v0Oo',
    youtubeSourceLabel: 'Simultaneous standing curl demo',
  ),

  ExerciseGuideContent(
    type: ExerciseType.lyingLegRaise,
    subtitle:
        'Sirt ustu kalca fleksiyonu ve core kontrolu icin dinamik hareket.',
    purpose:
        'Bacaklari birlikte kaldirip indirirken kalca fleksiyonunu ve dizlerin uzatilmis kalmasini izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Sirt ustu uzan ve tum vucudunu yan kamerada gorunecek sekilde kadraja al.',
      'Bacaklarini birlikte ve dizlerini rahatca uzatilmis tut.',
      'Baslangicta bacaklarini zemine yakin, govdenle ayni hatta konumla.',
      'Belinde agri olursa hareket araligini azalt veya hareketi birak.',
    ],
    tips: [
      'Bacaklari tek parca gibi kontrollu kaldir.',
      'Dizlerini gereksiz bukmeden rahat bir hareket araligi kullan.',
      'Inisi yercekimiyle birakmak yerine kontrollu tamamla.',
      'Bel kontrolunu kaybetmeden hareket et.',
    ],
    commonMistakes: [
      'Dizleri belirgin bukmek.',
      'Bacaklari momentumla savurmak.',
      'Inisi kontrolsuz hizlandirmak.',
      'Bel rahatsizligina ragmen hareket araligini zorlamak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=JB2oyawG9KI',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.tricepsDip,
    subtitle:
        'Paralel bar uzerinde dirsek ekstansiyonu odakli ust vucut itis hareketi.',
    purpose:
        'Dirsek fleksiyon-ekstansiyonunu ana tekrar sinyali olarak izler ve asiri omuz ekstansiyonuna karsi form uyarisi verebilir.',
    difficulty: ExerciseDifficulty.advanced,
    setupSteps: [
      'Paralel barlarda ust pozisyonda kollarini kontrollu uzat.',
      'Kamerayi yandan, omuz-dirsek-bilek hattini gorecek sekilde yerlestir.',
      'Gogsu ve omuzlari rahat bir pozisyonda tut.',
      'Omuz agrisi varsa derinligi zorlamadan hareketi birak.',
    ],
    tips: [
      'Dirsekleri bukerek kontrollu asagi in.',
      'Omuzlari gereksiz yere cok geriye tasima.',
      'Alt noktadan kontrollu sekilde yukari it.',
      'Tekrarlar boyunca ayni derinligi korumaya calis.',
    ],
    commonMistakes: [
      'Omuzlari asiri derine zorlamak.',
      'Alt noktada kontrolsuz sekmek.',
      'Yarim dirsek hareket araligiyla tekrar yapmak.',
      'Goruntu disina cikacak kadar one-arkaya sallanmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=2z8JmcrW-As',
    youtubeSourceLabel: 'Bar dip technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.romanianDeadlift,
    subtitle:
        'Kalca menteşesi ve posterior chain kontrolu icin dinamik kuvvet hareketi.',
    purpose:
        'Ana hareketi kalca acisindan izler; diz acisinin tekrar boyunca gorece sabit kalmasini form sinyali olarak kullanir.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta dik basla ve kamerayi tam yandan yerlestir.',
      'Dizlerini hafif buk ve bu aciyi hareket boyunca buyuk olcude sabit tut.',
      'Kalcalarini geriye gondererek govdeyi kalcadan katla.',
      'Agirligi bacaklara yakin bir hatta tut.',
    ],
    tips: [
      'Hareketi dizlerden cok kalcadan baslat.',
      'Diz bukulmesini tekrar boyunca belirgin artirma.',
      'Kontrol edebildigin kalca fleksiyonunda don.',
      'Yukari gelirken kalcalari ileri getir ve govdeyi tamamla.',
    ],
    commonMistakes: [
      'Hareketi squata cevirip dizleri fazla bukmek.',
      'Agirligi govdeden uzaklastirmak.',
      'Alt noktayi zorlamak icin bel pozisyonunu kaybetmek.',
      'Kalca menteşesi yerine sadece govdeyi egmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=2SHsk9AzdjA',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.lateralRaise,
    subtitle: 'Omuz abdüksiyonu icin kontrollu iki kol kaldirma hareketi.',
    purpose:
        'Iki kolun yana kaldirilmasini birlikte izler; omuz acisi ana sinyal, dirsek uzatilmisligi form sinyalidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya onden bak ve iki omuz-dirsek-bilek hattini kadraja al.',
      'Kollarini yanlarda rahat bir sekilde baslat.',
      'Dirsekleri kilitlemeden hafif yumusak ama buyuk olcude uzatilmis tut.',
      'Iki kolu ayni anda hareket ettirmeye hazirlan.',
    ],
    tips: [
      'Kollari kontrollu sekilde yana kaldir.',
      'Omuz hizasi civarinda gereksiz yuksekligi zorlamadan don.',
      'Dirsek acini tekrar boyunca buyuk olcude koru.',
      'Agirligi savurmadan kontrollu indir.',
    ],
    commonMistakes: [
      'Dirsekleri belirgin bukerek hareketi kisaltmak.',
      'Kollari omuz hizasinin cok ustune savurmak.',
      'Govdeden momentum almak.',
      'Iki kolu farkli hizlarda hareket ettirmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=3VcKaXpzqRo',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.shoulderPress,
    subtitle: 'Iki kol overhead press icin dirsek ekstansiyonu odakli hareket.',
    purpose:
        'Iki dirsegin birlikte acilmasini ana tekrar sinyali olarak izler ve kontrollu press-donus dongusunu sayar.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya onden bak ve iki omuz-dirsek-bilek hattini kadraja al.',
      'Dirsekleri alt baslangic pozisyonunda rahatca buk.',
      'Iki kolu ayni anda yukari preslemeye hazirlan.',
      'Bas ve govde pozisyonunu gereksiz hareket ettirmeden sabit tut.',
    ],
    tips: [
      'Iki kolu birlikte yukari presle.',
      'Ustte dirsekleri kontrollu uzat.',
      'Baslangic pozisyonuna yavasca geri don.',
      'Tekrarlar arasinda ayni alt pozisyonu koru.',
    ],
    commonMistakes: [
      'Kollari farkli zamanlarda preslemek.',
      'Yarim dirsek hareket araligiyla tekrar yapmak.',
      'Agirligi kontrolsuz dusurmek.',
      'Govdeyi belirgin savurarak momentum kullanmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=qEwKCR5JCog',
    youtubeSourceLabel: 'Technique reference',
  ),
];
