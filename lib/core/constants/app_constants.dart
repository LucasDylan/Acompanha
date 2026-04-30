/// App-wide constants (categories, limits, etc.).
class AppConstants {
  AppConstants._();

  static const List<String> meetingCategories = [
    'Coffee',
    'Networking',
    'Mentorship',
    'Language Practice',
    'Travel Companionship',
    'Casual Social',
  ];

  static const int maxPhotosPerProfile = 6;
  static const int maxBioLength = 500;
  static const int minSlotDurationMinutes = 30;
  static const int maxSlotDurationMinutes = 480; // 8 hours
}
