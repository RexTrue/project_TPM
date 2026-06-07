import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_akhir_mobile/data/models/user_model.dart';
import 'package:tugas_akhir_mobile/data/repositories/user_repository.dart';
import 'package:tugas_akhir_mobile/data/sources/local/user_local_data_source.dart';
import 'package:tugas_akhir_mobile/presentation/providers/auth_provider.dart';
import 'package:tugas_akhir_mobile/core/services/database_service.dart';

class FakeUserRepository extends UserRepository {
  final Map<String, UserModel> _users = {};

  FakeUserRepository() : super(UserLocalDataSource(DatabaseService()));

  @override
  Future<bool> registerUser(String username, String password, {String role = 'student'}) async {
    if (_users.containsKey(username)) {
      throw Exception('Username sudah terdaftar');
    }
    final user = UserModel(
      id: _users.length + 1,
      username: username,
      password: password,
      role: role,
    );
    _users[username] = user;
    return true;
  }

  @override
  Future<UserModel> loginUser(String username, String password) async {
    final user = _users[username];
    if (user == null) {
      throw Exception('User not found');
    }
    if (user.password != password) {
      throw Exception('Invalid password');
    }
    return user;
  }

  @override
  Future<UserModel?> getUserById(int id) async {
    for (final user in _users.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  Future<void> updateUserXP(int userId, int xpGained) async {
    final existing = await getUserById(userId);
    if (existing == null) throw Exception('User not found');
    final updated = existing.copyWith(xp: existing.xp + xpGained);
    _users[updated.username] = updated;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    if (user.id == null) throw Exception('User id is required');
    _users[user.username] = user;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider behavior', () {
    late FakeUserRepository repo;
    late AuthProvider auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = FakeUserRepository();
      auth = AuthProvider(repo);
    });

    test('register creates user and auto-logs in', () async {
      final success = await auth.register('student', 'Password1');
      expect(success, isTrue);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.username, 'student');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isTrue);
      expect(prefs.getString('username'), 'student');
    });

    test('login returns false and sets error for invalid user', () async {
      final success = await auth.login('unknown', 'Password1');
      expect(success, isFalse);
      expect(auth.error, contains('User not found'));
      expect(auth.isLoggedIn, isFalse);
    });

    test('biometricQuickLogin fails when no session exists', () async {
      final result = await auth.biometricQuickLogin();
      expect(result, isFalse);
      expect(auth.error, 'Belum ada sesi login sebelumnya');
    });

    test('logout clears session from SharedPreferences', () async {
      await auth.register('student2', 'Password1');
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isFalse);
      expect(prefs.getString('username'), isNull);
    });

    test('setPremiumStatus updates current user and preferences', () async {
      await auth.register('premiumUser', 'Password1');
      final result = await auth.setPremiumStatus(true);
      expect(result, isTrue);
      expect(auth.currentUser?.isPremium, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_premium'), isTrue);
    });

    test('recordMembershipPurchase stores purchase metadata', () async {
      await auth.register('memberUser', 'Password1');
      final now = DateTime.now();
      final until = now.add(Duration(days: 5));
      final result = await auth.recordMembershipPurchase(
        planCode: 'PLAN-1',
        paymentMethod: 'Card',
        receiptId: 'R123',
        purchasedAt: now,
        validUntil: until,
      );
      expect(result, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('membership_plan_code'), 'PLAN-1');
      expect(prefs.getString('membership_valid_until'), until.toIso8601String());
    });

    test('mentor membership functions work with current user', () async {
      await auth.register('student3', 'Password1');
      final now = DateTime.now();
      final validUntil = now.add(Duration(days: 2));
      await auth.recordMentorMembershipPurchase(
        mentorId: 7,
        planCode: 'MENTOR-7',
        purchasedAt: now,
        validUntil: validUntil,
      );

      final isMember = await auth.isMentorMember(7);
      expect(isMember, isTrue);

      final memberships = await auth.activeMentorMembershipsForCurrentUser();
      expect(memberships.containsKey(7), isTrue);
      expect(memberships[7], validUntil);
    });

    test('addXp increases current user xp and saves through repository', () async {
      await auth.register('student4', 'Password1');
      final result = await auth.addXp(20);
      expect(result, isTrue);
      expect(auth.currentUser?.xp, 20);
    });
  });
}
