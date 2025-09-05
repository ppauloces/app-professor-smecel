import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/horario.dart';
import '../database/database_helper.dart';

class HorarioService {
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

  Future<List<Horario>> getHorariosPorData(
    String professorId,
    String escolaId,
    String turmaId,
    DateTime data,
  ) async {
    final professorIdInt = int.tryParse(professorId) ?? 0;
    final escolaIdInt = int.tryParse(escolaId) ?? 0;
    final turmaIdInt = int.tryParse(turmaId) ?? 0;

    // Verificar conectividade primeiro
    if (!await _isConnected()) {
      return _getHorariosOffline(professorIdInt, escolaIdInt, turmaIdInt, data);
    }

    try {
      final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$_baseUrl/get_horarios.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professorId': professorIdInt,
          'escolaId': escolaIdInt,
          'turmaId': turmaIdInt,
          'data': dataFormatada,
        }),
      );

      // ignore: avoid_print
      print('GET_HORARIOS BODY: ' + response.body);

      final responseData = jsonDecode(response.body);

      if (responseData['status'] == 'success') {
        final raw = responseData['horarios'];
        final List<dynamic> list = raw is List
            ? raw
            : raw is Map
                ? (raw as Map).values.toList()
                : <dynamic>[];

        final List<Map<String, dynamic>> horariosData = [];
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map) {
            final map = <String, dynamic>{};
            item.forEach((k, v) => map[k.toString()] = v);
            horariosData.add({
              'ch_lotacao_id': map['ch_lotacao_id']?.toString(),
              'ch_lotacao_disciplina_id': map['ch_lotacao_disciplina_id']?.toString(),
              'ch_lotacao_aula': map['ch_lotacao_aula']?.toString(),
              'ch_lotacao_dia': map['ch_lotacao_dia']?.toString(),
              'disciplina_nome': map['disciplina_nome']?.toString(),
            });
          }
        }

        // SALVAR NO CACHE LOCAL
        await _db.saveHorarios(horariosData, turmaIdInt, escolaIdInt, professorIdInt);

        return horariosData.map((horarioJson) => Horario.fromMap(horarioJson)).toList();
      } else {
        throw Exception(responseData['message'] ?? 'Erro ao carregar horários');
      }
    } catch (e) {
      // Em caso de erro de conexão, tentar dados offline
      return _getHorariosOffline(professorIdInt, escolaIdInt, turmaIdInt, data);
    }
  }

  Future<List<Horario>> _getHorariosOffline(
    int professorId,
    int escolaId,
    int turmaId,
    DateTime data,
  ) async {
    try {
      // USAR DADOS REAIS DO CACHE
      final diaSemana = data.weekday;
      final horariosCached = await _db.getHorariosCached(turmaId, escolaId, professorId, diaSemana);
      
      if (horariosCached.isNotEmpty) {
        return horariosCached.map((horarioJson) => Horario.fromMap(horarioJson)).toList();
      }
    } catch (e) {
      // Se não conseguir do cache, usar dados mockados como fallback
    }

    // Verificar se é um dia da semana válido (não domingo)
    if (data.weekday == DateTime.sunday) {
      return [];
    }

    // Sem cache: retorna vazio para não poluir com dados fictícios
    return [];
  }
}