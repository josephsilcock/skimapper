import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'resort_list_providers.dart';

/// The resort list area of the home screen.
class ResortListView extends ConsumerWidget {
  const ResortListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resorts = ref.watch(resortListProvider).shown?.byName ?? const [];
    return RefreshIndicator(
      onRefresh: ref.read(resortListProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final resort in resorts)
            ListTile(
              title: Text(resort.name),
              subtitle: Text(resort.countriesLabel),
            ),
        ],
      ),
    );
  }
}
