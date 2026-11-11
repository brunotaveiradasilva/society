import 'package:flutter/material.dart';

import '../main.dart';
import '../state.dart';
import '../theme.dart';

/// Tela inicial: um card por fut, do mais recente para o mais antigo.
class FutsScreen extends StatelessWidget {
  const FutsScreen({super.key, required this.store});
  final FutStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final futs = store.futs;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Society')),
          floatingActionButton: futs.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _newFut(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo fut'),
                ),
          body: futs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_soccer, size: 64, color: line),
                        const SizedBox(height: 16),
                        Text(
                          'Cada fut fica salvo com a data dele: lista, quem '
                          'chegou, times e quem pagou.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _newFut(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Criar o primeiro fut'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: futs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _FutCard(
                    fut: futs[i],
                    isNext: i == 0,
                    onOpen: () => _open(context, futs[i]),
                    onDelete: () => _delete(context, futs[i]),
                  ),
                ),
        );
      },
    );
  }

  void _open(BuildContext context, Fut fut) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => FutScreen(fut: fut)));
  }

  Future<void> _newFut(BuildContext context) async {
    final result = await showModalBottomSheet<(DateTime, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewFutSheet(
        initialDate: store.suggestedDate(),
        previous: store.latest,
      ),
    );
    if (result == null || !context.mounted) return;
    final fut = store.create(
      result.$1,
      copyFrom: result.$2 ? store.latest : null,
    );
    _open(context, fut);
  }

  Future<void> _delete(BuildContext context, Fut fut) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar o fut de ${shortDate(fut.date)}?'),
        content: Text(
          'Some a lista, quem chegou, os times e os pagamentos de '
          '${weekdayDate(fut.date)}.',
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
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    store.delete(fut);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text('Fut de ${shortDate(fut.date)} apagado'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => store.restore(fut),
          ),
        ),
      );
  }
}

class _FutCard extends StatelessWidget {
  const _FutCard({
    required this.fut,
    required this.isNext,
    required this.onOpen,
    required this.onDelete,
  });
  final Fut fut;
  final bool isNext;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = fut.date;
    final weekday = weekdayDate(d).split(',').first;
    final total = fut.players.length;
    final stats = [
      '$total na lista',
      if (fut.presentCount > 0) '${fut.presentCount} chegaram',
      if (fut.paidCount > 0) '${fut.paidCount} pagaram',
      if (fut.lastDraw != null) 'times sorteados',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isNext ? brandYellow : canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      two(d.day),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _months[d.month - 1],
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$weekday · ${fut.title}',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções',
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Apagar fut')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];

class _NewFutSheet extends StatefulWidget {
  const _NewFutSheet({required this.initialDate, this.previous});
  final DateTime initialDate;
  final Fut? previous;

  @override
  State<_NewFutSheet> createState() => _NewFutSheetState();
}

class _NewFutSheetState extends State<_NewFutSheet> {
  late DateTime _date = widget.initialDate;
  late bool _copy = widget.previous != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Data do fut',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prev = widget.previous;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Novo fut', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(weekdayDate(_date)),
          ),
          if (prev != null) ...[
            const SizedBox(height: 20),
            Text('Lista', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _Option(
              selected: _copy,
              title: 'Repetir a lista de ${shortDate(prev.date)}',
              subtitle:
                  '${prev.players.length} nomes, mesmos times e cores. '
                  'Chegadas e pagamentos começam zerados.',
              onTap: () => setState(() => _copy = true),
            ),
            const SizedBox(height: 8),
            _Option(
              selected: !_copy,
              title: 'Colar uma lista nova',
              subtitle: 'Começa vazio para colar a lista do grupo.',
              onTap: () => setState(() => _copy = false),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, (_date, _copy)),
            child: Text('Criar fut de ${shortDate(_date)}'),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? brandYellowSoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? ink : line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
