import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobile/data/models/user_model.dart';
import 'package:tugas_akhir_mobile/data/repositories/user_repository.dart';
import 'package:tugas_akhir_mobile/data/sources/local/user_local_data_source.dart';
import 'package:tugas_akhir_mobile/core/services/database_service.dart';

class InMemoryUserLocalDataSource extends UserLocalDataSource {
  final Map<String, UserModel> _users = {};

  InMemoryUserLocalDataSource() : super(DatabaseService());

  @override
  Future<UserModel?> getUserByUsername(String username) async {
    return _users[username];
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    if (_users.containsKey(user.username)) {
      throw Exception('Username sudah terdaftar');
    }
    final inserted = user.copyWith(id: _users.length + 1);
    _users[inserted.username] = inserted;
    return inserted;
  }

  @override
  Future<UserModel?> getUserById(int id) async {
    for (final user in _users.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    if (user.id == null) throw Exception('User id is required');
    _users[user.username] = user;
  }

  @override
  Future<void> updateUserXP(int userId, int xpGained) async {
    final existing = await getUserById(userId);
    if (existing == null) throw Exception('User not found');
    _users[existing.username] = existing.copyWith(xp: existing.xp + xpGained);
  }
}

void main() {
  group('UserRepository', () {
    late UserRepository repository;
    late InMemoryUserLocalDataSource dataSource;

    setUp(() {
      dataSource = InMemoryUserLocalDataSource();
      repository = UserRepository(dataSource);
    });

    test('registerUser saves a new user successfully', () async {
      final result = await repository.registerUser('user1', 'Password1');
      expect(result, isTrue);
    });

    test('registerUser throws when username already exists', () async {
      await repository.registerUser('user2', 'Password1');
      expect(
        () => repository.registerUser('user2', 'Password1'),
        throwsA(isA<Exception>()),
      );
    });

    test('loginUser returns user when credentials match', () async {
      await repository.registerUser('user3', 'Password1');
      final user = await repository.loginUser('user3', 'Password1');
      expect(user.username, 'user3');
      expect(user.password, 'Password1');
    });

    test('loginUser throws when password is invalid', () async {
      await repository.registerUser('user4', 'Password1');
      expect(
        () => repository.loginUser('user4', 'wrongpass'),
        throwsA(isA<Exception>()),
      );
    });

    test('getUserById returns the correct stored user', () async {
      await repository.registerUser('user5', 'Password1');
      final registered = await repository.loginUser('user5', 'Password1');
      final found = await repository.getUserById(registered.id!);
      expect(found?.username, 'user5');
    });

    test('updateUserXP increments xp on existing user', () async {
      await repository.registerUser('user6', 'Password1');
      final user = await repository.loginUser('user6', 'Password1');
      await repository.updateUserXP(user.id!, 30);
      final updated = await repository.getUserById(user.id!);
      expect(updated?.xp, 30);
    });
  });
}
