import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/custom_widgets.dart';

/// Help & Support Screen
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      'Bagaimana cara mengikuti mentor?',
      'Buka menu Beranda, pilih Cari Mentor, lalu tekan tombol Ikuti pada mentor yang diinginkan.',
    ),
    (
      'Bagaimana cara mengerjakan quiz?',
      'Masuk ke Materi atau Quiz, pilih quiz yang tersedia, lalu ikuti petunjuk di layar. Quiz pilihan ganda menggunakan sensor gerak, sedangkan essay menggunakan input teks.',
    ),
    (
      'Apa itu membership premium?',
      'Membership premium memberi akses ke konten eksklusif dari mentor tertentu. Pembayaran saat ini bersifat simulasi untuk keperluan demo.',
    ),
    (
      'Bagaimana cara menggunakan chatbot AI?',
      'Buka menu Chatbot di Beranda. Pastikan kunci API Gemini sudah dikonfigurasi agar mendapat jawaban AI penuh.',
    ),
    (
      'Bagaimana cara mendapatkan badge?',
      'Badge diperoleh otomatis saat Anda menyelesaikan quiz, bermain game, mengumpulkan XP, atau mengirim masukan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan & Dukungan'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CustomCard(
            child: ListTile(
              leading: Icon(Icons.email, color: Color(0xFF6366F1)),
              title: Text('Email Dukungan'),
              subtitle: Text('support@edufun.app'),
            ),
          ),
          const SizedBox(height: 12),
          CustomCard(
            child: ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF6366F1)),
              title: const Text('Salin Email'),
              subtitle: const Text('Ketuk untuk menyalin alamat email'),
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: 'support@edufun.app'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email disalin ke clipboard')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pertanyaan Umum (FAQ)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._faqs.map(
            (faq) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(
                  faq.$1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(faq.$2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
