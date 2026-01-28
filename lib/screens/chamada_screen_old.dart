import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/turma.dart';
import '../providers/frequencia_provider.dart';

class ChamadaScreen extends StatefulWidget {
  final Turma turma;

  const ChamadaScreen({super.key, required this.turma});

  @override
  State<ChamadaScreen> createState() => _ChamadaScreenState();
}

class _ChamadaScreenState extends State<ChamadaScreen> {
  final _tituloController = TextEditingController();
  bool _aulaIniciada = false;

  @override
  void initState() {
    super.initState();
    _tituloController.text =
        'Aula de ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    _carregarAlunos();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  Future<void> _carregarAlunos() async {
    final frequenciaProvider =
        Provider.of<FrequenciaProvider>(context, listen: false);
    await frequenciaProvider.carregarAlunos(widget.turma.id);
  }

  Future<void> _iniciarAula() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira o título da aula'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final frequenciaProvider =
        Provider.of<FrequenciaProvider>(context, listen: false);

    await frequenciaProvider.iniciarAula(
      turmaId: widget.turma.id,
      titulo: _tituloController.text.trim(),
    );

    if (frequenciaProvider.errorMessage == null) {
      setState(() {
        _aulaIniciada = true;
      });
    }
  }

  void _marcarTodosPresentes() {
    final frequenciaProvider =
        Provider.of<FrequenciaProvider>(context, listen: false);

    for (final aluno in frequenciaProvider.alunos) {
      if (!frequenciaProvider.isPresente(aluno.id)) {
        frequenciaProvider.registrarFrequencia(
          alunoId: aluno.id,
          presente: true,
        );
      }
    }
  }

  void _marcarTodosFaltosos() {
    final frequenciaProvider =
        Provider.of<FrequenciaProvider>(context, listen: false);

    for (final aluno in frequenciaProvider.alunos) {
      if (frequenciaProvider.isPresente(aluno.id)) {
        frequenciaProvider.registrarFrequencia(
          alunoId: aluno.id,
          presente: false,
        );
      }
    }
  }

  void _finalizarAula() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Aula'),
        content: const Text(
            'Deseja finalizar a aula? Os dados serão salvos automaticamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final frequenciaProvider =
                  Provider.of<FrequenciaProvider>(context, listen: false);
              frequenciaProvider.finalizarAula();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child:
                const Text('Finalizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.turma.nome),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: _aulaIniciada
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'todos_presentes':
                        _marcarTodosPresentes();
                        break;
                      case 'todos_faltosos':
                        _marcarTodosFaltosos();
                        break;
                      case 'finalizar':
                        _finalizarAula();
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
                    const PopupMenuItem(
                      value: 'finalizar',
                      child: Row(
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text('Finalizar aula'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: Consumer<FrequenciaProvider>(
        builder: (context, frequenciaProvider, child) {
          if (frequenciaProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (frequenciaProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(frequenciaProvider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => frequenciaProvider.clearError(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }

          if (!_aulaIniciada) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Iniciar Nova Aula',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título da Aula',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _iniciarAula,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Iniciar Aula',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final alunos = frequenciaProvider.alunos;

          if (alunos.isEmpty) {
            return const Center(
              child: Text('Nenhum aluno encontrado nesta turma'),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    Text(
                      frequenciaProvider.aulaAtual?.titulo ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${alunos.where((a) => frequenciaProvider.isPresente(a.id)).length} presentes de ${alunos.length} alunos',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alunos.length,
                  itemBuilder: (context, index) {
                    final aluno = alunos[index];
                    final isPresente = frequenciaProvider.isPresente(aluno.id);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isPresente ? Colors.green : Colors.grey,
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
                        subtitle: Text('Matrícula: ${aluno.matricula}'),
                        trailing: Switch(
                          value: isPresente,
                          onChanged: (value) {
                            frequenciaProvider.registrarFrequencia(
                              alunoId: aluno.id,
                              presente: value,
                            );
                          },
                          activeThumbColor: Colors.green,
                        ),
                        onTap: () {
                          frequenciaProvider.toggleFrequencia(aluno.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
