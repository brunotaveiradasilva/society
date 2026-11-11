import 'package:flutter/material.dart';

import '../state.dart';

/// Ícone na barra do topo que mostra se os futs estão sincronizados.
class SyncIcon extends StatelessWidget {
  const SyncIcon({super.key, required this.store});
  final FutStore store;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (store.status) {
      SyncStatus.local => (
        Icons.phone_android,
        'Os futs ficam só neste aparelho.',
      ),
      SyncStatus.synced => (
        Icons.cloud_done_outlined,
        'Tudo salvo. Quem abre o Society vê os mesmos futs.',
      ),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, 'Salvando…'),
      SyncStatus.offline => (
        Icons.cloud_off_outlined,
        'Sem conexão. O que você mudar fica salvo aqui e sobe quando a internet voltar.',
      ),
    };
    return IconButton(
      tooltip: text,
      icon: Icon(icon),
      onPressed: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text))),
    );
  }
}

/// Aviso curto embaixo do título quando não está tudo salvo.
String? syncLabel(FutStore store) => switch (store.status) {
  SyncStatus.syncing => 'salvando…',
  SyncStatus.offline => 'sem conexão, salvo aqui',
  _ => null,
};
