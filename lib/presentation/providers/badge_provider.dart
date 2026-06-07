import 'package:flutter/material.dart';

import '../../core/constants/badge_definitions.dart';
import '../../data/models/badge_model.dart';
import '../../data/repositories/badge_repository.dart';

/// Badge Provider untuk mengelola badge pengguna.
class BadgeProvider extends ChangeNotifier {
  final BadgeRepository _badgeRepository;

  List<BadgeModel> _userBadges = [];
  bool _isLoading = false;
  String? _error;

  BadgeProvider(this._badgeRepository);

  List<BadgeModel> get userBadges => _userBadges;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get badgeCount => _userBadges.length;

  Future<void> loadBadges(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userBadges = await _badgeRepository.getBadgesByUser(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> checkAndUnlock({
    required int userId,
    int? quizScore,
    bool quizCompleted = false,
    bool gamePlayed = false,
    bool feedbackSent = false,
    int? xp,
    int? level,
  }) async {
    final unlocked = <String>[];

    Future<void> tryUnlock(String badgeId) async {
      if (await _badgeRepository.hasBadge(userId, badgeId)) return;
      final definition = findBadgeDefinition(badgeId);
      if (definition == null) return;

      await _badgeRepository.unlockBadge(
        BadgeModel(
          userId: userId,
          badgeName: badgeId,
          badgeIcon: definition.icon,
        ),
      );
      unlocked.add(definition.name);
    }

    if (quizCompleted) await tryUnlock('first_quiz');
    if (quizScore != null && quizScore >= 80) await tryUnlock('quiz_master');
    if (quizScore != null && quizScore >= 100) await tryUnlock('perfect_score');
    if (gamePlayed) await tryUnlock('game_player');
    if (feedbackSent) await tryUnlock('feedback_giver');
    if (xp != null && xp >= 100) await tryUnlock('xp_hunter');
    if (level != null && level >= 5) await tryUnlock('level_5');

    if (unlocked.isNotEmpty) {
      await loadBadges(userId);
    }

    return unlocked;
  }
}
