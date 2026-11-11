/// Junta duas versões de um fut que mudaram ao mesmo tempo a partir de uma
/// base comum (a última versão que os dois viram).
///
/// Para cada campo: se só um lado mudou, vale esse lado; se os dois mudaram,
/// entra no detalhe (objetos campo a campo, listas de jogadores pessoa a
/// pessoa pelo `id`). Quando os dois mudaram o mesmo valor, vale o local.
Object? merge3(Object? base, Object? local, Object? server) {
  if (_same(local, base)) return server;
  if (_same(server, base)) return local;
  if (_same(local, server)) return local;

  if (local is Map && server is Map) {
    final b = base is Map ? base : const {};
    final out = <String, Object?>{};
    for (final key in {...local.keys, ...server.keys}.cast<String>()) {
      final v = merge3(b[key], local[key], server[key]);
      if (v != null) out[key] = v;
    }
    return out;
  }

  if (local is List && server is List && _byId(local) && _byId(server)) {
    final b = base is List && _byId(base) ? base : const [];
    return _mergeById(b, local, server);
  }

  return local;
}

/// Igualdade de JSON sem depender da ordem das chaves (o Postgres reordena).
bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_same(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

/// Mesmo conteúdo, ignorando a ordem das chaves.
bool sameJson(Object? a, Object? b) => _same(a, b);

bool _byId(List list) => list.every((e) => e is Map && e['id'] is String);

String _id(Object? e) => (e as Map)['id'] as String;

List<Object?> _mergeById(List base, List local, List server) {
  final baseById = {for (final e in base) _id(e): e};
  final localById = {for (final e in local) _id(e): e};
  final serverById = {for (final e in server) _id(e): e};

  bool keep(String id) {
    final inBase = baseById.containsKey(id);
    final inLocal = localById.containsKey(id);
    final inServer = serverById.containsKey(id);
    if (inLocal && inServer) return true;
    // Só de um lado: novo (não estava na base) fica; removido do outro lado sai.
    return !inBase;
  }

  final out = <Object?>[];
  final seen = <String>{};
  // Ordem do servidor primeiro, depois quem foi adicionado aqui.
  for (final e in [...server, ...local]) {
    final id = _id(e);
    if (!seen.add(id) || !keep(id)) continue;
    out.add(merge3(baseById[id], localById[id], serverById[id]));
  }
  return out;
}
