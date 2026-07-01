import '../models/exercise_guide_content.dart';

const exerciseGuideContents = [
  ExerciseGuideContent(
    id: 'squat',
    title: 'Squat',
    subtitle: 'Alt vücut gücü ve kalça-diz kontrolü için temel hareket.',
    difficulty: 'Orta',
    isAnalysisAvailable: true,
    tips: [
      'Ayaklarını omuz genişliğinde konumlandır.',
      'Dizlerini ayak parmaklarınla aynı hatta tut.',
      'Göğsünü açık, sırtını kontrollü ve doğal pozisyonda koru.',
      'Aşağı inerken kalçanı geriye doğru yönlendir.',
    ],
    commonMistakes: [
      'Dizlerin içe doğru kapanması.',
      'Sırtın fazla öne yuvarlanması.',
      'Topukların yerden kalkması.',
      'Hareketi çok hızlı ve kontrolsüz yapmak.',
    ],
  ),
  ExerciseGuideContent(
    id: 'plank',
    title: 'Plank',
    subtitle: 'Core dayanıklılığı ve gövde stabilitesi için izometrik hareket.',
    difficulty: 'Başlangıç',
    tips: [
      'Dirseklerini omuzlarının altında hizala.',
      'Kalçanı çok yukarı kaldırmadan düz bir çizgi oluştur.',
      'Karın kaslarını aktif tut ve nefesini tutma.',
      'Boynunu nötr pozisyonda koru.',
    ],
    commonMistakes: [
      'Kalçanın aşağı düşmesi.',
      'Belin çukurlaşması.',
      'Omuzların kulaklara doğru sıkışması.',
      'Nefesi tutarak gereksiz gerginlik oluşturmak.',
    ],
  ),
  ExerciseGuideContent(
    id: 'lunge',
    title: 'Lunge',
    subtitle: 'Tek bacak kontrolü, denge ve alt vücut kuvveti için dinamik hareket.',
    difficulty: 'Orta',
    tips: [
      'Öndeki dizini ayak bileğiyle aynı hatta tut.',
      'Gövdeni dik ve dengeli konumda koru.',
      'Arka dizini kontrollü şekilde yere yaklaştır.',
      'Her tekrarda iki bacak arasında kontrollü geçiş yap.',
    ],
    commonMistakes: [
      'Öndeki dizin içe veya fazla öne kaçması.',
      'Gövdenin yana devrilmesi.',
      'Adım mesafesinin çok kısa olması.',
      'Yerden hızlı ve kontrolsüz kalkmak.',
    ],
  ),
  ExerciseGuideContent(
    id: 'push_up',
    title: 'Push-up',
    subtitle: 'Üst vücut kuvveti, core kontrolü ve omuz stabilitesi için temel hareket.',
    difficulty: 'Orta',
    tips: [
      'Ellerini omuz genişliğinden biraz açık yerleştir.',
      'Baş, gövde ve kalçayı tek çizgide tut.',
      'Dirseklerini kontrollü şekilde bük ve aç.',
      'Karın ve kalça kaslarını hareket boyunca aktif tut.',
    ],
    commonMistakes: [
      'Kalçanın aşağı düşmesi.',
      'Dirseklerin fazla yana açılması.',
      'Boynun öne uzatılması.',
      'Yarım hareket aralığıyla tekrar yapmak.',
    ],
  ),
  ExerciseGuideContent(
    id: 'sit_up',
    title: 'Sit-up',
    subtitle: 'Karın kasları ve gövde fleksiyonu için klasik core hareketi.',
    difficulty: 'Başlangıç',
    tips: [
      'Ayaklarını sabit ve kontrollü tut.',
      'Yukarı kalkarken boynunu çekiştirme.',
      'Hareketi karın kaslarından başlat.',
      'Aşağı inerken kontrollü şekilde yere dön.',
    ],
    commonMistakes: [
      'Boynu ellerle çekmek.',
      'Momentumla hızlı kalkmak.',
      'Bel bölgesini kontrolsüz zorlamak.',
      'Nefesi tutarak hareket etmek.',
    ],
  ),
];
