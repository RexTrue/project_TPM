import '../models/feedback_model.dart';
import '../sources/local/feedback_local_data_source.dart';

/// Feedback Repository
class FeedbackRepository {
  final FeedbackLocalDataSource _localDataSource;

  FeedbackRepository(this._localDataSource);

  Future<FeedbackModel> createFeedback(FeedbackModel feedback) {
    return _localDataSource.createFeedback(feedback);
  }

  Future<List<FeedbackModel>> getFeedbacksByUser(int userId) {
    return _localDataSource.getFeedbacksByUser(userId);
  }
}
