import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/http_helper.dart';
import '../models/escola.dart';
import '../database/database_helper.dart';

class EscolaService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<List<Escola>> getEscolasByProfessor(String codigoProfessor) async {
    if (!await _isConnected()) {
      return _getEscolasOffline(codigoProfessor);
    }

    try {
      final response = await HttpHelper.post(
        '/get_escolas.php',
        {'codigo': codigoProfessor},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Resposta inesperada do servidor.');
      }

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Erro ao carregar escolas');
      }

      final raw = decoded['escolas'];
      final List<dynamic> list = raw is List
          ? raw
          : raw is Map
              ? (raw as Map).values.toList()
              : <dynamic>[];

      final List<Escola> escolas = [];
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is Map) {
          try {
            final Map<String, dynamic> map = {};
            item.forEach((k, v) => map[k.toString()] = v);
            final normalized = <String, dynamic>{
              'escola_id': map['escola_id']?.toString(),
              'escola_nome': map['escola_nome']?.toString(),
              'sincronizado': map['sincronizado'],
              'criado_em': map['criado_em'],
              'id': map['id'],
              'nome': map['nome'],
            };
            escolas.add(Escola.fromMap(normalized));
          } catch (err) {
            throw Exception('Item invalido na posicao $i: $item. Erro: $err');
          }
        } else {
          throw Exception('Item invalido na posicao $i: $item');
        }
      }
      return escolas;
    } catch (e) {
      return _getEscolasOffline(codigoProfessor);
    }
  }

  Future<List<Escola>> _getEscolasOffline(String codigoProfessor) async {
    try {
      final professorId = int.tryParse(codigoProfessor) ?? 0;
      final escolasCached = await _db.getEscolasCached(professorId);
      if (escolasCached.isNotEmpty) {
        return escolasCached.map((e) => Escola.fromMap(e)).toList();
      }
    } catch (e) {
      // Se nao conseguir do cache, retornar vazio
    }
    return [];
  }
}
