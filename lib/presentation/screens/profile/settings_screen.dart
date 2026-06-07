import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../notifications/notification_service.dart';
import '../../providers/theme_provider.dart';

/// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminder = true;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyReminder = prefs.getBool('daily_reminder_enabled') ?? true;
      _loadingPrefs = false;
    });
  }

  Future<void> _setDailyReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder_enabled', value);
    setState(() => _dailyReminder = value);

    if (value && mounted) {
      final notificationService = context.read<NotificationService>();
      await notificationService.requestPermission();
      await notificationService.showDailyReminderNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan'), elevation: 0),
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Tampilan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Mode Gelap'),
                  subtitle: const Text('Aktifkan tema gelap di seluruh aplikasi'),
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
                const Divider(height: 32),
                const Text(
                  'Notifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Pengingat Belajar Harian'),
                  subtitle: const Text(
                    'Kirim notifikasi pengingat belajar setiap hari',
                  ),
                  value: _dailyReminder,
                  onChanged: _setDailyReminder,
                ),
                const Divider(height: 32),
                const Text(
                  'Bahasa',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Bahasa Aplikasi'),
                  subtitle: const Text('Bahasa Indonesia'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ],
            ),
    );
  }
}
