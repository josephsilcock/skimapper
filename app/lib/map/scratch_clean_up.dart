import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/run_record.dart';
import 'resort_map_providers.dart';

/// Clears what earlier launches left of resort maps' scratch folders, once, as the app starts.
class ScratchCleanUp extends ConsumerStatefulWidget {
  const ScratchCleanUp({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScratchCleanUp> createState() => _ScratchCleanUpState();
}

class _ScratchCleanUpState extends ConsumerState<ScratchCleanUp> {
  @override
  void initState() {
    super.initState();
    _clear();
  }

  /// A failed clean-up is only logged: nothing on screen depends on it.
  Future<void> _clear() async {
    try {
      await ref.read(scratchFoldersProvider).clearAll();
    } catch (failure) {
      recordRun('scratch clean-up at launch failed: $failure');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
