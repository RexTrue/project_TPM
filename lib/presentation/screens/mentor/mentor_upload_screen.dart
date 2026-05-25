import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/mentor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../notifications/notification_service.dart';
import '../../../core/services/material_parser_service.dart';
import '../../../data/models/material_model.dart';
import '../../../data/models/quiz_question_model.dart';

class MentorUploadScreen extends StatefulWidget {
  const MentorUploadScreen({super.key});

  @override
  State<MentorUploadScreen> createState() => _MentorUploadScreenState();
}

class _MentorUploadScreenState extends State<MentorUploadScreen> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  final _contentController = TextEditingController();
  final _postQuestionController = TextEditingController();
  final _postEssayAnswerController = TextEditingController();
  final List<TextEditingController> _postOptionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _parserService = MaterialParserService();

  String? _selectedFileName;
  String? _selectedFileData;
  MaterialModel? _editingMaterial;
  bool _isParsingFile = false;
  bool _isExclusive = false;
  bool _addPostTest = false;
  String _postQuestionType = 'multiple_choice';
  int? _postCorrectIndex;
  final List<QuizQuestionModel> _postQuestions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _contentController.dispose();
    _postQuestionController.dispose();
    _postEssayAnswerController.dispose();
    for (final controller in _postOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditingMaterial());
  }

  Future<void> _loadEditingMaterial() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final materialId = args?['materialId'] as int?;
    if (materialId == null) return;
    final material = await context.read<MentorProvider>().getMaterialById(
      materialId,
    );
    if (!mounted || material == null) return;
    setState(() {
      _editingMaterial = material;
      _titleController.text = material.title;
      _categoryController.text = material.category;
      _contentController.text = material.content ?? '';
      _selectedFileName = material.filePath;
      _selectedFileData = material.fileData;
      _isExclusive = material.isExclusive;
      _addPostTest = material.postTestQuizId != null;
    });
  }

  List<QuizQuestionModel>? _buildPostTestQuestions() {
    if (!_addPostTest) return null;
    return _postQuestions.isEmpty
        ? null
        : List<QuizQuestionModel>.from(_postQuestions);
  }

  void _addPostQuestion() {
    final question = _postQuestionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pertanyaan post test tidak boleh kosong'),
        ),
      );
      return;
    }

    if (_postQuestionType == 'essay') {
      final rubric = _postEssayAnswerController.text.trim();
      if (rubric.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rubrik essay tidak boleh kosong')),
        );
        return;
      }
      setState(() {
        _postQuestions.add(
          QuizQuestionModel(
            quizId: 0,
            questionText: question,
            type: 'essay',
            options: '[]',
            correctAnswer: rubric,
          ),
        );
      });
      _resetPostQuestionForm();
      return;
    }

    final options = _postOptionControllers.map((c) => c.text.trim()).toList();
    if (options.any((option) => option.isEmpty) || _postCorrectIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi opsi dan jawaban benar')),
      );
      return;
    }
    setState(() {
      _postQuestions.add(
        QuizQuestionModel(
          quizId: 0,
          questionText: question,
          type: 'multiple_choice',
          options: jsonEncode(options),
          correctAnswer: options[_postCorrectIndex!],
        ),
      );
    });
    _resetPostQuestionForm();
  }

  void _resetPostQuestionForm() {
    _postQuestionController.clear();
    _postEssayAnswerController.clear();
    for (final controller in _postOptionControllers) {
      controller.clear();
    }
    setState(() {
      _postCorrectIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mentor = Provider.of<MentorProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    if (auth.currentUser?.role != 'mentor') {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Materi')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Akses ditolak. Hanya mentor dapat mengupload materi.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingMaterial == null ? 'Upload Materi' : 'Edit Materi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  hintText: 'Contoh: Matematika, IPA, Bahasa',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Konten manual',
                  hintText:
                      'Opsional: isi manual materi jika tidak mengunggah file',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isParsingFile
                          ? null
                          : () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: const [
                                      'pdf',
                                      'pptx',
                                      'ppt',
                                    ],
                                    withData: true,
                                  );
                              if (result == null || result.files.isEmpty) {
                                return;
                              }

                              final file = result.files.first;
                              final bytes = file.bytes;
                              if (bytes == null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'File tidak bisa dibaca di perangkat ini.',
                                      ),
                                    ),
                                  );
                                });
                                return;
                              }

                              setState(() {
                                _isParsingFile = true;
                                _selectedFileName = file.name;
                                _selectedFileData = base64Encode(bytes);
                              });

                              final extracted = await _parserService
                                  .extractText(
                                    bytes: bytes,
                                    fileName: file.name,
                                  );

                              if (!mounted) return;

                              if (extracted.isNotEmpty) {
                                _contentController.text = extracted;
                              }

                              setState(() {
                                _isParsingFile = false;
                              });

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      extracted.isNotEmpty
                                          ? 'Isi file berhasil diekstrak ke konten materi.'
                                          : 'File dipilih, tetapi isi teks tidak ditemukan. Kamu masih bisa isi manual.',
                                    ),
                                  ),
                                );
                              });
                            },
                      icon: _isParsingFile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _selectedFileName == null
                            ? 'Pilih PDF / PPTX / PPT'
                            : 'File: $_selectedFileName',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedFileName != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedFileName!,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isExclusive,
                onChanged: (value) => setState(() => _isExclusive = value),
                title: const Text('Materi exclusive'),
                subtitle: const Text(
                  'Hanya student yang join membership mentor ini bisa membuka materi.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _addPostTest,
                onChanged: (value) => setState(() => _addPostTest = value),
                title: const Text('Tambahkan post test'),
                subtitle: const Text(
                  'Post test akan muncul setelah student membuka materi.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (_addPostTest) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _postQuestionType == 'multiple_choice',
                        label: const Text('Pilihan Ganda'),
                        onSelected: (_) {
                          setState(() => _postQuestionType = 'multiple_choice');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: _postQuestionType == 'essay',
                        label: const Text('Essay'),
                        onSelected: (_) {
                          setState(() => _postQuestionType = 'essay');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _postQuestionController,
                  decoration: const InputDecoration(
                    labelText: 'Pertanyaan post test',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (_postQuestionType == 'multiple_choice') ...[
                  ...List.generate(4, (index) {
                    final labels = ['A', 'B', 'C', 'D'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _postOptionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Opsi ${labels[index]}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }),
                  DropdownButtonFormField<int>(
                    initialValue: _postCorrectIndex,
                    decoration: const InputDecoration(
                      labelText: 'Jawaban benar',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      4,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text('Opsi ${['A', 'B', 'C', 'D'][index]}'),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _postCorrectIndex = value),
                  ),
                ] else
                  TextField(
                    controller: _postEssayAnswerController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Rubrik / model jawaban',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addPostQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Pertanyaan Post Test'),
                ),
                if (_postQuestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._postQuestions.asMap().entries.map(
                    (entry) => Card(
                      child: ListTile(
                        title: Text(entry.value.questionText),
                        subtitle: Text(
                          entry.value.type == 'essay'
                              ? 'Essay'
                              : 'Pilihan ganda',
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() => _postQuestions.removeAt(entry.key));
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: mentor.isLoading
                    ? null
                    : () async {
                        // capture things synchronously to avoid using BuildContext across async gaps
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final notificationService = context
                            .read<NotificationService>();
                        final title = _titleController.text.trim();
                        final category = _categoryController.text.trim();
                        final content = _contentController.text.trim();
                        final mentorId = auth.currentUser?.id;

                        // Validation
                        if (mentorId == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error: User ID tidak ditemukan'),
                            ),
                          );
                          return;
                        }
                        if (title.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Judul tidak boleh kosong'),
                            ),
                          );
                          return;
                        }
                        if (category.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Kategori tidak boleh kosong'),
                            ),
                          );
                          return;
                        }
                        if (content.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Konten tidak boleh kosong'),
                            ),
                          );
                          return;
                        }

                        final postQuestions = _buildPostTestQuestions();
                        if (_addPostTest &&
                            postQuestions == null &&
                            _editingMaterial == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lengkapi data post test terlebih dahulu',
                              ),
                            ),
                          );
                          return;
                        }

                        final filePath = _selectedFileName;
                        final editing = _editingMaterial;
                        int? id;
                        if (editing == null) {
                          id = await mentor.uploadMaterial(
                            mentorId,
                            title,
                            content,
                            filePath,
                            category: category,
                            fileData: _selectedFileData,
                            isExclusive: _isExclusive,
                          );
                          if (id != null && postQuestions != null) {
                            await mentor.createQuiz(
                              mentorId,
                              'Post Test - $title',
                              postQuestions.any((q) => q.type == 'essay')
                                  ? 'mixed'
                                  : 'multiple_choice',
                              postQuestions,
                              materialId: id,
                            );
                          }
                        } else {
                          final updated = editing.copyWith(
                            title: title,
                            category: category,
                            content: content,
                            filePath: filePath,
                            fileData: _selectedFileData,
                            isExclusive: _isExclusive,
                          );
                          final ok = await mentor.updateMaterial(updated);
                          id = ok ? editing.id : null;
                          if (ok && postQuestions != null) {
                            await mentor.createQuiz(
                              mentorId,
                              'Post Test - $title',
                              postQuestions.any((q) => q.type == 'essay')
                                  ? 'mixed'
                                  : 'multiple_choice',
                              postQuestions,
                              materialId: editing.id,
                            );
                          }
                        }

                        if (id != null) {
                          await auth.checkLoginStatus();
                          if (editing == null) {
                            await notificationService.showAppNotification(
                              id: 310,
                              title: 'Materi baru diupload',
                              body: '$title tersedia untuk student.',
                            );
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                editing == null
                                    ? 'Materi berhasil diupload'
                                    : 'Materi berhasil diperbarui',
                              ),
                            ),
                          );
                          _titleController.clear();
                          _contentController.clear();
                          setState(() {
                            _selectedFileName = null;
                            _selectedFileData = null;
                            _postQuestionController.clear();
                            _postEssayAnswerController.clear();
                            _postQuestions.clear();
                            _resetPostQuestionForm();
                          });
                          if (editing != null && mounted) {
                            navigator.pop(true);
                          }
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                mentor.error ?? 'Gagal upload materi',
                              ),
                            ),
                          );
                        }
                      },
                child: mentor.isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _editingMaterial == null
                            ? 'Upload'
                            : 'Simpan Perubahan',
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
