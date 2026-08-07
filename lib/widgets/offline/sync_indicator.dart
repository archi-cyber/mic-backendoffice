import 'package:flutter/material.dart';

import '../../core/offline/offline_queue.dart';

/// Indicateur d'opérations en attente de synchronisation.
///
/// À placer dans la barre d'application, à côté des notifications.
///
/// **C'est le garde-fou du mode hors ligne.** Sans lui, un responsable peut
/// pointer tout un culte sans savoir que rien n'a été transmis — et le
/// découvrir une semaine plus tard, quand les chiffres ne correspondent pas.
/// Le badge rend l'attente visible en permanence.
///
/// Reste invisible quand la file est vide : un indicateur toujours affiché
/// finit par ne plus être vu.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key, this.onTap});

  /// Ouvre l'écran de synchronisation. Par défaut, la route nommée.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: OfflineQueue.instance.pendingCount,
      builder: (context, snapshot) {
        final pending = snapshot.data ?? 0;

        if (pending == 0) return const SizedBox.shrink();

        final theme = Theme.of(context);

        return Tooltip(
          message: pending == 1
              ? '1 saisie en attente de synchronisation'
              : '$pending saisies en attente de synchronisation',
          child: InkWell(
            onTap: onTap ??
                () => Navigator.of(context).pushNamed('/sync'),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      // Au-delà de 99, le chiffre exact n'apporte rien et
                      // déforme le badge.
                      pending > 99 ? '99+' : '$pending',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bandeau signalant que les données affichées viennent du cache.
///
/// Sans lui, l'utilisateur croit voir l'état actuel. Sur une liste de membres
/// consultée hors réseau, la différence compte : une personne inscrite ce
/// matin n'y figure pas.
///
/// Affiche l'ancienneté plutôt qu'un simple « hors ligne » : « il y a deux
/// heures » permet de juger si l'écart est acceptable.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    super.key,
    required this.cachedAt,
    this.onRefresh,
  });

  final DateTime cachedAt;
  final VoidCallback? onRefresh;

  String _formatAge(Duration age) {
    if (age.inMinutes < 1) return "à l'instant";
    if (age.inMinutes < 60) return 'il y a ${age.inMinutes} min';
    if (age.inHours < 24) return 'il y a ${age.inHours} h';
    return 'il y a ${age.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = DateTime.now().difference(cachedAt);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Données enregistrées ${_formatAge(age)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onRefresh != null)
              TextButton(
                onPressed: onRefresh,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Actualiser'),
              ),
          ],
        ),
      ),
    );
  }
}