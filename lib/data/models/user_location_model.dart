/// Snapshot lokasi user untuk leaderboard map
class UserLocationModel {
  final int? id;
  final int userId;
  final String userName;
  final double latitude;
  final double longitude;
  final String locationName;
  final int points;
  final String? timestamp;

  UserLocationModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.points,
    this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'points': points,
      'timestamp': timestamp,
    };
  }

  /// Data untuk insert database tanpa field auto-increment.
  Map<String, dynamic> toInsertMap() {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'points': points,
      'timestamp': timestamp,
    };
  }

  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    return UserLocationModel(
      id: json['id'],
      userId: json['userId'] ?? 0,
      userName: json['userName']?.toString() ?? 'Unknown',
      latitude: _readCoordinate(json['latitude']),
      longitude: _readCoordinate(json['longitude']),
      locationName: json['locationName']?.toString() ?? 'Unknown area',
      points: (json['points'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp']?.toString(),
    );
  }

  static double _readCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  UserLocationModel copyWith({
    int? id,
    int? userId,
    String? userName,
    double? latitude,
    double? longitude,
    String? locationName,
    int? points,
    String? timestamp,
  }) {
    return UserLocationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      points: points ?? this.points,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
