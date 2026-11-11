import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:society/backend.dart';
import 'package:society/merge.dart';
import 'package:society/state.dart';

/// Grupo falso em memória, com as mesmas regras do Firestore do app. As
/// mudanças só chegam aos aparelhos quando o teste chama [deliver], para dar
/// para simular duas pessoas mexendo antes de ver a mudança da outra.
class FakeBackend implements Backend {
  final grupos = <String, String>{};
  final futsDb =
      <String, Map<String, ({int versao, Map<String, dynamic> dados})>>{};
  final _listeners = <String, List<StreamController<List<ServerFut>>>>{};
  var _seq = 0;

  /// Cópia "de ida e volta", como o Firestore: reordena as chaves.
  Map<String, dynamic> _roundTrip(Map<String, dynamic> d) {
    final copy = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    return {for (final k in copy.keys.toList().reversed) k: copy[k]};
  }

  List<ServerFut> _list(String codigo) => [
    for (final e in futsDb[codigo]!.entries)
      ServerFut(e.key, e.value.versao, _roundTrip(e.value.dados)),
  ];

  /// Entrega o estado atual do grupo para quem está ouvindo.
  Future<void> deliver() async {
    for (final e in _listeners.entries) {
      for (final c in e.value) {
        c.add(_list(e.key));
      }
    }
    await pumpEventQueue();
  }

  @override
  Future<({String codigo, String nome})> criarGrupo(String nome) async {
    final codigo = 'codigo${_seq++}';
    grupos[codigo] = nome;
    futsDb[codigo] = {};
    return (codigo: codigo, nome: nome);
  }

  @override
  Future<String> nomeDoGrupo(String codigo) async =>
      grupos[codigo] ?? (throw GroupNotFoundException());

  @override
  Stream<List<ServerFut>> futs(String codigo) {
    late final StreamController<List<ServerFut>> c;
    c = StreamController<List<ServerFut>>(
      onListen: () => c.add(_list(codigo)),
      onCancel: () => _listeners[codigo]?.remove(c),
    );
    (_listeners[codigo] ??= []).add(c);
    return c.stream;
  }

  @override
  Future<int> gravar(
    String codigo,
    String id,
    int versao,
    Map<String, dynamic> dados,
  ) async {
    final doGrupo = futsDb[codigo]!;
    final atual = doGrupo[id];
    if (atual == null) {
      if (versao != 0) throw GoneException();
      doGrupo[id] = (versao: 1, dados: _roundTrip(dados));
      return 1;
    }
    if (atual.versao != versao) {
      throw ConflictException(
        ServerFut(id, atual.versao, _roundTrip(atual.dados)),
      );
    }
    doGrupo[id] = (versao: versao + 1, dados: _roundTrip(dados));
    return versao + 1;
  }

  @override
  Future<void> apagar(String codigo, String id) async =>
      futsDb[codigo]!.remove(id);
}

Future<FutStore> device(FakeBackend backend) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return FutStore(prefs, backend: backend);
}

Future<void> settle(List<FutStore> devices) async {
  await pumpEventQueue();
  for (final d in devices) {
    await d.syncNow();
  }
}

void main() {
  test('merge3 junta mudanças em pessoas diferentes', () {
    final base = {
      'title': 'Fut',
      'players': [
        {'id': 'a', 'name': 'Ana', 'present': false},
        {'id': 'b', 'name': 'Bia', 'present': false},
      ],
    };
    final local = {
      'title': 'Fut',
      'players': [
        {'id': 'a', 'name': 'Ana', 'present': true},
        {'id': 'b', 'name': 'Bia', 'present': false},
        {'id': 'c', 'name': 'Cris', 'present': false},
      ],
    };
    final server = {
      'players': [
        {'present': true, 'id': 'b', 'name': 'Bia'},
        {'id': 'a', 'name': 'Ana', 'present': false},
      ],
      'title': 'Arena',
    };
    final merged = merge3(base, local, server) as Map;
    expect(merged['title'], 'Arena');
    final players = {
      for (final p in merged['players'] as List) p['id']: p['present'],
    };
    expect(players, {'a': true, 'b': true, 'c': false});
  });

  test('o código do grupo é longo e serve para link', () {
    final codigo = newGroupCode();
    expect(codigo, hasLength(24));
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(codigo), isTrue);
  });

  test('o que um aparelho muda aparece no outro', () async {
    final backend = FakeBackend();
    final eu = await device(backend);
    final fut = eu.create(DateTime(2026, 11, 12));
    fut.importText('Arena\nLista:\n1- Ana\n2- Bia\n3- Cris');
    await eu.createGroup('Arena');
    await settle([eu]);
    expect(eu.status, SyncStatus.synced);

    final ele = await device(backend);
    await ele.joinGroup(eu.groupCode!);
    await backend.deliver();
    await settle([eu, ele]);
    expect(ele.futs.single.players.map((p) => p.name), ['Ana', 'Bia', 'Cris']);

    // Ele marca a Ana; eu marco a Bia antes de receber a mudança dele.
    final delefut = ele.futs.single;
    delefut.setPresent(delefut.players[0], true);
    await ele.syncNow();
    fut.setPresent(fut.players[1], true);
    await eu.syncNow();

    // Nada se perde: depois que tudo chega, os dois veem Ana e Bia.
    await backend.deliver();
    await settle([eu, ele]);
    await backend.deliver();
    await settle([eu, ele]);
    for (final d in [eu, ele]) {
      final presentes = d.futs.single.presentPlayers
          .map((p) => p.name)
          .toList();
      expect(presentes, ['Ana', 'Bia']);
    }

    // Apagar em um tira do outro.
    eu.delete(fut);
    await eu.syncNow();
    await backend.deliver();
    await settle([ele]);
    expect(ele.futs, isEmpty);

    eu.dispose();
    ele.dispose();
  });

  test('link de grupo que não existe avisa', () async {
    final eu = await device(FakeBackend());
    expect(
      () => eu.groupNameFor('nao-existe'),
      throwsA(isA<GroupNotFoundException>()),
    );
    eu.dispose();
  });
}
