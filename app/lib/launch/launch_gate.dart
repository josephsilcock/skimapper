import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/run_record.dart';
import '../resorts/catalogue.dart';
import 'launch_decision.dart';

/// Builds the app once launch has decided which resort, if any, to reopen.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key, required this.builder});

  final Widget Function(Resort? reopened) builder;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  ({Resort? reopened})? _decision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    _decide();
  }

  Future<void> _decide() async {
    final reopened = await ref.read(resortToReopenProvider.future);
    recordRun(_outcome(reopened));
    if (mounted) setState(() => _decision = (reopened: reopened));
    WidgetsBinding.instance.allowFirstFrame();
  }

  static String _outcome(Resort? reopened) => switch (reopened) {
    Resort(:final id) => 'launch: reopens $id',
    null => 'launch: shows the list',
  };

  @override
  Widget build(BuildContext context) => switch (_decision) {
    (:final reopened) => widget.builder(reopened),
    null => const SizedBox.shrink(),
  };
}
