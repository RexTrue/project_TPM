import '../models/quiz_model.dart';
import '../models/quiz_question_model.dart';
import '../models/quiz_submission_model.dart';
import '../sources/local/quiz_local_data_source.dart';

class QuizRepository {
  final QuizLocalDataSource _local;

  QuizRepository(this._local);

  Future<int> createQuiz(QuizModel quiz) => _local.createQuiz(quiz);
  Future<int> createQuestion(QuizQuestionModel q) => _local.createQuestion(q);
  Future<List<QuizModel>> getQuizzes() => _local.getQuizzes();
  Future<List<QuizModel>> getQuizzesByMentors(List<int> mentorIds) =>
      _local.getQuizzesByMentors(mentorIds);
  Future<List<QuizModel>> getQuizzesForMaterial(int materialId) =>
      _local.getQuizzesForMaterial(materialId);
  Future<int> getQuizCountByMentor(int mentorId) =>
      _local.getQuizCountByMentor(mentorId);
  Future<int> getSubmissionCountByStudent(int studentId) =>
      _local.getSubmissionCountByStudent(studentId);
  Future<double> getAverageSubmissionScore(int studentId) =>
      _local.getAverageSubmissionScore(studentId);
  Future<List<QuizQuestionModel>> getQuestions(int quizId) =>
      _local.getQuestionsForQuiz(quizId);
  Future<int> submitQuiz(QuizSubmissionModel submission) =>
      _local.submitQuiz(submission);
}
