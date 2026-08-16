/// App-wide constants (categories, limits, etc.).
class AppConstants {
  AppConstants._();

  static const List<String> meetingCategories = [
    'Café',
    'Networking',
    'Mentoria',
    'Prática de idiomas',
    'Acompanhamento de viagem',
    'Social casual',
  ];

  static const int maxPhotosPerProfile = 6;
  static const int maxBioLength = 500;
  static const int minSlotDurationMinutes = 30;
  static const int maxSlotDurationMinutes = 480; // 8 hours
}
