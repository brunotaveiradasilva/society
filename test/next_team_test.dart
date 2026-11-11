import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:society/state.dart';

void main() {
  test('próximo time não mexe nos times já sorteados', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FutStore(await SharedPreferences.getInstance());
    final fut = store.create(DateTime(2026, 11, 12));
    fut.importText(
      [
        'Goleiro:',
        '* G1',
        '* G2',
        '* G3',
        'Lista:',
        for (var i = 1; i <= 18; i++) '$i- P$i',
      ].join('\n'),
    );
    fut.setPerTeam(5);

    // Chegam os 2 primeiros goleiros e 10 de linha.
    for (final p in fut.players.take(2)) {
      fut.setPresent(p, true);
    }
    for (final p in fut.players.skip(3).take(10)) {
      fut.setPresent(p, true);
    }
    fut.draw();
    expect(fut.teams, hasLength(2));
    expect(fut.waiting, isEmpty);
    final firstTwo = fut.teams
        .map((t) => [t.goalkeeper!.id, ...t.players.map((p) => p.id)])
        .toList();

    // Chegam mais 5 de linha e o terceiro goleiro.
    fut.setPresent(fut.players[2], true);
    for (final p in fut.players.skip(13).take(5)) {
      fut.setPresent(p, true);
    }
    expect(fut.waiting, hasLength(6));
    fut.drawNext();

    expect(fut.teams, hasLength(3));
    expect(
      fut.teams
          .take(2)
          .map((t) => [t.goalkeeper!.id, ...t.players.map((p) => p.id)])
          .toList(),
      firstTwo,
    );
    final third = fut.teams.last;
    expect(third.goalkeeper!.name, 'G3');
    expect(third.players, hasLength(5));
    expect(
      third.colorIndex,
      isNot(anyOf(fut.teams[0].colorIndex, fut.teams[1].colorIndex)),
    );
    expect(fut.waiting, isEmpty);

    // Salva e recarrega com os 3 times.
    final reloaded = Fut.fromJson(fut.toJson());
    expect(reloaded.teams, hasLength(3));

    fut.undoTeams();
    expect(fut.teams, isEmpty);
    expect(fut.waiting, hasLength(18), reason: 'quem chegou continua marcado');
  });
}
