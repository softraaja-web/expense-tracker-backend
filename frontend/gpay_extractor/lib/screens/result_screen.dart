import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../widgets/tag_selector.dart';

class ResultScreen extends StatefulWidget {
  final UploadResponse uploadResponse;
  final XFile? imageFile;
  const ResultScreen({super.key, required this.uploadResponse, this.imageFile});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _dateController, _amountController, _recipientController, _upiIdController;
  String _selectedTag = 'Others';
  String _selectedType = 'expense';
  bool _isSaving = false;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final d = widget.uploadResponse.data;
    _dateController = TextEditingController(text: d?.date ?? '');
    _amountController = TextEditingController(text: d?.amount ?? '');
    _recipientController = TextEditingController(text: d?.recipient ?? '');
    _upiIdController = TextEditingController(text: d?.upiId ?? '');
    _selectedTag = d?.tag ?? 'Others';
    _selectedType = d?.type ?? 'expense';
    _animController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _slideAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _dateController.dispose(); _amountController.dispose();
    _recipientController.dispose(); _upiIdController.dispose();
    _animController.dispose(); super.dispose();
  }

  double get _confidence => widget.uploadResponse.data?.confidence ?? 0.0;
  Color get _confidenceColor {
    if (_confidence >= 0.8) return const Color(0xFF2ED573);
    if (_confidence >= 0.5) return const Color(0xFFFFA502);
    return const Color(0xFFFF4757);
  }
  String get _confidenceLabel {
    if (_confidence >= 0.8) return 'High';
    if (_confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _recipientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount and recipient are required'), backgroundColor: Color(0xFFFF4757)));
      return;
    }
    setState(() => _isSaving = true);
    final tx = Transaction(
      date: _dateController.text,
      amount: _amountController.text,
      recipient: _recipientController.text,
      upiId: _upiIdController.text.isNotEmpty ? _upiIdController.text : null,
      type: _selectedType,
      tag: _selectedTag,
      source: widget.uploadResponse.data?.source ?? 'screenshot',
    );
    final result = await ApiService.saveTransaction(tx);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 8), Text(result['message'] ?? 'Saved successfully')]), backgroundColor: const Color(0xFF2ED573)));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to save. Check backend.'), backgroundColor: const Color(0xFFFF4757)));
    }
  }

  Widget _buildField({required String label, required TextEditingController controller, required IconData icon, String? hint, String? prefixText, TextInputType? keyboardType}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E4EF)), boxShadow: [BoxShadow(color: const Color(0xFF1A1D26).withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: TextField(
        controller: controller, keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 15),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.45), fontSize: 13),
          hintStyle: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.25), fontSize: 14),
          prefixText: prefixText, prefixStyle: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
          prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D26), size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Transaction Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1D26))),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _confidenceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _confidenceColor.withOpacity(0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _confidenceColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_confidenceLabel, style: TextStyle(color: _confidenceColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      body: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(_slideAnimation),
        child: FadeTransition(
          opacity: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.uploadResponse.message.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (widget.uploadResponse.success ? const Color(0xFF2ED573) : const Color(0xFFFFA502)).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (widget.uploadResponse.success ? const Color(0xFF2ED573) : const Color(0xFFFFA502)).withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(widget.uploadResponse.success ? Icons.check_circle_outline : Icons.info_outline, color: widget.uploadResponse.success ? const Color(0xFF2ED573) : const Color(0xFFFFA502), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.uploadResponse.message, style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.7), fontSize: 13))),
                  ]),
                ),
              // Type toggle
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFF0F2F8), borderRadius: BorderRadius.circular(14)),
                child: Row(children: ['expense', 'income'].map((type) {
                  final sel = type == _selectedType;
                  final label = type[0].toUpperCase() + type.substring(1);
                  return Expanded(child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: sel ? (type == 'expense' ? const Color(0xFFFF4757) : const Color(0xFF2ED573)).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: sel ? (type == 'expense' ? const Color(0xFFFF4757) : const Color(0xFF2ED573)) : const Color(0xFF1A1D26).withOpacity(0.35), fontSize: 15, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  ));
                }).toList()),
              ),
              _buildField(label: 'Amount', controller: _amountController, icon: Icons.currency_rupee, hint: '1,500.00', prefixText: '₹', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _buildField(label: 'Recipient', controller: _recipientController, icon: Icons.person_outline, hint: 'John Doe'),
              _buildField(label: 'Date', controller: _dateController, icon: Icons.calendar_today_outlined, hint: '28 Apr 2026'),
              _buildField(label: 'UPI ID (optional)', controller: _upiIdController, icon: Icons.alternate_email, hint: 'user@upi'),
              const SizedBox(height: 8),
              TagSelector(selectedTag: _selectedTag, onTagSelected: (tag) => setState(() => _selectedTag = tag)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2, shadowColor: const Color(0xFF6C63FF).withOpacity(0.3)),
                  child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_rounded, size: 20), SizedBox(width: 8), Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.uploadResponse.data?.rawText != null && widget.uploadResponse.data!.rawText!.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Raw OCR Text', style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.4), fontSize: 13)),
                  iconColor: const Color(0xFF1A1D26).withOpacity(0.3),
                  children: [Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF0F2F8), borderRadius: BorderRadius.circular(10)), child: Text(widget.uploadResponse.data!.rawText!, style: TextStyle(color: const Color(0xFF1A1D26).withOpacity(0.5), fontSize: 12, fontFamily: 'monospace')))],
                ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}
