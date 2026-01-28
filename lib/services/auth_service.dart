import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/http_helper.dart';
import '../models/professor.dart';

class AuthService {
  static const String _keyProfessorCodigo = 'professor_codigo';
  static const String _keyProfessorEmail = 'professor_email';

  Future<Professor?> login(String codigo, String email, String senha) async {
    try {
      final response = await HttpHelper.post(
        '/login.php',
        {
          'codigo': codigo,
          'email': email,
          'senha': senha,
        },
      );

      final data = jsonDecode(response.body);
      
      if (data['status'] == 'success') {
        final professor = Professor(
          codigo: data['user']['codigo'].toString(),
          nome: '', // Will be filled later from API
          email: data['user']['email'],
          senha: senha,
        );
        
        await _salvarDadosLogin(codigo, email);
        return professor;
      }
      
      return null;
    } catch (e) {
      debugPrint('Erro no login: $e');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfessorCodigo);
    await prefs.remove(_keyProfessorEmail);
  }

  Future<Professor?> getProfessorLogado() async {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString(_keyProfessorCodigo);
    final email = prefs.getString(_keyProfessorEmail);
    
    if (codigo != null && email != null) {
      return Professor(
        codigo: codigo,
        nome: '',
        email: email,
        senha: '',
      );
    }
    
    return null;
  }

  Future<bool> isLogado() async {
    final professor = await getProfessorLogado();
    return professor != null;
  }

  Future<void> _salvarDadosLogin(String codigo, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfessorCodigo, codigo);
    await prefs.setString(_keyProfessorEmail, email);
  }
}