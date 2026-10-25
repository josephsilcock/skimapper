import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalogue.dart';
import 'resort_list.dart';
import 'resort_list_providers.dart';

/// The resort list area of the home screen: the list, or the first load's state, always pullable.
class ResortListView extends ConsumerWidget {
  const ResortListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(resortListProvider);
    final notifier = ref.read(resortListProvider.notifier);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: switch (list) {
        ResortListState(:final Catalogue shown) => _Resorts(shown),
        ResortListState(firstLoad: FirstLoad.loading) => const _FullArea(
          child: CircularProgressIndicator(),
        ),
        ResortListState(firstLoad: FirstLoad.couldNotLoad) => _FullAreaMessage(
          heading: "Couldn't load resorts",
          detail: 'Check your connection, then try again or pull down.',
          onRetry: notifier.refresh,
        ),
      },
    );
  }
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
