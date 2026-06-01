import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../models/mentor_leaderboard_entry.dart';
import '../../../core/services/database_service.dart';
import '../../models/user_model.dart';

/// Local Data Source for User
class UserLocalDataSource {
  final DatabaseService _databaseService;
  static final Map<int, UserModel> _memoryUsers = {};
  static final Set<String> _memoryFollows = {};
  static int _memoryIdCounter = 1;
  static bool _isMemoryLoaded = false;
  static const String _usersCacheKey = 'cached_users_v1';
  static const String _usersIdCounterKey = 'cached_users_id_counter_v1';

  UserLocalDataSource(this._databaseService);

  bool get _useSupabase {
    try {
      return SupabaseService().isReady;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureMemoryLoaded() async {
    if (_isMemoryLoaded) {
      debugPrint(
        '[UserLocalDataSource] Memory already loaded (${_memoryUsers.length} users in memory)',
      );
      return;
    }

    debugPrint(
      '[UserLocalDataSource] Starting memory load from SharedPreferences...',
    );

    try {
      final prefs = await SharedPreferences.getInstance();

      // Show all keys in SharedPreferences for debugging
      final allKeys = prefs.getKeys();
      debugPrint('[UserLocalDataSource] All SharedPreferences keys: $allKeys');

      final raw = prefs.getString(_usersCacheKey);
      final idCounter = prefs.getInt(_usersIdCounterKey);

      debugPrint(
        '[UserLocalDataSource] SharedPreferences raw data: ${raw != null ? "found (${raw.length} chars)" : "NOT FOUND"}',
      );
      debugPrint(
        '[UserLocalDataSource] SharedPreferences key $_usersCacheKey exists: ${prefs.containsKey(_usersCacheKey)}',
      );
      debugPrint('[UserLocalDataSource] ID Counter from prefs: $idCounter');

      if (idCounter != null && idCounter > 0) {
        _memoryIdCounter = idCounter;
        debugPrint(
          '[UserLocalDataSource] Set memory ID counter to: $_memoryIdCounter',
        );
      }

      if (raw != null && raw.isNotEmpty) {
        try {
          debugPrint(
            '[UserLocalDataSource] Decoding JSON from SharedPreferences...',
          );
          final decoded = jsonDecode(raw) as List<dynamic>;
          debugPrint(
            '[UserLocalDataSource] Decoded ${decoded.length} users from JSON',
          );

          for (final item in decoded) {
            final map = (item as Map).cast<String, dynamic>();
            final user = UserModel.fromJson(map);
            if (user.id != null) {
              _memoryUsers[user.id!] = user;
              debugPrint(
                '[UserLocalDataSource]   - Loaded user: id=${user.id}, username=${user.username}',
              );
            }
          }
          debugPrint(
            '[UserLocalDataSource] ✓ Loaded ${_memoryUsers.length} users from SharedPreferences cache',
          );
        } catch (e) {
          debugPrint(
            '[UserLocalDataSource] ✗ ERROR decoding SharedPreferences cache: $e',
          );
          debugPrint('[UserLocalDataSource] Raw data: $raw');
        }
      } else {
        debugPrint(
          '[UserLocalDataSource] No cached users found in SharedPreferences',
        );
        debugPrint(
          '[UserLocalDataSource] ⚠ This may be normal on first run, OR indicate persistence issue (e.g., private browsing)',
        );
        if (kIsWeb) {
          debugPrint(
            '[UserLocalDataSource] Web storage is tied to the browser origin.',
          );
          debugPrint(
            '[UserLocalDataSource] Use the same web hostname and port on every run, for example:',
          );
          debugPrint(
            '[UserLocalDataSource] flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5000',
          );
        }
      }

      _isMemoryLoaded = true;
      debugPrint(
        '[UserLocalDataSource] Memory load complete. Total users in memory: ${_memoryUsers.length}',
      );
    } catch (e) {
      debugPrint('[UserLocalDataSource] ✗ ERROR in _ensureMemoryLoaded: $e');
      _isMemoryLoaded = true;
    }
  }

  Future<void> _saveMemoryToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = _memoryUsers.values.map((e) => e.toJson()).toList();
      final encoded = jsonEncode(users);

      debugPrint(
        '[UserLocalDataSource] Saving ${users.length} users to SharedPreferences (${encoded.length} chars)',
      );
      debugPrint('[UserLocalDataSource] Saving ID counter: $_memoryIdCounter');

      try {
        final success1 = await prefs.setString(_usersCacheKey, encoded);
        debugPrint('[UserLocalDataSource] setString result: $success1');

        final success2 = await prefs.setInt(
          _usersIdCounterKey,
          _memoryIdCounter,
        );
        debugPrint('[UserLocalDataSource] setInt result: $success2');

        if (!success1 || !success2) {
          debugPrint(
            '[UserLocalDataSource] ⚠ WARNING: setString or setInt returned false!',
          );
        }

        // Verify write was successful
        final verification = prefs.getString(_usersCacheKey);
        if (verification != null && verification.isNotEmpty) {
          debugPrint(
            '[UserLocalDataSource] ✓ Verified: Data successfully written to SharedPreferences',
          );
          debugPrint(
            '[UserLocalDataSource] Verification length: ${verification.length} chars',
          );
        } else {
          debugPrint(
            '[UserLocalDataSource] ✗ CRITICAL: Could not verify SharedPreferences write!',
          );
          debugPrint(
            '[UserLocalDataSource] Data was NOT persisted to SharedPreferences!',
          );
          debugPrint(
            '[UserLocalDataSource] This is likely a browser/platform issue:',
          );
          debugPrint('[UserLocalDataSource]   - Private browsing mode?');
          debugPrint('[UserLocalDataSource]   - localStorage disabled?');
          debugPrint('[UserLocalDataSource]   - Browser quota exceeded?');
        }
      } catch (writeError) {
        debugPrint(
          '[UserLocalDataSource] ✗ CRITICAL ERROR during write: $writeError',
        );
        debugPrint(
          '[UserLocalDataSource] Stack trace: ${writeError.toString()}',
        );
      }
    } catch (e) {
      debugPrint(
        '[UserLocalDataSource] ✗ ERROR getting SharedPreferences instance: $e',
      );
      debugPrint(
        '[UserLocalDataSource] ⚠ This indicates SharedPreferences is not available on this platform',
      );
    }
  }

