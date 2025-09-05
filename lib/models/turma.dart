class Turma {
  final int id;
  final String nome;
  final String turno;
  final int anoLetivo;
  final bool sincronizado;
  final DateTime? criadoEm;

  Turma({
    required this.id,
    required this.nome,
    required this.turno,
    required this.anoLetivo,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'turno': turno,
      'ano_letivo': anoLetivo,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Turma.fromMap(Map<String, dynamic> map) {
    return Turma(
      id: _parseId(map['turma_id'] ?? map['id']),
      nome: map['turma_nome'] ?? map['nome'] ?? '',
      turno: map['turma_turno'] ?? map['turno'] ?? '',
      anoLetivo: _parseId(map['turma_ano_letivo'] ?? map['ano_letivo']),
      sincronizado: map['sincronizado'] == 1,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  static int _parseId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  Turma copyWith({
    int? id,
    String? nome,
    String? turno,
    int? anoLetivo,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Turma(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      turno: turno ?? this.turno,
      anoLetivo: anoLetivo ?? this.anoLetivo,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  String toString() {
    return 'Turma{id: $id, nome: $nome, turno: $turno}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Turma && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}