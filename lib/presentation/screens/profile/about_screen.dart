import 'package:flutter/material.dart';

import '../../widgets/custom_widgets.dart';

/// About Screen
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.school, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'EduFun',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Versi $_appVersion',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const CustomCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'EduFun adalah platform pembelajaran interaktif dengan gamifikasi, '
                  'mendukung peran mentor dan siswa, mini game berbasis sensor, '
                  'chatbot AI, serta sistem leaderboard dan badge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fitur Utama',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ...[
              ('Materi & Quiz', Icons.menu_book),
              ('Mini Game Sensor', Icons.videogame_asset),
              ('Chatbot AI', Icons.smart_toy),
              ('Leaderboard & Badge', Icons.emoji_events),
              ('Membership Premium', Icons.card_membership),
            ].map(
              (item) => ListTile(
                leading: Icon(item.$2, color: const Color(0xFF6366F1)),
                title: Text(item.$1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '© 2026 EduFun — Tugas Akhir TPM',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
