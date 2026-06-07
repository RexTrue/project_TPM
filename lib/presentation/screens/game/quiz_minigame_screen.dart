import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/score_provider.dart';

class QuizMinigameScreen extends StatefulWidget {
  const QuizMinigameScreen({super.key});

  @override
  State<QuizMinigameScreen> createState() => _QuizMinigameScreenState();
}

class _QuizMinigameScreenState extends State<QuizMinigameScreen>
    with SingleTickerProviderStateMixin {
  static const int _laneCount = 4;
  late final AnimationController _runner;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  double _runnerPosition = 1.5;
  int _currentIndex = 0;
  int _score = 0;
  bool _resolvingGate = false;
  List<String> _laneAnswers = [];

  @override
  void initState() {
    super.initState();
    _runner =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2300),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _resolveGate();
            }
          })
          ..addListener(() {
            if (mounted) setState(() {});
          });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<QuestionProvider>();
      await provider.prepareQuiz(
        category: 'General',
        difficulty: 'Easy',
        limit: 6,
      );
      if (!mounted) return;
      _prepareLaneAnswers();
      _runner.forward(from: 0);
    });

    _accelerometerSub = accelerometerEvents.listen((event) {
      if (_resolvingGate) return;
      final tilt = event.x.abs() < 0.35 ? 0.0 : -event.x * 0.045;
      if (tilt == 0.0) return;
      final next = (_runnerPosition + tilt)
          .clamp(0.0, (_laneCount - 1).toDouble())
          .toDouble();
      if ((next - _runnerPosition).abs() > 0.01) {
        setState(() => _runnerPosition = next);
      }
    });
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _runner.dispose();
    super.dispose();
  }

  void _prepareLaneAnswers() {
    final provider = context.read<QuestionProvider>();
    if (provider.currentQuestions.isEmpty) return;
    final q = provider.currentQuestions[_currentIndex];
    final options = List<String>.from(q.options)..shuffle();
    while (options.length < _laneCount) {
      options.add(q.correctAnswer);
    }
    _laneAnswers = options.take(_laneCount).toList();
    if (!_laneAnswers.contains(q.correctAnswer)) {
      _laneAnswers[Random().nextInt(_laneCount)] = q.correctAnswer;
    }
  }

  int _selectedLane() {
    final rounded = _runnerPosition.round();
    if (rounded < 0) return 0;
    if (rounded >= _laneCount) return _laneCount - 1;
    return rounded;
  }

  Future<void> _resolveGate() async {
    if (_resolvingGate) return;
    _resolvingGate = true;
    _runner.stop();

    final provider = context.read<QuestionProvider>();
    final questions = provider.currentQuestions;
    if (questions.isEmpty) return;

    final q = questions[_currentIndex];
    final selectedLane = _selectedLane();
    final chosen = _laneAnswers[selectedLane];
    final correct = chosen == q.correctAnswer;
    if (correct) _score++;

    setState(() {});
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final isLast = _currentIndex == questions.length - 1;
    if (isLast) {
      await _finish(questions.length);
      return;
    }

    setState(() {
      _currentIndex++;
      _runnerPosition = 1.5;
      _resolvingGate = false;
      _prepareLaneAnswers();
    });
    _runner.forward(from: 0);
  }

  Future<void> _finish(int total) async {
    final score100 = total == 0 ? 0 : ((_score / total) * 100).round();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      final locationProvider = context.read<LocationProvider>();
      await context.read<ScoreProvider>().saveScore(
        auth.currentUser!.id ?? 0,
        score100,
        100,
        'Quiz Runner',
      );
      await auth.addXp(score100);
      await locationProvider.fetchLocation(
        userId: auth.currentUser!.id,
        userName: auth.currentUser!.username,
        points: auth.currentUser!.xp,
      );
      await context.read<BadgeProvider>().checkAndUnlock(
        userId: auth.currentUser!.id!,
        gamePlayed: true,
        xp: auth.currentUser!.xp,
        level: auth.currentUser!.level,
      );
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Finish'),
        content: Text('Skor kamu: $score100 / 100'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionProvider>();
    if (provider.isLoading || provider.currentQuestions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = provider.currentQuestions[_currentIndex];
    final gateProgress = Curves.easeIn.transform(_runner.value);
    final selectedLane = _selectedLane();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Runner'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFF111827),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Soal ${_currentIndex + 1}/${provider.currentQuestions.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Skor: $_score',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final laneWidth = constraints.maxWidth / _laneCount;
                    final gateTop =
                        24 + gateProgress * (constraints.maxHeight - 170);
                    final runnerLeft =
                        laneWidth * _runnerPosition + (laneWidth - 54) / 2;

                    return Stack(
                      children: [
                        Row(
                          children: List.generate(_laneCount, (index) {
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: index == selectedLane
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        Positioned(
                          top: gateTop,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: List.generate(_laneCount, (index) {
                              final selected =
                                  _resolvingGate && index == selectedLane;
                              final answer = _laneAnswers[index];
                              final correct = answer == q.correctAnswer;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 110,
                                  margin: const EdgeInsets.all(6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (correct
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626))
                                        : const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: index == selectedLane
                                          ? const Color(0xFFFACC15)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.stop_circle,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFFDC2626),
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        answer,
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: selected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Positioned(
                          left: runnerLeft,
                          bottom: 40,
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF38BDF8),
                                ),
                                child: const Icon(
                                  Icons.directions_run,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tilt HP',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
