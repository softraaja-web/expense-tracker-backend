import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/daily_summary.dart';
import '../config/app_config.dart';

/// History screen showing all logged transactions with filtering.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  DailyTotal _dailyTotal = DailyTotal(date: '', totalExpense: 0, totalIncome: 0, netBalance: 0, transactionCount: 0);
  String _selectedType = 'All';
  String _selectedTag = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ApiService.getHistory(count: 50, type: _selectedType),
      ApiService.getDailyTotal(),
    ]);

    if (mounted) {
      setState(() {
        _transactions = results[0] as List<Transaction>;
        _dailyTotal = results[1] as DailyTotal;
        _isLoading = false;
      });
    }
  }

  List<Transaction> get _filteredTransactions {
    if (_selectedTag == 'All') return _transactions;
    return _transactions.where((tx) => tx.tag == _selectedTag).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D26),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF6C63FF),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Daily Total
            SliverToBoxAdapter(
              child: DailySummary(
                dailyTotal: _dailyTotal,
                isLoading: _isLoading,
              ),
            ),

            // Type Filter
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: ['All', 'Expense', 'Income'].map((type) {
                      final isSelected = _selectedType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedType = type);
                            _loadData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ] : null,
                            ),
                            child: Text(
                              type,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1A1D26).withOpacity(0.5),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Tag Filter Chips
            SliverToBoxAdapter(
              child: Container(
                height: 40,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['All', ...AppConfig.tags].map((tag) {
                    final isSelected = tag == _selectedTag;
                    final colorValue = tag != 'All'
                        ? AppConfig.tagColors[tag] ?? 0xFF8D99AE
                        : 0xFF6C63FF;
                    final color = Color(colorValue);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(tag),
                        labelStyle: TextStyle(
                          color: isSelected ? color : const Color(0xFF1A1D26).withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: color.withOpacity(0.1),
                        side: BorderSide(
                          color: isSelected ? color.withOpacity(0.35) : const Color(0xFFE0E4EF),
                        ),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (_) {
                          setState(() => _selectedTag = tag);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Results count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '${_filteredTransactions.length} transaction${_filteredTransactions.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: const Color(0xFF1A1D26).withOpacity(0.35),
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            // Transaction List
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF6C63FF),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_filteredTransactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: const Color(0xFF1A1D26).withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: TextStyle(
                          color: const Color(0xFF1A1D26).withOpacity(0.35),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TransactionCard(
                      transaction: _filteredTransactions[index],
                    );
                  },
                  childCount: _filteredTransactions.length,
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
