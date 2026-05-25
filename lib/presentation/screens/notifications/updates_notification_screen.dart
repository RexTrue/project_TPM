import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/material_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

class UpdatesNotificationScreen extends StatefulWidget {
  const UpdatesNotificationScreen({super.key});

  @override
  State<UpdatesNotificationScreen> createState() =>
      _UpdatesNotificationScreenState();
}

class _UpdatesNotificationScreenState extends State<UpdatesNotificationScreen> {
  late Future<_UpdateNotificationData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UpdateNotificationData> _load() async {
    final auth = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    final user = auth.currentUser;
    if (user == null) return const _UpdateNotificationData();

    if (user.role == 'mentor') {
      final students = await studentProvider.getStudentsFollowingMentor(
        user.id ?? 0,
      );
      return _UpdateNotificationData(students: students.take(10).toList());
    }

    final materials = await studentProvider.getMaterialsForStudent(
      user.id ?? 0,
    );
    return _UpdateNotificationData(materials: materials.take(10).toList());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isMentor = user?.role == 'mentor';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: FutureBuilder<_UpdateNotificationData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? const _UpdateNotificationData();
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  isMentor
                      ? 'Student yang mengikuti / membership'
                      : 'Materi terbaru',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (isMentor)
                  ..._buildStudentItems(data.students)
                else
                  ..._buildMaterialItems(data.materials),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMaterialItems(List<MaterialModel> materials) {
    if (materials.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada materi terbaru.'),
          ),
        ),
      ];
    }
    return materials
        .map(
          (material) => Card(
            child: ListTile(
              leading: Icon(
                material.isExclusive
                    ? Icons.workspace_premium
                    : Icons.menu_book,
              ),
              title: Text(material.title),
              subtitle: Text(material.category),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildStudentItems(List<UserModel> students) {
    if (students.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada student yang mengikuti.'),
          ),
        ),
      ];
    }
    return students
        .map(
          (student) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(student.username),
              subtitle: Text('Level ${student.level} - ${student.xp} XP'),
              trailing: student.isPremium
                  ? const Chip(label: Text('Member'))
                  : const Chip(label: Text('Free')),
            ),
          ),
        )
        .toList();
  }
}

class _UpdateNotificationData {
  final List<MaterialModel> materials;
  final List<UserModel> students;

  const _UpdateNotificationData({
    this.materials = const [],
    this.students = const [],
  });
}
