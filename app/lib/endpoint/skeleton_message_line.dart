import 'package:flutter/material.dart';

import 'contract_envelope.dart';
import 'endpoint_client.dart';

/// The placeholder screen's endpoint line (C4 design D9).
class SkeletonMessageLine extends StatefulWidget {
  const SkeletonMessageLine({super.key, required this.client});

  final EndpointClient client;

  @override
  State<SkeletonMessageLine> createState() => _SkeletonMessageLineState();
}

class _SkeletonMessageLineState extends State<SkeletonMessageLine> {
  late final Future<DocumentOutcome<String>> _outcome = widget.client
      .fetchDocument(
        '/v1/skeleton/message',
        kind: 'skeleton-message',
        parse: _message,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _outcome,
    builder: (context, snapshot) => Text(switch (snapshot.data) {
      Understood(:final value) => value,
      Failed() => 'service could not be reached',
      Incompatible() => 'service response not understood',
      null => 'endpoint: loading',
    }),
  );
}

String _message(Map<String, Object?> data) => '${data['message']}';
