import '../database/database_helper.dart';
import '../models/turma.dart';
import '../models/aluno.dart';
import '../models/aula.dart';
import '../models/frequencia.dart';

class FrequenciaService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Turma>> getTurmasProfessor(int professorId) async {
    return await _db.getTurmasByProfessor(professorId);
  }

  Future<List<Aluno>> getAlunosTurma(int turmaId) async {
    return await _db.getAlunosByTurma(turmaId);
  }

  Future<Aula> criarAula({
    required DateTime data,
    required String titulo,
    String? observacoes,
    required int turmaId,
  }) async {
    final aula = Aula(
      data: data,
      titulo: titulo,
      observacoes: observacoes,
      turmaId: turmaId,
      criadoEm: DateTime.now(),
    );

    final aulaId = await _db.insertAula(aula);
    return aula.copyWith(id: aulaId);
  }

  Future<void> registrarFrequencia({
    required int alunoId,
    required int aulaId,
    required bool presente,
    String? observacoes,
  }) async {
    final frequenciaExistente = await _db.getFrequencia(alunoId, aulaId);

    if (frequenciaExistente != null) {
      final frequenciaAtualizada = frequenciaExistente.copyWith(
        presente: presente,
        observacoes: observacoes,
        sincronizado: false,
      );
      await _db.updateFrequencia(frequenciaAtualizada);
    } else {
      final novaFrequencia = Frequencia(
        alunoId: alunoId,
        aulaId: aulaId,
        presente: presente,
        observacoes: observacoes,
        criadoEm: DateTime.now(),
      );
      await _db.insertFrequencia(novaFrequencia);
    }
  }

  Future<Map<int, bool>> getFrequenciasAula(int aulaId) async {
    final frequencias = await _db.getFrequenciasByAula(aulaId);
    final Map<int, bool> frequenciasMap = {};
    
    for (final freq in frequencias) {
      frequenciasMap[freq.alunoId] = freq.presente;
    }
    
    return frequenciasMap;
  }

  Future<bool> hasFrequenciaRegistrada(int alunoId, int aulaId) async {
    final frequencia = await _db.getFrequencia(alunoId, aulaId);
    return frequencia != null;
  }
}