import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../notifications/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

class MembershipScreen extends StatefulWidget {
  final int? mentorId;
  final String? mentorName;

  const MembershipScreen({super.key, this.mentorId, this.mentorName});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  static const double _basePriceIdr = 79000;

  bool _isProcessingPayment = false;
  String _selectedPlanCode = 'monthly';
  String _paymentMethod = 'QRIS';
  String _selectedCountryCode = 'ID';
  String? _receiptId;
  DateTime? _validUntil;
  bool _acknowledgeTerms = false;

  bool get _isMentorMembership => widget.mentorId != null;

  final List<_MembershipPlan> _plans = const [
    _MembershipPlan(
      code: 'monthly',
      title: 'Bulanan',
      description: 'Akses penuh selama 30 hari.',
      multiplier: 1.0,
      duration: Duration(days: 30),
    ),
    _MembershipPlan(
      code: 'semester',
      title: 'Semester',
      description: 'Lebih hemat untuk 6 bulan akses.',
      multiplier: 5.2,
      duration: Duration(days: 182),
    ),
    _MembershipPlan(
      code: 'yearly',
      title: 'Tahunan',
      description: 'Paling hemat untuk 12 bulan akses.',
      multiplier: 9.6,
      duration: Duration(days: 365),
    ),
  ];

  final List<_CurrencyCountry> _countries = const [
    _CurrencyCountry('ID', 'Indonesia', 'IDR', 1),
    _CurrencyCountry('US', 'United States', 'USD', 0.000064),
    _CurrencyCountry('JP', 'Japan', 'JPY', 0.0098),
    _CurrencyCountry('MY', 'Malaysia', 'MYR', 0.00030),
    _CurrencyCountry('SG', 'Singapore', 'SGD', 0.000086),
    _CurrencyCountry('EU', 'Europe', 'EUR', 0.000059),
  ];

