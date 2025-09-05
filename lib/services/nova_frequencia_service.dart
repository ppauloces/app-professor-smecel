import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/aluno.dart';

class NovaFrequenciaService {
  static const String _baseUrl = 'https://smecel.com.br/api/professor';

  Future<List<Aluno>> getAlunosPorAula({
    required String professorId,
    required String turmaId,
    required String disciplinaId,
    required DateTime data,
    required int aulaNumero,
  }) async {
    try {
      final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$_baseUrl/get_alunos.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professorId': int.parse(professorId),
          'turma': int.parse(turmaId),
          'disciplina': int.parse(disciplinaId),
          'data': dataFormatada,
          'aulaNumero': aulaNumero,
        }),
      );

      final responseData = jsonDecode(response.body);
      
      if (responseData['status'] == 'success') {
        final alunosData = responseData['alunos'] as List;
        return alunosData.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
      } else {
        throw Exception(responseData['message'] ?? 'Erro ao carregar alunos');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<bool> salvarFrequencia({
    required String professorId,
    required String turmaId,
    required String disciplinaId,
    required DateTime data,
    required int aulaNumero,
    required List<Map<String, dynamic>> presencas,
  }) async {
    try {
      final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$_baseUrl/salvar_frequencia.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professorId': int.parse(professorId),
          'turmaId': int.parse(turmaId),
          'disciplinaId': int.parse(disciplinaId),
          'aulaNumero': aulaNumero,
          'data': dataFormatada,
          'presencas': presencas,
        }),
      );

      final responseData = jsonDecode(response.body);
      
      if (responseData['status'] == 'success') {
        return true;
      } else {
        throw Exception(responseData['message'] ?? 'Erro ao salvar frequência');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }
}