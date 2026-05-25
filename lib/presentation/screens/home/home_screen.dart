import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../notifications/notification_service.dart';
import '../../../data/models/material_model.dart';
import '../../../data/models/user_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../profile/edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _studentMenuItems = [
    _HomeMenuItem(
      icon: Icons.book,
      title: 'Materi',
      subtitle: 'Baca, download PDF, dan tanya AI',
      color: Color(0xFF0F766E),
    ),
    _HomeMenuItem(
      icon: Icons.sync,
      title: 'Spin Rush',
      subtitle: 'Game santai pakai sensor putaran HP',
      color: Color(0xFF16A34A),
      route: AppNavigation.compassHunt,
    ),
    _HomeMenuItem(
      icon: Icons.chat,
      title: 'AI Chat',
      subtitle: 'Tanya materi ke asisten belajar',
      color: Color(0xFF7C3AED),
      route: AppNavigation.chatbot,
    ),
    _HomeMenuItem(
      icon: Icons.assignment,
      title: 'Quiz Mentor',
      subtitle: 'Pilih quiz dan post-test dari mentor',
      color: Color(0xFFEA580C),
      route: AppNavigation.studentQuizzes,
    ),
    _HomeMenuItem(
      icon: Icons.person_search,
      title: 'Cari Mentor',
      subtitle: 'Ikuti mentor agar materi muncul',
      color: Color(0xFF0891B2),
      route: AppNavigation.mentorSearch,
    ),
  ];

  static const _mentorMenuItems = [
    _HomeMenuItem(
      icon: Icons.assignment,
      title: 'Daftar Quiz Saya',
      subtitle: 'Lihat riwayat quiz yang sudah ditambahkan',
      color: Color(0xFF2563EB),
      route: AppNavigation.mentorQuizzes,
    ),
    _HomeMenuItem(
      icon: Icons.book,
      title: 'Materi Saya',
      subtitle: 'Lihat, tambah, dan edit materi',
      color: Color(0xFF0F766E),
      route: AppNavigation.mentorMaterials,
    ),
    _HomeMenuItem(
      icon: Icons.create,
      title: 'Buat Quiz',
      subtitle: 'Susun quiz atau post-test untuk siswa',
      color: Color(0xFF4F46E5),
      route: AppNavigation.mentorCreateQuiz,
    ),
    _HomeMenuItem(
      icon: Icons.chat,
      title: 'AI Chat',
      subtitle: 'Tanya materi ke asisten belajar',
      color: Color(0xFF7C3AED),
      route: AppNavigation.chatbot,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuestionProvider>().initialize();
      final auth = context.read<AuthProvider>();
      context.read<LocationProvider>().fetchLocation(
        userId: auth.currentUser?.id,
        userName: auth.currentUser?.username,
        points: auth.currentUser?.xp ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isMentor = authProvider.currentUser?.role == 'mentor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduFun'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () =>
                Navigator.pushNamed(context, AppNavigation.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushNamed(context, AppNavigation.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final auth = context.read<AuthProvider>();
          await context.read<LocationProvider>().fetchLocation(
            userId: auth.currentUser?.id,
            userName: auth.currentUser?.username,
            points: auth.currentUser?.xp ?? 0,
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeCard(authProvider: authProvider),
            if (isMentor) ...[
              const SizedBox(height: 24),
              const Text(
                'Student Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const _RecentStudentsPreview(),
            ] else ...[
              const SizedBox(height: 24),
              const Text(
                'Mentor Diikuti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const _FollowedMentorsPreview(),
              const SizedBox(height: 24),
              const Text(
                'Materi Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const _LatestMaterialsPreview(),
            ],
            const SizedBox(height: 24),
            const Text(
              'Menu Belajar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._buildMenuItems(authProvider).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeatureTile(
                  item: item,
                  onTap: () => _handleMenuTap(context, item, authProvider),
                ),
              ),
            ),
            if (!isMentor) ...[
              const SizedBox(height: 14),
              const _LocationReminderCard(),
            ],
            const SizedBox(height: 24),
            const Text(
              'Top Level Student',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const _LeaderboardPreview(),
          ],
        ),
      ),
    );
  }

  List<_HomeMenuItem> _buildMenuItems(AuthProvider authProvider) {
    if (authProvider.currentUser?.role == 'mentor') return _mentorMenuItems;
    return _studentMenuItems;
  }

  void _handleMenuTap(
    BuildContext context,
    _HomeMenuItem item,
    AuthProvider authProvider,
  ) {
    if (item.title == 'Materi') {
      final role = authProvider.currentUser?.role ?? 'student';
      Navigator.pushNamed(
        context,
        role == 'mentor'
            ? AppNavigation.mentorUpload
            : AppNavigation.studentMaterials,
      );
      return;
    }

    final route = item.route;
    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }
}

class _LatestMaterialsPreview extends StatelessWidget {
  const _LatestMaterialsPreview();

  @override
  Widget build(BuildContext context) {
    final studentId = context.watch<AuthProvider>().currentUser?.id;
    if (studentId == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: context.read<StudentProvider>().getMaterialsForStudent(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CustomCard(child: LinearProgressIndicator());
        }
        final materials = (snapshot.data ?? []).take(3).toList();
        if (materials.isEmpty) {
          return const CustomCard(child: Text('Belum ada materi terbaru.'));
        }
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: materials
                .map(
                  (material) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${material.title} - ${material.category}${material.isExclusive ? ' (Exclusive)' : ''}',
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _RecentStudentsPreview extends StatelessWidget {
  const _RecentStudentsPreview();

  @override
  Widget build(BuildContext context) {
    final mentorId = context.watch<AuthProvider>().currentUser?.id;
    if (mentorId == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: context.read<StudentProvider>().getStudentsFollowingMentor(
        mentorId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CustomCard(child: LinearProgressIndicator());
        }
        final students = (snapshot.data ?? []).take(3).toList();
        if (students.isEmpty) {
          return const CustomCard(
            child: Text('Belum ada student yang mengikuti.'),
          );
        }
        return CustomCard(
          child: Column(
            children: students
                .map(
                  (student) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(student.username),
                    subtitle: Text('Level ${student.level} - ${student.xp} XP'),
                    trailing: student.isPremium
                        ? const Chip(label: Text('Member'))
                        : const Chip(label: Text('Free')),
                    onTap: student.id == null
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            AppNavigation.statistics,
                            arguments: {'userId': student.id},
                          ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _FollowedMentorsPreview extends StatelessWidget {
  const _FollowedMentorsPreview();

  Future<_MentorPreviewData> _loadPreview(
    BuildContext context,
    int studentId,
  ) async {
    final provider = context.read<StudentProvider>();
    final mentors = await provider.getFollowedMentors(studentId);
    final materials = await provider.getMaterialsForStudent(studentId);
    return _MentorPreviewData(mentors: mentors, materials: materials);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final studentId = auth.currentUser?.id;
    if (studentId == null) {
      return const CustomCard(child: Text('Login untuk mengikuti mentor.'));
    }

    return FutureBuilder(
      future: _loadPreview(context, studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CustomCard(child: LinearProgressIndicator());
        }

        final mentors = snapshot.data?.mentors ?? [];
        final materials = snapshot.data?.materials ?? [];
        if (mentors.isEmpty) {
          return CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Belum mengikuti mentor.'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppNavigation.mentorSearch),
                  child: const Text('Cari Mentor'),
                ),
              ],
            ),
          );
        }

        return CustomCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mentors.take(5).length,
                  separatorBuilder: (_, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final mentor = mentors[index];
                    return InkWell(
                      onTap: mentor.id == null
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              AppNavigation.mentorProfile,
                              arguments: {'mentorId': mentor.id},
                            ),
                      child: SizedBox(
                        width: 74,
                        child: Column(
                          children: [
                            ProfileAvatar(photo: mentor.photo, radius: 24),
                            const SizedBox(height: 6),
                            Text(
                              mentor.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (materials.isNotEmpty)
                Text(
                  'Terbaru: ${materials.first.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MentorPreviewData {
  final List<UserModel> mentors;
  final List<MaterialModel> materials;

  const _MentorPreviewData({required this.mentors, required this.materials});
}

class _WelcomeCard extends StatelessWidget {
  final AuthProvider authProvider;

  const _WelcomeCard({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    const xpPerLevel = 100;
    final user = authProvider.currentUser;
    final totalXp = user?.xp ?? 0;
    final level = user?.level ?? (totalXp ~/ xpPerLevel) + 1;
    final xpInCurrentLevel = totalXp % xpPerLevel;
    final xpToNextLevel = xpPerLevel - xpInCurrentLevel;
    final progress = xpInCurrentLevel / xpPerLevel;

    return CustomCard(
      backgroundColor: const Color(0xFF1D4ED8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${authProvider.currentUser?.username ?? 'Player'}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level $level • $totalXp XP',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$xpToNextLevel XP lagi ke Level ${level + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                '$xpInCurrentLevel/$xpPerLevel XP',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationReminderCard extends StatelessWidget {
  const _LocationReminderCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, _) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GPS & Reminder',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(locationProvider.locationLabel),
              if (locationProvider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    locationProvider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: locationProvider.isLoading
                        ? null
                        : () {
                            final auth = context.read<AuthProvider>();
                            locationProvider.fetchLocation(
                              userId: auth.currentUser?.id,
                              userName: auth.currentUser?.username,
                              points: auth.currentUser?.xp ?? 0,
                            );
                          },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ambil Lokasi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final sent = await context
                          .read<NotificationService>()
                          .showDailyReminderNow();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'Reminder berhasil dikirim'
                                : 'Notifikasi belum diizinkan atau tidak tersedia',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Tes Reminder'),
                  ),
                  if (locationProvider.error != null)
                    TextButton.icon(
                      onPressed: locationProvider.openAppSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('Izin Aplikasi'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview();

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: FutureBuilder(
        future: context.read<StudentProvider>().getStudentLevelLeaderboard(),
        builder: (context, snapshot) {
          final students = (snapshot.data ?? []).take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (students.isEmpty)
                const Text('Belum ada student di leaderboard.')
              else
                ...students.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final student = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: rank == students.length ? 0 : 8,
                    ),
                    child: Text(
                      '${_rankLabel(rank)} ${student.username} - Level ${student.level} (${student.xp} XP)',
                    ),
                  );
                }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppNavigation.leaderboard),
                child: const Text('View Full Leaderboard'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _rankLabel(int rank) {
  switch (rank) {
    case 1:
      return '1.';
    case 2:
      return '2.';
    case 3:
      return '3.';
    default:
      return '$rank.';
  }
}

class _HomeMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? route;

  const _HomeMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.route,
  });
}

class _FeatureTile extends StatelessWidget {
  final _HomeMenuItem item;
  final VoidCallback onTap;

  const _FeatureTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: Colors.white,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: item.color),
        ],
      ),
    );
  }
}
