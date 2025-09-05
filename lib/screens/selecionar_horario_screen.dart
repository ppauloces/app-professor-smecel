import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/escola.dart';
import '../models/turma.dart';
import '../models/horario.dart';
import '../providers/auth_provider.dart';
import '../services/horario_service.dart';
import 'nova_chamada_screen.dart';

class SelecionarHorarioScreen extends StatefulWidget {
  final Escola escola;
  final Turma turma;
  final DateTime dataSelecionada;

  const SelecionarHorarioScreen({
    super.key,
    required this.escola,
    required this.turma,
    required this.dataSelecionada,
  });

  @override
  State<SelecionarHorarioScreen> createState() => _SelecionarHorarioScreenState();
}

class _SelecionarHorarioScreenState extends State<SelecionarHorarioScreen> {
  List<Horario> _horarios = [];
  bool _isLoading = true;
  String? _errorMessage;
  final HorarioService _horarioService = HorarioService();

  @override
  void initState() {
    super.initState();
    _carregarHorarios();
  }

  Future<void> _carregarHorarios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.professor != null) {
        final horarios = await _horarioService.getHorariosPorData(
          authProvider.professor!.codigo,
          widget.escola.id.toString(),
          widget.turma.id.toString(),
          widget.dataSelecionada,
        );
        
        setState(() {
          _horarios = horarios;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar horários: $e';
        _isLoading = false;
      });
    }
  }

  void _selecionarHorario(Horario horario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NovaChamadaScreen(
          escola: widget.escola,
          turma: widget.turma,
          dataSelecionada: widget.dataSelecionada,
          horarioSelecionado: horario,
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year;
    return '$dia/$mes/$ano';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Horários - ${_formatarData(widget.dataSelecionada)}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando horários...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarHorarios,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_horarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhum horário encontrado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Verifique se há aulas programadas\npara esta turma neste dia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escola: ${widget.escola.nome}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Turma: ${widget.turma.nome} - ${widget.turma.turno}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Data: ${_formatarData(widget.dataSelecionada)}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregarHorarios,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _horarios.length,
              itemBuilder: (context, index) {
                final horario = _horarios[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Text(
                        horario.numeroAula.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${horario.numeroAula}ª Aula',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      horario.disciplinaNome,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.blue,
                    ),
                    onTap: () => _selecionarHorario(horario),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}