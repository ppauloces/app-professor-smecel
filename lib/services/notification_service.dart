import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseHelper _db = DatabaseHelper();
  final Connectivity _connectivity = Connectivity();

  Timer? _timerLembrete;
  String? _professorCodigo;
  bool _initialized = false;
  bool _permissaoConcedida = false;

  /// Mensagens amigaveis para o professor
  static const List<String> _mensagensLembrete = [
    'Professor(a), voce tem chamadas registradas aguardando envio. Abra o app para sincronizar!',
    'Lembrete: ha registros de presenca que ainda nao foram enviados ao sistema.',
    'Voce tem frequencias salvas no celular. Conecte-se e sincronize para nao perder nada!',
    'Professor(a), seus registros de chamada estao prontos para enviar. Sincronize agora!',
    'Ha chamadas pendentes no seu celular. Aproveite a conexao para enviar!',
  ];

  /// Inicializa o plugin de notificacoes
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;

    debugPrint('[Notificacao] Servico inicializado');
  }

  /// Solicita permissao de notificacao (Android 13+)
  Future<void> _solicitarPermissao() async {
    if (_permissaoConcedida) return;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _permissaoConcedida = granted ?? false;
      debugPrint('[Notificacao] Permissao concedida: $_permissaoConcedida');
    } else {
      // iOS ja solicita no initialize via DarwinInitializationSettings
      _permissaoConcedida = true;
    }
  }

  /// Inicia os lembretes periodicos apos o login
  void iniciarLembretes(String professorCodigo) async {
    _professorCodigo = professorCodigo;

    // Solicitar permissao na primeira vez
    await _solicitarPermissao();

    // Cancela timer anterior se existir
    _timerLembrete?.cancel();

    // Verifica a cada 3 horas (3x ao dia em horario comercial ~8h-18h)
    _timerLembrete = Timer.periodic(
      const Duration(hours: 3),
      (_) => _verificarENotificar(),
    );

    // Primeira verificacao apos 30 minutos do login
    Future.delayed(
      const Duration(minutes: 30),
      () => _verificarENotificar(),
    );

    debugPrint('[Notificacao] Lembretes iniciados para professor $_professorCodigo');
  }

  /// Para os lembretes (chamado no logout)
  void pararLembretes() {
    _timerLembrete?.cancel();
    _timerLembrete = null;
    _professorCodigo = null;
    debugPrint('[Notificacao] Lembretes parados');
  }

  /// Verificacao disparada quando a internet volta
  Future<void> verificarAoReconectar() async {
    await _verificarENotificar();
  }

  /// Verifica se ha pendencias e mostra notificacao
  Future<void> _verificarENotificar() async {
    try {
      // Verificar se esta online
      final result = await _connectivity.checkConnectivity();
      final online = result != ConnectivityResult.none;

      if (!online) {
        debugPrint('[Notificacao] Offline, sem notificacao');
        return;
      }

      // Verificar se ha chamadas pendentes
      final pendentes = await _db.getFrequenciasPendentes();
      final qtdPendentes = pendentes.length;

      if (qtdPendentes == 0) {
        debugPrint('[Notificacao] Nenhuma pendencia, sem notificacao');
        return;
      }

      // Escolher mensagem aleatoria
      final random = Random();
      final mensagem = _mensagensLembrete[random.nextInt(_mensagensLembrete.length)];

      // Titulo com quantidade
      final titulo = qtdPendentes == 1
          ? '1 chamada aguardando envio'
          : '$qtdPendentes chamadas aguardando envio';

      await _mostrarNotificacao(titulo, mensagem);
    } catch (e) {
      debugPrint('[Notificacao] Erro ao verificar pendencias: $e');
    }
  }

  /// Mostra a notificacao local
  Future<void> _mostrarNotificacao(String titulo, String corpo) async {
    const androidDetails = AndroidNotificationDetails(
      'sync_reminders',
      'Lembretes de Sincronizacao',
      channelDescription: 'Lembretes para enviar chamadas registradas offline',
      importance: Importance.high,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0, // ID fixo para substituir notificacao anterior
      titulo,
      corpo,
      details,
    );

    debugPrint('[Notificacao] Lembrete mostrado: $titulo');
  }
}
