import 'dart:math';

import 'models.dart';

class DrawnTeam {
  DrawnTeam({required this.colorIndex, this.goalkeeper, required this.players});
  final int colorIndex;
  final Player? goalkeeper;
  final List<Player> players;

  BibColor get bib => bibColors[colorIndex % bibColors.length];
}

class DrawResult {
  DrawResult({required this.teams, required this.bench});
  final List<DrawnTeam> teams;

  /// Quem sobrou: fica de fora e entra na próxima.
  final List<Player> bench;
}

/// Sorteia os times entre os jogadores de [pool].
///
/// [perTeam] conta só jogadores de linha. Com [fixedGoalkeepers], cada time
/// recebe no máximo um goleiro e os goleiros que sobrarem vão para o fim da
/// fila da linha (só jogam na linha se faltar gente).
DrawResult drawTeams({
  required List<Player> pool,
  required int teamCount,
  required int perTeam,
  required List<int> colorIndexes,
  bool fixedGoalkeepers = true,
  Random? random,
}) {
  final rng = random ?? Random();
  final keepers = <Player>[];
  final line = <Player>[];
  for (final p in pool) {
    if (fixedGoalkeepers && p.role == Role.goalkeeper) {
      keepers.add(p);
    } else {
      line.add(p);
    }
  }
  keepers.shuffle(rng);
  line.shuffle(rng);

  final teamKeepers = keepers.take(teamCount).toList();
  line.addAll(keepers.skip(teamCount));

  final teamPlayers = List.generate(teamCount, (_) => <Player>[]);
  final spots = teamCount * perTeam;
  for (var i = 0; i < line.length && i < spots; i++) {
    teamPlayers[i % teamCount].add(line[i]);
  }

  return DrawResult(
    teams: [
      for (var t = 0; t < teamCount; t++)
        DrawnTeam(
          colorIndex: colorIndexes[t],
          goalkeeper: t < teamKeepers.length ? teamKeepers[t] : null,
          players: teamPlayers[t],
        ),
    ],
    bench: line.length > spots ? line.sublist(spots) : [],
  );
}

/// Sorteia um time novo só entre quem está esperando, sem mexer nos times
/// que já existem. Goleiro esperando vai para o gol; goleiros a mais vão para
/// o fim da fila da linha.
DrawnTeam drawNextTeam({
  required List<Player> waiting,
  required int perTeam,
  required int colorIndex,
  bool fixedGoalkeepers = true,
  Random? random,
}) {
  final rng = random ?? Random();
  final keepers = <Player>[];
  final line = <Player>[];
  for (final p in waiting) {
    if (fixedGoalkeepers && p.role == Role.goalkeeper) {
      keepers.add(p);
    } else {
      line.add(p);
    }
  }
  keepers.shuffle(rng);
  line.shuffle(rng);
  line.addAll(keepers.skip(1));
  return DrawnTeam(
    colorIndex: colorIndex,
    goalkeeper: keepers.isEmpty ? null : keepers.first,
    players: line.take(perTeam).toList(),
  );
}

String drawToText(DrawResult result, {String? title}) {
  final b = StringBuffer('⚽ Times sorteados');
  if (title != null && title.isNotEmpty) b.write(' – $title');
  b.writeln();
  for (final team in result.teams) {
    b
      ..writeln()
      ..writeln('${team.bib.emoji} Time ${team.bib.name}');
    if (team.goalkeeper != null) b.writeln('🧤 ${team.goalkeeper!.name}');
    for (var i = 0; i < team.players.length; i++) {
      b.writeln('${i + 1}. ${team.players[i].name}');
    }
  }
  if (result.bench.isNotEmpty) {
    b
      ..writeln()
      ..writeln('⏳ Esperando');
    for (var i = 0; i < result.bench.length; i++) {
      b.writeln('${i + 1}. ${result.bench[i].name}');
    }
  }
  return b.toString().trimRight();
}
