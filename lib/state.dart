import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'draw.dart';
import 'merge.dart';
import 'models.dart';
import 'parser.dart';

const maxTeams = 6;

/// Espaço no Firestore onde ficam os futs de todo mundo que usa o app.
const sharedGroupCode = 'ahl8-1sR0XR5Ie8yKEegOuar';

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
    f._fill(d);
    return f;
  }

  /// Troca o conteúdo pelo que veio de outro aparelho, sem disparar o salvar.
  void applyJson(Map<String, dynamic> d) {
    _fill(d);
    notifyListeners();
  }

  void _fill(Map<String, dynamic> d) {
    final parsedDate = DateTime.tryParse(d['date'] as String? ?? '');
    if (parsedDate != null) date = dateOnly(parsedDate);
    title = d['title'] as String? ?? 'Fut';
    info = d['info'] as String?;
    players
      ..clear()
      ..addAll(
        (d['players'] as List? ?? const []).map(
          (e) => Player.fromJson((e as Map).cast<String, dynamic>()),
        ),
      );
    teamCount = d['teamCount'] as int? ?? 2;
    perTeam = d['perTeam'] as int? ?? 5;
    fixedGoalkeepers = d['fixedGoalkeepers'] as bool? ?? true;
    final colors = (d['colorIndexes'] as List?)?.cast<int>();
    colorIndexes = colors != null && colors.length == maxTeams
        ? [...colors]
        : List.generate(maxTeams, (i) => i);
    pricePerPerson = (d['price'] as num?)?.toDouble();

    teams.clear();
    final draw = d['draw'] as Map?;
    if (draw != null) {
      final byId = {for (final p in players) p.id: p};
      List<Player> resolve(List ids) =>
          ids.map((id) => byId[id]).whereType<Player>().toList();
      teams.addAll([
        for (final t in (draw['teams'] as List).cast<Map>())
          DrawnTeam(
            colorIndex: t['color'] as int,
            goalkeeper: byId[t['gk']],
            players: resolve(t['players'] as List),
          ),
      ]);
    }
  }
}

/// Estado da conexão com o grupo, para mostrar na tela.
enum SyncStatus { local, synced, syncing, offline }

/// Dados de sincronia de um fut: a versão do grupo que este aparelho
/// conhece e como o fut estava nela (base para juntar mudanças).
class _SyncInfo {
  _SyncInfo({this.versao = 0, this.base, this.dirty = false});
  int versao;
  Map<String, dynamic>? base;
  bool dirty;

  Map<String, dynamic> toJson() => {
    'versao': versao,
    'base': ?base,
    'dirty': dirty,
  };

  factory _SyncInfo.fromJson(Map<String, dynamic> j) => _SyncInfo(
    versao: j['versao'] as int? ?? 0,
    base: (j['base'] as Map?)?.cast<String, dynamic>(),
    dirty: j['dirty'] as bool? ?? false,
  );
}

/// Todos os futs. Sem grupo, ficam só no aparelho. Com grupo, cada mudança
/// vai para o grupo e as mudanças dos outros chegam na hora.
class FutStore extends ChangeNotifier {
  FutStore(this._prefs, {this._backend}) {
    _load();
  }

  static const _key = 'society_futs_v1';
  static const _legacyKey = 'society_v1';
  static const _syncKey = 'society_sync_v2';
  static const retryEvery = Duration(seconds: 10);

  final SharedPreferences _prefs;
  final Backend? _backend;
  final List<Fut> _futs = [];

  String? groupCode;
  String? groupName;
  final Map<String, _SyncInfo> _sync = {};
  final Set<String> _pendingDeletes = {};

  /// Futs que já apareceram no grupo. Só esses podem ter sido apagados lá:
  /// um fut que ainda não apareceu pode só não ter chegado.
  final Set<String> _seen = {};
  SyncStatus status = SyncStatus.local;

  StreamSubscription<List<ServerFut>>? _sub;
  List<ServerFut>? _fromServer;
  bool _heard = false;
  Timer? _retry;
  Timer? _pushDebounce;
  Future<void>? _running;
  bool _again = false;

  /// Dá para compartilhar (no Android ainda não tem grupo).
  bool get canShare => _backend != null;
  bool get inGroup => groupCode != null;

