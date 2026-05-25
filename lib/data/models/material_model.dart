/// Material uploaded by mentor
class MaterialModel {
  final int? id;
  final int mentorId;
  final String title;
  final String category;
  final String? content;
  final String? filePath;
  final String? fileData;
  final int? postTestQuizId;
  final bool isExclusive;
  final String? createdAt;

  MaterialModel({
    this.id,
    required this.mentorId,
    required this.title,
    this.category = 'General',
    this.content,
    this.filePath,
    this.fileData,
    this.postTestQuizId,
    this.isExclusive = false,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mentorId': mentorId,
      'title': title,
      'category': category,
      'content': content,
      'filePath': filePath,
      'fileData': fileData,
      'postTestQuizId': postTestQuizId,
      'isExclusive': isExclusive ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: json['id'],
      mentorId: json['mentorId'],
      title: json['title'],
      category: json['category'] ?? 'General',
      content: json['content'],
      filePath: json['filePath'],
      fileData: json['fileData'],
      postTestQuizId: json['postTestQuizId'],
      isExclusive: (() {
        final raw = json['isExclusive'];
        if (raw is bool) return raw;
        if (raw is int) return raw == 1;
        if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
        return false;
      })(),
      createdAt: json['createdAt'],
    );
  }

  MaterialModel copyWith({
    int? id,
    int? mentorId,
    String? title,
    String? category,
    String? content,
    String? filePath,
    String? fileData,
    int? postTestQuizId,
    bool? isExclusive,
    String? createdAt,
  }) {
    return MaterialModel(
      id: id ?? this.id,
      mentorId: mentorId ?? this.mentorId,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      fileData: fileData ?? this.fileData,
      postTestQuizId: postTestQuizId ?? this.postTestQuizId,
      isExclusive: isExclusive ?? this.isExclusive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
