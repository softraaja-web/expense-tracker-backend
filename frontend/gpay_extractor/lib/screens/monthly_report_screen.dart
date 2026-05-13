import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../config/app_config.dart';
import 'category_detail_screen.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  Map<String, double> _categoryTotals = {};
  Map<String, List<Transaction>> _categoryGroups = {};
  double _totalExpense = 0;
  int _fetchToken = 0; // Used to cancel stale in-flight requests
  
  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<int> _years = List.generate(5, (index) => DateTime.now().year - index);

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _selectedYear = DateTime.now().year;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final token = ++_fetchToken; // Stamp this request
    setState(() => _isLoading = true);
    final data = await ApiService.getHistory(
      count: 1000, 
      type: 'expense',
      month: _selectedMonth,
      year: _selectedYear,
    );
    // Discard response if a newer fetch was started
    if (token != _fetchToken) return;
    _transactions = data;
    _processData();
  }

  /// Client-side guard: verify transaction date matches selected month & year.
  /// Date format from backend: "DD MMM YYYY" e.g. "13 May 2026"
  bool _isInSelectedMonth(String dateStr) {
    try {
      final parts = dateStr.trim().split(' ');
      if (parts.length < 3) return true;
      const monthAbbr = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final monthNum = monthAbbr.indexWhere(
        (m) => m.toLowerCase() == parts[1].toLowerCase()
      ) + 1; // 1-based
      final year = int.tryParse(parts[2]);
      if (monthNum == 0 || year == null) return true; // Can't parse, allow
      return monthNum == _selectedMonth && year == _selectedYear;
    } catch (_) {
      return true; // Allow if parsing fails
    }
  }

  void _processData() {
    double total = 0;
    Map<String, double> totals = {};
    Map<String, List<Transaction>> groups = {};

    for (var tx in _transactions) {
      // Only expenses for selected month/year
      if (tx.type.toLowerCase().trim() == 'expense' && _isInSelectedMonth(tx.date)) {
        final val = tx.amountValue;
        if (val > 0) {
          total += val;
          final category = tx.tag;
          totals[category] = (totals[category] ?? 0) + val;
          groups[category] ??= [];
          groups[category]!.add(tx);
        }
      }
    }

    if (mounted) {
      setState(() {
        _totalExpense = total;
        _categoryTotals = totals;
        _categoryGroups = groups;
        _isLoading = false;
      });
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted')),
          );
          _fetchData();
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

  void _showExportBottomSheet() {
    // Gather filtered transactions (only the ones in _categoryGroups)
    final filteredTransactions = _categoryGroups.values.expand((txs) => txs).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Report',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D26),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_months[_selectedMonth - 1]} $_selectedYear • ${filteredTransactions.length} transactions',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            _buildExportOption(
              icon: Icons.description_outlined,
              color: const Color(0xFF27AE60),
              title: 'Export as CSV',
              subtitle: 'Spreadsheet-compatible format',
              onTap: () {
                Navigator.pop(context);
                ExportService.exportToCsv(
                  transactions: filteredTransactions,
                  month: _selectedMonth,
                  year: _selectedYear,
                );
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('CSV downloaded!'), backgroundColor: Color(0xFF27AE60)),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.table_chart_outlined,
              color: const Color(0xFF2E7D32),
              title: 'Export as Excel',
              subtitle: 'With summary & category breakdown',
              onTap: () {
                Navigator.pop(context);
                ExportService.exportToExcel(
                  transactions: filteredTransactions,
                  categoryTotals: _categoryTotals,
                  totalExpense: _totalExpense,
                  month: _selectedMonth,
                  year: _selectedYear,
                );
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Excel downloaded!'), backgroundColor: Color(0xFF2E7D32)),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFFE53935),
              title: 'Export as PDF',
              subtitle: 'Formatted monthly report',
              onTap: () async {
                Navigator.pop(context);
                await ExportService.exportToPdf(
                  transactions: filteredTransactions,
                  categoryTotals: _categoryTotals,
                  totalExpense: _totalExpense,
                  month: _selectedMonth,
                  year: _selectedYear,
                );
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('PDF downloaded!'), backgroundColor: Color(0xFFE53935)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8ECF4)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D26),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Monthly Report', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Color(0xFF6C63FF), size: 24),
              tooltip: 'Export Report',
              onPressed: _showExportBottomSheet,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: const Color(0xFF6C63FF),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(),
                          const SizedBox(height: 30),
                          const Text(
                            'Spending by Category',
                            style: TextStyle(
                              color: Color(0xFF1A1D26),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryList(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(_months[index]),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMonth = val);
                      _fetchData();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  isExpanded: true,
                  items: _years.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _fetchData();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spending (${_months[_selectedMonth - 1]})',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_totalExpense.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('Transactions', '${_categoryGroups.values.fold<int>(0, (sum, txs) => sum + txs.length)}'),
              const SizedBox(width: 24),
              _buildStatItem('Categories', '${_categoryTotals.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    if (_categoryTotals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No expenses found for this month',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }

    final sortedCategories = _categoryTotals.keys.toList()
      ..sort((a, b) => _categoryTotals[b]!.compareTo(_categoryTotals[a]!));
    
    const accentColor = Color(0xFF6C63FF);

    return Column(
      children: sortedCategories.map((category) {
        final val = _categoryTotals[category]!;
        final pct = (val / _totalExpense) * 100;
        final txs = _categoryGroups[category] ?? [];

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8ECF4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1D26).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_rounded, color: accentColor, size: 24),
              ),
              title: Text(
                category,
                style: const TextStyle(
                  color: Color(0xFF1A1D26),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${txs.length} records • ${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: const Color(0xFF1A1D26).withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              trailing: Text(
                '₹${val.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Divider(color: const Color(0xFF1A1D26).withOpacity(0.06)),
                      const SizedBox(height: 12),
                      ...txs.map((tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: Key(tx.id ?? 'tx_${tx.recipient}_${tx.date}'),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            await _deleteTransaction(tx);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.recipient,
                                      style: const TextStyle(
                                        color: Color(0xFF1A1D26),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      tx.date,
                                      style: TextStyle(
                                        color: const Color(0xFF1A1D26).withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                tx.amount,
                                style: const TextStyle(
                                  color: Color(0xFF1A1D26),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () async {
                            final hasChanged = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (c) => CategoryDetailScreen(
                                  category: category,
                                  transactions: txs,
                                ),
                              ),
                            );
                            if (hasChanged == true) {
                              _fetchData();
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: accentColor.withOpacity(0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
