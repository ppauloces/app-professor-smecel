class Aula {
  final int? id;
  final DateTime data;
  final String titulo;
  final String? observacoes;
  final int turmaId;
  final bool sincronizado;
  final DateTime? criadoEm;

  Aula({
    this.id,
    required this.data,
    required this.titulo,
    this.observacoes,
    required this.turmaId,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data.toIso8601String(),
      'titulo': titulo,
      'observacoes': observacoes,
      'turma_id': turmaId,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Aula.fromMap(Map<String, dynamic> map) {
    return Aula(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      data: DateTime.parse(map['data']),
      titulo: map['titulo'],
      observacoes: map['observacoes'],
      turmaId: int.tryParse((map['turma_id']).toString()) ?? 0,
      sincronizado: map['sincronizado'] == 1,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Aula copyWith({
    int? id,
    DateTime? data,
    String? titulo,
    String? observacoes,
    int? turmaId,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Aula(
      id: id ?? this.id,
      data: data ?? this.data,
      titulo: titulo ?? this.titulo,
      observacoes: observacoes ?? this.observacoes,
      turmaId: turmaId ?? this.turmaId,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}