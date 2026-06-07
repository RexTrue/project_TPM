import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobile/core/security/password_hashing.dart';
import 'package:tugas_akhir_mobile/core/utils/validators.dart';
import 'package:tugas_akhir_mobile/data/models/score_model.dart';

void main() {
  group('White-box testing', () {
    test('validateEmail returns error for null email', () {
      expect(Validators.validateEmail(null), 'Email is required');
    });

    test('validateEmail returns error for invalid email', () {
      expect(Validators.validateEmail('invalid-email'), 'Invalid email format');
    });

    test('validateEmail returns null for valid email', () {
      expect(Validators.validateEmail('student@example.com'), isNull);
    });

    test('validatePassword rejects short password', () {
      expect(Validators.validatePassword('Ab1'), 'Password must be at least 8 characters');
    });

    test('validatePassword rejects missing uppercase', () {
      expect(Validators.validatePassword('password1'), 'Password must contain uppercase letter');
    });

    test('validatePassword rejects missing number', () {
      expect(Validators.validatePassword('Password'), 'Password must contain number');
    });

    test('validatePassword accepts strong password', () {
      expect(Validators.validatePassword('Password1'), isNull);
    });

    test('hashPassword returns stable SHA-256 fingerprint with expected length', () {
      final hash = PasswordHashing.hashPassword('Password1');
      expect(hash.length, 64);
      expect(hash, '19513fdc9da4fb72a4a05eb66917548d3c90ff94d5419e1f2363eea89dfee1dd');
    });

    test('verifyPassword returns true for matching password and hash', () {
      final hash = PasswordHashing.hashPassword('Password1');
      expect(PasswordHashing.verifyPassword('Password1', hash), isTrue);
    });

    test('verifyPassword returns false for non-matching password', () {
      final hash = PasswordHashing.hashPassword('Password1');
      expect(PasswordHashing.verifyPassword('password1', hash), isFalse);
    });
  });

  group('Black-box testing', () {
    test('validateConfirmPassword rejects mismatch', () {
      expect(Validators.validateConfirmPassword('Password1', 'Password2'), 'Passwords do not match');
    });

    test('validateRequired rejects empty required fields', () {
      expect(Validators.validateRequired('', 'Nama'), 'Nama is required');
    });

    test('ScoreModel calculates percentage correctly', () {
      final score = ScoreModel(
        userId: 1,
        score: 8,
        totalQuestions: 10,
        category: 'Matematika',
      );
      expect(score.getPercentage(), closeTo(80.0, 0.0001));
    });

    test('ScoreModel percentage is 0 when totalQuestions is zero', () {
      final score = ScoreModel(
        userId: 1,
        score: 0,
        totalQuestions: 0,
        category: 'Sains',
      );
      expect(score.getPercentage(), 0);
    });
  });

  group('Load and stress testing', () {
    test('load testing email validator with 10000 iterations', () {
      for (var i = 0; i < 10000; i++) {
        final result = Validators.validateEmail('student$i@example.com');
        expect(result, isNull);
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('stress testing password hashing with 100000 iterations', () {
      for (var i = 0; i < 100000; i++) {
        final hash = PasswordHashing.hashPassword('Password$i');
        expect(hash.length, 64);
      }
    }, timeout: Timeout(Duration(seconds: 60)));
  });
}
