import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/escola.dart';

class EscolaService {
  static const String _baseUrl = 'https://smecel.com.br/api/professor';

  Future<List<Escola>> getEscolasByProfessor(String codigoProfessor) async {
    try {
      // Muitos endpoints PHP esperam form-urlencoded, não JSON.
      final response = await http.post(
        Uri.parse('$_baseUrl/get_escolas.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigoProfessor}),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // Log simples do corpo, útil para diagnosticar tipos inesperados
      // ignore: avoid_print
      //print('GET_ESCOLAS BODY: '+response.body);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Resposta inesperada do servidor.');
      }

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Erro ao carregar escolas');
      }

      final raw = decoded['escolas'];
      // Aceita tanto List quanto Map (ex.: {"0": {...}, "1": {...}})
      final List<dynamic> list = raw is List
          ? raw
          : raw is Map
              ? (raw).values.toList()
              : <dynamic>[];

      final List<Escola> escolas = [];
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is Map) {
          try {
            // Normaliza chaves e garante tipos em texto para os helpers do modelo
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
            throw Exception('Item inválido na posição $i: $item. Erro: $err');
          }
        } else {
          throw Exception('Item inválido na posição $i: $item');
        }
      }
      return escolas;
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }
}
