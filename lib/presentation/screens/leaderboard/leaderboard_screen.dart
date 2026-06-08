import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/map_utils.dart';
import '../../../data/models/mentor_leaderboard_entry.dart';
import '../../../data/models/user_location_model.dart';
import '../../../data/models/user_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/custom_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<_LeaderboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_LeaderboardData> _loadData() async {
    final provider = context.read<StudentProvider>();
    final locationProvider = context.read<LocationProvider>();
    final students = await provider.getStudentLevelLeaderboard();
    final mentors = await provider.getMentorLeaderboard();
    await locationProvider.loadLeaderboardSnapshots();
    return _LeaderboardData(
      students: students,
      mentors: mentors,
      locations: filterValidLocations(locationProvider.leaderboardSnapshots),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _refreshMapWithLocation() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user?.id != null) {
      await context.read<LocationProvider>().fetchLocation(
        userId: user!.id,
        userName: user.username,
        points: user.xp,
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Student Level'),
              Tab(text: 'Mentor'),
              Tab(text: 'Peta LBS'),
            ],
          ),
        ),
        body: FutureBuilder<_LeaderboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingIndicator();
            }

            final data =
                snapshot.data ??
                const _LeaderboardData(
                  students: [],
                  mentors: [],
                  locations: [],
                );
            return TabBarView(
              children: [
                _StudentLevelLeaderboard(
                  students: data.students,
                  onRefresh: _refresh,
                ),
                _MentorLeaderboard(mentors: data.mentors, onRefresh: _refresh),
                _LocationLeaderboardMap(
                  locations: data.locations,
                  onRefresh: _refreshMapWithLocation,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LocationLeaderboardMap extends StatefulWidget {
  final List<UserLocationModel> locations;
  final Future<void> Function() onRefresh;

  const _LocationLeaderboardMap({
    required this.locations,
    required this.onRefresh,
  });

  @override
  State<_LocationLeaderboardMap> createState() =>
      _LocationLeaderboardMapState();
}

class _LocationLeaderboardMapState extends State<_LocationLeaderboardMap>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fitMapToLocations(widget.locations);
  }

  @override
  void didUpdateWidget(covariant _LocationLeaderboardMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations != widget.locations) {
      _fitMapToLocations(widget.locations);
    }
  }

  void _fitMapToLocations(List<UserLocationModel> locations) {
    final valid = filterValidLocations(locations);
    if (valid.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (valid.length == 1) {
          _mapController.move(
            LatLng(valid.first.latitude, valid.first.longitude),
            12,
          );
          return;
        }

        final bounds = LatLngBounds.fromPoints(
          valid.map((item) => LatLng(item.latitude, item.longitude)).toList(),
        );
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
        );
      } catch (_) {
        // Abaikan error fit kamera agar peta tetap tampil.
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locations = filterValidLocations(widget.locations);
    final center = resolveMapCenter(locations);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height - 160,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: locations.isEmpty ? 5 : 10,
                    minZoom: 3,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tugas_akhir_mobile',
                      maxNativeZoom: 19,
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint(
                          '[LeaderboardMap] Tile error z=${tile.coordinates.z}: $error',
                        );
                      },
                    ),
                    MarkerLayer(
                      markers: locations.map((location) {
                        return Marker(
                          point: LatLng(
                            location.latitude,
                            location.longitude,
                          ),
                          width: 96,
                          height: 68,
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            onTap: () => _showLocation(context, location),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFDC2626),
                                  size: 36,
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 96,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    location.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'Lokasi ditampilkan sebagai area perkiraan untuk menjaga privasi.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        if (locations.isEmpty)
          Positioned(
            top: 72,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Belum ada lokasi user. Tekan tombol di bawah untuk mengambil lokasi Anda.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _isRefreshing ? null : _handleRefresh,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Ambil Lokasi Saya'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'leaderboard_map_refresh',
            onPressed: _isRefreshing ? null : _handleRefresh,
            child: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  void _showLocation(BuildContext context, UserLocationModel location) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${location.userName} - ${location.locationName} - ${location.points} XP',
        ),
      ),
    );
  }
}

class _StudentLevelLeaderboard extends StatelessWidget {
  final List<UserModel> students;
  final Future<void> Function() onRefresh;

  const _StudentLevelLeaderboard({
    required this.students,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Belum ada student di leaderboard.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final rank = index + 1;
          return Card(
            child: ListTile(
              leading: _RankBadge(rank: rank),
              title: Text(student.username),
              subtitle: Text('Level ${student.level}'),
              trailing: Text(
                '${student.xp} XP',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MentorLeaderboard extends StatelessWidget {
  final List<MentorLeaderboardEntry> mentors;
  final Future<void> Function() onRefresh;

  const _MentorLeaderboard({required this.mentors, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (mentors.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Belum ada mentor di leaderboard.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mentors.length,
        itemBuilder: (context, index) {
          final entry = mentors[index];
          final mentor = entry.mentor;
          final rank = index + 1;
          return Card(
            child: ListTile(
              leading: _RankBadge(rank: rank),
              title: Text(mentor.username),
              subtitle: Text('Level ${mentor.level} - ${mentor.xp} XP'),
              trailing: Text(
                '${entry.followerCount} pengikut',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: mentor.id == null
                  ? null
                  : () => Navigator.pushNamed(
                      context,
                      AppNavigation.mentorProfile,
                      arguments: {'mentorId': mentor.id},
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: switch (rank) {
        1 => const Color(0xFFFDE68A),
        2 => const Color(0xFFE5E7EB),
        3 => const Color(0xFFFED7AA),
        _ => const Color(0xFFE0F2FE),
      },
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LeaderboardData {
  final List<UserModel> students;
  final List<MentorLeaderboardEntry> mentors;
  final List<UserLocationModel> locations;

  const _LeaderboardData({
    required this.students,
    required this.mentors,
    required this.locations,
  });
}
