import 'package:flutter/material.dart';

import 'endpoint_client.dart';

/// The placeholder screen's endpoint line (C4 design D9).
class SkeletonMessageLine extends StatefulWidget {
  const SkeletonMessageLine({super.key, required this.client});

  final EndpointClient client;

  @override
  State<SkeletonMessageLine> createState() => _SkeletonMessageLineState();
}

class _SkeletonMessageLineState extends State<SkeletonMessageLine> {
  late final Future<EndpointOutcome> _outcome = widget.client.fetchDocument(
    '/v1/skeleton/message',
    kind: 'skeleton-message',
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _outcome,
    builder: (context, snapshot) => Text(switch (snapshot.data) {
      Reached(:final data) => '${data['message']}',
      Unreachable() => 'service could not be reached',
      NotUnderstood() => 'service response not understood',
      null => 'endpoint: loading',
    }),
  );
}
