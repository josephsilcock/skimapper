import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/endpoint/skeleton_message_line.dart';

void main() {
  testWidgets('says the service could not be reached when it is unreachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SkeletonMessageLine(client: _clientAnswering(_refuse))),
    );
    await tester.pumpAndSettle();

    expect(find.text('service could not be reached'), findsOneWidget);
  });

  testWidgets('says the service response was not understood', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SkeletonMessageLine(client: _clientAnswering(_garble))),
    );
    await tester.pumpAndSettle();

    expect(find.text('service response not understood'), findsOneWidget);
  });
}

Future<http.Response> _refuse(http.Request request) async =>
    throw http.ClientException('Connection refused');

EndpointClient _clientAnswering(MockClientHandler handler) => EndpointClient(
  baseUrl: Uri.parse('http://endpoint.test'),
  timeout: const Duration(milliseconds: 100),
  httpClient: MockClient(handler),
);

Future<http.Response> _garble(http.Request request) async =>
    http.Response('this is not an envelope', 200);
