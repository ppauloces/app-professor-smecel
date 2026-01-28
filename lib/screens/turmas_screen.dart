import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/escola.dart';
import '../models/turma.dart';
import '../providers/auth_provider.dart';
import '../services/turma_service.dart';
import '../widgets/lottie_loading.dart';
import 'selecionar_data_screen.dart';

class TurmasScreen extends StatefulWidget {
  final Escola escola;

  const TurmasScreen({super.key, required this.escola});

  @override
  State<TurmasScreen> createState() => _TurmasScreenState();
}

class _TurmasScreenState extends State<TurmasScreen> {
  List<Turma> _turmas = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TurmaService _turmaService = TurmaService();

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.professor != null) {
        final turmas = await _turmaService.getTurmasByEscola(
          authProvider.professor!.codigo,
          widget.escola.id.toString(),
        );
        
        setState(() {
          _turmas = turmas;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar turmas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.escola.nome),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LottieLoading();
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
              onPressed: _carregarTurmas,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_turmas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.class_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhuma turma encontrada',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarTurmas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _turmas.length,
        itemBuilder: (context, index) {
          final turma = _turmas[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Text(
                  turma.nome.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                turma.nome,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Turno: ${turma.turno}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SelecionarDataScreen(
                      escola: widget.escola,
                      turma: turma,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}