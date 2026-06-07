import 'package:flutter/foundation.dart';

import '../../../core/services/database_service.dart';
import '../../models/feedback_model.dart';

/// Local Data Source for Feedback
class FeedbackLocalDataSource {
  final DatabaseService _databaseService;
  static final Map<int, FeedbackModel> _memoryFeedback = {};
  static int _memoryIdCounter = 1;

  FeedbackLocalDataSource(this._databaseService);

  Future<FeedbackModel> createFeedback(FeedbackModel feedback) async {
    final timestamp = DateTime.now().toIso8601String();

    if (kIsWeb) {
      final id = _memoryIdCounter++;
      final stored = FeedbackModel(
        id: id,
        userId: feedback.userId,
        rating: feedback.rating,
        message: feedback.message,
        category: feedback.category,
        createdAt: timestamp,
      );
      _memoryFeedback[id] = stored;
      return stored;
    }

    try {
      final db = await _databaseService.database;
      final id = await db.insert('feedbacks', {
        'userId': feedback.userId,
        'rating': feedback.rating,
        'message': feedback.message,
        'category': feedback.category,
        'createdAt': timestamp,
      });
      return FeedbackModel(
        id: id,
        userId: feedback.userId,
        rating: feedback.rating,
        message: feedback.message,
        category: feedback.category,
        createdAt: timestamp,
      );
    } catch (_) {
      final id = _memoryIdCounter++;
      final stored = FeedbackModel(
        id: id,
        userId: feedback.userId,
        rating: feedback.rating,
        message: feedback.message,
        category: feedback.category,
        createdAt: timestamp,
      );
      _memoryFeedback[id] = stored;
      return stored;
    }
  }

  Future<List<FeedbackModel>> getFeedbacksByUser(int userId) async {
    if (kIsWeb) {
      return _memoryFeedback.values
          .where((item) => item.userId == userId)
          .toList();
    }

    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        'feedbacks',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'createdAt DESC',
      );
      return rows.map((json) => FeedbackModel.fromJson(json)).toList();
    } catch (_) {
      return _memoryFeedback.values
          .where((item) => item.userId == userId)
          .toList();
    }
  }
}
