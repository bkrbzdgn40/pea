import '../models/achievement.dart';

const demoAchievements = [
  Achievement(
    id: 'first_analysis',
    title: 'İlk Analiz',
    description: 'İlk canlı analiz oturumunu tamamladın.',
    isUnlocked: true,
    progress: 1,
    requirementText: '1 analiz tamamla',
  ),
  Achievement(
    id: 'seven_day_streak',
    title: '7 Gün Seri',
    description: 'Antrenman alışkanlığını düzenli hale getir.',
    isUnlocked: false,
    progress: 0.43,
    requirementText: '7 gün üst üste antrenman yap',
  ),
  Achievement(
    id: 'score_90_plus',
    title: '90+ Skor',
    description: 'Yüksek form kalitesiyle güçlü bir oturum çıkar.',
    isUnlocked: false,
    progress: 0.82,
    requirementText: 'Bir oturumda 90+ ortalama skor al',
  ),
  Achievement(
    id: 'hundred_reps',
    title: '100 Tekrar',
    description: 'Toplam tekrar hacmini istikrarlı şekilde artır.',
    isUnlocked: true,
    progress: 1,
    requirementText: 'Toplam 100 tekrar tamamla',
  ),
  Achievement(
    id: 'ten_sessions',
    title: '10 Oturum',
    description: 'Antrenman geçmişini büyüt ve ritmini koru.',
    isUnlocked: false,
    progress: 0.6,
    requirementText: '10 analiz oturumu tamamla',
  ),
];
