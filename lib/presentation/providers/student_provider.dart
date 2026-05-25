import 'package:flutter/material.dart';
import '../../data/models/material_model.dart';
import '../../data/models/mentor_leaderboard_entry.dart';
import '../../data/models/quiz_model.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/models/quiz_submission_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/user_repository.dart';

class StudentProvider extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final QuizRepository _quizRepo;
  final UserRepository _userRepo;

  StudentProvider(this._materialRepo, this._quizRepo, this._userRepo);

  Future<List<MaterialModel>> getMaterials() async {
    return await _materialRepo.getAllMaterials();
  }

  Future<List<MaterialModel>> getMaterialsForStudent(int studentId) async {
    final mentors = await _userRepo.getFollowedMentors(studentId);
    final mentorIds = mentors
        .map((mentor) => mentor.id)
        .whereType<int>()
        .toList();
    return await _materialRepo.getMaterialsByMentors(mentorIds);
  }

  Future<List<QuizModel>> getQuizzes() async {
    return await _quizRepo.getQuizzes();
  }

  Future<List<QuizModel>> getQuizzesForStudent(int studentId) async {
    final mentors = await _userRepo.getFollowedMentors(studentId);
    final mentorIds = mentors
        .map((mentor) => mentor.id)
        .whereType<int>()
        .toList();
    return await _quizRepo.getQuizzesByMentors(mentorIds);
  }

  Future<List<QuizModel>> getPostTestsForMaterial(int materialId) async {
    return await _quizRepo.getQuizzesForMaterial(materialId);
  }

  Future<List<QuizQuestionModel>> getQuizQuestions(int quizId) async {
    return await _quizRepo.getQuestions(quizId);
  }

  Future<int> submitQuiz(
    int studentId,
    int quizId,
    Map<String, dynamic> answers,
    int score,
  ) async {
    final submission = QuizSubmissionModel(
      quizId: quizId,
      studentId: studentId,
      answers: answers.toString(),
      score: score,
    );
    return await _quizRepo.submitQuiz(submission);
  }

  Future<List<UserModel>> searchMentors(String query) async {
    return await _userRepo.searchMentors(query);
  }

  Future<UserModel?> getUserById(int userId) async {
    return await _userRepo.getUserById(userId);
  }

  Future<List<MaterialModel>> getMaterialsByMentor(int mentorId) async {
    return await _materialRepo.getMaterialsByMentor(mentorId);
  }

  Future<List<UserModel>> getFollowedMentors(int studentId) async {
    return await _userRepo.getFollowedMentors(studentId);
  }

  Future<List<UserModel>> getStudentsFollowingMentor(int mentorId) async {
    return await _userRepo.getStudentsFollowingMentor(mentorId);
  }

  Future<bool> isFollowingMentor(int studentId, int mentorId) async {
    return await _userRepo.isFollowingMentor(studentId, mentorId);
  }

  Future<int> getFollowerCount(int mentorId) async {
    return await _userRepo.getFollowerCount(mentorId);
  }

  Future<List<UserModel>> getStudentLevelLeaderboard() async {
    return await _userRepo.getUsersByLevel(role: 'student');
  }

  Future<List<MentorLeaderboardEntry>> getMentorLeaderboard() async {
    return await _userRepo.getMentorLeaderboard();
  }

  Future<UserStatistics> getUserStatistics(UserModel user) async {
    final userId = user.id;
    if (userId == null) {
      return const UserStatistics();
    }
    if (user.role == 'mentor') {
      final materialCount = await _materialRepo.getMaterialCountByMentor(
        userId,
      );
      final quizCount = await _quizRepo.getQuizCountByMentor(userId);
      final followerCount = await _userRepo.getFollowerCount(userId);
      return UserStatistics(
        materialCount: materialCount,
        quizCount: quizCount,
        followerCount: followerCount,
      );
    }

    final followedMentors = await _userRepo.getFollowedMentors(userId);
    final submissionCount = await _quizRepo.getSubmissionCountByStudent(userId);
    final averageScore = await _quizRepo.getAverageSubmissionScore(userId);
    return UserStatistics(
      followedMentorCount: followedMentors.length,
      submissionCount: submissionCount,
      averageScore: averageScore,
    );
  }

  Future<void> followMentor(int studentId, int mentorId) async {
    await _userRepo.followMentor(studentId, mentorId);
    notifyListeners();
  }

  Future<void> unfollowMentor(int studentId, int mentorId) async {
    await _userRepo.unfollowMentor(studentId, mentorId);
    notifyListeners();
  }
}

class UserStatistics {
  final int materialCount;
  final int quizCount;
  final int followerCount;
  final int followedMentorCount;
  final int submissionCount;
  final double averageScore;

  const UserStatistics({
    this.materialCount = 0,
    this.quizCount = 0,
    this.followerCount = 0,
    this.followedMentorCount = 0,
    this.submissionCount = 0,
    this.averageScore = 0,
  });
}
