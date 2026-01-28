import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/turma.dart';
import '../database/database_helper.dart';

class TurmaService {
  static const String _baseUrl = 'https://smecel.com.br/api/professor';
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<List<Turma>> getTurmasByEscola(
      String codigoProfessor, String escolaId) async {
    final professorId = int.tryParse(codigoProfessor) ?? 0;
    final escolaIdInt = int.tryParse(escolaId) ?? 0;

    // Verificar conectividade primeiro
    if (!await _isConnected()) {
      return _getTurmasOffline(professorId, escolaIdInt);
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_turmas.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'codigo': codigoProfessor,
          'escola': escolaId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // ignore: avoid_print
      print('GET_TURMAS BODY: ${response.body}');

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Resposta inesperada do servidor.');
      }

      if (decoded['status'] == 'success') {
        final raw = decoded['turmas'];
        final List<dynamic> list = raw is List
            ? raw
            : raw is Map
                ? (raw).values.toList()
                : <dynamic>[];

        final List<Map<String, dynamic>> turmasData = [];
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map) {
            try {
              final map = <String, dynamic>{};
              item.forEach((k, v) => map[k.toString()] = v);
              final normalized = <String, dynamic>{
                'turma_id': map['turma_id']?.toString(),
                'turma_nome': map['turma_nome']?.toString(),
                'turma_turno': map['turma_turno']?.toString(),
                'turma_ano_letivo': map['turma_ano_letivo']?.toString(),
              };
              turmasData.add(normalized);
            } catch (err) {
              throw Exception('Item inválido na posição $i: $item. Erro: $err');
            }
          } else {
            throw Exception('Item inválido na posição $i: $item');
          }
        }

        // SALVAR NO CACHE LOCAL
        await _db.saveTurmas(turmasData, escolaIdInt, professorId);

        return turmasData.map((turmaJson) => Turma.fromMap(turmaJson)).toList();
      } else {
        throw Exception(decoded['message'] ?? 'Erro ao carregar turmas');
      }
    } catch (e) {
      // Em caso de erro de conexão, tentar dados offline
      return _getTurmasOffline(professorId, escolaIdInt);
    }
  }

  Future<List<Turma>> _getTurmasOffline(int professorId, int escolaId) async {
    try {
      // USAR DADOS REAIS DO CACHE
      final turmasCached = await _db.getTurmasCached(escolaId, professorId);

      if (turmasCached.isNotEmpty) {
        return turmasCached
            .map((turmaJson) => Turma.fromMap(turmaJson))
            .toList();
      }
    } catch (e) {
      // Se não conseguir do cache, usar dados mockados como fallback
    }

    // Fallback para dados mockados apenas se não houver cache
    return [];
  }
}