  /// Mais recente primeiro.
  List<Fut> get futs => [..._futs]..sort((a, b) => b.date.compareTo(a.date));

  Fut? get latest => _futs.isEmpty ? null : futs.first;

  Fut? byId(String id) {
    for (final f in _futs) {
      if (f.id == id) return f;
    }
    return null;
  }

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
    _changedFut(f);
    return f;
  }

  void delete(Fut f) {
    _futs.remove(f);
    f.onSave = null;
    final info = _sync.remove(f.id);
    if (inGroup && info != null && info.versao > 0) _pendingDeletes.add(f.id);
    _changed();
    if (inGroup) _schedulePush();
  }

  void restore(Fut f) {
    _pendingDeletes.remove(f.id);
    _attach(f);
    _futs.add(f);
    _changedFut(f);
  }

  void _attach(Fut f) => f.onSave = () => _changedFut(f);

  void _changedFut(Fut f) {
    if (inGroup) {
      (_sync[f.id] ??= _SyncInfo()).dirty = true;
      _schedulePush();
    }
    _changed();
  }

  void _changed() {
    notifyListeners();
    _saveLocal();
  }

  void _saveLocal() {
    _prefs.setString(_key, jsonEncode(_futs.map((f) => f.toJson()).toList()));
    _prefs.setString(
      _syncKey,
      jsonEncode({
        'grupo': ?groupCode,
        'nome': ?groupName,
        'futs': {for (final e in _sync.entries) e.key: e.value.toJson()},
        'apagar': _pendingDeletes.toList(),
      }),
    );
  }

  void _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as List)) {
          final f = Fut.fromJson((e as Map).cast<String, dynamic>());
          _attach(f);
          _futs.add(f);
        }
      } else {
        // A versão anterior guardava um fut só: ele vira o primeiro da lista.
        final legacy = _prefs.getString(_legacyKey);
        if (legacy != null) {
          final f = Fut.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
          _attach(f);
          _futs.add(f);
          _saveLocal();
          _prefs.remove(_legacyKey);
        }
      }

      final sync = _prefs.getString(_syncKey);
      if (sync != null && canShare) {
        final s = jsonDecode(sync) as Map<String, dynamic>;
        groupCode = s['grupo'] as String?;
        groupName = s['nome'] as String?;
        for (final e in (s['futs'] as Map? ?? const {}).entries) {
          _sync[e.key as String] = _SyncInfo.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          );
        }
        _pendingDeletes.addAll(
          (s['apagar'] as List? ?? const []).cast<String>(),
        );
      }
    } catch (e) {
      debugPrint('Falha ao ler dados salvos: $e');
    }
    // O que já tinha versão no grupo já foi visto lá.
    _seen.addAll(
      _sync.entries.where((e) => e.value.versao > 0).map((e) => e.key),
    );
    // Todo mundo usa o mesmo espaço: quem abre o app vê e edita os mesmos
    // futs. Na primeira vez, os futs que estavam só no aparelho vão junto.
    if (canShare) {
      if (groupCode == sharedGroupCode) {
        _connect();
      } else {
        _enterGroup(sharedGroupCode, 'Society');
      }
    }
  }

  // ---------- Espaço compartilhado ----------

  void _enterGroup(String codigo, String nome) {
    groupCode = codigo;
    groupName = nome;
    _sync.clear();
    _pendingDeletes.clear();
    _seen.clear();
    for (final f in _futs) {
      _sync[f.id] = _SyncInfo(dirty: true);
    }
    _changed();
    _connect();
  }

  // ---------- Sincronia ----------

  void _connect() {
    _disconnect();
    final code = groupCode!;
    _heard = false;
    _setStatus(SyncStatus.syncing);
    _sub = _backend!
        .futs(code)
        .listen(
          (list) {
            _heard = true;
            _fromServer = list;
            syncNow();
          },
          onError: (Object e) {
            debugPrint('Sem conexão com o grupo: $e');
            _setStatus(SyncStatus.offline);
          },
        );
    // Tenta de novo o que ficou pendente (sem internet, por exemplo).
    _retry = Timer.periodic(retryEvery, (_) {
      if (_pendingDeletes.isNotEmpty || _sync.values.any((s) => s.dirty)) {
        syncNow();
      }
    });
    syncNow();
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _retry?.cancel();
    _pushDebounce?.cancel();
    _fromServer = null;
  }

  /// O app voltou para a tela: tenta mandar o que ficou pendente.
  void resume() {
    if (inGroup) syncNow();
  }

  void pause() {}

  void _schedulePush() {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 400), syncNow);
  }

  void _setStatus(SyncStatus s) {
    if (status == s) return;
    status = s;
    notifyListeners();
  }

  /// Junta o que chegou do grupo e manda o que mudou aqui.
  ///
  /// Se já tem uma rodada em andamento, marca para repetir e espera as duas.
  Future<void> syncNow() {
    if (groupCode == null) return Future.value();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _syncLoop().whenComplete(() => _running = null);
  }

  Future<void> _syncLoop() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again && groupCode != null);
  }

  Future<void> _syncOnce() async {
    final code = groupCode;
    if (code == null) return;
    try {
      final incoming = _fromServer;
      _fromServer = null;
      if (incoming != null) _applyServer(incoming);

      final hasLocal =
          _pendingDeletes.isNotEmpty || _sync.values.any((s) => s.dirty);
      if (hasLocal) {
        _setStatus(SyncStatus.syncing);
        await _pushDeletes(code);
        await _pushDirty(code);
      }
      // Só fica "sincronizado" depois que o grupo respondeu pelo menos uma vez.
      if (_heard) _setStatus(SyncStatus.synced);
    } on GoneException {
      // Tratado por fut em _pushDirty.
    } catch (e) {
      debugPrint('Falha ao sincronizar: $e');
      _setStatus(SyncStatus.offline);
    } finally {
      _saveLocal();
    }
  }

  Future<void> _pushDeletes(String code) async {
    for (final id in [..._pendingDeletes]) {
      await _backend!.apagar(code, id);
      _pendingDeletes.remove(id);
    }
  }

  void _applyServer(List<ServerFut> list) {
    var changed = false;
    final onServer = <String>{};

    for (final s in list) {
      onServer.add(s.id);
      _seen.add(s.id);
      if (_pendingDeletes.contains(s.id)) continue;
      final local = byId(s.id);
      final info = _sync[s.id];
      if (local == null) {
        final f = Fut.fromJson({...s.dados, 'id': s.id});
        _attach(f);
        _futs.add(f);
        _sync[s.id] = _SyncInfo(versao: s.versao, base: s.dados);
        changed = true;
      } else if (info == null || s.versao > info.versao) {
        _receive(local, info ?? (_sync[s.id] = _SyncInfo()), s);
        changed = true;
      }
    }

    // Apagados em outro aparelho: estavam no grupo e sumiram.
    for (final f in [..._futs]) {
      if (_seen.contains(f.id) && !onServer.contains(f.id)) {
        _futs.remove(f);
        f.onSave = null;
        _sync.remove(f.id);
        _seen.remove(f.id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Chegou uma versão nova do grupo. Sem mudança pendente aqui, ela
  /// substitui a local; com mudança pendente, as duas são juntadas.
  void _receive(Fut local, _SyncInfo info, ServerFut s) {
    if (info.dirty) {
      final merged = merge3(info.base, local.toJson(), s.dados);
      local.applyJson((merged as Map).cast<String, dynamic>());
    } else {
      local.applyJson(s.dados);
    }
    info
      ..versao = s.versao
      ..base = s.dados;
  }

  Future<void> _pushDirty(String code) async {
    for (final f in [..._futs]) {
      final info = _sync[f.id] ??= _SyncInfo(dirty: true);
      if (!info.dirty) continue;
      // Cada conflito junta as mudanças e tenta de novo.
      for (var attempt = 0; attempt < 3; attempt++) {
        final sent = f.toJson();
        try {
          final versao = await _backend!.gravar(code, f.id, info.versao, sent);
          info
            ..versao = versao
            ..base = sent
            // Mudou de novo enquanto gravava? Continua pendente.
            ..dirty = !sameJson(f.toJson(), sent);
          break;
        } on ConflictException catch (c) {
          _receive(f, info, c.atual);
          info.dirty = true;
          notifyListeners();
        } on GoneException {
          _futs.remove(f);
          f.onSave = null;
          _sync.remove(f.id);
          notifyListeners();
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
