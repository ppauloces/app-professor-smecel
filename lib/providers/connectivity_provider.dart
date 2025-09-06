import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/full_sync_service.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final FullSyncService _fullSyncService = FullSyncService();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isConnected = false;
  bool _wasOffline = false;
  DateTime? _lastSyncTime;
  String? _lastSyncMessage;
  bool _isSyncing = false;
  
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get lastSyncMessage => _lastSyncMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get wasOffline => _wasOffline;
  
  void clearWasOffline() {
    _wasOffline = false;
  }
  
  String get connectionStatus => _isConnected ? 'Online' : 'Offline';
  
  String get lastSyncTimeFormatted {
    if (_lastSyncTime == null) return 'Nunca';
    
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);
    
    if (difference.inMinutes < 1) {
      return 'Agora há pouco';
    } else if (difference.inHours < 1) {
      return 'Há ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Há ${difference.inHours}h';
    } else {
      return 'Há ${difference.inDays} dias';
    }
  }

  Future<void> initialize() async {
    // Verificar estado inicial
    await _checkInitialConnection();
    
    // Configurar listener de mudanças de conectividade
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('🚨 Erro no listener de conectividade: $error');
      },
    );
    
    print('🌐 ConnectivityProvider inicializado - Status: $connectionStatus');
  }
  
  Future<void> _checkInitialConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      _wasOffline = !_isConnected;
      notifyListeners();
    } catch (e) {
      print('❌ Erro ao verificar conectividade inicial: $e');
      _isConnected = false;
      _wasOffline = true;
    }
  }
  
  void _onConnectivityChanged(ConnectivityResult result) async {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    print('🔄 Conectividade alterada: $result -> Status: $connectionStatus');
    
    // Se ficou online depois de estar offline, fazer sincronização
    if (_isConnected && !wasConnected) {
      print('🔌 Reconectou! Iniciando sincronização automática...');
      // Manter o flag wasOffline true temporariamente para permitir a sincronização
      _wasOffline = true; 
      // A sincronização automática será chamada externamente com o código do professor
      notifyListeners(); // Notificar mudança para que AuthProvider possa reagir
    } else {
      _wasOffline = !_isConnected;
      if (!_isConnected || wasConnected) {
        notifyListeners();
      }
    }
  }
  
  /// Sincronização automática chamada externamente
  Future<void> performAutomaticSync(String professorCodigo) async {
    await _performAutomaticSync(professorCodigo);
  }

  /// Sincronização automática quando volta a ficar online
  Future<void> _performAutomaticSync([String? professorCodigo]) async {
    if (_isSyncing) {
      print('⏳ Sincronização já em andamento, ignorando...');
      return;
    }
    
    _setSyncing(true, 'Enviando dados offline...');
    
    try {
      // Fazer sincronização incremental (apenas upload de pendências)
      final result = await _fullSyncService.syncIncremental(
        professorCodigo ?? ''
      );
      
      _lastSyncTime = DateTime.now();
      
      if (result['success']) {
        final details = result['details'] as Map<String, dynamic>?;
        final uploaded = details?['uploaded'] ?? 0;
        final errors = details?['errors'] ?? 0;
        
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
        if (_lastSyncMessage?.contains('Enviados') == true || 
            _lastSyncMessage == 'Dados sincronizados') {
          _lastSyncMessage = null;
          notifyListeners();
        }
      });
      
    } catch (e) {
      print('❌ Erro na sincronização automática: $e');
      _setSyncing(false, 'Erro na sincronização automática');
    }
  }
  
  /// Sincronização manual disparada pelo usuário
  Future<Map<String, dynamic>> syncNow(String? professorCodigo) async {
    if (!_isConnected) {
      return {
        'success': false,
        'message': 'Sem conexão com a internet'
      };
    }
    
    if (_isSyncing) {
      return {
        'success': false,
        'message': 'Sincronização já em andamento'
      };
    }
    
    if (professorCodigo == null || professorCodigo.isEmpty) {
      return {
        'success': false,
        'message': 'Professor não identificado'
      };
    }
    
    _setSyncing(true, 'Sincronização manual em andamento...');
    
    try {
      // Fazer sincronização completa
      final result = await _fullSyncService.syncAllData(professorCodigo);
      
      if (result['success']) {
        _lastSyncTime = DateTime.now();
        final details = result['details'] as Map<String, dynamic>?;
        
        if (details != null) {
          _setSyncing(false, 
            'Sincronizado: ${details['escolas']} escolas, ${details['turmas']} turmas, ${details['horarios']} horários'
          );
        } else {
          _setSyncing(false, 'Sincronização manual concluída');
        }
        
        // Limpar mensagem após 4 segundos
        Future.delayed(Duration(seconds: 4), () {
          if (_lastSyncMessage?.contains('Sincronizado:') == true || 
              _lastSyncMessage == 'Sincronização manual concluída') {
            _lastSyncMessage = null;
            notifyListeners();
          }
        });
        
        return result;
      } else {
        _setSyncing(false, 'Falha na sincronização');
        return result;
      }
      
    } catch (e) {
      _setSyncing(false, 'Erro na sincronização manual');
      return {
        'success': false,
        'message': 'Erro na sincronização: $e'
      };
    }
  }
  
  void _setSyncing(bool syncing, String? message) {
    _isSyncing = syncing;
    _lastSyncMessage = message;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}