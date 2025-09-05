import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/escola.dart';
import '../models/turma.dart';
import '../models/horario.dart';
import '../models/aluno.dart';
import '../providers/auth_provider.dart';
import '../services/nova_frequencia_service.dart';

class NovaChamadaScreen extends StatefulWidget {
  final Escola escola;
  final Turma turma;
  final DateTime dataSelecionada;
  final Horario horarioSelecionado;

  const NovaChamadaScreen({
    super.key,
    required this.escola,
    required this.turma,
    required this.dataSelecionada,
    required this.horarioSelecionado,
  });

  @override
  State<NovaChamadaScreen> createState() => _NovaChamadaScreenState();
}

class _NovaChamadaScreenState extends State<NovaChamadaScreen> {
  List<Aluno> _alunos = [];
  Map<int, bool> _presencas = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  final NovaFrequenciaService _frequenciaService = NovaFrequenciaService();

  @override
  void initState() {
    super.initState();
    _carregarAlunos();
  }

  Future<void> _carregarAlunos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.professor != null) {
        final alunos = await _frequenciaService.getAlunosPorAula(
          professorId: authProvider.professor!.codigo,
          turmaId: widget.turma.id.toString(),
          disciplinaId: widget.horarioSelecionado.disciplinaId.toString(),
          data: widget.dataSelecionada,
          aulaNumero: widget.horarioSelecionado.numeroAula,
        );
        
        setState(() {
          _alunos = alunos;
          // Inicializa presenças baseado no status atual (lógica inversa: tem falta = false)
          _presencas = {
            for (var aluno in alunos) aluno.id: !aluno.temFalta
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar alunos: $e';
        _isLoading = false;
      });
    }
  }

  void _togglePresenca(int alunoId) {
    setState(() {
      _presencas[alunoId] = !(_presencas[alunoId] ?? false);
    });
  }

  void _marcarTodosPresentes() {
    setState(() {
      for (var alunoId in _presencas.keys) {
        _presencas[alunoId] = true;
      }
    });
  }

  void _marcarTodosFaltosos() {
    setState(() {
      for (var alunoId in _presencas.keys) {
        _presencas[alunoId] = false;
      }
    });
  }

  Future<void> _salvarFrequencia() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.professor != null) {
        // Prepara dados para envio (mapear IDs corretos)
        final presencasParaEnvio = _alunos.map((aluno) {
          final presente = _presencas[aluno.id] ?? false;
          return {
            'aluno_id': aluno.vinculoAlunoId, // Usa o ID correto do vínculo
            'presente': presente,
          };
        }).toList();

        final sucesso = await _frequenciaService.salvarFrequencia(
          professorId: authProvider.professor!.codigo,
          turmaId: widget.turma.id.toString(),
          disciplinaId: widget.horarioSelecionado.disciplinaId.toString(),
          data: widget.dataSelecionada,
          aulaNumero: widget.horarioSelecionado.numeroAula,
          presencas: presencasParaEnvio,
        );

        if (sucesso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frequência salva com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar frequência: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year;
    return '$dia/$mes/$ano';
  }

  int get _totalPresentes => _presencas.values.where((presente) => presente).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.horarioSelecionado.numeroAula}ª Aula'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'todos_presentes':
                  _marcarTodosPresentes();
                  break;
                case 'todos_faltosos':
                  _marcarTodosFaltosos();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'todos_presentes',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Todos presentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'todos_faltosos',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Todos faltosos'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
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
            Text('Carregando alunos...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarAlunos,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_alunos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum aluno encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header com informações da aula
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.horarioSelecionado.disciplinaNome,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text('${widget.escola.nome} - ${widget.turma.nome}'),
              Text('Data: ${_formatarData(widget.dataSelecionada)}'),
              const SizedBox(height: 8),
              Text(
                '$_totalPresentes presentes de ${_alunos.length} alunos',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Lista de alunos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _alunos.length,
            itemBuilder: (context, index) {
              final aluno = _alunos[index];
              final isPresente = _presencas[aluno.id] ?? false;
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPresente ? Colors.green : Colors.grey,
                    child: Text(
                      aluno.nome.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    aluno.nome,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Switch(
                    value: isPresente,
                    onChanged: (value) => _togglePresenca(aluno.id),
                    activeColor: Colors.green,
                  ),
                  onTap: () => _togglePresenca(aluno.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _salvarFrequencia,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Salvar Frequência',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}