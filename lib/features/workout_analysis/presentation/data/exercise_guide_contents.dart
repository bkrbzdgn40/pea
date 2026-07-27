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
    subtitle:
        'Merkez bölge dayanıklılığı ve gövde stabilitesi için izometrik hareket.',
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
        'Sırt üstü merkez bölge gerilimi, gövde kontrolü ve izometrik dayanıklılık için ileri seviye hareket.',
    purpose:
        'Karnı aktif tutmayı, omuzları yerden ayırmayı, kolları baş üstüne uzatmayı ve bacakları düz tutarken gövde kontrolünü korumayı hedefler.',
    difficulty: ExerciseDifficulty.advanced,
    setupSteps: [
      'Sırt üstü uzan ve belini kontrollü şekilde zemine yaklaştır.',
      'Karnı sıkmadan aktifleştir, kaburgaları aşırı dışarı açma.',
      'Omuzlarını yerden hafif ayır ve kolları baş üstüne uzat.',
      'Bacaklarını kaldırırken dizleri düz ve gövdeyi sabit tutmaya odaklan.',
    ],
    tips: [
      'Form bozuluyorsa bacak yüksekliğini azalt veya dizleri hafif bük.',
      'Kolları kulaklara yakın uzat ve boynu gereksiz kasma.',
      'Hareket boyunca nefesi tutmadan merkez bölge gerilimini sürdür.',
      'Süreyi zorlamak yerine gövde sıkılığını ve düz bacak pozisyonunu koru.',
    ],
    commonMistakes: [
      'Bel kontrolünü kaybedip gövdeyi gevşetmek.',
      'Kolları baş üstünde tutamadan omuzları düşürmek.',
      'Dizleri büküp bacak hattını bozmak.',
      'Bacakları fazla indirmek pahasına formu kaybetmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=u6vuP12rdJY',
    youtubeSourceLabel: 'FITTR',
  ),
  ExerciseGuideContent(
    type: ExerciseType.lunge,
    subtitle:
        'Sabit adım pozisyonunda tek bacak kontrolü ve alt vücut kuvveti için hareket.',
    purpose:
        'Sabit ayrık duruş pozisyonunda ön bacağın kontrollü fleksiyon-ekstansiyonunu ve dengeyi çalıştırır.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta uzun ve dengeli başla.',
      'Ayaklarını rahat bir ayrık duruş pozisyonuna al ve adım boyunu sabitle.',
      'Kameraya yakın bacağını önde tut ve ayağını zemine sağlam yerleştir.',
      'Gövdeni dik, bakışını ileriye yakın tut.',
    ],
    tips: [
      'Aşağı inerken hareketi dikey ve kontrollü tut.',
      'Ön diz ayak hattını takip etsin.',
      'Arka dizi zemine yaklaştırırken acele etme.',
      'Yukarı kalkarken dengeyi bozmadan it.',
    ],
    commonMistakes: [
      'Tekrarlar arasında ayak pozisyonunu değiştirmek.',
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
        'Üst vücut kuvveti, merkez bölge kontrolü ve omuz stabilitesi için temel hareket.',
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
    subtitle: 'Gövde fleksiyonu için kontrollü merkez bölge hareketi.',
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
        'Eş zamanlı iki kol büküş kontrolü için ayakta üst vücut hareketi.',
    purpose:
        'İki kolun birlikte, kontrollü ve simetrik çalışmasını hedefler. Dirseklerin gövdeye yakın kalması ve salınımın sınırlanması önceliklidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Ayakta dengeli dur ve iki kolunu başlangıçta aşağıda uzat.',
      'Omuz, dirsek, bilek ve kalçaların kadrajda net görünmesini sağla.',
      'İlk kalibrasyon için kamerayı doğrudan karşıdan, iki kol ve kalçaların birlikte görüneceği şekilde yerleştir.',
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
        'Sırt üstü kalça fleksiyonu ve merkez bölge kontrolü için dinamik hareket.',
    purpose:
        'Bacakları birlikte kaldırıp indirirken kalça fleksiyonunu ve dizlerin uzatılmış kalmasını izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Sırt üstü uzan ve tüm vücudunu yan kamerada görünecek şekilde kadraja al.',
      'Bacaklarını birlikte ve dizlerini rahatça uzatılmış tut.',
      'Başlangıçta bacaklarını zemine yakın, gövdenle aynı hatta konumla.',
      'Belinde ağrı olursa hareket aralığını azalt veya hareketi bırak.',
    ],
    tips: [
      'Bacakları tek parça gibi kontrollü kaldır.',
      'Dizlerini gereksiz bükmeden rahat bir hareket aralığı kullan.',
      'İnişi yerçekimine bırakmak yerine kontrollü tamamla.',
      'Bel kontrolünü kaybetmeden hareket et.',
    ],
    commonMistakes: [
      'Dizleri belirgin bükmek.',
      'Bacakları momentumla savurmak.',
      'İnişi kontrolsüz hızlandırmak.',
      'Bel rahatsızlığına rağmen hareket aralığını zorlamak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=JB2oyawG9KI',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.tricepsDip,
    subtitle:
        'Sabit bir bench veya sağlam yükselti üzerinde triseps odaklı vücut ağırlığı itiş hareketi.',
    purpose:
        'Dirsek fleksiyon-ekstansiyonunu ana tekrar sinyali olarak izler ve aşırı omuz ekstansiyonuna karşı form uyarısı verebilir.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Sağlam ve kaymayan bir bench veya yükseltinin kenarına, sırtın yüzeye dönük olacak şekilde ellerini yerleştir.',
      'Kalçanı benchin hemen önüne al; ayaklarını öne yerleştir ve ağırlığını ellerinle kontrollü destekle.',
      'Kamerayı yandan, omuz-dirsek-bilek hattını görecek şekilde yerleştir.',
      'Omuz ağrısı veya rahatsızlık hissedersen derinliği zorlama ve hareketi bırak.',
    ],
    tips: [
      'Dirsekleri geriye doğru bükerek kontrollü aşağı in.',
      'Alt pozisyonda dirsek açısını yaklaşık 90 derece civarında tut; gereksiz derinliği zorlama.',
      'Kalçanı benchin kenarına yakın tut ve omuzlarını gereksiz yere öne-yukarı taşıma.',
      'Avuçlarından iterek kontrollü biçimde başlangıç pozisyonuna dön.',
    ],
    commonMistakes: [
      'Omuzları gereksiz derecede geriye ve aşağı zorlamak.',
      'Kalçayı benchten fazla uzaklaştırmak.',
      'Alt noktada kontrolsüz sekmek.',
      'Yarım dirsek hareket aralığıyla tekrar yapmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=akoIbSegslk',
    youtubeSourceLabel: 'Bench dip technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.romanianDeadlift,
    subtitle:
        'Kalça menteşesi ve arka zincir kontrolü için dinamik kuvvet hareketi.',
    purpose:
        'Ana hareketi kalça açısından izler; diz açısının tekrar boyunca görece sabit kalmasını form sinyali olarak kullanır.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta dik başla ve kamerayı tam yandan yerleştir.',
      'Dizlerini hafif bük ve bu açıyı hareket boyunca büyük ölçüde sabit tut.',
      'Kalçalarını geriye göndererek gövdeyi kalçadan katla.',
      'Ağırlığı bacaklara yakın bir hatta tut.',
    ],
    tips: [
      'Hareketi dizlerden çok kalçadan başlat.',
      'Diz bükülmesini tekrar boyunca belirgin artırma.',
      'Kontrol edebildiğin kalça fleksiyonunda dön.',
      'Yukarı gelirken kalçaları ileri getir ve gövdeyi tamamla.',
    ],
    commonMistakes: [
      'Hareketi squata çevirip dizleri fazla bükmek.',
      'Ağırlığı gövdeden uzaklaştırmak.',
      'Alt noktayı zorlamak için bel pozisyonunu kaybetmek.',
      'Kalça menteşesi yerine sadece gövdeyi eğmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=2SHsk9AzdjA',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.goodMorning,
    subtitle:
        'Kalça menteşesi ve arka zincir kontrolü için ayakta yapılan kontrollü kuvvet hareketi.',
    purpose:
        'Ana hareketi kalça açısından izler; diz açısının tekrar boyunca görece sabit kalmasını form sinyali olarak kullanır.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta dik başla ve kamerayı tam yandan yerleştir.',
      'Ayaklarını kalça genişliğinde aç ve dizlerini hafifçe yumuşak tut.',
      'Ellerini göğsünde veya başının arkasında rahatça konumlandır.',
      'Kalçanı geriye göndermeden önce gövdeni sıkı ve dengeli hazırla.',
    ],
    tips: [
      'Hareketi dizlerden değil kalçayı geriye göndererek başlat.',
      'Diz açını tekrar boyunca büyük ölçüde sabit tut.',
      'Gövde hizanı koruyabildiğin kontrollü derinlikte geri dön.',
      'Yukarı gelirken kalçalarını ileri getir ve dik pozisyonu tamamla.',
    ],
    commonMistakes: [
      'Dizleri fazla bükerek hareketi squata çevirmek.',
      'Kontrollü kalça menteşesi yerine belden yuvarlanmak.',
      'Hareket aralığını zorlamak için gövde hizasını kaybetmek.',
      'Yukarı dönüşte kalçayı tamamlamadan tekrarı bitirmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=f23vXjoG2e8',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.lateralRaise,
    subtitle: 'Omuz abdüksiyonu için kontrollü iki kol kaldırma hareketi.',
    purpose:
        'İki kolun yana kaldırılmasını birlikte izler; omuz açısı ana sinyal, dirsek uzatılmışlığı form sinyalidir.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya önden bak ve iki omuz-dirsek-bilek hattını kadraja al.',
      'Kollarını yanlarda rahat bir şekilde başlat.',
      'Dirsekleri kilitlemeden hafif yumuşak ama büyük ölçüde uzatılmış tut.',
      'İki kolu aynı anda hareket ettirmeye hazırlan.',
    ],
    tips: [
      'Kolları kontrollü şekilde yana kaldır.',
      'Omuz hizası civarında gereksiz yüksekliği zorlamadan dön.',
      'Dirsek açını tekrar boyunca büyük ölçüde koru.',
      'Ağırlığı savurmadan kontrollü indir.',
    ],
    commonMistakes: [
      'Dirsekleri belirgin bükerek hareketi kısaltmak.',
      'Kolları omuz hizasının çok üstüne savurmak.',
      'Gövdeden momentum almak.',
      'İki kolu farklı hızlarda hareket ettirmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=3VcKaXpzqRo',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.shoulderPress,
    subtitle: 'İki kol baş üstü itiş için dirsek ekstansiyonu odaklı hareket.',
    purpose:
        'İki dirseğin birlikte açılmasını ana tekrar sinyali olarak izler ve kontrollü itiş-dönüş döngüsünü sayar.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya önden bak ve iki omuz-dirsek-bilek hattını kadraja al.',
      'Dirsekleri alt başlangıç pozisyonunda rahatça bük.',
      'İki kolu aynı anda yukarı itmeye hazırlan.',
      'Baş ve gövde pozisyonunu gereksiz hareket ettirmeden sabit tut.',
    ],
    tips: [
      'İki kolu birlikte yukarı it.',
      'Üstte dirsekleri kontrollü uzat.',
      'Başlangıç pozisyonuna yavaşça geri dön.',
      'Tekrarlar arasında aynı alt pozisyonu koru.',
    ],
    commonMistakes: [
      'Kolları farklı zamanlarda yukarı itmek.',
      'Yarım dirsek hareket aralığıyla tekrar yapmak.',
      'Ağırlığı kontrolsüz düşürmek.',
      'Gövdeyi belirgin savurarak momentum kullanmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=qEwKCR5JCog',
    youtubeSourceLabel: 'Technique reference',
  ),

  ExerciseGuideContent(
    type: ExerciseType.calfRaise,
    subtitle:
        'Baldır kuvveti ve ayak bileği plantar fleksiyonu için kontrollü tekrar hareketi.',
    purpose:
        'Topuk yükseltme-alçaltma döngüsünü izler; hareket boyunca diz hattını büyük ölçüde sabit tutmayı hedefler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kamerayı yandan, kalça-diz-ayak bileği-ayak hattını görecek şekilde yerleştir.',
      'Ayaklarını rahat ve dengeli bir pozisyonda tut.',
      'Dizlerini kilitlemeden büyük ölçüde uzatılmış başla.',
      'Topuklarını birlikte ve kontrollü kaldırmaya hazırlan.',
    ],
    tips: [
      'Topukları yukarı taşırken ayak parmakları üzerinde dengeni koru.',
      'Dizlerini belirgin biçimde bükerek hareketten kaçma.',
      'Üst noktada kısa ve kontrollü bir duruş yap.',
      'Aşağı dönüşü yerçekimine bırakmadan tamamla.',
    ],
    commonMistakes: [
      'Dizlerden yaylanmak.',
      'Topukları çok az kaldırmak.',
      'Üst noktada dengeyi kaybetmek.',
      'Aşağı kontrolsüz düşmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=-M4-G8p8fmc',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.frontRaise,
    subtitle: 'Omuz fleksiyonu için kontrollü öne kol kaldırma hareketi.',
    purpose:
        'Kolun öne yükselmesini ve dirsek hattının büyük ölçüde uzatılmış kalmasını izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kamerayı yandan, omuz-dirsek-bilek ve kalça hattını görecek şekilde yerleştir.',
      'Kollarını gövdenin yanında rahat başlat.',
      'Dirseklerini kilitlemeden büyük ölçüde uzatılmış tut.',
      'Gövdeyi savurmadan kolu öne kaldırmaya hazırlan.',
    ],
    tips: [
      'Kolu kontrollü biçimde öne kaldır.',
      'Omuz hizası civarında gereksiz yüksekliği zorlamadan dön.',
      'Dirsek açını tekrar boyunca büyük ölçüde koru.',
      'Aşağı dönüşü yavaş tamamla.',
    ],
    commonMistakes: [
      'Dirseği belirgin bükmek.',
      'Gövdeyi geriye savurmak.',
      'Kolu kontrolsüz yukarı fırlatmak.',
      'Aşağı dönüşü hızlı bırakmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=-t7fuZ0KhDA',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.gluteBridge,
    subtitle:
        'Kalça ekstansiyonu ve arka zincir kontrolü için yerde yapılan hareket.',
    purpose:
        'Omuz-kalça-diz hattının açılmasını ana tekrar sinyali olarak izler ve kontrollü köprü döngüsünü sayar.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan ve kamerayı tam yandan yerleştir.',
      'Dizlerini bük, ayaklarını zemine dengeli bas.',
      'Omuz, kalça, diz ve ayak bileğinin kadrajda olduğundan emin ol.',
      'Kalçanı kontrollü kaldırmaya hazırlan.',
    ],
    tips: [
      'Kalçayı yukarı iterken gövdeyi kontrollü aç.',
      'Üst noktada belini aşırı çukurlaştırma.',
      'Ayaklarını hareket boyunca sabit tut.',
      'Aşağı dönüşü kontrollü tamamla.',
    ],
    commonMistakes: [
      'Belden aşırı yaylanmak.',
      'Kalçayı yeterince yükseltmeden yarım tekrar yapmak.',
      'Ayakları tekrarlar arasında kaydırmak.',
      'Aşağı kontrolsüz düşmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=wPM8icPu6H8',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.wallSit,
    subtitle:
        'Diz ve kalça açısını sabit tutmaya dayalı izometrik alt vücut hareketi.',
    purpose:
        'Duvar oturuşunda kontrollü diz derinliği, kalça pozisyonu ve dik gövde hattını sürdürmeyi hedefler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Sırtını duvara ver ve kamerayı yandan yerleştir.',
      'Ayaklarını duvardan rahat bir mesafeye al.',
      'Dizlerini kontrollü bükerek oturuş pozisyonuna in.',
      'Baş, omuz, kalça, diz ve ayak bileğinin kadrajda kalmasını sağla.',
    ],
    tips: [
      'Diz açını rahat ve kontrollü aralıkta sabit tut.',
      'Gövdeni duvar hattına yakın ve dik koru.',
      'Ayak tabanlarını zeminde dengeli tut.',
      'Pozisyon bozuluyorsa süreyi zorlamak yerine çık.',
    ],
    commonMistakes: [
      'Çok yukarıda kalarak hareketi etkisizleştirmek.',
      'Aşırı derine inip pozisyonu sürdürememek.',
      'Gövdeyi öne katlamak.',
      'Ayakları pozisyon boyunca kaydırmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=y-wV4Venusw',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.sidePlank,
    subtitle:
        'Yan gövde dayanıklılığı ve yanal merkez bölge stabilitesi için izometrik hareket.',
    purpose:
        'Omuz-kalça-ayak hattını, dengeli bir ön kol veya düz kol desteğini ve uzatılmış bacak pozisyonunu korumayı hedefler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Yan yat; ön kol desteğinde dirseğini, düz kol desteğinde elini omzunun altına yerleştir.',
      'Bacaklarını uzat ve ayaklarını üst üste ya da dengeli bir pozisyonda tut.',
      'Kamerayı gövdenin önünden veya arkasından vücut hattını görecek şekilde yerleştir.',
      'Kalçanı kaldırarak omuzdan ayak bileğine uzun bir çizgi kur.',
    ],
    tips: [
      'Kalçanın aşağı düşmesine izin verme.',
      'Ön kol veya düz kol desteğini omuz altında ve stabil tut.',
      'Bacak hattını mümkün olduğunca uzun tut.',
      'Nefesi tutmadan pozisyonu sürdür.',
    ],
    commonMistakes: [
      'Kalçanın zemine doğru sarkması.',
      'Destek dirseğinin veya elinin omuz hattından çok uzağa kaçması.',
      'Dizleri belirgin bükmek.',
      'Gövdeyi öne veya arkaya döndürmek.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=K2VljzCC16g',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.jumpingJack,
    subtitle:
        'Kol ve bacakların eş zamanlı açılıp kapandığı dinamik tam vücut hareketi.',
    purpose:
        'İki kolun birlikte yükselmesini ana tekrar sinyali, bacakların yana açılmasını ise form sinyali olarak izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya önden bak ve tüm vücudunu kadraja al.',
      'Ayaklarını yakın, kollarını yanlarda başlat.',
      'İki kol ve iki bacağın net göründüğünden emin ol.',
      'Kollar ve bacakları aynı döngüde açıp kapatmaya hazırlan.',
    ],
    tips: [
      'Kolları ve bacakları aynı anda aç.',
      'Üst noktada kolları yeterli yüksekliğe taşı.',
      'Bacak açılımını küçük bir kol hareketiyle taklit etme.',
      'İnişleri yumuşak ve ritmik tut.',
    ],
    commonMistakes: [
      'Sadece kolları hareket ettirmek.',
      'Kolları farklı hızlarda kaldırmak.',
      'Ayakları kontrolsüz ve sert indirmek.',
      'Tekrarları aceleyle yarım hareket aralığında yapmak.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=c4DAnQ6DtF8',
    youtubeSourceLabel: 'Technique reference',
  ),
  ExerciseGuideContent(
    type: ExerciseType.crunch,
    subtitle:
        'Merkez bölge kontrolü için omuzların zeminden kontrollü kaldırıldığı kısa gövde fleksiyonu.',
    purpose:
        'Omuz-kalça hattındaki kontrollü kapanmayı izler ve tam mekikten daha kısa bir hareket aralığında tekrar sayar.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan, dizlerini bük ve ayaklarını zemine yerleştir.',
      'Kamerayı yandan, omuz-kalça-diz hattını görecek şekilde konumlandır.',
      'Boynunu rahat tut ve ellerini başını çekmeyecek bir pozisyona al.',
      'Omuzlarını kontrollü kaldırmaya hazır şekilde nötr pozisyonda bekle.',
    ],
    tips: [
      'Omuzlarını zeminden kaldırırken gövdeni kısa ve kontrollü kıvır.',
      'Belini zorla yerden koparmadan merkez bölgeni kullan.',
      'Üst noktada savrulmadan yön değiştir.',
      'Aşağı dönüşü yerçekimine bırakma.',
    ],
    commonMistakes: [
      'Boynu ellerle öne çekmek.',
      'Hareketi hızla savurarak tamamlamak.',
      'Omuzları yeterince kaldırmadan yarım tekrar yapmak.',
      'Aşağı kontrolsüz düşmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=crunch+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.reverseCrunch,
    subtitle:
        'Kalçanın kontrollü biçimde zeminden ayrıldığı merkez bölge hareketi.',
    purpose:
        'Omuz-kalça-diz açısındaki kapanmayı izleyerek kontrollü kalça kıvırma döngülerini sayar.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan ve dizlerini rahatça bük.',
      'Kamerayı yandan, omuz-kalça-diz hattı görünür olacak şekilde yerleştir.',
      'Kollarını denge için yanında tut ve gövdeni sabitle.',
      'Dizlerini kalçanın biraz ilerisinde, kontrollü kıvırmaya hazır bir başlangıç konumuna getir.',
    ],
    tips: [
      'Dizleri savurmak yerine kalçanı kontrollü kıvır.',
      'Üst noktada küçük ve temiz bir kalça kaldırışı hedefle.',
      'Belini rahatsız eden aşırı menzilden kaçın.',
      'Başlangıç pozisyonuna yavaşça dön.',
    ],
    commonMistakes: [
      'Bacakları momentumla savurmak.',
      'Kalçayı kaldırmadan yalnız dizleri hareket ettirmek.',
      'Üst noktada kontrolü kaybetmek.',
      'Aşağı dönüşü hızla bırakmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=reverse+crunch+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.bentKneeLegRaise,
    subtitle:
        'Dizler bükülü halde yapılan kontrollü kalça fleksiyonu ve merkez bölge hareketi.',
    purpose:
        'Omuz-kalça-diz açısını kullanarak bükülü bacakların kaldırılıp indirilmesini tekrar döngüsü olarak izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan, dizlerini rahatça bük ve bacaklarını birlikte tut.',
      'Kamerayı yandan, omuz-kalça-diz ve ayak bileği hattını görecek şekilde yerleştir.',
      'Kollarını denge için yanında tut.',
      'Belini zorlamadan bacaklarını düşük başlangıç konumuna getir.',
    ],
    tips: [
      'İki bacağını birlikte ve kontrollü kaldır.',
      'Diz açını hareket boyunca yaklaşık aynı tut.',
      'Bel kontrolünü kaybettiğin noktadan daha aşağı inme.',
      'İnişi yavaş ve kontrollü tamamla.',
    ],
    commonMistakes: [
      'Bacakları savurmak.',
      'Diz açısını tekrar boyunca sürekli değiştirmek.',
      'Bel kontrolünü kaybederek fazla aşağı inmek.',
      'Başlangıç konumuna hızlı düşmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=bent+knee+leg+raise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.standingHamstringCurl,
    subtitle:
        'Ayakta tek taraflı diz fleksiyonu ve arka bacak kontrolü için hareket.',
    purpose:
        'Kalça-diz-ayak bileği açısını izleyerek topuğun kalçaya doğru çekilip tekrar uzatılmasını sayar.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya yandan dön ve çalışan bacağını kameraya yakın tut.',
      'Ağırlığını destek bacağına dengeli biçimde aktar.',
      'Gerekirse sabit bir yüzeye hafifçe tutun.',
      'Çalışan dizi başlangıçta uzatılmış ve kalçayı sabit tut.',
    ],
    tips: [
      'Topuğunu kalçana doğru kontrollü çek.',
      'Dizini öne taşımadan uyluğunu mümkün olduğunca sabit tut.',
      'Gövdeni öne veya arkaya savurma.',
      'Bacağını başlangıç konumuna kontrollü uzat.',
    ],
    commonMistakes: [
      'Kalçadan öne doğru bükülmek.',
      'Dizi öne taşıyarak hareket aralığını taklit etmek.',
      'Destek bacağında dengeyi kaybetmek.',
      'Bacağı kontrolsüz bırakmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=standing+hamstring+curl+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.standingHipAbduction,
    subtitle:
        'Ayakta tek taraflı yanal bacak kaldırma ve kalça kontrolü hareketi.',
    purpose:
        'Omuz-kalça-diz açısını ana tekrar sinyali, diz açıklığını ise form sinyali olarak kullanır.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya önden bak ve tüm vücudunu kadraja al.',
      'Ağırlığını destek bacağına aktar ve gövdeni dik tut.',
      'Kollarını yanında rahat bırak veya denge için sabit bir yüzeye hafifçe tutun.',
      'Çalışan bacağını diz uzatılmış halde nötr pozisyonda başlat.',
    ],
    tips: [
      'Bacağını yana kaldırırken gövdeni karşı tarafa yatırma.',
      'Çalışan dizi mümkün olduğunca düz tut.',
      'Ayağını doğal hizada ve kalçanı öne dönük koru.',
      'Bacağını kontrollü biçimde başlangıca indir.',
    ],
    commonMistakes: [
      'Gövdeyi yana eğerek hareketi büyütmek.',
      'Çalışan dizi belirgin biçimde bükmek.',
      'Kalçayı dışa döndürmek.',
      'Bacağı kontrolsüz sallamak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=standing+hip+abduction+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.overheadTricepsExtension,
    subtitle:
        'İki kolun birlikte çalıştığı baş üstü dirsek ekstansiyonu hareketi.',
    purpose:
        'Her iki dirseğin eş zamanlı açılmasını tekrar sinyali, üst kol hizasını ise form sinyali olarak izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya önden bak ve baş, omuz, dirsek ve bileklerini kadraja al.',
      'Kollarını baş üstüne getir ve dirseklerini rahatça bük.',
      'Üst kollarını başına yakın ve gövdeni dik tut.',
      'İki kolu aynı anda hareket ettirmeye hazırlan.',
    ],
    tips: [
      'Dirseklerini birlikte ve kontrollü aç.',
      'Üst kollarını ileri-geri savurmadan sabit tut.',
      'Üst noktada dirsekleri zorla kilitleme.',
      'Ağırlığı baş arkasına kontrollü indir.',
    ],
    commonMistakes: [
      'Üst kolları iki yana açmak.',
      'Kolları farklı zamanlarda hareket ettirmek.',
      'Belden aşırı geriye yaslanmak.',
      'Ağırlığı hızla aşağı bırakmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=overhead+triceps+extension+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.uprightRow,
    subtitle:
        'Dirseklerin yukarı yönlendirildiği eş zamanlı iki kol çekiş hareketi.',
    purpose:
        'Her iki omuz açısının birlikte artmasını izleyerek kontrollü yukarı çekiş ve dönüş döngülerini sayar.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya önden bak ve iki omuz-dirsek-bilek hattını kadraja al.',
      'Kollarını gövdenin önünde aşağıda başlat.',
      'Omuzlarını rahat, gövdeni dik tut.',
      'İki dirseği aynı anda yukarı yönlendirmeye hazırlan.',
    ],
    tips: [
      'Çekişi ellerden çok dirseklerle yönlendir.',
      'Dirsekleri omuz hizasının gereksiz üzerine çıkarma.',
      'Gövdeyi savurmadan iki kolu birlikte hareket ettir.',
      'Aşağı dönüşü kontrollü tamamla.',
    ],
    commonMistakes: [
      'Omuzları kulaklara doğru aşırı sıkıştırmak.',
      'Gövde momentumuyla ağırlığı savurmak.',
      'Kolları farklı yüksekliklere çekmek.',
      'Ağırlığı kontrolsüz indirmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=upright+row+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.standingHipExtension,
    subtitle:
        'Ayakta tek taraflı kalça ekstansiyonu ve arka zincir kontrolü hareketi.',
    purpose:
        'Omuz-kalça-diz açısını kullanarak düz bacağın kontrollü biçimde geriye götürülüp başlangıca dönmesini izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya yandan dön ve çalışan bacağını kameraya yakın tut.',
      'Ağırlığını destek bacağına dengeli biçimde aktar.',
      'Çalışan dizini düz, gövdeni dik başlat.',
      'Gerekirse denge için sabit bir yüzeye hafifçe tutun.',
    ],
    tips: [
      'Bacağını kalçadan kontrollü biçimde geriye götür.',
      'Belini aşırı çukurlaştırmadan kalçayı çalıştır.',
      'Çalışan dizi mümkün olduğunca düz tut.',
      'Bacağını başlangıca kontrollü döndür.',
    ],
    commonMistakes: [
      'Gövdeyi öne eğerek hareketi büyütmek.',
      'Belden aşırı geriye yaylanmak.',
      'Çalışan dizi belirgin bükmek.',
      'Bacağı kontrolsüz sallamak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=standing+hip+extension+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.standingKneeRaise,
    subtitle:
        'Ayakta tek taraflı diz kaldırma, kalça fleksiyonu ve denge hareketi.',
    purpose:
        'Kalça açısındaki kapanmayı ve dizin bükülü kalmasını izleyerek kontrollü diz kaldırma tekrarlarını sayar.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Kameraya yandan dön ve çalışan bacağını kameraya yakın tut.',
      'Gövdeni dik ve destek ayağını dengeli tut.',
      'Çalışan bacağını başlangıçta uzatılmış konumda hazırla.',
      'Gerekirse hafif bir destek kullan.',
    ],
    tips: [
      'Dizini gövdene doğru kontrollü kaldır.',
      'Kaldırırken dizi rahatça bük.',
      'Gövdeyi geriye yatırmadan kalçadan hareket et.',
      'Ayağını zemine kontrollü döndür.',
    ],
    commonMistakes: [
      'Gövdeyi geriye yatırmak.',
      'Dizi yeterince bükmeden düz bacak gibi kaldırmak.',
      'Destek ayağında dengeyi kaybetmek.',
      'Bacağı hızlı ve kontrolsüz indirmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=standing+knee+raise+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.standingStraightLegRaise,
    subtitle: 'Ayakta düz bacakla yapılan kontrollü kalça fleksiyonu hareketi.',
    purpose:
        'Çalışan dizin uzatılmış kaldığı öne bacak kaldırma döngülerini kalça açısı üzerinden izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya yandan dön ve çalışan bacağını kameraya yakın tut.',
      'Ağırlığını destek bacağına aktar.',
      'Çalışan dizini düz ve ayağını nötr pozisyonda tut.',
      'Gövdeni dik ve dengeli başlat.',
    ],
    tips: [
      'Bacağını öne doğru kontrollü kaldır.',
      'Çalışan dizi hareket boyunca düz tut.',
      'Gövdeyi geriye yatırarak menzil kazanmaya çalışma.',
      'Bacağını yavaşça başlangıca indir.',
    ],
    commonMistakes: [
      'Çalışan dizi bükmek.',
      'Gövdeyi geriye yatırmak.',
      'Bacağı momentumla savurmak.',
      'İnişi kontrolsüz bırakmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=standing+straight+leg+raise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.vUp,
    subtitle:
        'Üst gövde ve düz bacakların birlikte yükseldiği ileri seviye merkez bölge hareketi.',
    purpose:
        'Omuz-kalça-diz açısındaki güçlü kapanmayı kullanarak kontrollü V biçimli tekrar döngülerini izler.',
    difficulty: ExerciseDifficulty.advanced,
    setupSteps: [
      'Sırt üstü uzan, bacaklarını birleştir ve dizlerini uzat.',
      'Kollarını baş üstünde uzun biçimde uzat.',
      'Kamerayı yandan, omuz-kalça-diz hattını görecek şekilde yerleştir.',
      'Belini zorlamadan uzun başlangıç pozisyonuna yerleş.',
    ],
    tips: [
      'Üst gövde ve bacakları birlikte kaldır.',
      'Dizleri mümkün olduğunca düz tut.',
      'Tepe noktasına savrulmadan kontrollü ulaş.',
      'Aşağı dönüşü yavaşça tamamla.',
    ],
    commonMistakes: [
      'Yalnız bacakları veya yalnız gövdeyi kaldırmak.',
      'Dizleri belirgin bükmek.',
      'Momentumla savrulmak.',
      'Başlangıç pozisyonuna kontrolsüz düşmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=v+up+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.frogPump,
    subtitle:
        'Ayak tabanları birleşik ve dizler dışa açık yapılan kısa kalça ekstansiyonu hareketi.',
    purpose:
        'Frog pozisyonunda kalçanın zeminden kontrollü kaldırılıp indirilmesini tekrar döngüsü olarak izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan ve dizlerini bük.',
      'Ayak tabanlarını birbirine getir ve dizlerini iki yana aç.',
      'Kollarını gövdenin yanında rahatça yerleştir.',
      'Kamerayı yandan kalça hattını görecek şekilde konumlandır.',
    ],
    tips: [
      'Kalçanı kontrollü biçimde yukarı kaldır.',
      'Üst noktada kalçayı sıkarken beli aşırı yaylandırma.',
      'Ayak tabanlarının temasını koru.',
      'Kalçanı zemine kontrollü indir.',
    ],
    commonMistakes: [
      'Belden aşırı yaylanmak.',
      'Ayak tabanlarını ayırmak.',
      'Kalçayı yeterince kaldırmadan yarım tekrar yapmak.',
      'Aşağı kontrolsüz düşmek.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=frog+pump+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.lyingTricepsExtension,
    subtitle:
        'Yerde sırtüstü pozisyonda yapılan kontrollü dirsek ekstansiyonu hareketi.',
    purpose:
        'Kameraya yakın dirseğin bükülü pozisyondan kontrollü açılıp tekrar bükülmesini izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Sırt üstü uzan, dizlerini bük ve ayaklarını yere bas.',
      'Kamerayı yandan, omuz-dirsek-bilek hattını görecek şekilde yerleştir.',
      'Üst kolunu omuz üzerinde sabit tut.',
      'Dirseğini bükerek ellerini başına yakın başlangıç konumuna getir.',
    ],
    tips: [
      'Dirseğini kontrollü biçimde aç.',
      'Üst kolu ileri-geri savurmadan sabit tut.',
      'Üst noktada dirseği zorla kilitleme.',
      'Ellerini başına doğru kontrollü indir.',
    ],
    commonMistakes: [
      'Üst kolu omuzdan hareket ettirmek.',
      'Dirseği yana açmak.',
      'Ağırlığı hızla başa doğru bırakmak.',
      'Hareketi yarım açışla tamamlamak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=lying+triceps+extension+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.floorChestPress,
    subtitle:
        'Yerde sırtüstü pozisyonda yapılan kontrollü göğüs press hareketi.',
    purpose:
        'Kameraya yakın dirseğin bükülü başlangıçtan açılıp tekrar yere yakın pozisyona dönmesini izler.',
    difficulty: ExerciseDifficulty.beginner,
    setupSteps: [
      'Sırt üstü uzan, dizlerini bük ve ayaklarını yere bas.',
      'Kamerayı yandan, omuz-dirsek-bilek hattını görecek şekilde yerleştir.',
      'Dirseğini yaklaşık dik açıyla bük ve üst kolunu zemine yakın tut.',
      'Bileğini dirseğinin üzerinde dengeli konumlandır.',
    ],
    tips: [
      'Kolunu kontrollü biçimde yukarı it.',
      'Omzunu zeminden gereksiz kaldırma.',
      'Üst noktada dirseği zorla kilitleme.',
      'Dirseğini zemine kontrollü yaklaştır.',
    ],
    commonMistakes: [
      'Omzu öne kaldırmak.',
      'Bileği aşırı geriye kırmak.',
      'Dirseği kontrolsüz zemine bırakmak.',
      'Tam açışa ulaşmadan yarım tekrar yapmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=floor+chest+press+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
  ExerciseGuideContent(
    type: ExerciseType.yRaise,
    subtitle:
        'Kolların çapraz yukarı kaldırılarak Y şekli oluşturduğu omuz kontrol hareketi.',
    purpose:
        'Her iki kolun birlikte Y hattına yükselmesini ana hareket, dirseklerin düz kalmasını form sinyali olarak izler.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Kameraya önden dön ve üst vücudunu kadraja al.',
      'Kollarını yanlarda aşağıda başlat.',
      'Dirseklerini hafif yumuşak ama uzun tut.',
      'Gövdeni dik ve omuzlarını rahat hazırla.',
    ],
    tips: [
      'Kollarını çapraz yukarı kaldırarak geniş bir Y oluştur.',
      'İki kolu aynı hızda hareket ettir.',
      'Dirsek açını hareket boyunca koru.',
      'Kolları kontrollü biçimde başlangıca indir.',
    ],
    commonMistakes: [
      'Dirsekleri belirgin bükmek.',
      'Kolları farklı yüksekliklere kaldırmak.',
      'Omuzları kulaklara doğru sıkıştırmak.',
      'Gövdeyi geriye savurmak.',
    ],
    youtubeUrl:
        'https://www.youtube.com/results?search_query=y+raise+exercise+technique',
    youtubeSourceLabel: 'Exercise technique search',
  ),
];
