import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';

String _money(double v) {
  final cents = (v * 100).round();
  final reais = (cents ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  return 'R\$ $buf,${(cents % 100).toString().padLeft(2, '0')}';
}

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key, required this.state});
  final Fut state;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  bool _onlyUnpaid = false;
  late final _price = TextEditingController(
    text: widget.state.pricePerPerson == null
        ? ''
        : widget.state.pricePerPerson!.toStringAsFixed(2).replaceAll('.', ','),
  );

  Fut get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = state.presentCount;
    final paid = state.paidCount;
    final unpaid = state.players.where((p) => p.present && !p.paid).length;
    final price = state.pricePerPerson;

    final filtered = state.players.where(
      (p) => !_onlyUnpaid || (p.present && !p.paid),
    );
    // Lista de espera por último, mantendo a ordem da lista.
    final visible = [
      ...filtered.where((p) => p.role != Role.waitlist),
      ...filtered.where((p) => p.role == Role.waitlist),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chamada'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'copy') _copyUnpaid(context);
              if (v == 'reset') _confirmReset(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'copy',
                child: Text('Copiar quem falta pagar'),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text('Limpar marcações (nova semana)'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              _Stat(label: 'Foram', value: '$present'),
              const SizedBox(width: 8),
              _Stat(label: 'Pagaram', value: '$paid'),
              const SizedBox(width: 8),
              _Stat(
                label: 'Falta pagar',
                value: '$unpaid',
                highlight: unpaid > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Valor por pessoa',
              prefixText: 'R\$ ',
              border: const OutlineInputBorder(),
              helperText: price == null
                  ? null
                  : 'Recebido ${_money(price * paid)} de ${_money(price * present)}',
            ),
            onChanged: (v) {
              // Aceita "25,50" e "25.50".
              final normalized = v.contains(',')
                  ? v.replaceAll('.', '').replaceAll(',', '.')
                  : v;
              final parsed = double.tryParse(normalized);
              state.setPrice(parsed);
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Todos')),
              ButtonSegment(value: true, label: Text('Falta pagar')),
            ],
            selected: {_onlyUnpaid},
            onSelectionChanged: (s) => setState(() => _onlyUnpaid = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _ColLabel('Foi'),
                _ColLabel('Pagou'),
              ],
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.players.isEmpty
                    ? 'A lista está vazia. Cole a lista na primeira aba.'
                    : 'Todo mundo que foi já pagou.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final p in visible) _CheckRow(state: state, player: p),
                ],
              ),
            ),
          const SectionHeader(title: 'Dica'),
          Text(
            '"Foi" é o mesmo que marcar quem chegou no Sorteio: só quem está marcado entra nos times.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyUnpaid(BuildContext context) async {
    final names = state.players
        .where((p) => p.present && !p.paid)
        .map((p) => p.name)
        .toList();
    final price = state.pricePerPerson;
    final text = names.isEmpty
        ? '✅ Todo mundo pagou!'
        : [
            '💰 Falta pagar${price != null ? ' (${_money(price)})' : ''}:',
            for (var i = 0; i < names.length; i++) '${i + 1}. ${names[i]}',
          ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista de quem falta pagar copiada')),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar marcações?'),
        content: const Text(
          'Desmarca "Pagou" de todo mundo, desmarca quem chegou e apaga o último sorteio. A lista de nomes continua.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true) state.resetChecks();
  }
}

class _ColLabel extends StatelessWidget {
  const _ColLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium,
    ),
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.state, required this.player});
  final Fut state;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded = !player.present;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: faded ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
                if (player.role != Role.line)
                  Text(
                    player.role.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Checkbox(
              value: player.present,
              onChanged: (v) => state.setPresent(player, v ?? false),
            ),
          ),
          SizedBox(
            width: 56,
            child: Checkbox(
              value: player.paid,
              onChanged: (v) => state.setPaid(player, v ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: highlight ? scheme.errorContainer : Colors.white,
          border: Border.all(
            color: highlight ? scheme.errorContainer : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? scheme.onErrorContainer : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: highlight
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
