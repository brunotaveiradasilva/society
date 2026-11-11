import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key, required this.state});
  final Fut state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = state.players.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Editar nome e informações',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editHeader(context),
          ),
        ],
      ),
      floatingActionButton: empty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addPlayer(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Adicionar'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: theme.textTheme.titleMedium,
              ),
              onPressed: () => _pickDate(context),
              icon: const Icon(Icons.event, size: 20),
              label: Text(weekdayDate(state.date)),
            ),
          ),
          if (state.info != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.info!, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: () => _pasteList(context),
            icon: const Icon(Icons.content_paste),
            label: Text(empty ? 'Colar lista do WhatsApp' : 'Colar nova lista'),
          ),
          if (empty) ...[
            const SizedBox(height: 32),
            Icon(
              Icons.sports_soccer,
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Cole a lista do grupo que eu separo goleiros, linha e espera, '
              'tiro numeração, emojis e @menções.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _addPlayer(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ou adicione um por um'),
              ),
            ),
          ],
          for (final role in const [Role.goalkeeper, Role.line, Role.waitlist])
            ..._section(context, role),
        ],
      ),
    );
  }

  List<Widget> _section(BuildContext context, Role role) {
    final list = state.byRole(role).toList();
    if (list.isEmpty) return const [];
    final title = switch (role) {
      Role.goalkeeper => 'Goleiros',
      Role.line => 'Linha',
      Role.waitlist => 'Lista de espera',
    };
    return [
      SectionHeader(title: title, count: list.length),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++)
              _PlayerTile(state: state, player: list[i], position: i + 1),
          ],
        ),
      ),
    ];
  }

  Future<void> _pasteList(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PasteSheet(
        controller: controller,
        askReplace: state.players.isNotEmpty,
      ),
    );
    if (result == null || result.$1.trim().isEmpty) return;
    final added = state.importText(result.$1, replace: result.$2);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 5),
        content: Text('$added ${added == 1 ? 'pessoa' : 'pessoas'} na lista'),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Data do fut',
    );
    if (picked != null) state.setDate(picked);
  }

  Future<void> _addPlayer(BuildContext context) async {
    final result = await showDialog<(String, Role)>(
      context: context,
      builder: (context) => const _PlayerDialog(title: 'Adicionar pessoa'),
    );
    if (result != null) state.addPlayer(result.$1, result.$2);
  }

  Future<void> _editHeader(BuildContext context) async {
    final t = TextEditingController(text: state.title);
    final i = TextEditingController(text: state.info ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jogo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: t,
              decoration: const InputDecoration(
                labelText: 'Nome (quadra, grupo)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: i,
              decoration: const InputDecoration(
                labelText: 'Endereço, dia e horário',
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true) state.setTitle(t.text, i.text);
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.state,
    required this.player,
    required this.position,
  });
  final Fut state;
  final Player player;
  final int position;

  /// Remove a pessoa e, se ela ocupava vaga de linha ou gol e há gente na
  /// espera, pergunta se o primeiro da espera sobe para a linha.
  Future<void> _remove(BuildContext context) async {
    // O tile some da árvore ao remover, então guarda contextos que continuam vivos.
    final navContext = Navigator.of(context).context;
    final messenger = ScaffoldMessenger.of(context);
    final index = state.players.indexOf(player);
    state.removePlayer(player);

    void showUndo(String text, {Player? promoted}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 5),
            content: Text(text),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () {
                if (promoted != null) state.setRole(promoted, Role.waitlist);
                state.insertPlayer(index, player);
              },
            ),
          ),
        );
    }

    final waiting = state.byRole(Role.waitlist);
    if (player.role == Role.waitlist || waiting.isEmpty) {
      showUndo('${player.name} saiu da lista');
      return;
    }

    final next = waiting.first;
    final promote = await showDialog<bool>(
      context: navContext,
      builder: (context) => AlertDialog(
        title: Text('Subir ${next.name}?'),
        content: Text(
          '${player.name} saiu da lista. Quer passar ${next.name}, '
          'o primeiro da lista de espera, para a linha?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Subir ${next.name}'),
          ),
        ],
      ),
    );

    if (promote == true) {
      state.setRole(next, Role.line);
      showUndo(
        '${player.name} saiu e ${next.name} subiu para a linha',
        promoted: next,
      );
    } else {
      showUndo('${player.name} saiu da lista');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(player.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => _remove(context),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 28,
          child: Text(
            '$position',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        title: Text(player.name, style: theme.textTheme.bodyLarge),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opções',
          onSelected: (v) async {
            switch (v) {
              case 'rename':
                final result = await showDialog<(String, Role)>(
                  context: context,
                  builder: (_) => _PlayerDialog(
                    title: 'Editar',
                    initialName: player.name,
                    initialRole: player.role,
                  ),
                );
                if (result != null) {
                  state.rename(player, result.$1);
                  state.setRole(player, result.$2);
                }
              case 'delete':
                _remove(context);
              default:
                state.setRole(player, Role.values.byName(v));
            }
          },
          itemBuilder: (_) => [
            for (final r in Role.values)
              if (r != player.role)
                PopupMenuItem(
                  value: r.name,
                  child: Text('Mover para ${r.label}'),
                ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'rename', child: Text('Editar')),
            const PopupMenuItem(value: 'delete', child: Text('Remover')),
          ],
        ),
      ),
    );
  }
}

class _PasteSheet extends StatefulWidget {
  const _PasteSheet({required this.controller, required this.askReplace});
  final TextEditingController controller;
  final bool askReplace;

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  bool _replace = true;

  Future<void> _paste() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain)
          .timeout(const Duration(seconds: 5));
      final text = clip?.text;
      if (text != null && text.trim().isNotEmpty) {
        widget.controller.text = text;
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        persist: false,
        duration: Duration(seconds: 5),
        content: Text(
          'Não deu para ler o que foi copiado. Toque na caixa e cole.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cole a lista',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Colar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Arena…\nLista:\n1- Fulano\n2- Ciclano\n\nLista de espera:\n1- Beltrano',
            ),
          ),
          if (widget.askReplace)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _replace,
              onChanged: (v) => setState(() => _replace = v),
              title: const Text('Substituir a lista atual'),
              subtitle: Text(
                _replace
                    ? 'Começa do zero com esta lista'
                    : 'Só acrescenta quem ainda não está',
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, (widget.controller.text, _replace)),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Organizar lista'),
          ),
        ],
      ),
    );
  }
}

class _PlayerDialog extends StatefulWidget {
  const _PlayerDialog({
    required this.title,
    this.initialName = '',
    this.initialRole = Role.line,
  });
  final String title;
  final String initialName;
  final Role initialRole;

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late Role _role = widget.initialRole;

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, (_name.text, _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<Role>(
            segments: [
              for (final r in Role.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
            showSelectedIcon: false,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
