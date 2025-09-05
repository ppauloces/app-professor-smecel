import 'package:flutter/material.dart';
import '../models/escola.dart';
import '../models/turma.dart';
import 'selecionar_horario_screen.dart';

class SelecionarDataScreen extends StatefulWidget {
  final Escola escola;
  final Turma turma;

  const SelecionarDataScreen({
    super.key,
    required this.escola,
    required this.turma,
  });

  @override
  State<SelecionarDataScreen> createState() => _SelecionarDataScreenState();
}

class _SelecionarDataScreenState extends State<SelecionarDataScreen> {
  DateTime _dataSelecionada = DateTime.now();

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecionar data da aula',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  void _continuar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelecionarHorarioScreen(
          escola: widget.escola,
          turma: widget.turma,
          dataSelecionada: _dataSelecionada,
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final diasSemana = [
      'Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
      'Quinta-feira', 'Sexta-feira', 'Sábado'
    ];
    
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    final diaSemana = diasSemana[data.weekday % 7];
    final dia = data.day.toString().padLeft(2, '0');
    final mes = meses[data.month - 1];
    final ano = data.year;

    return '$diaSemana, $dia de $mes de $ano';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.escola.nome} - ${widget.turma.nome}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              'Selecione a Data da Aula',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Turma: ${widget.turma.nome}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Turno: ${widget.turma.turno}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue.shade50,
              ),
              child: Column(
                children: [
                  const Text(
                    'Data Selecionada:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatarData(_dataSelecionada),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _selecionarData,
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Alterar Data'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _continuar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );

  }
}