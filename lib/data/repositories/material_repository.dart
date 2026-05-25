import '../models/material_model.dart';
import '../sources/local/material_local_data_source.dart';

class MaterialRepository {
  final MaterialLocalDataSource _local;

  MaterialRepository(this._local);

  Future<int> createMaterial(MaterialModel material) =>
      _local.createMaterial(material);
  Future<List<MaterialModel>> getAllMaterials() => _local.getAllMaterials();
  Future<List<MaterialModel>> getMaterialsByMentor(int mentorId) =>
      _local.getMaterialsByMentor(mentorId);
  Future<List<MaterialModel>> getMaterialsByMentors(List<int> mentorIds) =>
      _local.getMaterialsByMentors(mentorIds);
  Future<void> attachPostTest(int materialId, int quizId) =>
      _local.attachPostTest(materialId, quizId);
  Future<void> updateMaterial(MaterialModel material) =>
      _local.updateMaterial(material);
  Future<MaterialModel?> getMaterialById(int id) => _local.getMaterialById(id);
  Future<int> getMaterialCountByMentor(int mentorId) =>
      _local.getMaterialCountByMentor(mentorId);
}
