class Professor {
  final int? id;
  final String codigo;
  final String nome;
  final String email;
  final String senha;
  final bool sincronizado;
  final DateTime? criadoEm;

  Professor({
    this.id,
    required this.codigo,
    required this.nome,
    required this.email,
    required this.senha,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'email': email,
      'senha': senha,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Professor.fromMap(Map<String, dynamic> map) {
    return Professor(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      codigo: map['codigo']?.toString() ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      sincronizado: map['sincronizado'] == 1,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Professor copyWith({
    int? id,
    String? codigo,
    String? nome,
    String? email,
    String? senha,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Professor(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senha: senha ?? this.senha,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}