import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../models/material_model.dart';

bool _useSupabaseGlobal() {
  try {
    return SupabaseService().isReady;
  } catch (_) {
    return false;
  }
}

class MaterialLocalDataSource {
  final DatabaseService _databaseService;

  MaterialLocalDataSource(this._databaseService);

  bool get _useSupabase => _useSupabaseGlobal();

  Future<int> createMaterial(MaterialModel material) async {
    try {
      // Validate input
      if (material.title.isEmpty) {
        throw Exception('Judul materi tidak boleh kosong');
      }
      if (material.mentorId <= 0) {
        throw Exception('Mentor ID tidak valid');
      }

      if (_useSupabase) {
        final client = Supabase.instance.client;
        final createdAt =
            material.createdAt ?? DateTime.now().toIso8601String();
        final insertData = {
          'mentorId': material.mentorId,
          'title': material.title,
          'category': material.category,
          'content': material.content ?? '',
          'filePath': material.filePath,
          'fileData': material.fileData,
          'postTestQuizId': material.postTestQuizId,
          'isExclusive': material.isExclusive ? 1 : 0,
          'createdAt': createdAt,
        };
        final inserted = await client
            .from('materials')
            .insert(insertData)
            .select()
            .maybeSingle();
        if (inserted != null && inserted['id'] != null) {
          return inserted['id'] as int;
        }
        throw Exception('Supabase insert returned null');
      }

      final count = await _databaseService.getRowCount('materials');
      if (count >= DatabaseService.maxMaterials) {
        throw Exception(
          'Batas materi sudah tercapai (max ${DatabaseService.maxMaterials})',
        );
      }

      final db = await _databaseService.database;
      final id = await db.insert('materials', {
        'mentorId': material.mentorId,
        'title': material.title,
        'category': material.category,
        'content': material.content ?? '',
        'filePath': material.filePath,
        'fileData': material.fileData,
        'postTestQuizId': material.postTestQuizId,
        'isExclusive': material.isExclusive ? 1 : 0,
        'createdAt': material.createdAt ?? DateTime.now().toIso8601String(),
      });
      return id;
    } catch (e) {
      // bubble up error for caller to handle; do not crash the app
      throw Exception('Gagal menyimpan materi: $e');
    }
  }

  Future<List<MaterialModel>> getAllMaterials() async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('materials')
            .select()
            .order('createdAt', ascending: false);
        if (rows == null) return [];
        final list = rows is List ? rows : [rows];
        return list
            .map(
              (r) => MaterialModel.fromJson((r as Map).cast<String, dynamic>()),
            )
            .toList();
      } catch (_) {
        // fallback to sqlite
      }
    }

    final db = await _databaseService.database;
    final rows = await db.query('materials', orderBy: 'createdAt DESC');
    return rows.map((r) => MaterialModel.fromJson(r)).toList();
  }

  Future<List<MaterialModel>> getMaterialsByMentor(int mentorId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('materials')
            .select()
            .eq('mentorId', mentorId);
        if (rows == null) return [];
        final list = rows is List ? rows : [rows];
        return list
            .map(
              (r) => MaterialModel.fromJson((r as Map).cast<String, dynamic>()),
            )
            .toList();
      } catch (_) {
        // fallback
      }
    }

    final db = await _databaseService.database;
    final rows = await db.query(
      'materials',
      where: 'mentorId = ?',
      whereArgs: [mentorId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => MaterialModel.fromJson(r)).toList();
  }

  Future<List<MaterialModel>> getMaterialsByMentors(List<int> mentorIds) async {
    if (mentorIds.isEmpty) return [];
    final all = await getAllMaterials();
    return all
        .where((material) => mentorIds.contains(material.mentorId))
        .toList();
  }

  Future<void> attachPostTest(int materialId, int quizId) async {
    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('materials')
            .update({'postTestQuizId': quizId})
            .eq('id', materialId);
        return;
      } catch (_) {
        // fallback to sqlite
      }
    }

    final db = await _databaseService.database;
    await db.update(
      'materials',
      {'postTestQuizId': quizId},
      where: 'id = ?',
      whereArgs: [materialId],
    );
  }

  Future<void> updateMaterial(MaterialModel material) async {
    if (material.id == null) {
      throw Exception('Material ID tidak ditemukan');
    }

    if (_useSupabase) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('materials')
            .update(material.toJson())
            .eq('id', material.id!);
        return;
      } catch (_) {
        // fallback to sqlite
      }
    }

    final db = await _databaseService.database;
    await db.update(
      'materials',
      material.toJson(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }

  Future<MaterialModel?> getMaterialById(int id) async {
    final all = await getAllMaterials();
    try {
      return all.firstWhere((material) => material.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> getMaterialCountByMentor(int mentorId) async {
    final materials = await getMaterialsByMentor(mentorId);
    return materials.length;
  }
}
