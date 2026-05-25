import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/user_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

class MentorSearchScreen extends StatefulWidget {
  const MentorSearchScreen({super.key});

  @override
  State<MentorSearchScreen> createState() => _MentorSearchScreenState();
}

class _MentorSearchScreenState extends State<MentorSearchScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _mentors = [];
  Set<int> _followedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMentors());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMentors([String query = '']) async {
    final student = context.read<StudentProvider>();
    final auth = context.read<AuthProvider>();
    final studentId = auth.currentUser?.id;
    setState(() => _isLoading = true);
    final mentors = await student.searchMentors(query);
    final followed = studentId == null
        ? <UserModel>[]
        : await student.getFollowedMentors(studentId);
    if (!mounted) return;
    setState(() {
      _mentors = mentors;
      _followedIds = followed
          .map((mentor) => mentor.id)
          .whereType<int>()
          .toSet();
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow(UserModel mentor) async {
    final studentId = context.read<AuthProvider>().currentUser?.id;
    final mentorId = mentor.id;
    if (studentId == null || mentorId == null) return;

    final provider = context.read<StudentProvider>();
    if (_followedIds.contains(mentorId)) {
      await provider.unfollowMentor(studentId, mentorId);
    } else {
      await provider.followMentor(studentId, mentorId);
    }
    await _loadMentors(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cari Mentor')),
      body: RefreshIndicator(
        onRefresh: () => _loadMentors(_searchController.text),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _loadMentors,
              decoration: InputDecoration(
                hintText: 'Cari nama mentor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_mentors.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: Text('Mentor tidak ditemukan')),
              )
            else
              ..._mentors.map((mentor) {
                final isFollowed =
                    mentor.id != null && _followedIds.contains(mentor.id);
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.school)),
                    title: Text(mentor.username),
                    subtitle: Text(
                      isFollowed ? 'Sudah diikuti' : 'Belum diikuti',
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => _toggleFollow(mentor),
                      icon: Icon(isFollowed ? Icons.check : Icons.add),
                      label: Text(isFollowed ? 'Diikuti' : 'Ikuti'),
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
              }),
          ],
        ),
      ),
    );
  }
}
