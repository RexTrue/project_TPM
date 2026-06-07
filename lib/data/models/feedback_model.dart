/// Feedback Model
class FeedbackModel {
  final int? id;
  final int? userId;
  final int rating;
  final String message;
  final String? category;
  final String createdAt;

  FeedbackModel({
    this.id,
    this.userId,
    required this.rating,
    required this.message,
    this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'rating': rating,
      'message': message,
      'category': category,
      'createdAt': createdAt,
    };
  }

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'],
      userId: json['userId'],
      rating: json['rating'] ?? 5,
      message: json['message'] ?? '',
      category: json['category'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
