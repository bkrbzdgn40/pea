import '../models/workout_goal.dart';

const demoWorkoutGoals = [
  WorkoutGoal(
    id: 'weekly_analysis_count',
    title: 'Haftalık 5 analiz',
    targetValue: 5,
    currentValue: 3,
    unit: 'analiz',
    description: 'Bu hafta en az 5 canlı analiz tamamla.',
    isCompleted: false,
  ),
  WorkoutGoal(
    id: 'average_score_85',
    title: 'Ortalama skoru 85 üstüne çıkar',
    targetValue: 85,
    currentValue: 82,
    unit: 'skor',
    description: 'Form kalitesini koruyarak ortalama skorunu yükselt.',
    isCompleted: false,
  ),
  WorkoutGoal(
    id: 'total_reps_200',
    title: 'Toplam 200 tekrar',
    targetValue: 200,
    currentValue: 126,
    unit: 'tekrar',
    description: 'Haftalık toplam tekrar hacmini kontrollü şekilde artır.',
    isCompleted: false,
  ),
  WorkoutGoal(
    id: 'three_day_streak',
    title: '3 gün üst üste antrenman',
    targetValue: 3,
    currentValue: 3,
    unit: 'gün',
    description: 'Düzenli antrenman ritmini koru.',
    isCompleted: true,
  ),
];
