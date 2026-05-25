import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/mentor_provider.dart';

class MentorQuizListScreen extends StatelessWidget {
  const MentorQuizListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mentorId = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Quiz Saya')),
      body: mentorId == null
          ? const Center(child: Text('Mentor tidak ditemukan'))
          : FutureBuilder(
              future: context.read<MentorProvider>().getQuizzesByMentor(
                mentorId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final quizzes = snapshot.data ?? [];
                if (quizzes.isEmpty) {
                  return const Center(
                    child: Text('Belum ada quiz yang dibuat.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.assignment),
                        title: Text(quiz.title),
                        subtitle: Text(
                          quiz.deadlineAt == null
                              ? 'Tanpa tenggat'
                              : 'Tenggat: ${DateTime.tryParse(quiz.deadlineAt!)?.toLocal()}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
