import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Um fut como está guardado no grupo: [versao] sobe a cada gravação.
class ServerFut {
  ServerFut(this.id, this.versao, this.dados);
  final String id;
  final int versao;
  final Map<String, dynamic> dados;
}

/// O código do link não corresponde a nenhum grupo.
class GroupNotFoundException implements Exception {}

/// Alguém gravou o fut antes: [atual] é o que está no grupo agora.
class ConflictException implements Exception {
  ConflictException(this.atual);
  final ServerFut atual;
}

/// O fut foi apagado em outro aparelho.
class GoneException implements Exception {}

/// Onde os futs do grupo ficam guardados.
abstract class Backend {
  Future<({String codigo, String nome})> criarGrupo(String nome);

  /// Nome do grupo do código; [GroupNotFoundException] se não existir.
  Future<String> nomeDoGrupo(String codigo);

  /// Todos os futs do grupo, de novo a cada mudança.
  Stream<List<ServerFut>> futs(String codigo);

  /// Grava se [versao] ainda for a do grupo (0 cria). Devolve a versão nova.
  Future<int> gravar(
    String codigo,
    String id,
    int versao,
    Map<String, dynamic> dados,
  );

  Future<void> apagar(String codigo, String id);
}

/// 18 bytes aleatórios em base64 de URL: 24 caracteres, seguros para o link.
String newGroupCode([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(18, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Grupos no Firestore: `grupos/{codigo}` e `grupos/{codigo}/futs/{id}`.
/// As regras do Firestore só deixam abrir um grupo por quem sabe o código.
class FirestoreBackend implements Backend {
  FirestoreBackend([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _grupo(String codigo) =>
      _db.collection('grupos').doc(codigo);

  @override
  Future<({String codigo, String nome})> criarGrupo(String nome) async {
    final codigo = newGroupCode();
    await _grupo(codigo)
        .set({'nome': nome, 'criadoEm': FieldValue.serverTimestamp()});
    return (codigo: codigo, nome: nome);
  }

  @override
  Future<String> nomeDoGrupo(String codigo) async {
    final snap = await _grupo(codigo)
        .get(const GetOptions(source: Source.server));
    final data = snap.data();
    if (!snap.exists || data == null) throw GroupNotFoundException();
    return data['nome'] as String? ?? 'Grupo';
  }

  @override
  Stream<List<ServerFut>> futs(String codigo) {
    return _grupo(codigo)
        .collection('futs')
        .snapshots()
        .map(
          (q) => [
            for (final d in q.docs)
              ServerFut(
                d.id,
                (d.data()['versao'] as num).toInt(),
                _plain(d.data()['dados']) as Map<String, dynamic>,
              ),
          ],
        );
  }

  @override
  Future<int> gravar(
    String codigo,
    String id,
    int versao,
    Map<String, dynamic> dados,
  ) async {
    final ref = _grupo(codigo).collection('futs').doc(id);
    // A transação devolve o resultado em vez de lançar erro: erros lançados
    // dentro dela chegam embrulhados de jeitos diferentes na web e no Android.
    final result = await _db.runTransaction<(int?, ServerFut?)>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) {
        if (versao != 0) return (null, null);
        tx.set(ref, _doc(1, dados));
        return (1, null);
      }
      final atual = (data['versao'] as num).toInt();
      if (atual != versao) {
        return (
          null,
          ServerFut(id, atual, _plain(data['dados']) as Map<String, dynamic>),
        );
      }
      tx.set(ref, _doc(versao + 1, dados));
      return (versao + 1, null);
    });
    final (nova, conflito) = result;
    if (nova != null) return nova;
    if (conflito != null) throw ConflictException(conflito);
    throw GoneException();
  }

  Map<String, dynamic> _doc(int versao, Map<String, dynamic> dados) => {
    'versao': versao,
    'dados': dados,
    'atualizadoEm': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> apagar(String codigo, String id) =>
      _grupo(codigo).collection('futs').doc(id).delete();

  /// Converte o que vem do Firestore para JSON puro (mapas e listas comuns).
  static Object? _plain(Object? v) {
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries) e.key as String: _plain(e.value),
      };
    }
    if (v is List) return [for (final e in v) _plain(e)];
    return v;
  }
}
