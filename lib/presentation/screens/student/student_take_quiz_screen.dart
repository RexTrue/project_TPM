import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../data/models/quiz_question_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/score_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/custom_widgets.dart';

class StudentTakeQuizScreen extends StatefulWidget {
  final int quizId;
  const StudentTakeQuizScreen({super.key, required this.quizId});

  @override
  State<StudentTakeQuizScreen> createState() => _StudentTakeQuizScreenState();
}

class _StudentTakeQuizScreenState extends State<StudentTakeQuizScreen>
    with SingleTickerProviderStateMixin {
  static const int _laneCount = 4;
  late final Future<List<QuizQuestionModel>> _questionsFuture;
  late final AnimationController _runner;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  final _essayController = TextEditingController();

  List<QuizQuestionModel> _questions = [];
  List<String> _laneAnswers = [];
  final Map<int, String> _answers = {};
  double _runnerPosition = 1.5;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _resolvingGate = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final student = Provider.of<StudentProvider>(context, listen: false);
    _questionsFuture = student.getQuizQuestions(widget.quizId);
    _runner =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2400),
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _resolveGate();
            }
          });

    _accelerometerSub = accelerometerEvents.listen((event) {
      if (_resolvingGate || _questions.isEmpty) return;
      if (_isEssay(_questions[_currentIndex])) return;
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
    _essayController.dispose();
    super.dispose();
  }

  bool _isEssay(QuizQuestionModel question) => question.type == 'essay';

  List<String> _decodeOptions(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {}
    return raw.split('|').where((item) => item.trim().isNotEmpty).toList();
  }

  List<String> _rubricKeywords(String rubric) {
    return rubric
        .split(RegExp(r'[,;\n]| dan '))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.length >= 2)
        .toList();
  }

  int _gradeEssayPercent(String answer, String rubric) {
    final keywords = _rubricKeywords(rubric);
    if (keywords.isEmpty) {
      return answer.trim().length >= 10 ? 100 : 0;
    }
    final normalized = answer.toLowerCase();
    final matched = keywords.where((k) => normalized.contains(k)).length;
    return ((matched / keywords.length) * 100).round();
  }

  void _prepareLaneAnswers() {
    if (_questions.isEmpty) return;
    final question = _questions[_currentIndex];
    if (_isEssay(question)) return;

    final options = _decodeOptions(question.options);
    final shuffled = List<String>.from(options)..shuffle();
    while (shuffled.length < _laneCount) {
      shuffled.add(question.correctAnswer);
    }
    _laneAnswers = shuffled.take(_laneCount).toList();
    if (!_laneAnswers.contains(question.correctAnswer)) {
      _laneAnswers[Random().nextInt(_laneCount)] = question.correctAnswer;
    }
  }

  int _selectedLane() {
    final rounded = _runnerPosition.round();
    if (rounded < 0) return 0;
    if (rounded >= _laneCount) return _laneCount - 1;
    return rounded;
  }

  Future<void> _advanceToNextQuestion() async {
    final isLast = _currentIndex == _questions.length - 1;
    if (isLast) {
      await _submit();
      return;
    }

    setState(() {
      _currentIndex++;
      _runnerPosition = 1.5;
      _resolvingGate = false;
      _prepareLaneAnswers();
    });

    if (!_isEssay(_questions[_currentIndex])) {
      _runner.forward(from: 0);
    }
  }

  Future<void> _resolveGate() async {
    if (_resolvingGate || _submitted) return;
    if (_isEssay(_questions[_currentIndex])) return;
    _resolvingGate = true;
    _runner.stop();

    final question = _questions[_currentIndex];
    final key = question.id ?? question.hashCode;
    final selectedLane = _selectedLane();
    final chosen = _laneAnswers[selectedLane];
    _answers[key] = chosen;
    if (chosen == question.correctAnswer) _correctCount++;

    setState(() {});
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await _advanceToNextQuestion();
  }

  Future<void> _submitEssayAnswer() async {
    if (_resolvingGate || _submitted) return;
    final text = _essayController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan tulis jawaban essay Anda')),
      );
      return;
    }

    _resolvingGate = true;
    final question = _questions[_currentIndex];
    final key = question.id ?? question.hashCode;
    _answers[key] = text;

    final percent = _gradeEssayPercent(text, question.correctAnswer);
    if (percent >= 50) _correctCount++;

    _essayController.clear();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _advanceToNextQuestion();
  }

  int _score100() {
    if (_questions.isEmpty) return 0;
    return ((_correctCount / _questions.length) * 100).round();
  }

  Future<void> _submit() async {
    if (_submitted) return;
    _submitted = true;
    final auth = context.read<AuthProvider>();
    final studentId = auth.currentUser?.id;
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    final score = _score100();
    final student = context.read<StudentProvider>();
    final scoreProvider = context.read<ScoreProvider>();
    final navigator = Navigator.of(context);

    await student.submitQuiz(
      studentId,
      widget.quizId,
      _answers.map((key, value) => MapEntry(key.toString(), value)),
      score,
    );
    await scoreProvider.saveScore(studentId, score, 100, 'Sensor Quiz');
    await auth.addXp(score);

    final unlocked = await context.read<BadgeProvider>().checkAndUnlock(
      userId: studentId,
      quizCompleted: true,
      quizScore: score,
      xp: auth.currentUser?.xp,
      level: auth.currentUser?.level,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Quiz selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skor: $score/100'),
            if (unlocked.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Badge baru: ${unlocked.join(', ')}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              navigator.pop();
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _startIfNeeded(List<QuizQuestionModel> questions) {
    if (_questions.isNotEmpty) return;
    _questions = questions;
    _prepareLaneAnswers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isEssay(_questions[_currentIndex])) {
        _runner.forward(from: 0);
      }
    });
  }

  Widget _buildEssayView(QuizQuestionModel question, int score) {
    final keywords = _rubricKeywords(question.correctAnswer);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Soal ${_currentIndex + 1}/${_questions.length}'),
              Text(
                '$score/100',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rubrik penilaian:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              keywords.isEmpty
                  ? question.correctAnswer
                  : keywords.map((k) => '• $k').join('\n'),
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Tulis jawaban essay Anda...',
            controller: _essayController,
            maxLines: 8,
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: _currentIndex == _questions.length - 1
                ? 'Kirim Jawaban'
                : 'Lanjut',
            onPressed: _resolvingGate ? () {} : _submitEssayAnswer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kerjakan Quiz')),
      body: FutureBuilder<List<QuizQuestionModel>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return const Center(child: Text('Tidak ada pertanyaan'));
          }
          _startIfNeeded(questions);

          final question = _questions[_currentIndex];
          final score = _score100();

          if (_isEssay(question)) {
            return _buildEssayView(question, score);
          }

          final gateProgress = Curves.easeIn.transform(_runner.value);
          final selectedLane = _selectedLane();

          return Container(
            color: const Color(0xFF111827),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Soal ${_currentIndex + 1}/${_questions.length}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              '$score/100',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.questionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gerakkan ponsel kiri/kanan untuk menggeser pelari menuju jawaban.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final laneWidth = constraints.maxWidth / _laneCount;
                        final gateTop =
                            18 + gateProgress * (constraints.maxHeight - 176);
                        final runnerLeft =
                            laneWidth * _runnerPosition + (laneWidth - 58) / 2;

                        return Stack(
                          children: [
                            Row(
                              children: List.generate(_laneCount, (index) {
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: index == selectedLane
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.white.withValues(
                                              alpha: 0.04,
                                            ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
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
                                  final correct =
                                      answer == question.correctAnswer;
                                  return Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      height: 112,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                              bottom: 38,
                              child: Column(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF38BDF8),
                                    ),
                                    child: const Icon(
                                      Icons.directions_run,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Runner',
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
          );
        },
      ),
    );
  }
}
