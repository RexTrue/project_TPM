import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../models/badge_model.dart';

bool _useSupabaseGlobal() {
  try {
    return SupabaseService().isReady;
  } catch (_) {
    return false;
  }
}

/// Local Data Source for Badges
class BadgeLocalDataSource {
  final DatabaseService _databaseService;
  static final Map<int, BadgeModel> _memoryBadges = {};
  static int _memoryIdCounter = 1;

  BadgeLocalDataSource(this._databaseService);

  bool get _useSupabase => _useSupabaseGlobal();

  Future<BadgeModel> unlockBadge(BadgeModel badge) async {
    final unlockedAt = DateTime.now().toIso8601String();

    if (kIsWeb && !_useSupabase) {
      final existing = _memoryBadges.values.where(
        (item) =>
            item.userId == badge.userId && item.badgeName == badge.badgeName,
      );
      if (existing.isNotEmpty) return existing.first;

      final id = _memoryIdCounter++;
      final stored = badge.copyWith(id: id, unlockedAt: unlockedAt);
      _memoryBadges[id] = stored;
      return stored;
    }

    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final existing = await client
            .from('badges')
            .select()
            .eq('userId', badge.userId)
            .eq('badgeName', badge.badgeName)
            .maybeSingle();
        if (existing != null) {
          return BadgeModel.fromJson(existing.cast<String, dynamic>());
        }

        final inserted = await client
            .from('badges')
            .insert({
              'userId': badge.userId,
              'badgeName': badge.badgeName,
              'badgeIcon': badge.badgeIcon,
              'unlockedAt': unlockedAt,
            })
            .select();
        if (inserted != null &&
            inserted is List &&
            inserted.isNotEmpty) {
          return BadgeModel.fromJson(
            (inserted.first as Map).cast<String, dynamic>(),
          );
        }
      }

      final db = await _databaseService.database;
      final rows = await db.query(
        'badges',
        where: 'userId = ? AND badgeName = ?',
        whereArgs: [badge.userId, badge.badgeName],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return BadgeModel.fromJson(rows.first);
      }

      final id = await db.insert('badges', {
        'userId': badge.userId,
        'badgeName': badge.badgeName,
        'badgeIcon': badge.badgeIcon,
        'unlockedAt': unlockedAt,
      });
      return badge.copyWith(id: id, unlockedAt: unlockedAt);
    } catch (_) {
      final existing = _memoryBadges.values.where(
        (item) =>
            item.userId == badge.userId && item.badgeName == badge.badgeName,
      );
      if (existing.isNotEmpty) return existing.first;

      final id = _memoryIdCounter++;
      final stored = badge.copyWith(id: id, unlockedAt: unlockedAt);
      _memoryBadges[id] = stored;
      return stored;
    }
  }

  Future<List<BadgeModel>> getBadgesByUser(int userId) async {
    if (kIsWeb && !_useSupabase) {
      return _memoryBadges.values
          .where((badge) => badge.userId == userId)
          .toList();
    }

    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final rows = await client
            .from('badges')
            .select()
            .eq('userId', userId)
            .order('unlockedAt', ascending: false);
        if (rows != null) {
          final list = rows is List ? rows : [rows];
          return list
              .map(
                (row) => BadgeModel.fromJson(
                  (row as Map).cast<String, dynamic>(),
                ),
              )
              .toList();
        }
      }

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
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final row = await client
            .from('badges')
            .select('id')
            .eq('userId', userId)
            .eq('badgeName', badgeId)
            .maybeSingle();
        return row != null;
      } catch (_) {}
    }

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
