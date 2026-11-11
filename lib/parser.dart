import 'models.dart';

class ParsedEntry {
  const ParsedEntry(this.name, this.role);
  final String name;
  final Role role;

  @override
  String toString() => '${role.name}:$name';
}

class ParsedList {
  const ParsedList({this.title, this.info, required this.entries});
  final String? title;
  final String? info;
  final List<ParsedEntry> entries;
}

// Caracteres invisíveis que o WhatsApp costuma colar (word joiner, zero width, BOM).
final _invisible = RegExp('[​-‏⁠-⁤﻿]');
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]',
  unicode: true,
);
// Marcadores no começo da linha: "*", "-", "•", "1-", "2.", "3)", "4º" etc.
final _bullet = RegExp(r'^[\s*•·▪◦\-–—>]+');
final _number = RegExp(r'^\d+\s*[-.)º°:]*\s*');
final _mention = RegExp(r'@\S+');
final _trailingJunk = RegExp(r'[\s\-–—|,;:*]+$');
final _spaces = RegExp(r'\s+');

String _clean(String raw) {
  var s = raw.replaceAll(' ', ' ').replaceAll(_invisible, '');
  s = s.replaceAll(_emoji, ' ');
  return s.replaceAll(_spaces, ' ').trim();
}

String _cleanName(String line) {
  var s = line;
  // Repete porque às vezes vem "* 1- Fulano" ou "- ⁠Fulano".
  for (var i = 0; i < 3; i++) {
    s = s.replaceFirst(_bullet, '').replaceFirst(_number, '');
  }
  s = s.replaceAll(_mention, '');
  s = s.replaceAll(_trailingJunk, '').replaceAll(_spaces, ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Se a linha for um cabeçalho de seção, devolve a seção e o que vier depois
/// dos dois-pontos (ex.: "Goleiro: Zé Carlos").
(Role, String)? _section(String line) {
  final colon = line.indexOf(':');
  final head = (colon >= 0 ? line.substring(0, colon) : line).trim();
  final rest = colon >= 0 ? line.substring(colon + 1).trim() : '';
  final h = head.toLowerCase();
  if (h.length > 25) return null;

  final hasColon = colon >= 0;
  bool matches(List<String> words) =>
      words.any((w) => h == w || (hasColon && h.contains(w)));

  if (matches(['lista de espera', 'espera', 'suplentes', 'reservas'])) {
    return (Role.waitlist, rest);
  }
  if (matches(['goleiro', 'goleiros', 'gol', 'goleiras'])) {
    return (Role.goalkeeper, rest);
  }
  if (matches(['lista', 'jogadores', 'linha', 'confirmados'])) {
    return (Role.line, rest);
  }
  return null;
}

/// Organiza uma lista colada do WhatsApp em goleiros, linha e espera.
///
/// O que vem antes da primeira seção vira título (1ª linha) e informações
/// (local, dia, horário). Se não houver nenhuma seção, cada linha é um jogador.
ParsedList parseList(String text) {
  final lines = text.split(RegExp(r'\r?\n')).map(_clean).toList();
  final hasSections = lines.any((l) => _section(l) != null);

  final header = <String>[];
  final entries = <ParsedEntry>[];
  final seen = <String>{};
  Role? current = hasSections ? null : Role.line;

  void add(String raw, Role role) {
    final name = _cleanName(raw);
    if (name.isEmpty) return;
    if (!seen.add(name.toLowerCase())) return;
    entries.add(ParsedEntry(name, role));
  }

  for (final line in lines) {
    if (line.isEmpty) continue;
    final section = hasSections ? _section(line) : null;
    if (section != null) {
      current = section.$1;
      if (section.$2.isNotEmpty) add(section.$2, current);
      continue;
    }
    if (current == null) {
      header.add(line);
    } else {
      add(line, current);
    }
  }

  return ParsedList(
    title: header.isNotEmpty ? header.first : null,
    info: header.length > 1 ? header.skip(1).join('\n') : null,
    entries: entries,
  );
}
