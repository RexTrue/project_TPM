import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../navigation/navigation.dart';
import '../../widgets/custom_widgets.dart';
import 'edit_profile_screen.dart';

/// Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBadges());
  }

  Future<void> _loadBadges() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    await context.read<BadgeProvider>().loadBadges(userId);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final badgeProvider = context.watch<BadgeProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      child: ProfileAvatar(photo: user?.photo, radius: 50),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.username ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((user?.about ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user!.about!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: 'Level', value: '${user?.level ?? 1}'),
                    _StatItem(label: 'XP', value: '${user?.xp ?? 0}'),
                    _StatItem(
                      label: 'Badges',
                      value: '${badgeProvider.badgeCount}',
                      onTap: () =>
                          Navigator.pushNamed(context, AppNavigation.badges),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _MenuTile(
                icon: Icons.edit,
                title: 'Edit Profile',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.editProfile),
              ),
              _MenuTile(
                icon: Icons.emoji_events,
                title: 'Badge Saya',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.badges),
              ),
              _MenuTile(
                icon: Icons.show_chart,
                title: 'Statistics',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppNavigation.statistics,
                  arguments: {'userId': user?.id},
                ),
              ),
              _MenuTile(
                icon: Icons.settings,
                title: 'Settings',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.settings),
              ),
              _MenuTile(
                icon: Icons.card_membership,
                title: 'Membership',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.membership),
              ),
              _MenuTile(
                icon: Icons.videogame_asset,
                title: 'Minigame Quiz',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.quizMinigame),
              ),
              _MenuTile(
                icon: Icons.help,
                title: 'Help & Support',
                onTap: () =>
                    Navigator.pushNamed(context, AppNavigation.helpSupport),
              ),
              _MenuTile(
                icon: Icons.info,
                title: 'About',
                onTap: () => Navigator.pushNamed(context, AppNavigation.about),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Logout',
                backgroundColor: Colors.red,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            authProvider.logout();
                            Navigator.pushReplacementNamed(
                              context,
                              AppNavigation.login,
                            );
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatItem({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6366F1)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
