import 'user_model.dart';

class MentorLeaderboardEntry {
  final UserModel mentor;
  final int followerCount;

  const MentorLeaderboardEntry({
    required this.mentor,
    required this.followerCount,
  });
}
