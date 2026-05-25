import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigation/navigation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mentor_provider.dart';

class MentorMaterialsScreen extends StatefulWidget {
  const MentorMaterialsScreen({super.key});

  @override
  State<MentorMaterialsScreen> createState() => _MentorMaterialsScreenState();
}

class _MentorMaterialsScreenState extends State<MentorMaterialsScreen> {
  Future<void> _openEditor({int? materialId}) async {
    final updated = await Navigator.pushNamed(
      context,
      AppNavigation.mentorUpload,
      arguments: materialId == null ? null : {'materialId': materialId},
    );
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentorId = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materi Saya'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah materi',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Materi'),
      ),
      body: mentorId == null
          ? const Center(child: Text('User mentor tidak ditemukan'))
          : FutureBuilder(
              future: context.read<MentorProvider>().getMaterialsByMentor(
                mentorId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final materials = snapshot.data ?? [];
                if (materials.isEmpty) {
                  return const Center(
                    child: Text('Belum ada materi yang diupload.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    final material = materials[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          material.isExclusive
                              ? Icons.workspace_premium
                              : Icons.menu_book,
                        ),
                        title: Text(material.title),
                        subtitle: Text(
                          '${material.category}${material.postTestQuizId != null ? ' - ada post test' : ''}',
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _openEditor(materialId: material.id),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
