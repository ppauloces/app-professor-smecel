class Escola {
  final int id;
  final String nome;
  final bool sincronizado;
  final DateTime? criadoEm;

  Escola({
    required this.id,
    required this.nome,
    this.sincronizado = false,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'sincronizado': sincronizado ? 1 : 0,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  factory Escola.fromMap(Map<String, dynamic> map) {
    return Escola(
      id: _asInt(map['escola_id'] ?? map['id']),
      nome: _asString(map['escola_nome'] ?? map['nome']),
      sincronizado: _asBool(map['sincronizado']),
      criadoEm: _asDateTime(map['criado_em']),
    );
  }

  // --- Helpers tolerantes ---
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _asString(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  static bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'sim';
    }
    return false;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      // Tenta ISO-8601; ajuste se seu backend usar outro formato
      return DateTime.tryParse(v);
    }
    return null;
  }

  Escola copyWith({
    int? id,
    String? nome,
    bool? sincronizado,
    DateTime? criadoEm,
  }) {
    return Escola(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      sincronizado: sincronizado ?? this.sincronizado,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  String toString() => 'Escola{id: $id, nome: $nome}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Escola && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
