class Aluno {
  final int id;
  final int vinculoAlunoId;
  final String nome;
  final bool temFalta;
  final bool sincronizado;
  final DateTime? criadoEm;

  Aluno({
    required this.id,
    required this.vinculoAlunoId,
    required this.nome,
    this.temFalta = false,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vinculo_aluno_id': vinculoAlunoId,
      'nome': nome,
      'tem_falta': temFalta ? 1 : 0,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Aluno.fromMap(Map<String, dynamic> map) {
    return Aluno(
      id: int.tryParse((map['aluno_id'] ?? map['id']).toString()) ?? 0,
      vinculoAlunoId: int.tryParse((map['vinculo_aluno_id'] ?? map['id']).toString()) ?? 0,
      nome: map['aluno_nome'] ?? map['nome'] ?? '',
      temFalta: map['falta'] == 1 || map['tem_falta'] == 1,
      sincronizado: map['sincronizado'] == 1,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Aluno copyWith({
    int? id,
    int? vinculoAlunoId,
    String? nome,
    bool? temFalta,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Aluno(
      id: id ?? this.id,
      vinculoAlunoId: vinculoAlunoId ?? this.vinculoAlunoId,
      nome: nome ?? this.nome,
      temFalta: temFalta ?? this.temFalta,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  bool get isPresente => !temFalta;

  @override
  String toString() {
    return 'Aluno{id: $id, nome: $nome, temFalta: $temFalta}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Aluno && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}