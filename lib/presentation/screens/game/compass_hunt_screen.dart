import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CompassHuntScreen extends StatefulWidget {
  const CompassHuntScreen({super.key});

  @override
  State<CompassHuntScreen> createState() => _CompassHuntScreenState();
}

class _CompassHuntScreenState extends State<CompassHuntScreen>
    with SingleTickerProviderStateMixin {
  static const double _goal = 100;
  static const int _roundSeconds = 20;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  Timer? _timer;
  late final AnimationController _spinController;

  double _energy = 0;
  double _spinVelocity = 0;
  int _secondsLeft = _roundSeconds;
  int _bestScore = 0;
  bool _running = false;
  bool _finished = false;
  String _sensorMode = 'Gyroscope';

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _startSensor();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _accelerometerSub?.cancel();
    _timer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _startSensor() {
    _gyroSub = gyroscopeEvents.listen(
      (event) {
        final movement = (event.x.abs() + event.y.abs() + event.z.abs()).clamp(
          0,
          18,
        );
        _addSpin(movement * 0.95, mode: 'Gyroscope');
      },
      onError: (_) => _startAccelerometerFallback(),
      cancelOnError: true,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _spinVelocity > 0 || _accelerometerSub != null) return;
      _startAccelerometerFallback();
    });
  }

  void _startAccelerometerFallback() {
    _gyroSub?.cancel();
    _accelerometerSub ??= accelerometerEvents.listen((event) {
      final movement = (event.x.abs() + event.y.abs() + (event.z - 9.8).abs())
          .clamp(0, 18);
      _addSpin(movement * 0.55, mode: 'Accelerometer');
    });
  }

  void _startGame() {
    setState(() {
      _energy = 0;
      _spinVelocity = 0;
      _secondsLeft = _roundSeconds;
      _running = true;
      _finished = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        _spinVelocity *= 0.72;
      });
      if (_secondsLeft <= 0 || _energy >= _goal) {
        _finishGame();
      }
    });
  }

  void _finishGame() {
    _timer?.cancel();
    final score = (_energy * 10).round();
    setState(() {
      _running = false;
      _finished = true;
      _bestScore = max(_bestScore, score);
    });
  }

  void _addSpin(num movement, {required String mode}) {
    if (!mounted) return;
    setState(() {
      _sensorMode = mode;
      _spinVelocity = (_spinVelocity + movement.toDouble()).clamp(0, 48);
      if (_running) {
        _energy = (_energy + movement * 0.18).clamp(0, _goal);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _energy / _goal;
    final currentScore = (_energy * 10).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Spin Rush')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(label: 'Waktu', value: '${_secondsLeft}s'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'Skor', value: '$currentScore'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'Best', value: '$_bestScore'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, child) {
                    final turns =
                        _spinController.value * (1 + _spinVelocity / 8);
                    return Transform.rotate(
                      angle: turns * 2 * pi,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: const [
                          Color(0xFF2563EB),
                          Color(0xFF22C55E),
                          Color(0xFFF97316),
                          Color(0xFF2563EB),
                        ],
                        stops: [0, progress.clamp(0.15, 0.55), 0.82, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sync,
                          size: 42,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 12),
            Text(
              _running
                  ? 'Putar atau goyangkan HP untuk mengisi energi spin.'
                  : _finished
                  ? 'Selesai. Main lagi untuk kalahkan skor terbaik.'
                  : 'Game refreshing: kumpulkan energi spin dalam 20 detik.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              'Sensor aktif: $_sensorMode',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _running ? null : _startGame,
              icon: const Icon(Icons.play_arrow),
              label: Text(_finished ? 'Main Lagi' : 'Mulai Spin Rush'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
