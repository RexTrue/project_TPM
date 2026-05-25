import 'package:flutter/material.dart';
import '../../data/models/material_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/user_repository.dart';

class MentorProvider extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final QuizRepository _quizRepo;
  final UserRepository _userRepo;

  bool _isLoading = false;
  String? _error;

  MentorProvider(this._materialRepo, this._quizRepo, this._userRepo);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<List<MaterialModel>> getMaterialsByMentor(int mentorId) {
    return _materialRepo.getMaterialsByMentor(mentorId);
  }

  Future<int?> uploadMaterial(
    int mentorId,
    String title,
    String? content,
    String? filePath, {
    String category = 'General',
    String? fileData,
    bool isExclusive = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final model = MaterialModel(
        mentorId: mentorId,
        title: title,
        category: category,
        content: content,
        filePath: filePath,
        fileData: fileData,
        isExclusive: isExclusive,
      );
      final id = await _materialRepo.createMaterial(model);
      await _userRepo.updateUserXP(mentorId, 20);
      return id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMaterial(MaterialModel material) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _materialRepo.updateMaterial(material);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MaterialModel?> getMaterialById(int materialId) {
    return _materialRepo.getMaterialById(materialId);
  }

  Future<List<QuizModel>> getQuizzesByMentor(int mentorId) async {
    final quizzes = await _quizRepo.getQuizzes();
    return quizzes.where((quiz) => quiz.mentorId == mentorId).toList();
  }

  Future<int?> createQuiz(
    int mentorId,
    String title,
    String type,
    List<QuizQuestionModel> questions, {
    int? materialId,
    DateTime? deadlineAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final quiz = QuizModel(
        mentorId: mentorId,
        title: title,
        type: type,
        materialId: materialId,
        deadlineAt: deadlineAt?.toIso8601String(),
      );
      final quizId = await _quizRepo.createQuiz(quiz);
      for (final q in questions) {
        final qToInsert = QuizQuestionModel(
          quizId: quizId,
          questionText: q.questionText,
          options: q.options,
          correctAnswer: q.correctAnswer,
        );
        await _quizRepo.createQuestion(qToInsert);
      }
      if (materialId != null) {
        await _materialRepo.attachPostTest(materialId, quizId);
      }
      await _userRepo.updateUserXP(mentorId, 30);
      return quizId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
