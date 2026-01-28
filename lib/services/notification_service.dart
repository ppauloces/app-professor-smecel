import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
  bool _timeZoneReady = false;

  static const int _reminderBaseId = 7000;

  static const List<_ReminderTime> _horariosLembrete = [
    _ReminderTime(6, 30),
    _ReminderTime(7, 0),
    _ReminderTime(12, 0),
    _ReminderTime(13, 0),
    _ReminderTime(18, 0),
    _ReminderTime(22, 0),
  ];

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
    await _configureLocalTimeZone();
    _initialized = true;

    debugPrint('[Notificacao] Servico inicializado');
  }

  Future<void> _configureLocalTimeZone() async {
    if (_timeZoneReady) return;
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      final minutes = offset.inMinutes.remainder(60).abs();

      if (minutes == 0) {
        final sign = hours <= 0 ? '+' : '-';
        final name = 'Etc/GMT$sign${hours.abs()}';
        tz.setLocalLocation(tz.getLocation(name));
      } else {
        // Fallback para horario Brasil em offsets nao inteiros
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      }
      _timeZoneReady = true;
    } catch (e) {
      debugPrint('[Notificacao] Falha ao configurar fuso horario: $e');
    }
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

    // Agendar lembretes fixos diarios
    await _agendarLembretesFixos();

    // Cancela timer anterior se existir (mantido apenas por compatibilidade)
    _timerLembrete?.cancel();
    _timerLembrete = null;

    debugPrint('[Notificacao] Lembretes iniciados para professor $_professorCodigo');
  }

  /// Para os lembretes (chamado no logout)
  void pararLembretes() {
    _timerLembrete?.cancel();
    _timerLembrete = null;
    _professorCodigo = null;
    _cancelarLembretesFixos();
    debugPrint('[Notificacao] Lembretes parados');
  }

  /// Verificacao disparada quando a internet volta
  Future<void> verificarAoReconectar() async {
    await _agendarLembretesFixos();
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

  Future<void> _agendarLembretesFixos() async {
    if (!_permissaoConcedida) return;
    await _configureLocalTimeZone();

    const mensagem = 'Lembrete: abra o app para verificar e sincronizar suas chamadas.';
    const titulo = 'Lembrete de frequencia';

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

    for (var i = 0; i < _horariosLembrete.length; i++) {
      final time = _horariosLembrete[i];
      final id = _reminderBaseId + i;
      await _plugin.zonedSchedule(
        id,
        titulo,
        mensagem,
        _nextInstanceOfTime(time.hour, time.minute),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _cancelarLembretesFixos() async {
    for (var i = 0; i < _horariosLembrete.length; i++) {
      await _plugin.cancel(_reminderBaseId + i);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

class _ReminderTime {
  final int hour;
  final int minute;
  const _ReminderTime(this.hour, this.minute);
}
