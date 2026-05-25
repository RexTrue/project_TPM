import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

class StatisticsScreen extends StatefulWidget {
  final int? userId;

  const StatisticsScreen({super.key, this.userId});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<_StatisticsViewData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatisticsViewData?> _load() async {
    final studentProvider = context.read<StudentProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final targetId = widget.userId ?? currentUser?.id;
    if (targetId == null) return null;
    final user = await studentProvider.getUserById(targetId);
    if (user == null) return null;
    final stats = await studentProvider.getUserStatistics(user);
    return _StatisticsViewData(user: user, stats: stats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: FutureBuilder<_StatisticsViewData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Data statistik tidak ditemukan'));
          }

          final user = data.user;
          final stats = data.stats;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      user.role == 'mentor' ? Icons.school : Icons.person,
                    ),
                  ),
                  title: Text(user.username),
                  subtitle: Text(
                    '${user.role} - Level ${user.level} - ${user.xp} XP',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (user.role == 'mentor') ...[
                _StatTile(
                  icon: Icons.menu_book,
                  title: 'Materi diupload',
                  value: '${stats.materialCount}',
                ),
                _StatTile(
                  icon: Icons.assignment,
                  title: 'Quiz dibuat',
                  value: '${stats.quizCount}',
                ),
                _StatTile(
                  icon: Icons.groups,
                  title: 'Pengikut',
                  value: '${stats.followerCount}',
                ),
              ] else ...[
                _StatTile(
                  icon: Icons.school,
                  title: 'Mentor diikuti',
                  value: '${stats.followedMentorCount}',
                ),
                _StatTile(
                  icon: Icons.assignment_turned_in,
                  title: 'Quiz dikerjakan',
                  value: '${stats.submissionCount}',
                ),
                _StatTile(
                  icon: Icons.percent,
                  title: 'Rata-rata skor submit',
                  value: stats.averageScore.toStringAsFixed(1),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _StatisticsViewData {
  final UserModel user;
  final UserStatistics stats;

  const _StatisticsViewData({required this.user, required this.stats});
}
