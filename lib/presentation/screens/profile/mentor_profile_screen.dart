import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/material_model.dart';
import '../../../data/models/user_model.dart';
import '../../../notifications/notification_service.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import 'edit_profile_screen.dart';

class MentorProfileScreen extends StatefulWidget {
  final int mentorId;

  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  UserModel? _mentor;
  List<MaterialModel> _materials = [];
  int _followers = 0;
  bool _isFollowing = false;
  bool _isMember = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final student = context.read<StudentProvider>();
    final auth = context.read<AuthProvider>();
    final studentId = auth.currentUser?.id;

    final mentor = await student.getUserById(widget.mentorId);
    final materials = await student.getMaterialsByMentor(widget.mentorId);
    final followers = await student.getFollowerCount(widget.mentorId);
    final following = studentId == null
        ? false
        : await student.isFollowingMentor(studentId, widget.mentorId);
    final isMember = await auth.isMentorMember(widget.mentorId);

    if (!mounted) return;
    setState(() {
      _mentor = mentor;
      _materials = materials;
      _followers = followers;
      _isFollowing = following;
      _isMember = isMember;
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final studentId = context.read<AuthProvider>().currentUser?.id;
    if (studentId == null) return;
    final student = context.read<StudentProvider>();
    final notificationService = context.read<NotificationService>();
    if (_isFollowing) {
      await student.unfollowMentor(studentId, widget.mentorId);
    } else {
      await student.followMentor(studentId, widget.mentorId);
      await notificationService.showAppNotification(
        id: 320,
        title: 'Mentor diikuti',
        body: 'Kamu mulai mengikuti ${_mentor?.username ?? 'mentor ini'}.',
      );
    }
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final mentor = _mentor;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Mentor')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : mentor == null
          ? const Center(child: Text('Mentor tidak ditemukan'))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProfileAvatar(photo: mentor.photo, radius: 42),
                          const SizedBox(height: 12),
                          Text(
                            mentor.username,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Level ${mentor.level} - ${mentor.xp} XP'),
                          if ((mentor.about ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              mentor.about!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('$_followers pengikut')),
                              Chip(label: Text('${_materials.length} materi')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _toggleFollow,
                            icon: Icon(_isFollowing ? Icons.check : Icons.add),
                            label: Text(
                              _isFollowing ? 'Diikuti' : 'Ikuti Mentor',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final updated = await Navigator.pushNamed(
                                context,
                                AppNavigation.mentorMembership,
                                arguments: {
                                  'mentorId': mentor.id,
                                  'mentorName': mentor.username,
                                },
                              );
                              if (updated == true) {
                                await _loadProfile();
                              }
                            },
                            icon: Icon(
                              _isMember
                                  ? Icons.verified
                                  : Icons.workspace_premium,
                            ),
                            label: Text(
                              _isMember ? 'Member aktif' : 'Join Membership',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppNavigation.statistics,
                              arguments: {'userId': mentor.id},
                            ),
                            icon: const Icon(Icons.bar_chart),
                            label: const Text('Lihat Statistik'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Materi yang Diunggah',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_materials.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Mentor ini belum mengunggah materi.'),
                      ),
                    )
                  else
                    ..._materials.map(
                      (material) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book),
                          title: Text(material.title),
                          subtitle: Text(
                            '${material.category}${material.isExclusive ? ' - Exclusive' : ''}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
