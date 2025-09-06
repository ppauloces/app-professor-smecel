import 'package:flutter/foundation.dart';
import '../models/professor.dart';
import '../services/auth_service.dart';
import '../services/full_sync_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FullSyncService _fullSyncService = FullSyncService();
  
  Professor? _professor;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;
  String? _syncMessage;

  Professor? get professor => _professor;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  bool get isAuthenticated => _professor != null;

  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      _professor = await _authService.getProfessorLogado();
      _clearError();
    } catch (e) {
      _setError('Erro ao verificar autenticação: $e');
    }
    _setLoading(false);
  }

  Future<bool> login(String codigo, String email, String senha) async {
    _setLoading(true);
    _clearError();
    
    try {
      final professor = await _authService.login(codigo, email, senha);
      if (professor != null) {
        _professor = professor;
        
        // SINCRONIZAÇÃO COMPLETA NO LOGIN
        await _performFullSync(codigo);
        
        _setLoading(false);
        return true;
      } else {
        _setError('Código, email ou senha incorretos');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Erro durante o login: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Realiza sincronização completa dos dados do professor
  Future<void> _performFullSync(String professorCodigo) async {
    _setSyncing(true, 'Verificando dados locais...');
    
    try {
      final professorId = int.tryParse(professorCodigo) ?? 0;
      
      // Verificar se já tem dados locais
      final hasLocal = await _fullSyncService.hasLocalData(professorId);
      
      if (!hasLocal) {
        _setSyncing(true, 'Baixando dados para uso offline...');
        
        final result = await _fullSyncService.syncAllData(professorCodigo);
        
        if (result['success']) {
          final details = result['details'] as Map<String, dynamic>;
          _setSyncing(true, 'Dados sincronizados: ${details['escolas']} escolas, ${details['turmas']} turmas, ${details['horarios']} horários');
          
          // Aguardar um pouco para mostrar a mensagem de sucesso
          await Future.delayed(Duration(seconds: 2));
        } else {
          print('Falha na sincronização: ${result['message']}');
          // Continua mesmo se a sincronização falhar, para permitir uso online
        }
      } else {
        _setSyncing(true, 'Dados offline disponíveis');
        await Future.delayed(Duration(seconds: 1));
      }
      
    } catch (e) {
      print('Erro na sincronização: $e');
      // Continua mesmo se a sincronização falhar
    }
    
    _setSyncing(false, null);
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
      _professor = null;
      _clearError();
    } catch (e) {
      _setError('Erro durante logout: $e');
    }
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSyncing(bool syncing, String? message) {
    _isSyncing = syncing;
    _syncMessage = message;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  /// Força re-sincronização completa (limpa cache e baixa tudo novamente)
  Future<void> forceFullSync() async {
    if (_professor == null) return;
    
    _setSyncing(true, 'Limpando cache local...');
    
    try {
      final professorId = int.tryParse(_professor!.codigo) ?? 0;
      await _fullSyncService.clearCache(professorId);
      
      _setSyncing(true, 'Re-sincronizando dados...');
      final result = await _fullSyncService.syncAllData(_professor!.codigo);
      
      if (result['success']) {
        final details = result['details'] as Map<String, dynamic>;
        _setSyncing(true, 'Sincronização completa: ${details['escolas']} escolas, ${details['turmas']} turmas, ${details['horarios']} horários');
        await Future.delayed(Duration(seconds: 2));
      } else {
        _setError('Erro na re-sincronização: ${result['message']}');
      }
    } catch (e) {
      _setError('Erro na re-sincronização: $e');
    }
    
    _setSyncing(false, null);
  }

  /// Método chamado quando a conectividade é restaurada
  Future<void> onConnectivityRestored() async {
    print('🔄 AuthProvider.onConnectivityRestored: INICIADO - professor: ${_professor?.codigo}, isSyncing: $_isSyncing');
    
    if (_professor != null && !_isSyncing) {
      print('📱 Conectividade restaurada, iniciando sincronização automática...');
      print('🔄 AuthProvider.onConnectivityRestored: chamando syncIncremental');
      
      _setSyncing(true, 'Enviando dados offline...');
      
      try {
        print('🔄 AuthProvider: antes de chamar syncIncremental');
        final result = await _fullSyncService.syncIncremental(_professor!.codigo);
        print('🔄 AuthProvider: depois de chamar syncIncremental - result: $result');
        
        if (result['success']) {
          final details = result['details'] as Map<String, dynamic>?;
          final uploaded = details?['uploaded'] ?? 0;
          
          if (uploaded > 0) {
            _setSyncing(false, 'Enviados $uploaded registros offline');
          } else {
            _setSyncing(false, 'Dados sincronizados');
          }
        } else {
          _setSyncing(false, 'Erro na sincronização');
        }
        
        // Limpar mensagem após 3 segundos
        Future.delayed(Duration(seconds: 3), () {
          if (_syncMessage?.contains('Enviados') == true || 
              _syncMessage == 'Dados sincronizados' ||
              _syncMessage == 'Erro na sincronização') {
            _syncMessage = null;
            notifyListeners();
          }
        });
        
      } catch (e) {
        _setSyncing(false, 'Erro na sincronização automática');
        print('❌ Erro na sincronização automática: $e');
      }
    } else {
      print('🔄 AuthProvider.onConnectivityRestored: NÃO EXECUTADO - professor: ${_professor?.codigo}, isSyncing: $_isSyncing');
    }
  }
}