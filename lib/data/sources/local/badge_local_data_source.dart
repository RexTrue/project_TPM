import 'package:flutter/foundation.dart';

import '../../../core/services/database_service.dart';
import '../../models/badge_model.dart';

/// Local Data Source for Badges
class BadgeLocalDataSource {
  final DatabaseService _databaseService;
  static final Map<int, BadgeModel> _memoryBadges = {};
  static int _memoryIdCounter = 1;

  BadgeLocalDataSource(this._databaseService);

  Future<BadgeModel> unlockBadge(BadgeModel badge) async {
    if (kIsWeb) {
      final id = _memoryIdCounter++;
      final stored = badge.copyWith(
        id: id,
        unlockedAt: DateTime.now().toIso8601String(),
      );
      _memoryBadges[id] = stored;
      return stored;
    }

    try {
      final db = await _databaseService.database;
      final existing = await db.query(
        'badges',
        where: 'userId = ? AND badgeName = ?',
        whereArgs: [badge.userId, badge.badgeName],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return BadgeModel.fromJson(existing.first);
      }

      final id = await db.insert('badges', {
        'userId': badge.userId,
        'badgeName': badge.badgeName,
        'badgeIcon': badge.badgeIcon,
        'unlockedAt': DateTime.now().toIso8601String(),
      });
      return badge.copyWith(
        id: id,
        unlockedAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      final id = _memoryIdCounter++;
      final stored = badge.copyWith(
        id: id,
        unlockedAt: DateTime.now().toIso8601String(),
      );
      _memoryBadges[id] = stored;
      return stored;
    }
  }

  Future<List<BadgeModel>> getBadgesByUser(int userId) async {
    if (kIsWeb) {
      return _memoryBadges.values
          .where((badge) => badge.userId == userId)
          .toList();
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        'badges',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'unlockedAt DESC',
      );
      return rows.map((json) => BadgeModel.fromJson(json)).toList();
    } catch (_) {
      return _memoryBadges.values
          .where((badge) => badge.userId == userId)
          .toList();
    }
  }

  Future<bool> hasBadge(int userId, String badgeId) async {
    final badges = await getBadgesByUser(userId);
    return badges.any((badge) => badge.badgeName == badgeId);
  }

  Future<int> countBadgesByUser(int userId) async {
    final badges = await getBadgesByUser(userId);
    return badges.length;
  }
}

extension BadgeModelCopy on BadgeModel {
  BadgeModel copyWith({
    int? id,
    int? userId,
    String? badgeName,
    String? badgeIcon,
    String? unlockedAt,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      badgeName: badgeName ?? this.badgeName,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
