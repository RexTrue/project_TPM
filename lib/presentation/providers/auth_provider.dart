import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/security/password_hashing.dart';

/// Auth Provider for Login/Register
class AuthProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._userRepository);

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isPremium => _currentUser?.isPremium ?? false;

  String _mentorMembershipKey(int studentId, int mentorId) =>
      'mentor_membership_${studentId}_${mentorId}_valid_until';

  String _mentorMembershipPlanKey(int studentId, int mentorId) =>
      'mentor_membership_${studentId}_${mentorId}_plan';

  DateTime? _readMembershipExpiry(SharedPreferences prefs) {
    final raw = prefs.getString('membership_valid_until');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _syncMembershipState(
    UserModel? user,
    SharedPreferences prefs,
  ) async {
    if (user == null) return;

    final expiry = _readMembershipExpiry(prefs);
    final now = DateTime.now();
    final hasExpiry = expiry != null;
    final isExpired = hasExpiry && now.isAfter(expiry);
    final activeFromStorage = prefs.getBool('is_premium') ?? user.isPremium;
    final shouldBePremium = isExpired ? false : activeFromStorage;

    if (isExpired) {
      await prefs.setBool('is_premium', false);
      await prefs.remove('membership_plan_code');
      await prefs.remove('membership_payment_method');
      await prefs.remove('membership_receipt_id');
      await prefs.remove('membership_purchased_at');
      await prefs.remove('membership_valid_until');
    } else {
      await prefs.setBool('is_premium', shouldBePremium);
    }

    if (user.isPremium != shouldBePremium) {
      final updatedUser = user.copyWith(isPremium: shouldBePremium);
      await _userRepository.updateUser(updatedUser);
      _currentUser = updatedUser;
    } else {
      _currentUser = user.copyWith(isPremium: shouldBePremium);
    }
  }

  /// Register new user
  Future<bool> register(
    String username,
    String password, {
    String role = 'student',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[AuthProvider] Starting registration for user: $username');

      final hashedPassword = PasswordHashing.hashPassword(password);
      await _userRepository.registerUser(username, hashedPassword, role: role);

      debugPrint('[AuthProvider] ✓ User registered successfully: $username');

      // Auto login after registration
      final loginSuccess = await login(username, password);

      if (loginSuccess) {
        debugPrint('[AuthProvider] ✓ Auto-login successful after registration');
      } else {
        debugPrint('[AuthProvider] ✗ Auto-login failed after registration');
      }

      return loginSuccess;
    } catch (e) {
      debugPrint('[AuthProvider] ✗ Registration error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login user
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[AuthProvider] Starting login for user: $username');

      final hashedPassword = PasswordHashing.hashPassword(password);
      final user = await _userRepository.loginUser(username, hashedPassword);

      _currentUser = user;
      debugPrint(
        '[AuthProvider] ✓ Login successful: $username (id=${user.id})',
      );

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id ?? 0);
      await prefs.setString('username', user.username);
      await prefs.setString('role', user.role);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_premium', user.isPremium);
      if (user.id != null) {
        await prefs.setInt('biometric_user_id', user.id!);
      }
      await _syncMembershipState(_currentUser, prefs);

      debugPrint('[AuthProvider] ✓ Session saved to SharedPreferences');

      return true;
    } catch (e) {
      debugPrint('[AuthProvider] ✗ Login error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user is already logged in
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      _currentUser = await _userRepository.getUserById(userId);
      await _syncMembershipState(_currentUser, prefs);
      notifyListeners();
    }
  }

  Future<bool> biometricQuickLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? prefs.getInt('biometric_user_id');
    if (userId == null) {
      _error = 'Belum ada sesi login sebelumnya';
      notifyListeners();
      return false;
    }

    final user = await _userRepository.getUserById(userId);
    if (user == null) {
      _error = 'Data pengguna tidak ditemukan';
      notifyListeners();
      return false;
    }

    _currentUser = user;
    await prefs.setInt('user_id', user.id ?? userId);
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_premium', user.isPremium);
    await prefs.setString('username', user.username);
    await prefs.setString('role', user.role);
    await prefs.setInt('biometric_user_id', user.id ?? userId);
    await _syncMembershipState(_currentUser, prefs);
    notifyListeners();
    return true;
  }

  /// Logout user
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_id');
    await prefs.remove('is_premium');
    await prefs.remove('username');
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile({String? photo, String? about}) async {
    if (_currentUser == null) return false;

    try {
      final updatedUser = _currentUser!.copyWith(photo: photo, about: about);
      await _userRepository.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addXp(int amount) async {
    final userId = _currentUser?.id;
    if (userId == null || amount <= 0) return false;

    try {
      await _userRepository.updateUserXP(userId, amount);
      _currentUser = await _userRepository.getUserById(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Mark current user as premium and persist the status.
  Future<bool> setPremiumStatus(bool value) async {
    if (_currentUser == null) return false;

    try {
      final updatedUser = _currentUser!.copyWith(isPremium: value);
      await _userRepository.updateUser(updatedUser);
      _currentUser = updatedUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', value);
      if (!value) {
        await prefs.remove('membership_plan_code');
        await prefs.remove('membership_payment_method');
        await prefs.remove('membership_receipt_id');
        await prefs.remove('membership_purchased_at');
        await prefs.remove('membership_valid_until');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Store membership purchase metadata for the active user.
  Future<bool> recordMembershipPurchase({
    required String planCode,
    required String paymentMethod,
    required String receiptId,
    required DateTime purchasedAt,
    required DateTime? validUntil,
  }) async {
    if (_currentUser == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('membership_plan_code', planCode);
      await prefs.setString('membership_payment_method', paymentMethod);
      await prefs.setString('membership_receipt_id', receiptId);
      await prefs.setString(
        'membership_purchased_at',
        purchasedAt.toIso8601String(),
      );
      if (validUntil != null) {
        await prefs.setString(
          'membership_valid_until',
          validUntil.toIso8601String(),
        );
      } else {
        await prefs.remove('membership_valid_until');
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordMentorMembershipPurchase({
    required int mentorId,
    required String planCode,
    required DateTime purchasedAt,
    required DateTime validUntil,
  }) async {
    final studentId = _currentUser?.id;
    if (studentId == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _mentorMembershipKey(studentId, mentorId),
        validUntil.toIso8601String(),
      );
      await prefs.setString(
        _mentorMembershipPlanKey(studentId, mentorId),
        planCode,
      );
      await prefs.setString(
        'mentor_membership_${studentId}_${mentorId}_purchased_at',
        purchasedAt.toIso8601String(),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> isMentorMember(int mentorId) async {
    final studentId = _currentUser?.id;
    if (studentId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mentorMembershipKey(studentId, mentorId));
    final validUntil = raw == null ? null : DateTime.tryParse(raw);
    if (validUntil == null) return false;
    return DateTime.now().isBefore(validUntil);
  }

  Future<Map<int, DateTime>> activeMentorMembershipsForCurrentUser() async {
    final studentId = _currentUser?.id;
    if (studentId == null) return {};
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'mentor_membership_${studentId}_';
    final result = <int, DateTime>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix) || !key.endsWith('_valid_until')) continue;
      final mentorPart = key.substring(
        prefix.length,
        key.length - '_valid_until'.length,
      );
      final mentorId = int.tryParse(mentorPart);
      final validUntil = DateTime.tryParse(prefs.getString(key) ?? '');
      if (mentorId != null &&
          validUntil != null &&
          DateTime.now().isBefore(validUntil)) {
        result[mentorId] = validUntil;
      }
    }
    return result;
  }
}
