import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/quiz_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

class StudentQuizListScreen extends StatefulWidget {
  const StudentQuizListScreen({super.key});

  @override
  State<StudentQuizListScreen> createState() => _StudentQuizListScreenState();
}

class _StudentQuizListScreenState extends State<StudentQuizListScreen> {
  List<QuizModel> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuizzes());
  }

  Future<void> _loadQuizzes() async {
    final studentId = context.read<AuthProvider>().currentUser?.id;
    if (studentId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final quizzes = await context.read<StudentProvider>().getQuizzesForStudent(
      studentId,
    );
    if (!mounted) return;
    setState(() {
      _quizzes = quizzes;
      _isLoading = false;
    });
  }

  String _deadlineText(QuizModel quiz) {
    if (!quiz.hasDeadline) return 'Tanpa tenggat waktu';
    final parsed = DateTime.tryParse(quiz.deadlineAt!);
    if (parsed == null) return 'Tenggat tidak valid';
    return quiz.isPastDeadline
        ? 'Tenggat terlewat'
        : 'Tenggat: ${parsed.toLocal()}';
  }

  void _openQuiz(QuizModel quiz) {
    Navigator.pushNamed(
      context,
      AppNavigation.studentTakeQuiz,
      arguments: {'quizId': quiz.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Mentor')),
      body: RefreshIndicator(
        onRefresh: _loadQuizzes,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_quizzes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text('Belum ada quiz dari mentor yang kamu ikuti.'),
                ),
              )
            else
              ..._quizzes.map((quiz) {
                final locked = quiz.isPastDeadline;
                return Card(
                  child: ListTile(
                    leading: Icon(locked ? Icons.lock_clock : Icons.assignment),
                    title: Text(quiz.title),
                    subtitle: Text(_deadlineText(quiz)),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !locked,
                    onTap: locked ? null : () => _openQuiz(quiz),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
