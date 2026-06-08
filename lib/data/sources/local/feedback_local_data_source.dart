import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../models/feedback_model.dart';

bool _useSupabaseGlobal() {
  try {
    return SupabaseService().isReady;
  } catch (_) {
    return false;
  }
}

/// Local Data Source for Feedback
class FeedbackLocalDataSource {
  final DatabaseService _databaseService;
  static final Map<int, FeedbackModel> _memoryFeedback = {};
  static int _memoryIdCounter = 1;

  FeedbackLocalDataSource(this._databaseService);

  bool get _useSupabase => _useSupabaseGlobal();

  Future<FeedbackModel> createFeedback(FeedbackModel feedback) async {
    final timestamp = DateTime.now().toIso8601String();

    if (kIsWeb && !_useSupabase) {
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
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final inserted = await client
            .from('feedbacks')
            .insert({
              'userId': feedback.userId,
              'rating': feedback.rating,
              'message': feedback.message,
              'category': feedback.category,
              'createdAt': timestamp,
            })
            .select();
        if (inserted != null &&
            inserted is List &&
            inserted.isNotEmpty &&
            inserted.first['id'] != null) {
          return FeedbackModel.fromJson(
            (inserted.first as Map).cast<String, dynamic>(),
          );
        }
      }

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
    if (kIsWeb && !_useSupabase) {
      return _memoryFeedback.values
          .where((item) => item.userId == userId)
          .toList();
    }

    try {
      if (_useSupabase) {
        final client = Supabase.instance.client;
        final rows = await client
            .from('feedbacks')
            .select()
            .eq('userId', userId)
            .order('createdAt', ascending: false);
        if (rows != null) {
          final list = rows is List ? rows : [rows];
          return list
              .map(
                (row) => FeedbackModel.fromJson(
                  (row as Map).cast<String, dynamic>(),
                ),
              )
              .toList();
        }
      }

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
