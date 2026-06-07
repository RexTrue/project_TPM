import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobile/core/security/password_hashing.dart';
import 'package:tugas_akhir_mobile/core/utils/validators.dart';
import 'package:tugas_akhir_mobile/data/models/quiz_model.dart';
import 'package:tugas_akhir_mobile/data/models/quiz_question_model.dart';
import 'package:tugas_akhir_mobile/data/models/score_model.dart';
import 'package:tugas_akhir_mobile/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('toJson and fromJson preserve all fields', () {
      final user = UserModel(
        id: 10,
        username: 'tester',
        password: 'Password1',
        role: 'mentor',
        photo: 'avatar.png',
        about: 'About me',
        createdAt: '2026-06-06T12:00:00Z',
        level: 5,
        xp: 500,
        isPremium: true,
      );

      final json = user.toJson();
      final reconstructed = UserModel.fromJson(json);

      expect(reconstructed.id, 10);
      expect(reconstructed.username, 'tester');
      expect(reconstructed.role, 'mentor');
      expect(reconstructed.photo, 'avatar.png');
      expect(reconstructed.about, 'About me');
      expect(reconstructed.createdAt, '2026-06-06T12:00:00Z');
      expect(reconstructed.level, 5);
      expect(reconstructed.xp, 500);
      expect(reconstructed.isPremium, isTrue);
    });

    test('fromJson handles isPremium values in multiple formats', () {
      final boolJson = UserModel.fromJson({
        'id': 1,
        'username': 'booluser',
        'password': 'Password1',
        'isPremium': true,
      });
      expect(boolJson.isPremium, isTrue);

      final intJson = UserModel.fromJson({
        'id': 2,
        'username': 'intuser',
        'password': 'Password1',
        'isPremium': 1,
      });
      expect(intJson.isPremium, isTrue);

      final stringJson = UserModel.fromJson({
        'id': 3,
        'username': 'stringuser',
        'password': 'Password1',
        'isPremium': 'true',
      });
      expect(stringJson.isPremium, isTrue);
    });

    test('copyWith updates only provided fields', () {
      final original = UserModel(
        id: 4,
        username: 'original',
        password: 'Password1',
        role: 'student',
      );
      final updated = original.copyWith(
        username: 'updated',
        xp: 42,
        isPremium: true,
      );

      expect(updated.id, 4);
      expect(updated.username, 'updated');
      expect(updated.password, 'Password1');
      expect(updated.role, 'student');
      expect(updated.xp, 42);
      expect(updated.isPremium, isTrue);
    });
  });

  group('QuizModel', () {
    test('toJson and fromJson round trip', () {
      final quiz = QuizModel(
        id: 12,
        mentorId: 99,
        title: 'Flutter Topics',
        type: 'multiple_choice',
        materialId: 5,
        deadlineAt: '2026-06-10T12:00:00Z',
        createdAt: '2026-06-06T12:00:00Z',
      );

      final json = quiz.toJson();
      final parsed = QuizModel.fromJson(json);

      expect(parsed.id, 12);
      expect(parsed.mentorId, 99);
      expect(parsed.title, 'Flutter Topics');
      expect(parsed.type, 'multiple_choice');
      expect(parsed.materialId, 5);
      expect(parsed.deadlineAt, '2026-06-10T12:00:00Z');
      expect(parsed.createdAt, '2026-06-06T12:00:00Z');
      expect(parsed.hasDeadline, isTrue);
    });

    test('isPastDeadline returns false for future deadline and true for past deadline', () {
      final futureQuiz = QuizModel(
        mentorId: 1,
        title: 'Future quiz',
        deadlineAt: DateTime.now().add(Duration(days: 1)).toIso8601String(),
      );
      final pastQuiz = QuizModel(
        mentorId: 1,
        title: 'Past quiz',
        deadlineAt: DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
      );

      expect(futureQuiz.isPastDeadline, isFalse);
      expect(pastQuiz.isPastDeadline, isTrue);
    });
  });

  group('QuizQuestionModel', () {
    test('toJson and fromJson preserve values', () {
      final question = QuizQuestionModel(
        id: 7,
        quizId: 15,
        questionText: 'What is 2+2?',
        type: 'multiple_choice',
        options: '["1","2","4","5"]',
        correctAnswer: '4',
      );

      final json = question.toJson();
      final parsed = QuizQuestionModel.fromJson(json);

      expect(parsed.id, 7);
      expect(parsed.quizId, 15);
      expect(parsed.questionText, 'What is 2+2?');
      expect(parsed.type, 'multiple_choice');
      expect(parsed.options, '["1","2","4","5"]');
      expect(parsed.correctAnswer, '4');
    });
  });

  group('ScoreModel', () {
    test('toJson and fromJson round trip', () {
      final score = ScoreModel(
        id: 20,
        userId: 3,
        score: 9,
        totalQuestions: 10,
        category: 'Science',
        timestamp: '2026-06-06T12:00:00Z',
      );

      final json = score.toJson();
      final parsed = ScoreModel.fromJson(json);

      expect(parsed.id, 20);
      expect(parsed.userId, 3);
      expect(parsed.score, 9);
      expect(parsed.totalQuestions, 10);
      expect(parsed.category, 'Science');
      expect(parsed.timestamp, '2026-06-06T12:00:00Z');
    });

    test('copyWith modifies only selected fields', () {
      final score = ScoreModel(
        id: 1,
        userId: 2,
        score: 5,
        totalQuestions: 10,
        category: 'Math',
      );
      final changed = score.copyWith(score: 8, category: 'Physics');

      expect(changed.id, 1);
      expect(changed.userId, 2);
      expect(changed.score, 8);
      expect(changed.totalQuestions, 10);
      expect(changed.category, 'Physics');
    });

    test('getPercentage returns zero when totalQuestions is zero', () {
      final score = ScoreModel(
        userId: 4,
        score: 0,
        totalQuestions: 0,
        category: 'History',
      );
      expect(score.getPercentage(), 0);
    });
  });

  group('Validator and security helpers', () {
    test('validateUsername rejects too short username', () {
      expect(Validators.validateUsername('ab'), 'Username must be at least 3 characters');
    });

    test('validateUsername accepts valid username', () {
      expect(Validators.validateUsername('abc'), isNull);
    });

    test('isPasswordStrong identifies strong passwords', () {
      expect(PasswordHashing.isPasswordStrong('StrongPass1'), isTrue);
      expect(PasswordHashing.isPasswordStrong('weakpass'), isFalse);
    });
  });
}
