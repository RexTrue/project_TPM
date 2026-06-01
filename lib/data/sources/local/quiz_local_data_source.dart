import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_question_model.dart';
import '../../models/quiz_submission_model.dart';

bool _useSupabaseGlobal() {
  try {
    return SupabaseService().isReady;
  } catch (_) {
    return false;
  }
}

class QuizLocalDataSource {
  final DatabaseService _databaseService;

  QuizLocalDataSource(this._databaseService);

  bool get _useSupabase => _useSupabaseGlobal();

  Future<int> createQuiz(QuizModel quiz) async {
    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final createdAt = quiz.createdAt ?? DateTime.now().toIso8601String();
        final inserted = await client.from('quizzes').insert({
          'mentorId': quiz.mentorId,
          'title': quiz.title,
          'type': quiz.type,
          'materialId': quiz.materialId,
          'deadlineAt': quiz.deadlineAt,
          'createdAt': createdAt,
        }).select();
        if (inserted != null &&
            inserted is List &&
            inserted.isNotEmpty &&
            inserted.first['id'] != null) {
          return inserted.first['id'] as int;
        }
        throw Exception('Supabase insert failed');
      }

      final count = await _databaseService.getRowCount('quizzes');
      if (count >= DatabaseService.maxQuizzes) {
        throw Exception('Quiz limit reached');
      }

      final db = await _databaseService.database;
      final id = await db.insert('quizzes', {
        'mentorId': quiz.mentorId,
        'title': quiz.title,
        'type': quiz.type,
        'materialId': quiz.materialId,
        'deadlineAt': quiz.deadlineAt,
        'createdAt': quiz.createdAt ?? DateTime.now().toIso8601String(),
      });
      return id;
    } catch (e) {
      throw Exception('Failed to create quiz: $e');
    }
  }

  Future<int> createQuestion(QuizQuestionModel question) async {
    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final inserted = await client.from('quiz_questions').insert({
          'quizId': question.quizId,
          'questionText': question.questionText,
          'type': question.type,
          'options': question.options,
          'correctAnswer': question.correctAnswer,
        }).select();
        if (inserted != null &&
            inserted is List &&
            inserted.isNotEmpty &&
            inserted.first['id'] != null) {
          return inserted.first['id'] as int;
        }
        throw Exception('Supabase insert failed');
      }

      final count = await _databaseService.getRowCount('quiz_questions');
      if (count >= DatabaseService.maxQuizQuestions) {
        throw Exception('Quiz questions limit reached');
      }

      final db = await _databaseService.database;
      final id = await db.insert('quiz_questions', {
        'quizId': question.quizId,
        'questionText': question.questionText,
        'type': question.type,
        'options': question.options,
        'correctAnswer': question.correctAnswer,
      });
      return id;
    } catch (e) {
      throw Exception('Failed to insert question: $e');
    }
  }

  Future<List<QuizModel>> getQuizzes() async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('quizzes')
            .select()
            .order('createdAt', ascending: false);
        if (rows == null) return [];
        final list = rows is List ? rows : [rows];
        return list
            .map((r) => QuizModel.fromJson((r as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {}
    }

    final db = await _databaseService.database;
    final rows = await db.query('quizzes', orderBy: 'createdAt DESC');
    return rows.map((r) => QuizModel.fromJson(r)).toList();
  }

  Future<List<QuizModel>> getQuizzesByMentors(List<int> mentorIds) async {
    if (mentorIds.isEmpty) return [];
    final quizzes = await getQuizzes();
    return quizzes.where((quiz) => mentorIds.contains(quiz.mentorId)).toList();
  }

  Future<List<QuizModel>> getQuizzesForMaterial(int materialId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('quizzes')
            .select()
            .eq('materialId', materialId)
            .order('createdAt', ascending: false);
        if (rows == null) return [];
        final list = rows is List ? rows : [rows];
        return list
            .map((r) => QuizModel.fromJson((r as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {}
    }

    final db = await _databaseService.database;
    final rows = await db.query(
      'quizzes',
      where: 'materialId = ?',
      whereArgs: [materialId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => QuizModel.fromJson(r)).toList();
  }

  Future<int> getQuizCountByMentor(int mentorId) async {
    final quizzes = await getQuizzes();
    return quizzes.where((quiz) => quiz.mentorId == mentorId).length;
  }

  Future<int> getSubmissionCountByStudent(int studentId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('quiz_submissions')
            .select()
            .eq('studentId', studentId);
        if (rows == null) return 0;
        return rows is List ? rows.length : 1;
      } catch (_) {}
    }

    final db = await _databaseService.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(1) as count FROM quiz_submissions WHERE studentId = ?',
      [studentId],
    );
    final value = rows.firstOrNull?['count'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<double> getAverageSubmissionScore(int studentId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('quiz_submissions')
            .select()
            .eq('studentId', studentId);
        final list = rows is List ? rows : [rows];
        if (list.isEmpty) return 0;
        final total = list.fold<double>(
          0,
          (sum, row) => sum + (((row as Map)['score'] as num?) ?? 0),
        );
        return total / list.length;
      } catch (_) {}
    }

    final db = await _databaseService.database;
    final rows = await db.rawQuery(
      'SELECT AVG(score) as averageScore FROM quiz_submissions WHERE studentId = ?',
      [studentId],
    );
    final value = rows.firstOrNull?['averageScore'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<List<QuizQuestionModel>> getQuestionsForQuiz(int quizId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('quiz_questions')
            .select()
            .eq('quizId', quizId);
        if (rows == null) return [];
        final list = rows is List ? rows : [rows];
        return list
            .map(
              (r) => QuizQuestionModel.fromJson(
                (r as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      } catch (_) {}
    }

    final db = await _databaseService.database;
    final rows = await db.query(
      'quiz_questions',
      where: 'quizId = ?',
      whereArgs: [quizId],
    );
    return rows.map((r) => QuizQuestionModel.fromJson(r)).toList();
  }

  Future<int> submitQuiz(QuizSubmissionModel submission) async {
    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final inserted = await client.from('quiz_submissions').insert({
          'quizId': submission.quizId,
          'studentId': submission.studentId,
          'answers': submission.answers,
          'score': submission.score,
          'submittedAt':
              submission.submittedAt ?? DateTime.now().toIso8601String(),
        }).select();
        if (inserted != null &&
            inserted is List &&
            inserted.isNotEmpty &&
            inserted.first['id'] != null) {
          return inserted.first['id'] as int;
        }
        throw Exception('Supabase insert failed');
      }

      final count = await _databaseService.getRowCount('quiz_submissions');
      if (count >= DatabaseService.maxQuizSubmissions) {
        throw Exception('Submissions limit reached');
      }

      final db = await _databaseService.database;
      final id = await db.insert('quiz_submissions', {
        'quizId': submission.quizId,
        'studentId': submission.studentId,
        'answers': submission.answers,
        'score': submission.score,
        'submittedAt':
            submission.submittedAt ?? DateTime.now().toIso8601String(),
      });
      return id;
    } catch (e) {
      throw Exception('Failed to submit quiz: $e');
    }
  }
}
