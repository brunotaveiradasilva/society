import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:society/draw.dart';
import 'package:society/models.dart';
import 'package:society/parser.dart';

const whatsapp = '''Arena Central
Rua das Flores, 100 - Quinta-feira - 20:00h.

Lista:
🥅 Goleiro:
* Zé Carlos
* ⁠Tiago
-
-

Lista:
1- Lucas Almeida
2- Rafael Souza
3- Paraná
4- Otávio
5- Diego
6- Renato (Primo Diego)
7- Marcelo
8- Vitor
9-  Caio - @~Caio
10- André Lima
11- Neto
12- Igor
13- Felipe Rocha
14- Thiago Nunes
15- Beto Show
16- Duda
17- pastel
18- Leo Santos
19- Hugo
20- tanaka

Lista de espera:
1- Samuel 
2-  Davi primo do Zé
3-
4-
''';

void main() {
  test('organiza a lista do WhatsApp', () {
    final r = parseList(whatsapp);
    expect(r.title, 'Arena Central');
    expect(r.info, 'Rua das Flores, 100 - Quinta-feira - 20:00h.');

    List<String> names(Role role) =>
        r.entries.where((e) => e.role == role).map((e) => e.name).toList();

    expect(names(Role.goalkeeper), ['Zé Carlos', 'Tiago']);
    final line = names(Role.line);
    expect(line, hasLength(20));
    expect(line.first, 'Lucas Almeida');
    expect(line, contains('Caio'));
    expect(line, contains('Renato (Primo Diego)'));
    expect(line, contains('Pastel'));
    expect(line.last, 'Tanaka');
    expect(names(Role.waitlist), ['Samuel', 'Davi primo do Zé']);
  });

  test('lista solta sem seções vira tudo linha', () {
    final r = parseList('João\n2. Maria\n- Zé\n\nJoão');
    expect(r.entries.map((e) => e.name), ['João', 'Maria', 'Zé']);
    expect(r.entries.every((e) => e.role == Role.line), isTrue);
    expect(r.title, isNull);
  });

  test('goleiro na mesma linha do cabeçalho', () {
    final r = parseList('Goleiros: Tião\nLista:\n1- Ana');
    expect(r.entries.map((e) => e.toString()), ['goalkeeper:Tião', 'line:Ana']);
  });

  test('sorteio respeita vagas, goleiros e banco', () {
    final pool = [
      for (var i = 0; i < 2; i++)
        Player(id: 'g$i', name: 'G$i', role: Role.goalkeeper),
      for (var i = 0; i < 13; i++) Player(id: 'p$i', name: 'P$i'),
    ];
    final r = drawTeams(
      pool: pool,
      teamCount: 3,
      perTeam: 4,
      colorIndexes: [0, 1, 2],
      random: Random(1),
    );
    expect(r.teams, hasLength(3));
    expect(r.teams.where((t) => t.goalkeeper != null), hasLength(2));
    expect(r.teams.every((t) => t.players.length == 4), isTrue);
    expect(r.bench, hasLength(1));
    final all = [
      ...r.teams.expand((t) => [?t.goalkeeper, ...t.players]),
      ...r.bench,
    ];
    expect(all.map((p) => p.id).toSet(), hasLength(15));
  });
}
