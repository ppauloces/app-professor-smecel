class Horario {
  final int id;
  final int disciplinaId;
  final int numeroAula;
  final int diaSemana;
  final String disciplinaNome;
  final bool sincronizado;
  final DateTime? criadoEm;

  Horario({
    required this.id,
    required this.disciplinaId,
    required this.numeroAula,
    required this.diaSemana,
    required this.disciplinaNome,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'disciplina_id': disciplinaId,
      'numero_aula': numeroAula,
      'dia_semana': diaSemana,
      'disciplina_nome': disciplinaNome,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Horario.fromMap(Map<String, dynamic> map) {
    return Horario(
      id: _parseId(map['ch_lotacao_id'] ?? map['id']),
      disciplinaId: _parseId(map['ch_lotacao_disciplina_id'] ?? map['disciplina_id']),
      numeroAula: _parseId(map['ch_lotacao_aula'] ?? map['numero_aula']),
      diaSemana: _parseId(map['ch_lotacao_dia'] ?? map['dia_semana']),
      disciplinaNome: map['disciplina_nome'] ?? '',
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

  Horario copyWith({
    int? id,
    int? disciplinaId,
    int? numeroAula,
    int? diaSemana,
    String? disciplinaNome,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Horario(
      id: id ?? this.id,
      disciplinaId: disciplinaId ?? this.disciplinaId,
      numeroAula: numeroAula ?? this.numeroAula,
      diaSemana: diaSemana ?? this.diaSemana,
      disciplinaNome: disciplinaNome ?? this.disciplinaNome,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  String get aulaLabel => '${numeroAula}ª aula - $disciplinaNome';

  @override
  String toString() {
    return 'Horario{numeroAula: $numeroAula, disciplina: $disciplinaNome}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Horario && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}