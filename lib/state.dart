import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'draw.dart';
import 'models.dart';
import 'parser.dart';

const maxTeams = 6;

int _idSeq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _weekdays = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

String two(int n) => n.toString().padLeft(2, '0');

/// "12/11"
String shortDate(DateTime d) => '${two(d.day)}/${two(d.month)}';

/// "Quinta, 12/11"
String weekdayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${shortDate(d)}';

/// Um jogo de um dia: lista, chegadas, pagamentos e sorteio.
class Fut extends ChangeNotifier {
  Fut({required this.id, required DateTime date}) : date = dateOnly(date);

  final String id;
  DateTime date;
  String title = 'Fut';
  String? info;
  final List<Player> players = [];

  int teamCount = 2;
  int perTeam = 5;
  bool fixedGoalkeepers = true;
  List<int> colorIndexes = List.generate(maxTeams, (i) => i);
  double? pricePerPerson;

  /// Times já sorteados. Ficam travados: sortear o próximo não mexe neles.
  final List<DrawnTeam> teams = [];

  /// Quem chegou e ainda não está em nenhum time, na ordem da lista.
  List<Player> get waiting {
    final inTeams = {
      for (final t in teams) ...[
        if (t.goalkeeper != null) t.goalkeeper!.id,
        ...t.players.map((p) => p.id),
      ],
    };
    return players.where((p) => p.present && !inTeams.contains(p.id)).toList();
  }

  DrawResult? get lastDraw =>
      teams.isEmpty ? null : DrawResult(teams: teams, bench: waiting);

  /// Cor do próximo time: a próxima da sequência escolhida que ainda não foi
  /// usada; se acabarem, qualquer cor livre.
  int get _nextColor {
    final used = teams.map((t) => t.colorIndex).toSet();
    for (final c in [
      ...colorIndexes,
      ...List.generate(bibColors.length, (i) => i),
    ]) {
      if (!used.contains(c)) return c;
    }
    return teams.length % bibColors.length;
  }

  /// Chamado a cada mudança para salvar.
  VoidCallback? onSave;

  Iterable<Player> byRole(Role role) => players.where((p) => p.role == role);
  List<Player> get presentPlayers => players.where((p) => p.present).toList();
  int get presentCount => players.where((p) => p.present).length;
  int get paidCount => players.where((p) => p.paid).length;
  int get presentGoalkeepers =>
      players.where((p) => p.present && p.role == Role.goalkeeper).length;

  /// Vagas de linha disponíveis contra quem chegou (sem contar goleiros fixos).
  int get lineSpots => teamCount * perTeam;
  int get presentForLine => fixedGoalkeepers
      ? presentCount - presentGoalkeepers.clamp(0, teamCount)
      : presentCount;

  /// Novo fut com a mesma lista e configuração, mas ninguém chegou nem pagou.
  Fut copyFor(DateTime newDate) {
    final f = Fut(id: newId(), date: newDate)
      ..title = title
      ..info = info
      ..teamCount = teamCount
      ..perTeam = perTeam
      ..fixedGoalkeepers = fixedGoalkeepers
      ..colorIndexes = [...colorIndexes]
      ..pricePerPerson = pricePerPerson;
    f.players.addAll(
      players.map((p) => Player(id: newId(), name: p.name, role: p.role)),
    );
    return f;
  }

  // ---------- Lista ----------

  /// Importa uma lista colada. Retorna quantas pessoas entraram.
  int importText(String text, {bool replace = true}) {
    final parsed = parseList(text);
    if (replace) {
      players.clear();
      teams.clear();
      if (parsed.title != null) {
        title = parsed.title!;
        info = parsed.info;
      }
    }
    final existing = players.map((p) => p.name.toLowerCase()).toSet();
    var added = 0;
    for (final e in parsed.entries) {
      if (existing.contains(e.name.toLowerCase())) continue;
      players.add(Player(id: newId(), name: e.name, role: e.role));
      added++;
    }
    _changed();
    return added;
  }

  void addPlayer(String name, Role role) {
    final n = name.trim();
    if (n.isEmpty) return;
    players.add(Player(id: newId(), name: n, role: role));
    _changed();
  }

  void removePlayer(Player p) {
    players.remove(p);
    _changed();
  }

  void insertPlayer(int index, Player p) {
    players.insert(index.clamp(0, players.length), p);
    _changed();
  }

  void rename(Player p, String name) {
    if (name.trim().isEmpty) return;
    p.name = name.trim();
    _changed();
  }

  void setRole(Player p, Role role) {
    p.role = role;
    _changed();
  }

  void setTitle(String t, String? i) {
    title = t.trim().isEmpty ? 'Fut' : t.trim();
    info = (i == null || i.trim().isEmpty) ? null : i.trim();
    _changed();
  }

  void setDate(DateTime d) {
    date = dateOnly(d);
    _changed();
  }

  // ---------- Chegada e pagamento ----------

  void setPresent(Player p, bool v) {
    p.present = v;
    if (!v) p.paid = false;
    _changed();
  }

  void setAllPresent(bool v) {
    for (final p in players) {
      p.present = v;
      if (!v) p.paid = false;
    }
    _changed();
  }

  void setPaid(Player p, bool v) {
    p.paid = v;
    if (v) p.present = true;
    _changed();
  }

  void setPrice(double? v) {
    pricePerPerson = v;
    _changed();
  }

  /// Ninguém chegou ainda e ninguém pagou.
  void resetChecks() {
    for (final p in players) {
      p.present = false;
      p.paid = false;
    }
    teams.clear();
    _changed();
  }

  // ---------- Sorteio ----------

  void setTeamCount(int v) {
    teamCount = v.clamp(2, maxTeams);
    _changed();
  }

