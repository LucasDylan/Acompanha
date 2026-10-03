/// Options for the gym-partner side of the profile.
class Fitness {
  Fitness._();

  static const workoutTypes = [
    'Musculação',
    'Cardio',
    'Corrida',
    'CrossFit',
    'Funcional',
    'Pilates',
    'Calistenia',
    'Natação',
    'Yoga',
    'Lutas',
  ];

  /// Same values the API validates (`WEEK_DAYS`).
  static const weekDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  static const levels = {
    'beginner': 'Iniciante',
    'intermediate': 'Intermediário',
    'advanced': 'Avançado',
  };

  static String levelLabel(String? level) =>
      levels[level] ?? levels['beginner']!;
}
