import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';

/// Screen showing all transactions for a specific category.
class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final List<Transaction> transactions;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.transactions,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late List<Transaction> _localTransactions;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _localTransactions = List.from(widget.transactions);
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    if (transaction.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete the transaction for ₹${transaction.amount} to ${transaction.recipient}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteTransaction(transaction.id!);
      if (success) {
        if (mounted) {
          setState(() {
            _localTransactions.removeWhere((tx) => tx.id == transaction.id);
            _hasChanges = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete transaction'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _localTransactions.fold<double>(0, (sum, tx) => sum + tx.amountValue);
    final colorValue = AppConfig.tagColors[widget.category] ?? 0xFF6C63FF;
    final color = Color(colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(widget.category, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(total, color, _localTransactions.length),
          Expanded(
            child: _localTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No transactions left', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _localTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _localTransactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: Key(transaction.id ?? 'tx_$index'),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            await _deleteTransaction(transaction);
                            return false; // We handle removal from state manually
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                          child: TransactionCard(transaction: transaction),
                        ),
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
            'Total ${widget.category} Spending',
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