  /// Migrate any users cached in SharedPreferences memory into SQLite DB.
  /// This will insert users that do not exist in DB and update the in-memory
  /// cache keys to the DB-assigned ids. Also migrates saved session `user_id`.
  Future<void> migratePrefsToDb() async {
    await _ensureMemoryLoaded();

    if (kIsWeb) return; // DB persistence not available on web in this app
    // If Supabase is configured, migrate memory cache to remote Postgres first
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final prefs = await SharedPreferences.getInstance();
        final sessionId = prefs.getInt('user_id');
        final biometricUserId = prefs.getInt('biometric_user_id');
        final entries = _memoryUsers.entries.toList();
        for (final e in entries) {
          final memUser = e.value;
          try {
            final existing = await getUserByUsername(memUser.username);
            if (existing != null && existing.id != null) {
              _memoryUsers.remove(e.key);
              _memoryUsers[existing.id!] = existing;
              if (sessionId == e.key) {
                await prefs.setInt('user_id', existing.id!);
              }
              if (biometricUserId == e.key) {
                await prefs.setInt('biometric_user_id', existing.id!);
              }
              continue;
            }

            final inserted = await client
                .from('users')
                .insert({
                  'username': memUser.username,
                  'password': memUser.password,
                  'role': memUser.role,
                  'photo': memUser.photo,
                  'about': memUser.about,
                  'createdAt':
                      memUser.createdAt ?? DateTime.now().toIso8601String(),
                  'level': memUser.level,
                  'xp': memUser.xp,
                  'isPremium': memUser.isPremium ? 1 : 0,
                })
                .select()
                .maybeSingle();

            if (inserted != null && inserted['id'] != null) {
              final id = inserted['id'] as int;
              final migrated = memUser.copyWith(id: id);
              _memoryUsers.remove(e.key);
              _memoryUsers[id] = migrated;
              if (sessionId == e.key) {
                await prefs.setInt('user_id', id);
              }
              if (biometricUserId == e.key) {
                await prefs.setInt('biometric_user_id', id);
              }
            }
          } catch (e) {
            debugPrint(
              '[UserLocalDataSource] Supabase migration failed for ${memUser.username}: $e',
            );
            continue;
          }
        }
        await _saveMemoryToPrefs();
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase migration failed: $e');
      }
      return;
    }

    try {
      final db = await _databaseService.database;

      // Work on a snapshot to avoid concurrent modification while iterating
      final entries = _memoryUsers.entries.toList();
      for (final e in entries) {
        final memUser = e.value;

        // Check if user already exists in DB by username
        try {
          final existing = await getUserByUsername(memUser.username);
          if (existing != null && existing.id != null) {
            // Map memory entry to existing DB id
            _memoryUsers.remove(e.key);
            _memoryUsers[existing.id!] = existing;
            continue;
          }

          // Insert into DB
          final id = await db.insert('users', {
            'username': memUser.username,
            'password': memUser.password,
            'role': memUser.role,
            'photo': memUser.photo,
            'about': memUser.about,
            'createdAt': memUser.createdAt ?? DateTime.now().toIso8601String(),
            'level': memUser.level,
            'xp': memUser.xp,
            'isPremium': memUser.isPremium ? 1 : 0,
          });

          final migrated = memUser.copyWith(id: id);
          _memoryUsers.remove(e.key);
          _memoryUsers[id] = migrated;
        } catch (_) {
          // Ignore per-user migration errors and continue
          continue;
        }
      }

      // Persist updated memory cache
      await _saveMemoryToPrefs();

      // Migrate session user_id if it references an old memory id
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getInt('user_id');
      if (sessionId != null) {
        if (!_memoryUsers.containsKey(sessionId)) {
          // Try to find by username in cache
          final raw = prefs.getString('username');
          if (raw != null) {
            UserModel? byName;
            try {
              byName = _memoryUsers.values.firstWhere((u) => u.username == raw);
            } catch (_) {
              byName = null;
            }
            if (byName != null && byName.id != null) {
              await prefs.setInt('user_id', byName.id!);
            }
          }
        }
      }
    } catch (_) {
      // migration failed, but don't crash app
    }
  }

  /// Create user
  Future<UserModel> createUser(UserModel user) async {
    await _ensureMemoryLoaded();

    if (kIsWeb && !_useSupabase) {
      final id = _memoryIdCounter++;
      final storedUser = user.copyWith(
        id: id,
        createdAt: DateTime.now().toIso8601String(),
      );
      _memoryUsers[id] = storedUser;
      debugPrint(
        '[UserLocalDataSource] Added user to memory: id=$id, username=${user.username}',
      );
      debugPrint(
        '[UserLocalDataSource] Total users in memory now: ${_memoryUsers.length}',
      );

      await _saveMemoryToPrefs();
      debugPrint(
        '[UserLocalDataSource] ✓ User created (web memory): id=$id, username=${user.username}',
      );
      return storedUser;
    }

    // If Supabase configured, create user in remote Postgres
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final createdAt = DateTime.now().toIso8601String();
        final insertData = {
          'username': user.username,
          'password': user.password,
          'role': user.role,
          'photo': user.photo,
          'about': user.about,
          'createdAt': createdAt,
          'level': user.level,
          'xp': user.xp,
          'isPremium': user.isPremium ? 1 : 0,
        };

        debugPrint(
          '[UserLocalDataSource] Inserting user to Supabase: $insertData',
        );
        final inserted = await client
            .from('users')
            .insert(insertData)
            .select()
            .maybeSingle();
        if (inserted != null && inserted['id'] != null) {
          final id = inserted['id'] as int;
          final savedUser = user.copyWith(id: id, createdAt: createdAt);
          _memoryUsers[id] = savedUser;
          debugPrint(
            '[UserLocalDataSource] ✓ User created in Supabase: id=$id, username=${user.username}',
          );
          return savedUser;
        }
      } catch (e) {
        debugPrint('[UserLocalDataSource] ✗ Supabase create user failed: $e');
        // fall through to SQLite path
      }
    }

    try {
      final db = await _databaseService.database;
      final createdAt = DateTime.now().toIso8601String();
      final insertData = {
        'username': user.username,
        'password': user.password,
        'role': user.role,
        'photo': user.photo,
        'about': user.about,
        'createdAt': createdAt,
        'level': user.level,
        'xp': user.xp,
        'isPremium': user.isPremium ? 1 : 0,
      };

      debugPrint('[UserLocalDataSource] Inserting user to SQLite: $insertData');
      final id = await db.insert('users', insertData);
      debugPrint(
        '[UserLocalDataSource] ✓ User successfully created in SQLite: id=$id, username=${user.username}',
      );

      final savedUser = user.copyWith(id: id, createdAt: createdAt);

      // Also cache in memory for quick access
      _memoryUsers[id] = savedUser;

      return savedUser;
    } catch (e) {
      debugPrint('[UserLocalDataSource] ✗ ERROR creating user in SQLite: $e');
      debugPrint(
        '[UserLocalDataSource] Falling back to in-memory storage (NOT PERSISTENT!)',
      );

      // Re-throw to let caller know about the failure
      rethrow;
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(int id) async {
    await _ensureMemoryLoaded();

    if (kIsWeb && !_useSupabase) {
      return _memoryUsers[id];
    }
    // Try Supabase first if available
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('users')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (res != null) return UserModel.fromJson(res as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[UserLocalDataSource] ✗ Supabase getUserById failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      debugPrint('[UserLocalDataSource] Querying SQLite for user ID: $id');

      final result = await db.query('users', where: 'id = ?', whereArgs: [id]);

      if (result.isEmpty) {
        debugPrint('[UserLocalDataSource] ✗ User NOT found in SQLite: id=$id');
        return _memoryUsers[id];
      }

      debugPrint('[UserLocalDataSource] ✓ User found in SQLite: id=$id');
      return UserModel.fromJson(result.first);
    } catch (e) {
      debugPrint('[UserLocalDataSource] ✗ ERROR querying SQLite by ID: $e');
      return _memoryUsers[id];
    }
  }

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    await _ensureMemoryLoaded();

    UserModel? findInMemory() {
      debugPrint(
        '[UserLocalDataSource] Searching in memory for username: $username (${_memoryUsers.length} users in memory)',
      );

      for (final user in _memoryUsers.values) {
        debugPrint('[UserLocalDataSource]   - Checking user: ${user.username}');
        if (user.username == username) {
          debugPrint('[UserLocalDataSource] ✓ User found in memory: $username');
          return user;
        }
      }

      debugPrint('[UserLocalDataSource] ✗ User NOT found in memory: $username');
      debugPrint(
        '[UserLocalDataSource] Available usernames in memory: ${_memoryUsers.values.map((u) => u.username).toList()}',
      );
      return null;
    }

    if (kIsWeb && !_useSupabase) {
      return findInMemory();
    }

    if (_useSupabase) {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select()
            .eq('username', username)
            .maybeSingle();
        if (row != null) {
          final user = UserModel.fromJson(row as Map<String, dynamic>);
          if (user.id != null) {
            _memoryUsers[user.id!] = user;
          }
          debugPrint(
            '[UserLocalDataSource] ✓ User found in Supabase: $username (id=${user.id})',
          );
          return user;
        }
        debugPrint(
          '[UserLocalDataSource] User not found in Supabase: $username',
        );
        return null;
      } catch (e) {
        debugPrint(
          '[UserLocalDataSource] ✗ Supabase getUserByUsername failed: $e',
        );
      }
    }

    try {
      final db = await _databaseService.database;
      debugPrint('[UserLocalDataSource] Querying SQLite for user: $username');

      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (result.isEmpty) {
        debugPrint(
          '[UserLocalDataSource] ✗ User NOT found in SQLite: $username',
        );
        debugPrint(
          '[UserLocalDataSource] Memory users count: ${_memoryUsers.length}',
        );
        return findInMemory();
      }

      debugPrint(
        '[UserLocalDataSource] ✓ User found in SQLite: $username (id=${result.first['id']})',
      );
      return UserModel.fromJson(result.first);
    } catch (e) {
      debugPrint('[UserLocalDataSource] ✗ ERROR querying SQLite: $e');
      return findInMemory();
    }
  }

  /// Update user
  Future<void> updateUser(UserModel user) async {
    await _ensureMemoryLoaded();

    if (kIsWeb && !_useSupabase) {
      if (user.id != null) {
        _memoryUsers[user.id!] = user;
        await _saveMemoryToPrefs();
      }
      return;
    }

    if (_useSupabase && user.id != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update(user.toJson()..remove('id'))
            .eq('id', user.id!);
        _memoryUsers[user.id!] = user;
        await _saveMemoryToPrefs();
        return;
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase updateUser failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      await db.update(
        'users',
        user.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (_) {
      if (user.id != null) {
        _memoryUsers[user.id!] = user;
        await _saveMemoryToPrefs();
      }
    }
  }

  /// Delete user
  Future<void> deleteUser(int id) async {
    await _ensureMemoryLoaded();

    if (kIsWeb && !_useSupabase) {
      _memoryUsers.remove(id);
      await _saveMemoryToPrefs();
      return;
    }

    if (_useSupabase) {
      try {
        await Supabase.instance.client.from('users').delete().eq('id', id);
        _memoryUsers.remove(id);
        await _saveMemoryToPrefs();
        return;
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase deleteUser failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
    } catch (_) {
      _memoryUsers.remove(id);
      await _saveMemoryToPrefs();
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    await _ensureMemoryLoaded();

    if (kIsWeb && !_useSupabase) {
      return _memoryUsers.values.toList();
    }

    if (_useSupabase) {
      try {
        final rows = await Supabase.instance.client.from('users').select();
        final list = rows is List ? rows : [rows];
        return list
            .map(
              (row) => UserModel.fromJson((row as Map).cast<String, dynamic>()),
            )
            .toList();
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase getAllUsers failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      final result = await db.query('users');
      return result.map((json) => UserModel.fromJson(json)).toList();
    } catch (_) {
      return _memoryUsers.values.toList();
    }
  }

  Future<List<UserModel>> getUsersByLevel({String role = 'student'}) async {
    final users = await getAllUsers();
    final filtered = users.where((user) => user.role == role).toList();
    filtered.sort((a, b) {
      final levelCompare = b.level.compareTo(a.level);
      if (levelCompare != 0) return levelCompare;
      return b.xp.compareTo(a.xp);
    });
    return filtered;
  }

  Future<List<UserModel>> searchMentors(String query) async {
    final lower = query.trim().toLowerCase();
    final users = await getAllUsers();
    return users.where((user) {
      final isMentor = user.role == 'mentor';
      if (!isMentor) return false;
      if (lower.isEmpty) return true;
      return user.username.toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> followMentor(int studentId, int mentorId) async {
    final key = '$studentId:$mentorId';
    if (kIsWeb && !_useSupabase) {
      _memoryFollows.add(key);
      return;
    }

    if (_useSupabase) {
      try {
        await Supabase.instance.client.from('user_mentor_follows').upsert({
          'studentId': studentId,
          'mentorId': mentorId,
          'followedAt': DateTime.now().toIso8601String(),
        });
        return;
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase followMentor failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      await db.insert('user_mentor_follows', {
        'studentId': studentId,
        'mentorId': mentorId,
        'followedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      _memoryFollows.add(key);
    }
  }

  Future<void> unfollowMentor(int studentId, int mentorId) async {
    final key = '$studentId:$mentorId';
    if (kIsWeb && !_useSupabase) {
      _memoryFollows.remove(key);
      return;
    }

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('user_mentor_follows')
            .delete()
            .eq('studentId', studentId)
            .eq('mentorId', mentorId);
        return;
      } catch (e) {
        debugPrint('[UserLocalDataSource] Supabase unfollowMentor failed: $e');
      }
    }

    try {
      final db = await _databaseService.database;
      await db.delete(
        'user_mentor_follows',
        where: 'studentId = ? AND mentorId = ?',
        whereArgs: [studentId, mentorId],
      );
    } catch (_) {
      _memoryFollows.remove(key);
    }
  }

  Future<List<UserModel>> getFollowedMentors(int studentId) async {
    if (kIsWeb && !_useSupabase) {
      final ids = _memoryFollows
          .where((key) => key.startsWith('$studentId:'))
          .map((key) => int.tryParse(key.split(':').last))
          .whereType<int>()
          .toSet();
      final users = await getAllUsers();
      return users
          .where((user) => user.id != null && ids.contains(user.id))
          .toList();
    }

    if (_useSupabase) {
      try {
        final rows = await Supabase.instance.client
            .from('user_mentor_follows')
            .select('users!user_mentor_follows_mentorId_fkey(*)')
            .eq('studentId', studentId)
            .order('followedAt', ascending: false);
        final list = rows is List ? rows : [rows];
        return list
            .map((row) => (row as Map)['users'])
            .whereType<Map>()
            .map((row) => UserModel.fromJson(row.cast<String, dynamic>()))
            .toList();
      } catch (e) {
        debugPrint(
          '[UserLocalDataSource] Supabase getFollowedMentors join failed: $e',
        );
        try {
          final follows = await Supabase.instance.client
              .from('user_mentor_follows')
              .select()
              .eq('studentId', studentId)
              .order('followedAt', ascending: false);
          final ids = (follows as List)
              .map((row) => (row as Map)['mentorId'])
              .whereType<int>()
              .toList();
          final users = await getAllUsers();
          return users
              .where((user) => user.id != null && ids.contains(user.id))
              .toList();
        } catch (_) {}
      }
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.rawQuery(
        '''
        SELECT users.* FROM users
        INNER JOIN user_mentor_follows follows ON follows.mentorId = users.id
        WHERE follows.studentId = ?
        ORDER BY follows.followedAt DESC
        ''',
        [studentId],
      );
      return rows.map((row) => UserModel.fromJson(row)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UserModel>> getStudentsFollowingMentor(int mentorId) async {
    if (kIsWeb && !_useSupabase) {
      final ids = _memoryFollows
          .where((key) => key.endsWith(':$mentorId'))
          .map((key) => int.tryParse(key.split(':').first))
          .whereType<int>()
          .toSet();
      final users = await getAllUsers();
      return users
          .where((user) => user.id != null && ids.contains(user.id))
          .toList();
    }

    if (_useSupabase) {
      try {
        final follows = await Supabase.instance.client
            .from('user_mentor_follows')
            .select()
            .eq('mentorId', mentorId)
            .order('followedAt', ascending: false);
        final ids = (follows as List)
            .map((row) => (row as Map)['studentId'])
            .whereType<int>()
            .toList();
        final users = await getAllUsers();
        return users
            .where((user) => user.id != null && ids.contains(user.id))
            .toList();
      } catch (e) {
        debugPrint(
          '[UserLocalDataSource] Supabase getStudentsFollowingMentor failed: $e',
        );
      }
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.rawQuery(
        '''
        SELECT users.* FROM users
        INNER JOIN user_mentor_follows follows ON follows.studentId = users.id
        WHERE follows.mentorId = ?
        ORDER BY follows.followedAt DESC
        ''',
        [mentorId],
      );
      return rows.map((row) => UserModel.fromJson(row)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getFollowerCount(int mentorId) async {
    if (kIsWeb && !_useSupabase) {
      return _memoryFollows.where((key) => key.endsWith(':$mentorId')).length;
    }

    if (_useSupabase) {
      try {
        final rows = await Supabase.instance.client
            .from('user_mentor_follows')
            .select()
            .eq('mentorId', mentorId);
        return rows is List ? rows.length : 0;
      } catch (e) {
        debugPrint(
          '[UserLocalDataSource] Supabase getFollowerCount failed: $e',
        );
      }
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.rawQuery(
        'SELECT COUNT(1) as count FROM user_mentor_follows WHERE mentorId = ?',
        [mentorId],
      );
      final value = rows.firstOrNull?['count'];
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<MentorLeaderboardEntry>> getMentorLeaderboard() async {
    final mentors = await searchMentors('');
    final entries = <MentorLeaderboardEntry>[];
    for (final mentor in mentors) {
      final mentorId = mentor.id;
      if (mentorId == null) continue;
      entries.add(
        MentorLeaderboardEntry(
          mentor: mentor,
          followerCount: await getFollowerCount(mentorId),
        ),
      );
    }
    entries.sort((a, b) {
      final followerCompare = b.followerCount.compareTo(a.followerCount);
      if (followerCompare != 0) return followerCompare;
      final levelCompare = b.mentor.level.compareTo(a.mentor.level);
      if (levelCompare != 0) return levelCompare;
      return b.mentor.xp.compareTo(a.mentor.xp);
    });
    return entries;
  }

  Future<bool> isFollowingMentor(int studentId, int mentorId) async {
    if (kIsWeb && !_useSupabase) {
      return _memoryFollows.contains('$studentId:$mentorId');
    }

    if (_useSupabase) {
      try {
        final row = await Supabase.instance.client
            .from('user_mentor_follows')
            .select()
            .eq('studentId', studentId)
            .eq('mentorId', mentorId)
            .maybeSingle();
        return row != null;
      } catch (e) {
        debugPrint(
          '[UserLocalDataSource] Supabase isFollowingMentor failed: $e',
        );
      }
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        'user_mentor_follows',
        where: 'studentId = ? AND mentorId = ?',
        whereArgs: [studentId, mentorId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Update user XP and Level
  Future<void> updateUserXP(int userId, int xpGained) async {
    await _ensureMemoryLoaded();

    final user = await getUserById(userId);
    if (user != null) {
      final newXP = max(0, user.xp + xpGained);
      final newLevel = (newXP ~/ 100) + 1;
      final updated = user.copyWith(xp: newXP, level: newLevel);
      if (kIsWeb && !_useSupabase) {
        _memoryUsers[userId] = updated;
        await _saveMemoryToPrefs();
        return;
      }

      if (_useSupabase) {
        try {
          await Supabase.instance.client
              .from('users')
              .update({'xp': newXP, 'level': newLevel})
              .eq('id', userId);
          _memoryUsers[userId] = updated;
          await _saveMemoryToPrefs();
          return;
        } catch (e) {
          debugPrint('[UserLocalDataSource] Supabase updateUserXP failed: $e');
        }
      }

      try {
        final db = await _databaseService.database;
        await db.update(
          'users',
          {'xp': newXP, 'level': newLevel},
          where: 'id = ?',
          whereArgs: [userId],
        );
        _memoryUsers[userId] = updated;
        await _saveMemoryToPrefs();
      } catch (_) {
        _memoryUsers[userId] = updated;
        await _saveMemoryToPrefs();
      }
    }
  }
}
