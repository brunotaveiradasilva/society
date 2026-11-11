import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../draw.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class DrawScreen extends StatelessWidget {
  const DrawScreen({super.key, required this.state});
  final Fut state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draw = state.lastDraw;
    final available = state.presentForLine;
    final spots = state.lineSpots;
    final gk = state.presentGoalkeepers;

    final hasTeams = state.teams.isNotEmpty;
    final waiting = state.waiting;
    final String status;
    final bool warn;
    if (hasTeams) {
      final n = waiting.length;
      status = n == 0
          ? 'Ninguém esperando. Marque quem chegar para sortear o próximo time'
          : '$n esperando para o próximo time'
                '${n < state.perTeam ? ' (time incompleto: precisa de ${state.perTeam})' : ''}';
      warn = n == 0;
    } else if (available < spots) {
      status = 'Faltam ${spots - available} para fechar $spots vagas de linha';
      warn = true;
    } else if (available > spots) {
      status = '${available - spots} ficam de fora e entram na próxima';
      warn = false;
    } else {
      status = 'Times completos, ninguém de fora';
      warn = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sorteio'),
        actions: [
          if (draw != null)
            IconButton(
              tooltip: 'Copiar para o WhatsApp',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () => _copy(context, draw),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ArrivalsCard(state: state),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stepper2(
                    label: 'Times',
                    value: state.teamCount,
                    min: 2,
                    max: maxTeams,
                    onChanged: state.setTeamCount,
                  ),
                  const SizedBox(height: 8),
                  Stepper2(
                    label: 'Jogadores de linha por time',
                    value: state.perTeam,
                    min: 1,
                    max: 11,
                    onChanged: state.setPerTeam,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.fixedGoalkeepers,
                    onChanged: state.setFixedGoalkeepers,
                    title: const Text('Um goleiro por time'),
                    subtitle: Text(
                      gk == 0
                          ? 'Nenhum goleiro marcado como presente'
                          : '$gk ${gk == 1 ? 'goleiro presente' : 'goleiros presentes'}',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Cor de cada time', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var t = 0; t < state.teamCount; t++)
                        _ColorChip(
                          bib: bibColors[state.colorIndexes[t]],
                          onTap: () => _pickColor(context, t),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                warn ? Icons.info_outline : Icons.check_circle_outline,
                size: 18,
                color: warn
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${state.presentCount} ${state.presentCount == 1 ? 'chegou' : 'chegaram'}. $status.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: theme.textTheme.titleMedium,
            ),
            onPressed: (hasTeams ? waiting.isEmpty : state.presentCount == 0)
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    hasTeams ? state.drawNext() : state.draw();
                  },
            icon: Icon(hasTeams ? Icons.group_add : Icons.shuffle),
            label: Text(hasTeams ? 'Sortear próximo time' : 'Sortear times'),
          ),
          if (state.presentCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.players.isEmpty
                    ? 'Cole a lista na aba Lista.'
                    : 'Toque nos nomes de quem já chegou.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (draw != null) ...[
            const SizedBox(height: 8),
            for (final team in draw.teams) _TeamCard(team: team),
            if (draw.bench.isNotEmpty) ...[
              SectionHeader(title: 'Esperando', count: draw.bench.length),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final p in draw.bench)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          p.role == Role.goalkeeper
                              ? Icons.sports_handball
                              : Icons.hourglass_empty,
                          size: 20,
                        ),
                        title: Text(p.name),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _copy(context, draw),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copiar times para o WhatsApp'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: danger),
              onPressed: () => _confirmUndo(context),
              icon: const Icon(Icons.undo),
              label: const Text('Desfazer times'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmUndo(BuildContext context) async {
    final n = state.teams.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer os times?'),
        content: Text(
          'Os $n times sorteados vão sumir e todo mundo volta a esperar. '
          'Quem chegou continua marcado.',
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
            child: const Text('Desfazer times'),
          ),
        ],
      ),
    );
    if (ok == true) state.undoTeams();
  }

  Future<void> _copy(BuildContext context, DrawResult draw) async {
    await Clipboard.setData(
      ClipboardData(
        text: drawToText(
          draw,
          title: '${state.title} – ${shortDate(state.date)}',
        ),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Times copiados. É só colar no grupo.')),
    );
  }

  Future<void> _pickColor(BuildContext context, int team) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cor do time ${team + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < bibColors.length; i++)
                  _ColorChip(
                    bib: bibColors[i],
                    selected: state.colorIndexes[team] == i,
                    onTap: () => Navigator.pop(context, i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) state.setTeamColor(team, picked);
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.bib,
    required this.onTap,
    this.selected = false,
  });
  final BibColor bib;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      onPressed: onTap,
      avatar: Container(
        decoration: BoxDecoration(
          color: bib.color,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline),
        ),
      ),
      label: Text(bib.name),
      side: selected
          ? BorderSide(color: scheme.onSurface, width: 2)
          : BorderSide(color: scheme.outlineVariant),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});
  final DrawnTeam team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bib = team.bib;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: bib.color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.checkroom, color: bib.onColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Time ${bib.name}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: bib.onColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${team.players.length + (team.goalkeeper == null ? 0 : 1)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: bib.onColor,
                  ),
                ),
              ],
            ),
          ),
          if (team.goalkeeper != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.sports_handball),
              title: Text(
                team.goalkeeper!.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Goleiro'),
            ),
          for (var i = 0; i < team.players.length; i++)
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 24,
                child: Text(
                  '${i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              title: Text(team.players[i].name),
            ),
          if (team.players.isEmpty && team.goalkeeper == null)
            const ListTile(dense: true, title: Text('Sem jogadores')),
        ],
      ),
    );
  }
}

/// Marca quem já chegou na quadra. Só quem chegou entra no sorteio.
class _ArrivalsCard extends StatelessWidget {
  const _ArrivalsCard({required this.state});
  final Fut state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrived = state.presentCount;
    final total = state.players.length;
    final groups = [
      (Role.goalkeeper, 'Goleiros'),
      (Role.line, 'Linha'),
      (Role.waitlist, 'Espera'),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Quem já chegou  ',
                          style: theme.textTheme.titleMedium,
                        ),
                        TextSpan(
                          text: '$arrived/$total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (total > 0)
                  TextButton(
                    onPressed: () => state.setAllPresent(arrived < total),
                    child: Text(arrived < total ? 'Todos' : 'Nenhum'),
                  ),
              ],
            ),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'Cole a lista na aba Lista para marcar quem chegou.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final (role, label) in groups)
              if (state.byRole(role).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in state.byRole(role))
                      FilterChip(
                        label: Text(p.name),
                        selected: p.present,
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          state.setPresent(p, v);
                        },
                        showCheckmark: true,
                        checkmarkColor: ink,
                        selectedColor: brandYellow,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: p.present
                              ? brandYellow
                              : theme.colorScheme.outlineVariant,
                        ),
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: p.present
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}
