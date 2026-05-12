import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/transaction.dart';

/// A styled card widget for displaying a transaction.
class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  Color get _tagColor {
    final colorValue = AppConfig.tagColors[transaction.tag];
    return colorValue != null ? Color(colorValue) : const Color(0xFF8D99AE);
  }

  IconData get _tagIcon {
    return AppConfig.tagIcons[transaction.tag] ?? Icons.more_horiz;
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type.toLowerCase() == 'expense';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8ECF4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1D26).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Tag icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _tagIcon,
                  color: _tagColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.recipient.isNotEmpty
                          ? transaction.recipient
                          : 'Unknown',
                      style: const TextStyle(
                        color: Color(0xFF1A1D26),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tagColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            transaction.tag,
                            style: TextStyle(
                              color: _tagColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          transaction.date,
                          style: TextStyle(
                            color: const Color(0xFF1A1D26).withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? "-" : "+"}₹${transaction.amount}',
                    style: TextStyle(
                      color: isExpense
                          ? const Color(0xFFFF4757)
                          : const Color(0xFF2ED573),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.type,
                    style: TextStyle(
                      color: const Color(0xFF1A1D26).withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
