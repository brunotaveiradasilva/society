import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend.dart';
import '../state.dart';
import '../theme.dart';

/// Ícone na barra do topo: mostra se está no grupo e se está sincronizado.
class GroupButton extends StatelessWidget {
  const GroupButton({super.key, required this.store});
  final FutStore store;

  @override
  Widget build(BuildContext context) {
    final (icon, tip) = switch (store.status) {
      SyncStatus.local => (
        Icons.group_add_outlined,
        'Compartilhar com o grupo',
      ),
      SyncStatus.synced => (Icons.cloud_done_outlined, 'Sincronizado'),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, 'Sincronizando'),
      SyncStatus.offline => (Icons.cloud_off_outlined, 'Sem conexão'),
    };
    return IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: () => store.inGroup
          ? showGroupSheet(context, store)
          : showCreateGroup(context, store),
    );
  }
}

/// Texto curto do estado da sincronia, para baixo do título.
String? syncLabel(FutStore store) => switch (store.status) {
  SyncStatus.local => null,
  SyncStatus.synced => store.groupName,
  SyncStatus.syncing => '${store.groupName} · sincronizando…',
  SyncStatus.offline => '${store.groupName} · sem conexão, salvo aqui',
};

Future<void> showCreateGroup(BuildContext context, FutStore store) async {
  final name = TextEditingController(text: store.latest?.title ?? '');
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CreateGroupSheet(store: store, name: name),
  );
  if (created == true && context.mounted) showGroupSheet(context, store);
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.store, required this.name});
  final FutStore store;
  final TextEditingController name;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    final nome = widget.name.text.trim();
    if (nome.isEmpty) {
      setState(() => _error = 'Dê um nome ao grupo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.store.createGroup(nome);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
            'Não deu para criar o grupo. Confira a internet e tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.store.futs.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Compartilhar com o grupo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Você recebe um link para mandar no WhatsApp. Quem abrir vê e '
            'edita os mesmos futs, e as mudanças aparecem em segundos.'
            '${count > 0 ? futsGoAlong(count) : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nome do grupo',
              hintText: 'Ex.: Fut de quinta',
              errorText: _error,
            ),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _create,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ink,
                    ),
                  )
                : const Text('Criar grupo e gerar link'),
          ),
        ],
      ),
    );
  }
}

Future<void> showGroupSheet(BuildContext context, FutStore store) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final link = store.shareLink;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                store.groupName ?? 'Grupo',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                switch (store.status) {
                  SyncStatus.offline =>
                    'Sem conexão agora. O que você mudar fica salvo aqui e vai '
                        'para o grupo quando a internet voltar.',
                  _ => 'Quem tem este link vê e edita os futs do grupo.',
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(link, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copiado. Mande no grupo do WhatsApp.',
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Não deu para copiar. Segure no link para selecionar.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Copiar link do grupo'),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: danger),
                onPressed: () => _confirmLeave(context, store),
                child: const Text('Sair do grupo'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _confirmLeave(BuildContext context, FutStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sair do grupo?'),
      content: const Text(
        'Os futs continuam neste aparelho, mas param de sincronizar. '
        'Para voltar, abra o link do grupo de novo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (ok == true) {
    store.leaveGroup();
    if (context.mounted) Navigator.pop(context);
  }
}

/// Abriu o app por um link de grupo: confirma antes de entrar.
Future<void> confirmJoin(
  BuildContext context,
  FutStore store,
  String code,
) async {
  String nome;
  try {
    nome = await store.groupNameFor(code);
  } catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Não deu para abrir o grupo'),
        content: Text(
          e is GroupNotFoundException
              ? 'Este link de grupo não existe mais. Peça o link de novo.'
              : 'Sem conexão com o servidor agora. Abra o link de novo quando a internet voltar.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  final count = store.futs.length;
  final leaving = store.inGroup
      ? ' Você sai do grupo ${store.groupName} neste aparelho (os futs dele continuam com quem tem aquele link).'
      : '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Entrar no grupo $nome?'),
      content: Text(
        'Você e quem tem o link vão ver e editar os mesmos futs.'
        '${count > 0 && !store.inGroup ? futsGoAlong(count) : ''}'
        '$leaving',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Entrar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  if (store.inGroup) store.leaveGroup(keepFuts: false);
  try {
    await store.joinGroup(code);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não deu para entrar no grupo. Tente abrir o link de novo.',
        ),
      ),
    );
  }
}

String futsGoAlong(int count) => count == 1
    ? ' O fut deste aparelho vai junto.'
    : ' Os $count futs deste aparelho vão junto.';
