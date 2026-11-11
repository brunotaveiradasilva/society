import 'package:flutter/material.dart';

/// Onde a pessoa está na lista do grupo.
enum Role { line, goalkeeper, waitlist }

extension RoleLabel on Role {
  String get label => switch (this) {
    Role.line => 'Linha',
    Role.goalkeeper => 'Goleiro',
    Role.waitlist => 'Espera',
  };
}

class Player {
  Player({
    required this.id,
    required this.name,
    this.role = Role.line,
    bool? present,
    this.paid = false,
  }) : present = present ?? false;

  final String id;
  String name;
  Role role;

  /// Marcado quando a pessoa chega na quadra. Só quem chegou entra no sorteio.
  bool present;
  bool paid;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'present': present,
    'paid': paid,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    role: Role.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => Role.line,
    ),
    present: json['present'] as bool? ?? true,
    paid: json['paid'] as bool? ?? false,
  );
}

/// Cores de colete mais comuns em pelada.
class BibColor {
  const BibColor(this.name, this.color, this.emoji);
  final String name;
  final Color color;
  final String emoji;

  Color get onColor =>
      color.computeLuminance() > 0.45 ? const Color(0xFF14181B) : Colors.white;
}

const bibColors = <BibColor>[
  BibColor('Laranja', Color(0xFFF57C00), '🟠'),
  BibColor('Verde', Color(0xFF2E7D32), '🟢'),
  BibColor('Azul', Color(0xFF1565C0), '🔵'),
  BibColor('Amarelo', Color(0xFFFDD835), '🟡'),
  BibColor('Vermelho', Color(0xFFC62828), '🔴'),
  BibColor('Preto', Color(0xFF212121), '⚫'),
  BibColor('Branco', Color(0xFFF5F5F5), '⚪'),
  BibColor('Roxo', Color(0xFF6A1B9A), '🟣'),
  BibColor('Rosa', Color(0xFFEC407A), '🩷'),
  BibColor('Cinza', Color(0xFF757575), '🩶'),
  BibColor('Marrom', Color(0xFF6D4C41), '🟤'),
  BibColor('Verde-limão', Color(0xFFC6E03A), '🍏'),
];
