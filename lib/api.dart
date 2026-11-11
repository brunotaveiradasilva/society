import 'dart:convert';

import 'package:http/http.dart' as http;

/// Endereço da API. No build publicado vem de `--dart-define=API_URL=...`.
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

class ServerFut {
  ServerFut(this.id, this.versao, this.dados);
  final String id;
  final int versao;
  final Map<String, dynamic> dados;

  factory ServerFut.fromJson(Map<String, dynamic> j) => ServerFut(
    j['id'] as String,
    j['versao'] as int,
    (j['dados'] as Map).cast<String, dynamic>(),
  );
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Alguém gravou o fut antes: [atual] é o que está no servidor.
class ConflictException implements Exception {
  ConflictException(this.atual);
  final ServerFut atual;
}

/// O fut foi apagado em outro aparelho.
class GoneException implements Exception {}

class Api {
  Api({String baseUrl = apiUrl, http.Client? client})
    : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _base;
  final http.Client _client;
  String? _etag;
  String? _lastBody;

  Uri _uri(String path) => Uri.parse('$_base$path');

  Map<String, String> _headers(String? grupo) => {
    'Content-Type': 'application/json',
    'X-Grupo': ?grupo,
  };

  Never _fail(http.Response r) {
    String msg = 'Erro ${r.statusCode} na API';
    try {
      msg = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['erro'] as String;
    } catch (_) {}
    throw ApiException(r.statusCode, msg);
  }

  Object? _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<({String codigo, String nome})> criarGrupo(String nome) async {
    final r = await _client.post(
      _uri('/api/grupos'),
      headers: _headers(null),
      body: jsonEncode({'nome': nome}),
    );
    if (r.statusCode != 201) _fail(r);
    final j = _json(r) as Map;
    return (codigo: j['codigo'] as String, nome: j['nome'] as String);
  }

  Future<String> nomeDoGrupo(String codigo) async {
    final r = await _client.get(
      _uri('/api/grupos/atual'),
      headers: _headers(codigo),
    );
    if (r.statusCode != 200) _fail(r);
    return (_json(r) as Map)['nome'] as String;
  }

  /// Lista os futs do grupo. Devolve `null` quando nada mudou desde a última
  /// vez (304, ou o navegador devolveu a mesma resposta do cache).
  Future<List<ServerFut>?> listar(String codigo) async {
    final r = await _client.get(
      _uri('/api/futs'),
      headers: {..._headers(codigo), 'If-None-Match': ?_etag},
    );
    if (r.statusCode == 304) return null;
    if (r.statusCode != 200) _fail(r);
    _etag = r.headers['etag'];
    final body = utf8.decode(r.bodyBytes);
    if (body == _lastBody) return null;
    _lastBody = body;
    return (jsonDecode(body) as List)
        .map((e) => ServerFut.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Esquece o que já baixou, para a próxima [listar] trazer tudo.
  void forget() {
    _etag = null;
    _lastBody = null;
  }

  /// Grava o fut se [versao] ainda for a do servidor. Devolve a versão nova.
  Future<int> gravar(
    String codigo,
    String id,
    int versao,
    Map<String, dynamic> dados,
  ) async {
    final r = await _client.put(
      _uri('/api/futs/${Uri.encodeComponent(id)}'),
      headers: _headers(codigo),
      body: jsonEncode({'versao': versao, 'dados': dados}),
    );
    if (r.statusCode == 200) return (_json(r) as Map)['versao'] as int;
    if (r.statusCode == 409) {
      final atual = (_json(r) as Map)['atual'] as Map;
      throw ConflictException(
        ServerFut.fromJson(atual.cast<String, dynamic>()),
      );
    }
    if (r.statusCode == 404 && versao > 0) throw GoneException();
    _fail(r);
  }

  Future<void> apagar(String codigo, String id) async {
    final r = await _client.delete(
      _uri('/api/futs/${Uri.encodeComponent(id)}'),
      headers: _headers(codigo),
    );
    if (r.statusCode != 204) _fail(r);
  }
}
