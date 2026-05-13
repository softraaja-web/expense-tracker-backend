import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'category_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  Map<String, double> _recipientTotals = {};
  Map<String, List<Transaction>> _recipientGroups = {};
  double _totalAmount = 0;
  String _activeType = 'expense';
  String? _aiInsight;
  bool _isLoadingInsight = false;

  @override
  void initState() { super.initState(); _fetchData(); }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getHistory(count: 500);
    _transactions = data;
    _processData();
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

  void _processData() {
    double total = 0;
    Map<String, double> totals = {};
    Map<String, List<Transaction>> groups = {};
    Map<String, String> originalNames = {};

    for (var tx in _transactions) {
      final type = tx.type.toLowerCase().trim();
      if (type == _activeType) {
        final val = tx.amountValue;
        if (val > 0) {
          total += val;
          String rawName = tx.recipient.trim();
          if (rawName.isEmpty) rawName = "Unknown Recipient";
          final lookupKey = rawName.toUpperCase();
          totals[lookupKey] = (totals[lookupKey] ?? 0) + val;
          originalNames[lookupKey] ??= rawName;
          final displayName = originalNames[lookupKey]!;
          groups[displayName] ??= [];
          groups[displayName]!.add(tx);
        }
      }
    }

    Map<String, double> finalTotals = {};
    Map<String, List<Transaction>> finalGroups = {};
    totals.forEach((key, val) {
      final name = originalNames[key]!;
      finalTotals[name] = val;
      finalGroups[name] = groups[name] ?? [];
    });

    if (mounted) {
      setState(() { 
        _totalAmount = total; 
        _recipientTotals = finalTotals; 
        _recipientGroups = finalGroups; 
        _isLoading = false; 
      });
      _fetchAiInsight();
    }
  }

  Future<void> _fetchAiInsight() async {
    if (_recipientTotals.isEmpty) return;
    setState(() => _isLoadingInsight = true);
    final insight = await ApiService.analyzeSpending(_recipientTotals, _totalAmount);
    if (mounted) setState(() { _aiInsight = insight; _isLoadingInsight = false; });
  }

  static const _chartColors = [
    Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF00B4D8),
    Color(0xFFFFA502), Color(0xFF2ED573), Color(0xFFFF6348),
    Color(0xFF5F27CD), Color(0xFF54A0FF), Color(0xFFFF9FF3),
    Color(0xFF1DD1A1),
  ];

  Color _colorForIndex(int i) => _chartColors[i % _chartColors.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Financial Analytics', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF1A1D26))),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
              onRefresh: _fetchData, color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTypeToggle(),
                  const SizedBox(height: 24),
                  _buildSummaryCard(),
                  const SizedBox(height: 30),
                  Text(_activeType == 'expense' ? 'Spending Distribution' : 'Income Sources', style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildPieChart(),
                  const SizedBox(height: 30),
                  Text(_activeType == 'expense' ? 'Spending by Recipient' : 'Income by Sender', style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildRecipientList(),
                  const SizedBox(height: 30),
                  _buildAiInsightSection(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ['expense', 'income'].map((type) {
          final isSelected = _activeType == type;
          final label = type[0].toUpperCase() + type.substring(1);
          final color = type == 'expense' ? const Color(0xFFFF4757) : const Color(0xFF2ED573);
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeType = type;
                  _isLoading = true;
                  _aiInsight = null;
                });
                _processData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected ? [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                  ] : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1A1D26).withOpacity(0.4),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAiInsightSection() {
    final color = _activeType == 'expense' ? const Color(0xFF6C63FF) : const Color(0xFF2ED573);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 10),
          const Text('AI Financial Coach', style: TextStyle(color: Color(0xFF1A1D26), fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_isLoadingInsight) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
        ]),
        const SizedBox(height: 16),
        if (_aiInsight != null)
          Text(_aiInsight!, style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.7), fontSize: 14, height: 1.5))
        else if (!_isLoadingInsight)
          Text('Upload more transactions to get personalized financial advice!', style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.4), fontSize: 14)),
      ]),
    );
  }

  Widget _buildPieChart() {
    if (_recipientTotals.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE8ECF4))),
        child: Center(child: Text('No data for this type', style: TextStyle(color: Colors.grey[400]))),
      );
    }

    final sortedKeys = _recipientTotals.keys.toList()..sort((a, b) => _recipientTotals[b]!.compareTo(_recipientTotals[a]!));
    double otherTotal = 0;
    List<PieChartSectionData> sections = [];
    
    for (int i = 0; i < sortedKeys.length; i++) {
      final name = sortedKeys[i];
      final val = _recipientTotals[name]!;
      final pct = (val / _totalAmount) * 100;
      
      if (i < 5 || pct > 5) {
        sections.add(
          PieChartSectionData(
            color: _colorForIndex(i),
            value: val,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      } else {
        otherTotal += val;
      }
    }
    
    if (otherTotal > 0) {
      final otherPct = (otherTotal / _totalAmount) * 100;
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: otherTotal,
          title: '${otherPct.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: [BoxShadow(color: const Color(0xFF1A1D26).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: sections)),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(sections.length, (i) {
                  final section = sections[i];
                  String label = i < sortedKeys.length ? sortedKeys[i] : "Others";
                  if (i >= sortedKeys.length && sections.length > sortedKeys.length) label = "Others";
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: section.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D26), fontWeight: FontWeight.w500, overflow: TextOverflow.ellipsis))),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final colors = _activeType == 'expense' 
      ? [const Color(0xFF6C63FF), const Color(0xFF4834D4)]
      : [const Color(0xFF2ED573), const Color(0xFF1B9E5A)];

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_activeType == 'expense' ? 'Total Spending' : 'Total Income', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _buildStatItem('Transactions', '${_recipientGroups.values.fold(0, (sum, list) => sum + list.length)}'),
          const SizedBox(width: 24),
          _buildStatItem(_activeType == 'expense' ? 'Recipients' : 'Sources', '${_recipientTotals.length}'),
        ]),
      ]),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildRecipientList() {
    if (_recipientTotals.isEmpty) return const SizedBox.shrink();
    
    final sortedKeys = _recipientTotals.keys.toList()..sort((a, b) => _recipientTotals[b]!.compareTo(_recipientTotals[a]!));
    final accentColor = _activeType == 'expense' ? const Color(0xFF6C63FF) : const Color(0xFF2ED573);

    return Column(children: sortedKeys.asMap().entries.map((entry) {
      final name = entry.value;
      final val = _recipientTotals[name]!;
      final pct = (val / _totalAmount) * 100;
      final txs = _recipientGroups[name] ?? [];

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8ECF4)),
            boxShadow: [BoxShadow(color: const Color(0xFF1A1D26).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(_activeType == 'expense' ? Icons.person_rounded : Icons.account_balance_wallet_rounded, color: accentColor, size: 24),
            ),
            title: Text(name, style: const TextStyle(color: Color(0xFF1A1D26), fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${txs.length} records • ${pct.toStringAsFixed(1)}%', style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.4), fontSize: 12)),
            trailing: Text('₹${val.toStringAsFixed(0)}', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(children: [
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
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: accentColor.withOpacity(0.5), shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tx.date, style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 13)),
                          Text(tx.tag, style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.4), fontSize: 11)),
                        ])),
                        Text(tx.amount, style: const TextStyle(color: Color(0xFF1A1D26), fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
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
                              category: name,
                              transactions: txs,
                            ),
                          ),
                        );
                        if (hasChanged == true) {
                          _fetchData();
                        }
                      },
                      style: TextButton.styleFrom(backgroundColor: accentColor.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('View Details', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
    }).toList());
  }
}