  final List<String> _paymentMethods = const [
    'QRIS',
    'Transfer Bank',
    'E-Wallet',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedPurchase();
    });
  }

  _MembershipPlan get _selectedPlan => _plans.firstWhere(
    (plan) => plan.code == _selectedPlanCode,
    orElse: () => _plans.first,
  );

  _CurrencyCountry get _selectedCountry => _countries.firstWhere(
    (country) => country.code == _selectedCountryCode,
    orElse: () => _countries.first,
  );

  double get _convertedPrice =>
      _basePriceIdr * _selectedPlan.multiplier * _selectedCountry.rateFromIdr;

  Future<void> _loadSavedPurchase() async {
    if (_isMentorMembership) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _receiptId = prefs.getString('membership_receipt_id');
      final validUntil = prefs.getString('membership_valid_until');
      _validUntil = validUntil != null ? DateTime.tryParse(validUntil) : null;
    });
  }

  Future<void> _showCheckoutConfirmation() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu.')),
      );
      return;
    }

    if (!_acknowledgeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setujui syarat membership terlebih dahulu.'),
        ),
      );
      return;
    }

    final target = _isMentorMembership
        ? 'mentor ${widget.mentorName ?? '#${widget.mentorId}'}'
        : 'akun EduFun';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Text(
          'Kamu akan membeli paket ${_selectedPlan.title} untuk $target.\n\n'
          'Total: ${_formatPrice(_convertedPrice)} ${_selectedCountry.currency}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processPurchase();
    }
  }

  Future<void> _processPurchase() async {
    setState(() => _isProcessingPayment = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final studentProvider = context.read<StudentProvider>();
      final notificationService = context.read<NotificationService>();
      final generatedReceipt = _generateReceiptId();
      final expiresAt = DateTime.now().add(_selectedPlan.duration);

      await Future<void>.delayed(const Duration(milliseconds: 800));

      if (_isMentorMembership) {
        final mentorId = widget.mentorId!;
        final recorded = await authProvider.recordMentorMembershipPurchase(
          mentorId: mentorId,
          planCode: _selectedPlan.code,
          purchasedAt: DateTime.now(),
          validUntil: expiresAt,
        );
        if (!recorded) {
          throw Exception('Gagal menyimpan membership mentor.');
        }
        final studentId = authProvider.currentUser?.id;
        if (studentId != null) {
          await studentProvider.followMentor(studentId, mentorId);
        }
        await notificationService.showAppNotification(
          id: 330,
          title: 'Membership mentor aktif',
          body:
              'Kamu sekarang bisa membuka materi eksklusif ${widget.mentorName ?? 'mentor ini'}.',
        );
      } else {
        final activated = await authProvider.setPremiumStatus(true);
        if (!activated) {
          throw Exception('Gagal mengaktifkan membership akun.');
        }
        final recorded = await authProvider.recordMembershipPurchase(
          planCode: _selectedPlan.code,
          paymentMethod: _paymentMethod,
          receiptId: generatedReceipt,
          purchasedAt: DateTime.now(),
          validUntil: expiresAt,
        );
        if (!recorded) {
          throw Exception('Gagal menyimpan bukti pembelian.');
        }
      }

      if (!mounted) return;
      setState(() {
        _receiptId = generatedReceipt;
        _validUntil = expiresAt;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pembayaran terverifikasi: ${_formatPrice(_convertedPrice)} ${_selectedCountry.currency}',
          ),
        ),
      );
      if (_isMentorMembership) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pembelian gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  String _formatPrice(double value) {
    if (_selectedCountry.currency == 'IDR' ||
        _selectedCountry.currency == 'JPY') {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _generateReceiptId() {
    final random = Random();
    final token = List.generate(8, (_) => random.nextInt(10)).join();
    return 'EDU-$token-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isPremium = _isMentorMembership ? false : authProvider.isPremium;
    final purchaseSummary = _receiptId == null
        ? null
        : 'Receipt $_receiptId${_validUntil != null ? '\nAktif sampai ${_validUntil!.toLocal()}' : ''}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMentorMembership ? 'Join Membership Mentor' : 'Membership',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: isPremium
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMentorMembership
                          ? 'Akses materi eksklusif ${widget.mentorName ?? ''}'
                          : isPremium
                          ? 'Membership aktif'
                          : 'Upgrade ke Premium',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMentorMembership
                          ? 'Membership ini membuka materi eksklusif dari mentor yang dipilih.'
                          : 'Pilih paket, negara, mata uang, dan metode pembayaran.',
                    ),
                    if (purchaseSummary != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        purchaseSummary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih Paket',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selectedPlanCode,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedPlanCode = value);
              },
              child: Column(
                children: _plans
                    .map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RadioListTile<String>(
                          value: plan.code,
                          title: Text(plan.title),
                          subtitle: Text(plan.description),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCountryCode,
              decoration: const InputDecoration(
                labelText: 'Negara dan mata uang',
                border: OutlineInputBorder(),
              ),
              items: _countries
                  .map(
                    (country) => DropdownMenuItem(
                      value: country.code,
                      child: Text('${country.name} (${country.currency})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCountryCode = value);
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Estimasi harga: ${_formatPrice(_convertedPrice)} ${_selectedCountry.currency}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Harga dasar Rp${(_basePriceIdr * _selectedPlan.multiplier).toStringAsFixed(0)} dikonversi dengan kurs simulasi.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _paymentMethods
                  .map(
                    (method) => ChoiceChip(
                      label: Text(method),
                      selected: _paymentMethod == method,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _paymentMethod = method);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _acknowledgeTerms,
              onChanged: (value) {
                setState(() => _acknowledgeTerms = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Saya setuju membership diproses sebagai checkout simulasi aplikasi.',
              ),
              subtitle: const Text(
                'Status dan bukti transaksi akan disimpan ke akun ini.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isProcessingPayment
                  ? null
                  : _showCheckoutConfirmation,
              icon: _isProcessingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open),
              label: Text(
                _isProcessingPayment ? 'Memproses...' : 'Lanjut ke Checkout',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Keuntungan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('- Akses konten eksklusif sesuai membership'),
                    Text('- Statistik lanjutan'),
                    Text('- Bukti transaksi tersimpan di profil akun'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipPlan {
  final String code;
  final String title;
  final String description;
  final double multiplier;
  final Duration duration;

  const _MembershipPlan({
    required this.code,
    required this.title,
    required this.description,
    required this.multiplier,
    required this.duration,
  });
}

class _CurrencyCountry {
  final String code;
  final String name;
  final String currency;
  final double rateFromIdr;

  const _CurrencyCountry(this.code, this.name, this.currency, this.rateFromIdr);
}
