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
              heading: "Couldn't load resorts",
              detail: 'Check your connection, then try again or pull down.',
              onRetry: notifier.refresh,
            ),
          ResortListState(firstLoad: FirstLoad.updateApp) => _FullAreaMessage(
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
  Widget build(BuildContext context) => const MaterialBanner(
    content: Text(
      'A newer resort list needs an app update. Showing your saved list.',
    ),
    // MaterialBanner requires an action; this one deliberately offers none.
    actions: [SizedBox.shrink()],
  );
}

class _Resorts extends StatelessWidget {
  const _Resorts(this.catalogue);

  final Catalogue catalogue;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      for (final resort in catalogue.byName)
        ListTile(
          title: Text(resort.name),
          subtitle: Text(resort.countriesLabel),
        ),
    ],
  );
}

/// A message filling the list area, still pullable.
class _FullAreaMessage extends StatelessWidget {
  const _FullAreaMessage({
    required this.heading,
    required this.detail,
    required this.onRetry,
  });

  final String heading;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _FullArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
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
