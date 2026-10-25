import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalogue.dart';
import 'resort_list.dart';
import 'resort_list_providers.dart';

/// The resort list area of the home screen: the list (under an update banner when one is needed),
/// or the first load's state; always pullable.
class ResortListView extends ConsumerWidget {
  const ResortListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(resortListProvider);
    final notifier = ref.read(resortListProvider.notifier);
    ref.listen(
      resortListProvider.select((list) => list.failedRefreshes),
      (_, _) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't refresh resorts"))),
    );
    return Column(
      children: [
        if (list.updateNeeded) const _UpdateBanner(),
        Expanded(child: _pullable(list, notifier)),
      ],
    );
  }

  Widget _pullable(ResortListState list, ResortList notifier) =>
      RefreshIndicator(
        onRefresh: notifier.refresh,
        child: switch (list) {
          ResortListState(:final Catalogue shown) => _Resorts(shown),
          ResortListState(firstLoad: FirstLoad.loading) => const _FullArea(
            child: CircularProgressIndicator(),
          ),
          ResortListState(firstLoad: FirstLoad.couldNotLoad) =>
            _FullAreaMessage(
              icon: Icons.cloud_off_outlined,
              heading: "Couldn't load resorts",
              detail: 'Check your connection, then try again or pull down.',
              onRetry: notifier.refresh,
            ),
          ResortListState(firstLoad: FirstLoad.updateApp) => _FullAreaMessage(
            icon: Icons.system_update_outlined,
            heading: 'Update SkiMapper to see resorts',
            detail: "This version can't read the latest resort list.",
            onRetry: notifier.refresh,
          ),
        },
      );
}

/// "Update the app" over a saved list, which stays usable. It has no Dismiss: it clears when a
/// later answer is understood.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A newer resort list needs an app update. Showing your saved list.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resorts extends StatelessWidget {
  const _Resorts(this.catalogue);

  final Catalogue catalogue;

  @override
  Widget build(BuildContext context) {
    final resorts = catalogue.byName;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room above and below for the cards' shadows.
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: resorts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Card(
        child: ListTile(
          title: Text(resorts[i].name),
          subtitle: Text(resorts[i].countriesLabel),
        ),
      ),
    );
  }
}

/// A message filling the list area, still pullable.
class _FullAreaMessage extends StatelessWidget {
  const _FullAreaMessage({
    required this.icon,
    required this.heading,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String heading;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _FullArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(heading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

/// Centres [child] in the whole list area, keeping the area pullable.
class _FullArea extends StatelessWidget {
  const _FullArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, area) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: area.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}
