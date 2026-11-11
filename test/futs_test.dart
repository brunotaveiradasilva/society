import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:society/models.dart';
import 'package:society/state.dart';

void main() {
  test('dado da versão antiga vira o primeiro fut', () async {
    SharedPreferences.setMockInitialValues({
      'society_v1': jsonEncode({
        'title': 'Arena Central',
        'players': [
          {
            'id': 'a',
            'name': 'Zé',
            'role': 'goalkeeper',
            'present': true,
            'paid': true,
          },
        ],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = FutStore(prefs);
    expect(store.futs, hasLength(1));
    expect(store.futs.first.title, 'Arena Central');
    expect(store.futs.first.players.single.paid, isTrue);
    expect(prefs.getString('society_v1'), isNull);

    // Recarregar lê da chave nova.
    expect(FutStore(prefs).futs.single.players.single.name, 'Zé');
  });

  test('novo fut repete a lista com chegada e pagamento zerados', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FutStore(await SharedPreferences.getInstance());
    final first = store.create(DateTime(2026, 11, 12));
    first.importText('Arena\nLista:\n1- Ana\n2- Bia\nEspera:\n1- Cris');
    first.setAllPresent(true);
    first.setPaid(first.players.first, true);
    first.setTeamCount(3);

    expect(store.suggestedDate().isAfter(DateTime(2026, 11, 18)), isTrue);
    final next = store.create(DateTime(2026, 11, 19), copyFrom: first);

    expect(store.futs.first, same(next));
    expect(next.players.map((p) => p.name), ['Ana', 'Bia', 'Cris']);
    expect(next.byRole(Role.waitlist).single.name, 'Cris');
    expect(next.presentCount, 0);
    expect(next.paidCount, 0);
    expect(next.teamCount, 3);
    expect(first.paidCount, 1, reason: 'o fut antigo continua igual');
    expect(weekdayDate(next.date), 'Quinta, 19/11');
  });
}
