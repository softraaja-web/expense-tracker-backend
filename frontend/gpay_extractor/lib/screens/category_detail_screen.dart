import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../config/app_config.dart';

/// Screen showing all transactions for a specific category.
class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<Transaction> transactions;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = transactions;
    final total = filteredTransactions.fold<double>(0, (sum, tx) => sum + tx.amountValue);
    final colorValue = AppConfig.tagColors[category] ?? 0xFF6C63FF;
    final color = Color(colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(total, color, filteredTransactions.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TransactionCard(transaction: filteredTransactions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double total, Color color, int count) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            'Total $category Spending',
            style: TextStyle(
              color: const Color(0xFF1A1D26).withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count Transactions',
            style: TextStyle(
              color: const Color(0xFF1A1D26).withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