  void setPerTeam(int v) {
    perTeam = v.clamp(1, 11);
    _changed();
  }

  void setFixedGoalkeepers(bool v) {
    fixedGoalkeepers = v;
    _changed();
  }

  void setTeamColor(int team, int colorIndex) {
    final other = colorIndexes.indexOf(colorIndex);
    // Se outro time já usa a cor, troca as duas.
    if (other >= 0 && other != team) colorIndexes[other] = colorIndexes[team];
    colorIndexes[team] = colorIndex;
    _changed();
  }

  /// Primeiro sorteio: monta [teamCount] times com quem chegou.
  void draw() {
    if (teams.isNotEmpty) return drawNext();
    final result = drawTeams(
      pool: presentPlayers,
      teamCount: teamCount,
      perTeam: perTeam,
      colorIndexes: colorIndexes,
      fixedGoalkeepers: fixedGoalkeepers,
    );
    teams.addAll(result.teams);
    _changed();
  }

  /// Sorteia mais um time só com quem está esperando. Os times já
  /// sorteados continuam iguais.
  void drawNext() {
    final pool = waiting;
    if (pool.isEmpty) return;
    teams.add(
      drawNextTeam(
        waiting: pool,
        perTeam: perTeam,
        colorIndex: _nextColor,
        fixedGoalkeepers: fixedGoalkeepers,
      ),
    );
    _changed();
  }

  /// Apaga todos os times; quem chegou continua marcado.
  void undoTeams() {
    teams.clear();
    _changed();
  }

  void _changed() {
    notifyListeners();
    onSave?.call();
  }

  // ---------- JSON ----------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'info': info,
      'players': players.map((p) => p.toJson()).toList(),
      'teamCount': teamCount,
      'perTeam': perTeam,
      'fixedGoalkeepers': fixedGoalkeepers,
      'colorIndexes': colorIndexes,
      'price': pricePerPerson,
      if (teams.isNotEmpty)
        'draw': {
          'teams': [
            for (final t in teams)
              {
                'color': t.colorIndex,
                'gk': t.goalkeeper?.id,
                'players': t.players.map((p) => p.id).toList(),
              },
          ],
        },
    };
  }

  factory Fut.fromJson(Map<String, dynamic> d) {
    final f = Fut(
      id: d['id'] as String? ?? newId(),
      date: DateTime.tryParse(d['date'] as String? ?? '') ?? DateTime.now(),
    );
    f.title = d['title'] as String? ?? 'Fut';
    f.info = d['info'] as String?;
    f.players.addAll(
      (d['players'] as List? ?? const []).map(
        (e) => Player.fromJson(e as Map<String, dynamic>),
      ),
    );
    f.teamCount = d['teamCount'] as int? ?? 2;
    f.perTeam = d['perTeam'] as int? ?? 5;
    f.fixedGoalkeepers = d['fixedGoalkeepers'] as bool? ?? true;
    final colors = (d['colorIndexes'] as List?)?.cast<int>();
    if (colors != null && colors.length == maxTeams) f.colorIndexes = colors;
    f.pricePerPerson = (d['price'] as num?)?.toDouble();

    final draw = d['draw'] as Map<String, dynamic>?;
    if (draw != null) {
      final byId = {for (final p in f.players) p.id: p};
      List<Player> resolve(List ids) =>
          ids.map((id) => byId[id]).whereType<Player>().toList();
      f.teams.addAll([
        for (final t in (draw['teams'] as List).cast<Map<String, dynamic>>())
          DrawnTeam(
            colorIndex: t['color'] as int,
            goalkeeper: byId[t['gk']],
            players: resolve(t['players'] as List),
          ),
      ]);
    }
    return f;
  }
}

/// Todos os futs salvos no aparelho.
class FutStore extends ChangeNotifier {
  FutStore(this._prefs) {
    _load();
  }

  static const _key = 'society_futs_v1';
  static const _legacyKey = 'society_v1';
  final SharedPreferences _prefs;
  final List<Fut> _futs = [];

  /// Mais recente primeiro.
  List<Fut> get futs => [..._futs]..sort((a, b) => b.date.compareTo(a.date));

  Fut? get latest => _futs.isEmpty ? null : futs.first;

  /// Sugestão de data: uma semana depois do último fut, ou hoje.
  DateTime suggestedDate() {
    final today = dateOnly(DateTime.now());
    final last = latest;
    if (last == null) return today;
    final next = last.date.add(const Duration(days: 7));
    return next.isBefore(today) ? today : next;
  }

  Fut create(DateTime date, {Fut? copyFrom}) {
    final f = copyFrom?.copyFor(date) ?? Fut(id: newId(), date: date);
    _attach(f);
    _futs.add(f);
    _changed();
    return f;
  }

  void delete(Fut f) {
    _futs.remove(f);
    f.onSave = null;
    _changed();
  }

  void restore(Fut f) {
    _attach(f);
    _futs.add(f);
    _changed();
  }

  void _attach(Fut f) => f.onSave = _changed;

  void _changed() {
    notifyListeners();
    _prefs.setString(_key, jsonEncode(_futs.map((f) => f.toJson()).toList()));
  }

  void _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as List)) {
          final f = Fut.fromJson(e as Map<String, dynamic>);
          _attach(f);
          _futs.add(f);
        }
        return;
      }
      // A versão anterior guardava um fut só: ele vira o primeiro da lista.
      final legacy = _prefs.getString(_legacyKey);
      if (legacy != null) {
        final f = Fut.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
        _attach(f);
        _futs.add(f);
        _changed();
        _prefs.remove(_legacyKey);
      }
    } catch (e) {
      debugPrint('Falha ao ler dados salvos: $e');
    }
  }
}
