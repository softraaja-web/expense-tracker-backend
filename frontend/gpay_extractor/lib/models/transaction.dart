/// Transaction data model matching the backend API response.
class Transaction {
  final String? id;
  final String date;
  final String amount;
  final String recipient;
  final String? upiId;
  final String type;
  final String tag;
  final String source;
  final double confidence;
  final String? rawText;

  Transaction({
    this.id,
    required this.date,
    required this.amount,
    required this.recipient,
    this.upiId,
    this.type = 'expense',
    this.tag = 'Others',
    this.source = 'screenshot',
    this.confidence = 1.0,
    this.rawText,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString(),
      date: json['date'] ?? json['Date'] ?? '',
      amount: json['amount'] ?? json['_amount'] ?? json['Amount'] ?? '',
      recipient: json['recipient'] ?? json['to'] ?? json['To'] ?? json['Recipient'] ?? '',
      upiId: json['upi_id'] ?? json['upi id'] ?? json['UPI ID'],
      type: (json['type'] == null || json['type'].toString().trim().isEmpty) 
          ? 'expense' 
          : json['type'].toString().toLowerCase(),
      tag: json['tag'] ?? 'Others',
      source: json['source'] ?? 'screenshot',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      rawText: json['raw_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'amount': amount,
      'recipient': recipient,
      'upi_id': upiId,
      'type': type,
      'tag': tag,
      'source': source,
    };
  }

  Map<String, dynamic> toSaveJson() {
    return {
      'date': date,
      'amount': amount,
      'recipient': recipient,
      'upi_id': upiId,
      'type': type,
      'tag': tag,
      'source': source,
    };
  }

  Transaction copyWith({
    String? id,
    String? date,
    String? amount,
    String? recipient,
    String? upiId,
    String? type,
    String? tag,
    String? source,
    double? confidence,
    String? rawText,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      recipient: recipient ?? this.recipient,
      upiId: upiId ?? this.upiId,
      type: type ?? this.type,
      tag: tag ?? this.tag,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
    );
  }

  /// Extracts numeric value from amount string (e.g., "₹100.00" -> 100.0)
  double get amountValue {
    final clean = amount.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }
}

/// API response wrapper for upload endpoint.
class UploadResponse {
  final bool success;
  final Transaction? data;
  final String message;
  final bool needsReview;

  UploadResponse({
    required this.success,
    this.data,
    this.message = '',
    this.needsReview = false,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? Transaction.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      needsReview: json['needs_review'] ?? false,
    );
  }
}

/// Daily total response.
class DailyTotal {
  final String date;
  final double totalExpense;
  final double totalIncome;
  final double netBalance;
  final int transactionCount;

  DailyTotal({
    required this.date,
    required this.totalExpense,
    required this.totalIncome,
    required this.netBalance,
    required this.transactionCount,
  });

  factory DailyTotal.fromJson(Map<String, dynamic> json) {
    return DailyTotal(
      date: json['date'] ?? '',
      totalExpense: (json['total_expense'] ?? 0.0).toDouble(),
      totalIncome: (json['total_income'] ?? 0.0).toDouble(),
      netBalance: (json['net_balance'] ?? 0.0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
    );
  }
}
