import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../data/models/material_model.dart';
import '../../../data/models/chat_response_model.dart';
import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/student_provider.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  late Future<List<MaterialModel>> _materialsFuture;
  final _searchController = TextEditingController();
  List<MaterialModel> _allMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  Set<int> _memberMentorIds = {};
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _materialsFuture = _fetchMaterials();
    _loadMaterials();
  }

  Future<List<MaterialModel>> _fetchMaterials() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final student = Provider.of<StudentProvider>(context, listen: false);
    final studentId = auth.currentUser?.id;
    if (studentId == null) return [];
    final memberships = await auth.activeMentorMembershipsForCurrentUser();
    if (mounted) {
      setState(() => _memberMentorIds = memberships.keys.toSet());
    }
    return student.getMaterialsForStudent(studentId);
  }

  Future<void> _loadMaterials() async {
    final materials = await _materialsFuture;
    if (!mounted) return;
    setState(() {
      _allMaterials = materials;
      _filteredMaterials = materials;
    });
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredMaterials = _applyFilters(_allMaterials, q);
      } else {
        _filteredMaterials = _applyFilters(_allMaterials, q);
      }
    });
  }

  List<MaterialModel> _applyFilters(
    List<MaterialModel> materials,
    String query,
  ) {
    return materials.where((m) {
      final categoryMatch =
          _selectedCategory == 'Semua' || m.category == _selectedCategory;
      final title = m.title.toLowerCase();
      final content = (m.content ?? '').toLowerCase();
      final category = m.category.toLowerCase();
      final queryMatch =
          query.isEmpty ||
          title.contains(query) ||
          content.contains(query) ||
          category.contains(query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  List<String> get _categories {
    final categories =
        _allMaterials.map((material) => material.category).toSet().toList()
          ..sort();
    return ['Semua', ...categories];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMaterialDetail(MaterialModel material) {
    final locked =
        material.isExclusive && !_memberMentorIds.contains(material.mentorId);
    if (locked) {
      _showJoinMembership(material);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  material.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: 'Mentor #${material.mentorId}'),
                    _InfoChip(label: material.category),
                    if ((material.filePath ?? '').isNotEmpty)
                      _InfoChip(label: material.filePath!),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openMaterialChat(material),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Chat AI Materi'),
                    ),
                    if ((material.fileData ?? '').isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _downloadMaterial(material),
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: material.postTestQuizId == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                AppNavigation.studentTakeQuiz,
                                arguments: {'quizId': material.postTestQuizId},
                              );
                            },
                      icon: const Icon(Icons.quiz),
                      label: const Text('Lanjut Post Test'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  material.content ?? 'Tidak ada isi materi.',
                  style: const TextStyle(height: 1.6, fontSize: 15),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showJoinMembership(MaterialModel material) async {
    final updated = await Navigator.pushNamed(
      context,
      AppNavigation.mentorMembership,
      arguments: {
        'mentorId': material.mentorId,
        'mentorName': 'Mentor #${material.mentorId}',
      },
    );
    if (updated == true) {
      final materials = await _fetchMaterials();
      if (!mounted) return;
      setState(() {
        _allMaterials = materials;
        _filteredMaterials = _applyFilters(
          materials,
          _searchController.text.trim().toLowerCase(),
        );
      });
    }
  }

  Future<void> _downloadMaterial(MaterialModel material) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Download file belum tersedia di web.')),
      );
      return;
    }

    final raw = material.fileData;
    if (raw == null || raw.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('File materi tidak tersedia.')),
      );
      return;
    }

    try {
      final bytes = base64Decode(raw);
      final dir = await getApplicationDocumentsDirectory();
      final safeName = _safeFileName(
        material.filePath ?? '${material.title}.pdf',
      );
      final file = File(p.join(dir.path, safeName));
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PDF tersimpan: ${file.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal download materi: $e')),
      );
    }
  }

  void _openMaterialChat(MaterialModel material) {
    context.read<ChatProvider>().clearMessages();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MaterialChatSheet(material: material),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materi Student'),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppNavigation.mentorSearch),
            icon: const Icon(Icons.person_search),
            tooltip: 'Cari mentor',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final materials = await _fetchMaterials();
          if (!mounted) return;
          setState(() {
            _allMaterials = materials;
            _filteredMaterials = _applyFilters(
              materials,
              _searchController.text.trim().toLowerCase(),
            );
          });
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Materi ditampilkan dari mentor yang kamu ikuti.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppNavigation.mentorSearch),
              icon: const Icon(Icons.person_search),
              label: const Text('Cari dan Ikuti Mentor'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Cari materi...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_categories.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = category;
                        _filteredMaterials = _applyFilters(
                          _allMaterials,
                          _searchController.text.trim().toLowerCase(),
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (_allMaterials.isNotEmpty) ...[
              const Text(
                'Materi Terbaru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._applyFilters(
                    _allMaterials,
                    _searchController.text.trim().toLowerCase(),
                  )
                  .take(3)
                  .map(
                    (material) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        material.isExclusive
                            ? Icons.workspace_premium
                            : Icons.menu_book,
                      ),
                      title: Text(material.title),
                      subtitle: Text(material.category),
                      trailing: Icon(
                        material.isExclusive &&
                                !_memberMentorIds.contains(material.mentorId)
                            ? Icons.lock
                            : Icons.chevron_right,
                      ),
                      onTap: () => _openMaterialDetail(material),
                    ),
                  ),
              const Divider(height: 28),
            ],
            if (_filteredMaterials.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Belum ada materi. Ikuti mentor terlebih dahulu.',
                  ),
                ),
              )
            else
              ..._filteredMaterials.map(
                (material) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          (material.filePath ?? '').toLowerCase().endsWith(
                                '.pdf',
                              )
                              ? Icons.picture_as_pdf
                              : Icons.menu_book,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      title: Text(
                        material.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              children: [
                                Chip(
                                  label: Text(material.category),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (material.isExclusive)
                                  const Chip(
                                    label: Text('Exclusive'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            Text(
                              material.isExclusive &&
                                      !_memberMentorIds.contains(
                                        material.mentorId,
                                      )
                                  ? 'Join membership mentor untuk membuka materi ini.'
                                  : _previewText(material.content ?? ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      trailing: Icon(
                        material.isExclusive &&
                                !_memberMentorIds.contains(material.mentorId)
                            ? Icons.lock
                            : Icons.chevron_right,
                      ),
                      onTap: () => _openMaterialDetail(material),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _previewText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return 'Tidak ada ringkasan materi.';
    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 120)}...';
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.toLowerCase().endsWith('.pdf')) return sanitized;
    return '$sanitized.pdf';
  }
}

class _MaterialChatSheet extends StatefulWidget {
  final MaterialModel material;

  const _MaterialChatSheet({required this.material});

  @override
  State<_MaterialChatSheet> createState() => _MaterialChatSheetState();
}

class _MaterialChatSheetState extends State<_MaterialChatSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI Chat: ${widget.material.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  if (provider.messages.isEmpty) {
                    return const Center(
                      child: Text('Tanyakan isi materi ini ke AI.'),
                    );
                  }

                  return ListView(
                    children: provider.messages.map((message) {
                      final isUser = message['isUser'] as bool;
                      final refs =
                          (message['references'] as List?)
                              ?.cast<ChatReference>() ??
                          [];
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['text'] as String,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              if (refs.isNotEmpty && !isUser) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Sumber: ${refs.map((e) => e.title).join(', ')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Tanya materi ini...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    return IconButton.filled(
                      onPressed: provider.isLoading
                          ? null
                          : () {
                              final text = _controller.text.trim();
                              if (text.isEmpty) return;
                              provider.sendMaterialQuestion(
                                materialTitle: widget.material.title,
                                materialContent:
                                    widget.material.content ??
                                    'Tidak ada isi materi.',
                                question: text,
                              );
                              _controller.clear();
                            },
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFF8FAFC),
    );
  }
}
