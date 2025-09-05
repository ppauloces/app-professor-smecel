class Frequencia {
  final int? id;
  final int alunoId;
  final int aulaId;
  final bool presente;
  final String? observacoes;
  final bool sincronizado;
  final DateTime? criadoEm;

  Frequencia({
    this.id,
    required this.alunoId,
    required this.aulaId,
    required this.presente,
    this.observacoes,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aluno_id': alunoId,
      'aula_id': aulaId,
      'presente': presente ? 1 : 0,
      'observacoes': observacoes,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Frequencia.fromMap(Map<String, dynamic> map) {
    return Frequencia(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      alunoId: int.tryParse((map['aluno_id']).toString()) ?? 0,
      aulaId: int.tryParse((map['aula_id']).toString()) ?? 0,
      presente: map['presente'] == 1,
      observacoes: map['observacoes'],
      sincronizado: map['sincronizado'] == 1,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Frequencia copyWith({
    int? id,
    int? alunoId,
    int? aulaId,
    bool? presente,
    String? observacoes,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Frequencia(
      id: id ?? this.id,
      alunoId: alunoId ?? this.alunoId,
      aulaId: aulaId ?? this.aulaId,
      presente: presente ?? this.presente,
      observacoes: observacoes ?? this.observacoes,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}