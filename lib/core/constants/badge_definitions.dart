/// Definisi badge yang dapat di-unlock pengguna.
class BadgeDefinition {
  final String id;
  final String name;
  final String icon;
  final String description;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}

const List<BadgeDefinition> kBadgeDefinitions = [
  BadgeDefinition(
    id: 'first_quiz',
    name: 'Pemula Quiz',
    icon: '🎯',
    description: 'Selesaikan quiz pertama',
  ),
  BadgeDefinition(
    id: 'quiz_master',
    name: 'Master Quiz',
    icon: '🏆',
    description: 'Raih skor 80+ pada quiz',
  ),
  BadgeDefinition(
    id: 'perfect_score',
    name: 'Sempurna',
    icon: '💯',
    description: 'Raih skor 100 pada quiz',
  ),
  BadgeDefinition(
    id: 'game_player',
    name: 'Pemain Game',
    icon: '🎮',
    description: 'Mainkan minigame',
  ),
  BadgeDefinition(
    id: 'xp_hunter',
    name: 'Pemburu XP',
    icon: '⚡',
    description: 'Kumpulkan minimal 100 XP',
  ),
  BadgeDefinition(
    id: 'level_5',
    name: 'Naik Level',
    icon: '🌟',
    description: 'Capai level 5',
  ),
  BadgeDefinition(
    id: 'feedback_giver',
    name: 'Kontributor',
    icon: '💬',
    description: 'Kirim masukan ke EduFun',
  ),
];

BadgeDefinition? findBadgeDefinition(String id) {
  for (final badge in kBadgeDefinitions) {
    if (badge.id == id) return badge;
  }
  return null;
}
