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
    type: ExerciseType.lunge,
    subtitle:
        'Tek bacak kontrolü, denge ve alt vücut kuvveti için dinamik hareket.',
    purpose:
        'Bacaklar arasındaki dengeyi, adım kontrolünü ve kalça-diz hizasını çalıştırır.',
    difficulty: ExerciseDifficulty.intermediate,
    setupSteps: [
      'Ayakta uzun ve dengeli başla.',
      'Kontrol edebileceğin kadar geniş bir adım at.',
      'Ön ayağını zemine sağlam yerleştir.',
      'Gövdeni dik, bakışını ileriye yakın tut.',
    ],
    tips: [
      'Aşağı inerken hareketi dikey ve kontrollü tut.',
      'Ön diz ayak hattını takip etsin.',
      'Arka dizi zemine yaklaştırırken acele etme.',
      'Yukarı kalkarken dengeyi bozmadan it.',
    ],
    commonMistakes: [
      'Adımı çok kısa atmak.',
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
];
