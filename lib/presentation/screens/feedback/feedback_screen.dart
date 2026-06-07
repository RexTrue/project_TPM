import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/feedback_model.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../widgets/custom_widgets.dart';

/// Feedback Screen
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 5;
  String? _selectedCategory;
  bool _isSubmitting = false;

  static const _categories = [
    'Bug Report',
    'Feature Request',
    'Improvement',
    'General',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan isi masukan Anda')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = context.read<AuthProvider>();
      final feedbackRepository = context.read<FeedbackRepository>();
      final userId = auth.currentUser?.id;

      await feedbackRepository.createFeedback(
        FeedbackModel(
          userId: userId,
          rating: _rating,
          message: _feedbackController.text.trim(),
          category: _selectedCategory,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      if (userId != null) {
        final unlocked = await context.read<BadgeProvider>().checkAndUnlock(
          userId: userId,
          feedbackSent: true,
          xp: auth.currentUser?.xp,
          level: auth.currentUser?.level,
        );

        if (unlocked.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Badge baru: ${unlocked.join(', ')}')),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih atas masukan Anda! 🙏')),
      );

      _feedbackController.clear();
      setState(() => _selectedCategory = null);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim masukan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bantu kami meningkatkan EduFun!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bagaimana pengalaman Anda?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ...List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setState(() => _rating = index + 1),
                      icon: Icon(
                        Icons.star,
                        size: 40,
                        color: index < _rating
                            ? Colors.amber
                            : Colors.grey[300],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Masukan Anda:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Ceritakan pendapat Anda...',
                controller: _feedbackController,
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              const Text(
                'Kategori (opsional):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _categories.map((category) {
                  final selected = _selectedCategory == category;
                  return FilterChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        _selectedCategory = value ? category : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Kirim Masukan',
                isLoading: _isSubmitting,
                onPressed: _submitFeedback,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
