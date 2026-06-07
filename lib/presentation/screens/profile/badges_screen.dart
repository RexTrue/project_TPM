import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/badge_definitions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../widgets/custom_widgets.dart';

/// Badges Screen
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
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
    final badgeProvider = context.watch<BadgeProvider>();
    final unlockedIds = badgeProvider.userBadges
        .map((badge) => badge.badgeName)
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Badge Saya'), elevation: 0),
      body: badgeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CustomCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Terbuka',
                          value: '${unlockedIds.length}',
                        ),
                        _SummaryItem(
                          label: 'Total',
                          value: '${kBadgeDefinitions.length}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...kBadgeDefinitions.map((definition) {
                    final unlocked = unlockedIds.contains(definition.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: unlocked
                              ? const Color(0xFF6366F1)
                              : Colors.grey.shade300,
                          child: Text(
                            definition.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        title: Text(
                          definition.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unlocked ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Text(definition.description),
                        trailing: Icon(
                          unlocked ? Icons.check_circle : Icons.lock,
                          color: unlocked ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
