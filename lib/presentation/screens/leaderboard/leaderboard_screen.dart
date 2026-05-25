import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/mentor_leaderboard_entry.dart';
import '../../../data/models/user_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/student_provider.dart';
import '../../widgets/custom_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<_LeaderboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_LeaderboardData> _loadData() async {
    final provider = context.read<StudentProvider>();
    final students = await provider.getStudentLevelLeaderboard();
    final mentors = await provider.getMentorLeaderboard();
    return _LeaderboardData(students: students, mentors: mentors);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Student Level'),
              Tab(text: 'Mentor'),
            ],
          ),
        ),
        body: FutureBuilder<_LeaderboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingIndicator();
            }

            final data =
                snapshot.data ??
                const _LeaderboardData(students: [], mentors: []);
            return TabBarView(
              children: [
                _StudentLevelLeaderboard(
                  students: data.students,
                  onRefresh: _refresh,
                ),
                _MentorLeaderboard(mentors: data.mentors, onRefresh: _refresh),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentLevelLeaderboard extends StatelessWidget {
  final List<UserModel> students;
  final Future<void> Function() onRefresh;

  const _StudentLevelLeaderboard({
    required this.students,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Belum ada student di leaderboard.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final rank = index + 1;
          return Card(
            child: ListTile(
              leading: _RankBadge(rank: rank),
              title: Text(student.username),
              subtitle: Text('Level ${student.level}'),
              trailing: Text(
                '${student.xp} XP',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MentorLeaderboard extends StatelessWidget {
  final List<MentorLeaderboardEntry> mentors;
  final Future<void> Function() onRefresh;

  const _MentorLeaderboard({required this.mentors, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (mentors.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Belum ada mentor di leaderboard.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mentors.length,
        itemBuilder: (context, index) {
          final entry = mentors[index];
          final mentor = entry.mentor;
          final rank = index + 1;
          return Card(
            child: ListTile(
              leading: _RankBadge(rank: rank),
              title: Text(mentor.username),
              subtitle: Text('Level ${mentor.level} - ${mentor.xp} XP'),
              trailing: Text(
                '${entry.followerCount} pengikut',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: mentor.id == null
                  ? null
                  : () => Navigator.pushNamed(
                      context,
                      AppNavigation.mentorProfile,
                      arguments: {'mentorId': mentor.id},
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: switch (rank) {
        1 => const Color(0xFFFDE68A),
        2 => const Color(0xFFE5E7EB),
        3 => const Color(0xFFFED7AA),
        _ => const Color(0xFFE0F2FE),
      },
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LeaderboardData {
  final List<UserModel> students;
  final List<MentorLeaderboardEntry> mentors;

  const _LeaderboardData({required this.students, required this.mentors});
}
