import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:society/backend.dart';
import 'package:society/merge.dart';
import 'package:society/state.dart';

/// Firestore falso em memória, com as mesmas regras do app. As mudanças só
/// chegam aos aparelhos quando o teste chama [deliver], para dar para simular
/// duas pessoas mexendo antes de ver a mudança da outra.
class FakeBackend implements Backend {
  final futsDb =
      <String, Map<String, ({int versao, Map<String, dynamic> dados})>>{};
  final _listeners = <String, List<StreamController<List<ServerFut>>>>{};

  Map<String, ({int versao, Map<String, dynamic> dados})> _doGrupo(
    String codigo,
  ) => futsDb[codigo] ??= {};

  /// Cópia "de ida e volta", como o Firestore: reordena as chaves.
  Map<String, dynamic> _roundTrip(Map<String, dynamic> d) {
    final copy = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    return {for (final k in copy.keys.toList().reversed) k: copy[k]};
  }

  List<ServerFut> _list(String codigo) => [
    for (final e in _doGrupo(codigo).entries)
      ServerFut(e.key, e.value.versao, _roundTrip(e.value.dados)),
  ];

  /// Entrega o estado atual para quem está ouvindo.
  Future<void> deliver() async {
    for (final e in _listeners.entries) {
      for (final c in e.value) {
        c.add(_list(e.key));
      }
    }
    await pumpEventQueue();
  }

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
    final doGrupo = _doGrupo(codigo);
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
      _doGrupo(codigo).remove(id);
}

/// Um aparelho novo (armazenamento vazio, ou com [saved]).
Future<FutStore> device(
  FakeBackend backend, [
  Map<String, Object> saved = const {},
]) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(saved);
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

  test('todo mundo vê e edita os mesmos futs', () async {
    final backend = FakeBackend();
    final eu = await device(backend);
    expect(eu.groupCode, sharedGroupCode);
    final fut = eu.create(DateTime(2026, 11, 12));
    fut.importText('Arena\nLista:\n1- Ana\n2- Bia\n3- Cris');
    await settle([eu]);
    expect(eu.status, SyncStatus.synced);

    // Outra pessoa abre o app pela primeira vez: já vê o fut.
    final ele = await device(backend);
    await settle([ele]);
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

  test('futs que estavam só no aparelho sobem na primeira vez', () async {
    final backend = FakeBackend();
    final antigo = {
      'id': 'local-1',
      'date': '2026-11-05T00:00:00.000',
      'title': 'Fut antigo',
      'players': [
        {'id': 'x', 'name': 'Xande', 'role': 'line'},
      ],
    };
    final eu = await device(backend, {
      'flutter.society_futs_v1': jsonEncode([antigo]),
    });
    await settle([eu]);
    expect(backend.futsDb[sharedGroupCode]!.keys, ['local-1']);

    final ele = await device(backend);
    await settle([ele]);
    expect(ele.futs.single.title, 'Fut antigo');

    eu.dispose();
    ele.dispose();
  });
}
