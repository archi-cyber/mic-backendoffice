import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/offline/offline_operation.dart';
import '../../core/offline/offline_queue.dart';

/// Écran de synchronisation.
///
/// Montre ce qui attend d'être transmis, et pourquoi ça n'a pas abouti.
///
/// C'est ici que se règlent les cas bloqués : une opération refusée par le
/// serveur — permission manquante, membre supprimé entre-temps — ne partira
/// jamais. Sans cet écran, elle resterait en file indéfiniment sans que
/// personne ne sache pourquoi.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  List<OfflineOperation> _operations = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  SyncResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final operations = await OfflineQueue.instance.pending();

    if (!mounted) return;
    setState(() {
      _operations = operations;
      _isLoading = false;
    });
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);

    final result = await OfflineQueue.instance.sync();
    await _load();

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastResult = result;
    });

    if (!mounted) return;

    final message = result.isComplete
        ? 'Tout est synchronisé.'
        : result.hasErrors
            ? '${result.synced} transmise(s), ${result.failed} en échec.'
            : '${result.synced} transmise(s), ${result.remaining} en attente.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Supprime une opération de la file.
  ///
  /// La confirmation est explicite : la saisie est définitivement perdue, et
  /// il peut s'agir de la présence d'un culte entier.
  Future<void> _discard(OfflineOperation operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner cette saisie ?'),
        content: Text(
          'La saisie « ${operation.label ?? operation.path} » sera '
          'définitivement perdue. Elle ne sera pas transmise au serveur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await OfflineQueue.instance.remove(operation.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        actions: [
          if (_operations.isNotEmpty)
            IconButton(
              onPressed: _isSyncing ? null : _sync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Synchroniser maintenant',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _operations.isEmpty
              ? _buildEmpty(theme)
              : _buildList(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Tout est synchronisé', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Vos saisies ont été transmises au serveur.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    // Les opérations abandonnées sont regroupées en tête : elles demandent une
    // décision, contrairement aux autres qui partiront d'elles-mêmes.
    final blocked = _operations.where((op) => !op.isRetryable).toList();
    final waiting = _operations.where((op) => op.isRetryable).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_lastResult != null && _lastResult!.hasErrors)
            _buildErrorSummary(theme, _lastResult!),

          if (blocked.isNotEmpty) ...[
            _buildSectionHeader(
              theme,
              'Bloquées',
              'Ces saisies ont échoué ${OfflineOperation.maxAttempts} fois. '
                  'Le problème vient de la donnée, pas du réseau.',
              theme.colorScheme.error,
            ),
            ...blocked.map((op) => _buildTile(theme, op, isBlocked: true)),
          ],

          if (waiting.isNotEmpty) ...[
            _buildSectionHeader(
              theme,
              'En attente',
              'Seront transmises automatiquement au retour du réseau.',
              theme.colorScheme.onSurfaceVariant,
            ),
            ...waiting.map((op) => _buildTile(theme, op)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    String subtitle,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildErrorSummary(ThemeData theme, SyncResult result) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernière synchronisation',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 6),
          ...result.errors.take(3).map(
                (error) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTile(
    ThemeData theme,
    OfflineOperation operation, {
    bool isBlocked = false,
  }) {
    final formatter = DateFormat('d MMM à HH:mm', 'fr_FR');

    return ListTile(
      leading: Icon(
        isBlocked ? Icons.error_outline : Icons.schedule,
        color: isBlocked
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        operation.label ?? '${operation.method} ${operation.path}',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatter.format(operation.createdAt),
            style: theme.textTheme.bodySmall,
          ),
          if (operation.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                operation.lastError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (operation.attempts > 0)
            Text(
              '${operation.attempts} tentative(s)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      isThreeLine: operation.lastError != null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Abandonner',
        onPressed: () => _discard(operation),
      ),
    );
  }
}