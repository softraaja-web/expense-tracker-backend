import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:js' as js;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/daily_summary.dart';
import '../widgets/transaction_card.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';

/// Home screen with upload/capture actions and recent transactions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isLoadingHistory = true;
  bool _isLoadingTotal = true;
  List<Transaction> _recentTransactions = [];
  DailyTotal _dailyTotal = DailyTotal(date: '', totalExpense: 0, totalIncome: 0, netBalance: 0, transactionCount: 0);
  Map<String, dynamic>? _userProfile;
  Razorpay? _razorpay;
  String? _selectedPlanId;
  String _loadingMessage = 'Extracting transaction...';
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    _loadData();

    if (kIsWeb) {
      _setupWebEventListeners();
    }
  }

  void _setupWebEventListeners() {
    html.window.addEventListener('razorpay_success', (event) {
      final detail = (event as html.CustomEvent).detail;
      _handleWebPaymentSuccess(detail);
    });

    html.window.addEventListener('razorpay_error', (event) {
      final detail = (event as html.CustomEvent).detail;
      _showError(detail['message'] ?? 'Payment failed');
    });
  }

  void _handleWebPaymentSuccess(dynamic detail) async {
    // Verify payment on backend
    final success = await ApiService.verifyPayment({
      'razorpay_payment_id': detail['payment_id'],
      'razorpay_order_id': detail['order_id'],
      'razorpay_signature': detail['signature'],
    }, _selectedPlanId ?? 'plus');

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgraded to Pro successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      _showError('Payment verification failed.');
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadProfile();
    _loadDailyTotal();
    _loadRecentTransactions();
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Verify payment on backend
    final success = await ApiService.verifyPayment({
      'razorpay_payment_id': response.paymentId,
      'razorpay_order_id': response.orderId,
      'razorpay_signature': response.signature,
    }, _selectedPlanId ?? 'plus');

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upgraded to ${_selectedPlanId?.toUpperCase() ?? 'Pro'} successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verification failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Not used for now
  }

  void _showPlanSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Your Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConfig.availablePlans.where((p) => p.id != 'free').map((plan) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(plan.description),
                trailing: Text('₹${plan.price}', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _startUpgradeFlow(plan);
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpgradeFlow(SubscriptionPlan plan) async {
    // 1. Create order on backend
    setState(() {
      _selectedPlanId = plan.id;
      _loadingMessage = 'Preparing your ${plan.name} upgrade...';
      _isUploading = true;
    });
    try {
      final order = await ApiService.createOrder(plan.id);
      
      if (!mounted) return;
      setState(() => _isUploading = false);

      if (order == null) {
        _showError('Failed to create order. Please check backend logs.');
        return;
      }

      // 2. Open Razorpay Checkout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening Payment Gateway for Order: ${order['id']}')),
      );

      var options = {
        'key': AppConfig.razorpayKey,
        'amount': order['amount'],
        'name': 'GPay Extractor',
        'order_id': order['id'],
        'description': 'Pro Plan - Unlimited extractions for 30 days',
        'prefill': {
          'contact': '',
          'email': AuthService.currentUser?.email ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      try {
        if (kIsWeb) {
          js.context.callMethod('openRazorpay', [
            AppConfig.razorpayKey,
            order['amount'],
            'GPay Extractor',
            'Pro Plan - Unlimited extractions',
            order['id'],
            AuthService.currentUser?.email ?? '',
            '', // Phone number
          ]);
        } else {
          _razorpay?.open(options);
        }
      } catch (e) {
        _showError('Razorpay Error: $e');
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      _showError('Error starting payment: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _loadDailyTotal() async {
    setState(() => _isLoadingTotal = true);
    final total = await ApiService.getDailyTotal();
    if (mounted) {
      setState(() {
        _dailyTotal = total;
        _isLoadingTotal = false;
      });
    }
  }

  Future<void> _loadRecentTransactions() async {
    setState(() => _isLoadingHistory = true);
    final transactions = await ApiService.getHistory(count: 5);
    if (mounted) {
      setState(() {
        _recentTransactions = transactions;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image == null) return;

      setState(() {
        _loadingMessage = 'Extracting transaction...';
        _isUploading = true;
      });

      final response = await ApiService.uploadImage(image);

      if (!mounted) return;
      setState(() => _isUploading = false);

      // Navigate to result screen
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            uploadResponse: response,
            imageFile: image,
          ),
        ),
      );

      // Refresh data if saved
      if (saved == true) {
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  Future<void> _showPasteTextDialog() async {
    final TextEditingController controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Transaction Text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the SMS or transaction message below.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'e.g. Sent Rs.400.00 to...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data != null && data.text != null) {
                controller.text = data.text!;
              }
            },
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text('Paste'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00B4D8),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Parse Text'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _loadingMessage = 'Analyzing transaction text...';
        _isUploading = true;
      });
      try {
        final response = await ApiService.parseText(result);
        if (!mounted) return;
        setState(() => _isUploading = false);

        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              uploadResponse: response,
            ),
          ),
        );

        if (saved == true) _loadData();
      } catch (e) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToManualEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          uploadResponse: UploadResponse(
            success: true,
            data: Transaction(
              date: DateTime.now().toString().split(' ')[0], // Default to today
              amount: '',
              recipient: '',
              source: 'manual',
            ),
          ),
        ),
      ),
    );

    if (saved == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          // Subtle background gradient orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF6584).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6C63FF),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'GPay Extractor',
                                      style: TextStyle(
                                        color: Color(0xFF1A1D26),
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_userProfile != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _userProfile!['plan'] == 'pro' 
                                            ? const Color(0xFFFFD700).withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _userProfile!['plan'] == 'pro'
                                              ? const Color(0xFFFFD700)
                                              : Colors.grey.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _userProfile!['plan'] == 'free' ? 'FREE' : _userProfile!['plan'].toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _userProfile!['plan'] != 'free'
                                              ? const Color(0xFFB8860B)
                                              : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (_userProfile != null)
                                  Row(
                                    children: [
                                      Text(
                                        'Credits: ${_userProfile!['credits']}',
                                        style: TextStyle(
                                          color: const Color(0xFF6C63FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_userProfile!['plan'] == 'free') ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _showPlanSelectionDialog,
                                          child: Text(
                                            'Upgrade',
                                            style: TextStyle(
                                              color: const Color(0xFFFF6584),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else
                                  Text(
                                    AuthService.currentUser?.displayName != null 
                                      ? 'Hi, ${AuthService.currentUser!.displayName!.split(' ').first}'
                                      : 'Extract & track transactions',
                                    style: TextStyle(
                                      color: const Color(0xFF1A1D26).withOpacity(0.45),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  await AuthService.signOut();
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1D26).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFF1A1D26),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AnalyticsScreen(),
                                    ),
                                  );
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.bar_chart_rounded,
                                    color: Color(0xFF6C63FF),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HistoryScreen(),
                                    ),
                                  );
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6584).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: Color(0xFFFF6584),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Daily Total Card
                  SliverToBoxAdapter(
                    child: DailySummary(
                      dailyTotal: _dailyTotal,
                      isLoading: _isLoadingTotal,
                    ),
                  ),

                  // Action Buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.add_a_photo_rounded,
                                  label: 'Screenshot',
                                  subtitle: 'Upload GPay screen',
                                  gradient: const [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Upload Screenshot',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 24),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _ActionIcon(
                                                  icon: Icons.camera_alt_rounded,
                                                  label: 'Camera',
                                                  color: const Color(0xFF00B4D8),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.camera);
                                                  },
                                                ),
                                                _ActionIcon(
                                                  icon: Icons.photo_library_rounded,
                                                  label: 'Gallery',
                                                  color: const Color(0xFF6C63FF),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.gallery);
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.paste_rounded,
                                  label: 'Paste SMS',
                                  subtitle: 'Parse transaction text',
                                  gradient: const [Color(0xFF00B4D8), Color(0xFF0096C7)],
                                  onTap: _showPasteTextDialog,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.edit_note_rounded,
                                  label: 'Manual',
                                  subtitle: 'Fill details yourself',
                                  gradient: const [Color(0xFFFF6584), Color(0xFFE84393)],
                                  onTap: _navigateToManualEntry,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recent Transactions Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(
                              color: Color(0xFF1A1D26),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HistoryScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'See All',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction list
                  if (_isLoadingHistory)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: const Color(0xFF6C63FF),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else if (_recentTransactions.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: const Color(0xFF1A1D26).withOpacity(0.1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                color: const Color(0xFF1A1D26).withOpacity(0.35),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a GPay screenshot to get started',
                              style: TextStyle(
                                color: const Color(0xFF1A1D26).withOpacity(0.25),
                                fontSize: 13,
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
                            transaction: _recentTransactions[index],
                          );
                        },
                        childCount: _recentTransactions.length,
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          ),

          // Upload overlay
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          color: Color(0xFF1A1D26),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadingMessage.contains('Pro') 
                          ? 'Setting up secure payment gateway' 
                          : 'Running OCR & AI analysis',
                        style: TextStyle(
                          color: const Color(0xFF1A1D26).withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // FAB
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: _showPasteTextDialog,
          backgroundColor: const Color(0xFF6C63FF),
          elevation: 4,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// Gradient action button widget.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gradient[0].withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: gradient[0].withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: gradient[0], size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF1A1D26),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF1A1D26).withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
