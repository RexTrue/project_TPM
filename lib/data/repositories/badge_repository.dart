import '../models/badge_model.dart';
import '../sources/local/badge_local_data_source.dart';

/// Badge Repository
class BadgeRepository {
  final BadgeLocalDataSource _localDataSource;

  BadgeRepository(this._localDataSource);

  Future<BadgeModel> unlockBadge(BadgeModel badge) {
    return _localDataSource.unlockBadge(badge);
  }

  Future<List<BadgeModel>> getBadgesByUser(int userId) {
    return _localDataSource.getBadgesByUser(userId);
  }

  Future<bool> hasBadge(int userId, String badgeId) {
    return _localDataSource.hasBadge(userId, badgeId);
  }

  Future<int> countBadgesByUser(int userId) {
    return _localDataSource.countBadgesByUser(userId);
  }
}
