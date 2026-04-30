/// App configuration constants.
class AppConfig {
  /// Backend API base URL.
  /// Change this to your deployed Render URL in production.
  // static const String apiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String apiBaseUrl = 'http://localhost:8000'; // Web / iOS
  // static const String apiBaseUrl = 'https://your-app.onrender.com'; // Production

  /// App name
  static const String appName = 'GPay Extractor';

  /// Razorpay API Key ID
  static const String razorpayKey = 'YOUR_RAZORPAY_KEY'; // Replace with your actual key

  /// Available transaction tags
  static const List<String> tags = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Transfer',
    'Others',
  ];

  /// Tag icons mapping
  static const Map<String, int> tagIcons = {
    'Food': 0xe57a,        // Icons.restaurant
    'Travel': 0xe1d5,      // Icons.directions_car
    'Shopping': 0xe59c,     // Icons.shopping_bag
    'Bills': 0xe8b0,       // Icons.receipt_long
    'Entertainment': 0xe40f, // Icons.movie
    'Health': 0xe559,       // Icons.local_hospital
    'Education': 0xe80c,    // Icons.school
    'Transfer': 0xe8d4,     // Icons.swap_horiz
    'Others': 0xe895,       // Icons.more_horiz
  };

  /// Tag colors (as hex values)
  static const Map<String, int> tagColors = {
    'Food': 0xFFFF6B35,
    'Travel': 0xFF4ECDC4,
    'Shopping': 0xFFE91E8C,
    'Bills': 0xFF7B68EE,
    'Entertainment': 0xFFFFD93D,
    'Health': 0xFF6BCB77,
    'Education': 0xFF4D96FF,
    'Transfer': 0xFF95AABE,
    'Others': 0xFF8D99AE,
  };
}
