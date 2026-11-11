import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:society/api.dart';
import 'package:society/merge.dart';
import 'package:society/state.dart';

/// API falsa em memória, com as mesmas regras da society-api.
class FakeServer {
  final grupos = <String, String>{};
  final futs =
      <String, Map<String, ({int versao, Map<String, dynamic> dados})>>{};
  var _seq = 0;

  http.Client client() => MockClient((req) async {
    final grupo = req.headers['X-Grupo'] ?? req.headers['x-grupo'];
    final path = req.url.path;
    Map<String, dynamic> body() =>
        req.body.isEmpty ? {} : jsonDecode(req.body) as Map<String, dynamic>;
    http.Response json(int status, Object? o) => http.Response(
      jsonEncode(o),
      status,
      headers: {'content-type': 'application/json'},
    );

    if (req.method == 'POST' && path == '/api/grupos') {
      final codigo = 'codigo${_seq++}';
      grupos[codigo] = body()['nome'] as String;
      futs[codigo] = {};
      return json(201, {'codigo': codigo, 'nome': grupos[codigo]});
    }
    if (grupo == null || !grupos.containsKey(grupo)) {
      return json(404, {'erro': 'Grupo não encontrado.'});
    }
    final doGrupo = futs[grupo]!;
    if (path == '/api/grupos/atual') {
      return json(200, {'codigo': grupo, 'nome': grupos[grupo]});
    }
    if (req.method == 'GET' && path == '/api/futs') {
      return json(200, [
        for (final e in doGrupo.entries)
          {'id': e.key, 'versao': e.value.versao, 'dados': e.value.dados},
      ]);
    }
    final id = Uri.decodeComponent(path.split('/').last);
    if (req.method == 'DELETE') {
      doGrupo.remove(id);
      return http.Response('', 204);
    }
    if (req.method == 'PUT') {
      final b = body();
      final versao = b['versao'] as int;
      final atual = doGrupo[id];
      if ((atual == null && versao == 0) ||
          (atual != null && atual.versao == versao)) {
        // Embaralha a ordem das chaves, como o jsonb do Postgres.
        final dados = (b['dados'] as Map<String, dynamic>);
        final reordered = {
          for (final k in dados.keys.toList().reversed) k: dados[k],
        };
        doGrupo[id] = (versao: versao + 1, dados: reordered);
        return json(200, {'id': id, 'versao': versao + 1});
      }
      if (atual == null) return json(404, {'erro': 'apagado'});
      return json(409, {
        'erro': 'conflito',
        'atual': {'id': id, 'versao': atual.versao, 'dados': atual.dados},
      });
    }
    return json(400, {'erro': '?'});
  });
}

Future<FutStore> device(FakeServer server) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return FutStore(
    prefs,
    api: Api(baseUrl: 'http://api', client: server.client()),
  );
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

  test('o que um aparelho muda aparece no outro', () async {
    final server = FakeServer();
    final eu = await device(server);
    final fut = eu.create(DateTime(2026, 11, 12));
    fut.importText('Arena\nLista:\n1- Ana\n2- Bia\n3- Cris');
    await eu.createGroup('Arena');
    await eu.syncNow();
    expect(eu.status, SyncStatus.synced);

    final ele = await device(server);
    await ele.joinGroup(eu.groupCode!);
    await ele.syncNow();
    expect(ele.futs.single.players.map((p) => p.name), ['Ana', 'Bia', 'Cris']);

    // Ele marca a Ana; eu marco a Bia ao mesmo tempo, sem ter visto a dele.
    final delefut = ele.futs.single;
    delefut.setPresent(delefut.players[0], true);
    await ele.syncNow();
    fut.setPresent(fut.players[1], true);
    await eu.syncNow();

    // Nada se perde: os dois veem Ana e Bia.
    await ele.syncNow();
    for (final d in [eu, ele]) {
      final presentes = d.futs.single.presentPlayers
          .map((p) => p.name)
          .toList();
      expect(presentes, ['Ana', 'Bia']);
    }

    // Apagar em um tira do outro.
    eu.delete(fut);
    await eu.syncNow();
    await ele.syncNow();
    expect(ele.futs, isEmpty);

    eu.dispose();
    ele.dispose();
  });
}
