/// Quiz model
class QuizModel {
  final int? id;
  final int mentorId;
  final String title;
  final String type; // 'multiple_choice' or 'essay'
  final int? materialId;
  final String? deadlineAt;
  final String? createdAt;

  QuizModel({
    this.id,
    required this.mentorId,
    required this.title,
    this.type = 'multiple_choice',
    this.materialId,
    this.deadlineAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mentorId': mentorId,
      'title': title,
      'type': type,
      'materialId': materialId,
      'deadlineAt': deadlineAt,
      'createdAt': createdAt,
    };
  }

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'],
      mentorId: json['mentorId'],
      title: json['title'],
      type: json['type'] ?? 'multiple_choice',
      materialId: json['materialId'],
      deadlineAt: json['deadlineAt'],
      createdAt: json['createdAt'],
    );
  }

  bool get hasDeadline => deadlineAt != null && deadlineAt!.isNotEmpty;

  bool get isPastDeadline {
    final raw = deadlineAt;
    if (raw == null || raw.isEmpty) return false;
    final deadline = DateTime.tryParse(raw);
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }
}
