import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/transaction.dart';
import 'auth_service.dart';

/// Service for communicating with the FastAPI backend.
class ApiService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  /// Get authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getIdToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
      };
    }
    return {};
  }

  /// Upload an image file to the backend for OCR processing.
  static Future<UploadResponse> uploadImage(XFile imageFile) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);
      final headers = await _getAuthHeaders();
      request.headers.addAll(headers);

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: imageFile.name,
        ));
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UploadResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        return UploadResponse(
          success: false,
          message: error['detail'] ?? 'Upload failed (${response.statusCode})',
          needsReview: true,
        );
      }
    } catch (e) {
      return UploadResponse(
        success: false,
        message: 'Connection error: $e',
        needsReview: true,
      );
    }
  }

  /// Parse pasted transaction text.
  static Future<UploadResponse> parseText(String text) async {
    try {
      final uri = Uri.parse('$_baseUrl/parse-text');
      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final body = jsonEncode({'text': text});
      
      final response = await http.post(uri, headers: headers, body: body).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UploadResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        return UploadResponse(
          success: false,
          message: error['detail'] ?? 'Failed to parse text',
          needsReview: true,
        );
      }
    } catch (e) {
      return UploadResponse(
        success: false,
        message: 'Network error: $e',
        needsReview: true,
      );
    }
  }

  /// Save a confirmed transaction to Supabase.
  static Future<Map<String, dynamic>> saveTransaction(Transaction transaction) async {
    try {
      final uri = Uri.parse('$_baseUrl/save');
      final authHeaders = await _getAuthHeaders();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode(transaction.toSaveJson()),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Saved successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to save (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Fetch recent transaction history.
  static Future<List<Transaction>> getHistory({int count = 20, String? type, int? month, int? year}) async {
    try {
      String url = '$_baseUrl/history?count=$count';
      if (type != null && type != 'All') url += '&type=${type.toLowerCase()}';
      if (month != null) url += '&month=$month';
      if (year != null) url += '&year=$year';
      
      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['transactions'] != null) {
          return (data['transactions'] as List)
              .map((tx) => Transaction.fromJson(tx))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get daily spending total.
  static Future<DailyTotal> getDailyTotal({String? date}) async {
    try {
      String url = '$_baseUrl/daily-total';
      if (date != null) url += '?target_date=$date';

      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DailyTotal.fromJson(data);
      }
      return DailyTotal(date: '', totalExpense: 0, totalIncome: 0, netBalance: 0, transactionCount: 0);
    } catch (e) {
      return DailyTotal(date: '', totalExpense: 0, totalIncome: 0, netBalance: 0, transactionCount: 0);
    }
  }

  /// Get available tags.
  static Future<List<String>> getTags() async {
    try {
      final uri = Uri.parse('$_baseUrl/tags');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['tags'] ?? []);
      }
      return AppConfig.tags;
    } catch (e) {
      return AppConfig.tags;
    }
  }

  /// Check if backend is reachable.
  static Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get AI spending analysis and insights.
  static Future<String?> analyzeSpending(Map<String, double> categoryTotals, double totalSpending) async {
    try {
      final uri = Uri.parse('$_baseUrl/analyze-spending');
      final authHeaders = await _getAuthHeaders();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({
          'category_totals': categoryTotals,
          'total_spending': totalSpending,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['insight'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user profile, plan, and credits.
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final uri = Uri.parse('$_baseUrl/profile');
      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a Razorpay order.
  static Future<Map<String, dynamic>?> createOrder(String planId) async {
    try {
      final uri = Uri.parse('$_baseUrl/create-order');
      final authHeaders = await _getAuthHeaders();
      final response = await http.post(
        uri, 
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({'plan_id': planId}),
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verify Razorpay payment.
  static Future<bool> verifyPayment(Map<String, dynamic> razorpayResponse, String planId) async {
    try {
      final uri = Uri.parse('$_baseUrl/verify-payment');
      final authHeaders = await _getAuthHeaders();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({
          ...razorpayResponse,
          'plan_id': planId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete a transaction from Supabase.
  static Future<bool> deleteTransaction(String transactionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/transactions/$transactionId');
      final headers = await _getAuthHeaders();
      final response = await http.delete(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
