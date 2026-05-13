import 'package:flutter/material.dart';

/// App configuration constants.
class AppConfig {
  /// Backend API base URL.
  /// Change this to your deployed Render URL in production.
  // static const String apiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String apiBaseUrl = 'http://localhost:8000'; // Web / iOS
  // static const String apiBaseUrl = 'http://localhost:8000'; // Web / iOS
  static const String apiBaseUrl = 'https://gpay-transaction-extractor.onrender.com';

  /// App name
  static const String appName = 'GPay Extractor';

  /// Razorpay API Key ID
  static const String razorpayKey = 'rzp_test_SojIgaUnpX8laR'; // Replace with your actual key

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
  static const Map<String, IconData> tagIcons = {
    'Food': Icons.restaurant,
    'Travel': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt_long,
    'Entertainment': Icons.movie,
    'Health': Icons.local_hospital,
    'Education': Icons.school,
    'Transfer': Icons.swap_horiz,
    'Others': Icons.more_horiz,
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

  /// Available subscription plans
  static const List<SubscriptionPlan> availablePlans = [
    SubscriptionPlan(
      id: 'free',
      name: 'Free',
      price: 0,
      limit: 20,
      description: '20 transactions/month',
    ),
    SubscriptionPlan(
      id: 'plus',
      name: 'Plus',
      price: 99,
      limit: 300,
      description: '300 transactions/month',
    ),
    SubscriptionPlan(
      id: 'pro',
      name: 'Pro',
      price: 299,
      limit: 1000,
      description: '1,000 transactions/month',
    ),
  ];
}

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final int limit;
  final String description;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.limit,
    required this.description,
  });
}
