import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pq_ai_fabric_client/pq_ai_fabric_client.dart';
import 'package:test/test.dart';

void main() {
  test('listCapabilities transmet le JWT et décode le contrat', () async {
    final transport = MockClient((request) async {
      expect(request.url.path, '/v1/capabilities');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({
          'capabilities': [
            {
              'id': 'audio.transcribe',
              'label': 'Transcription',
              'input_modalities': ['audio'],
              'output_modalities': ['text'],
              'degraded_strategy': ['saisie manuelle'],
              'provider_count': 3,
              'approved_provider_count': 2,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = PqAiFabricClient(
      gatewayBaseUri: Uri.parse('http://gateway.test'),
      accessTokenProvider: () async => 'test-token',
      httpClient: transport,
    );

    final capabilities = await client.listCapabilities();

    expect(capabilities.single.id, 'audio.transcribe');
    expect(capabilities.single.approvedProviderCount, 2);
  });

  test('une session absente est refusée avant le réseau', () async {
    final client = PqAiFabricClient(
      gatewayBaseUri: Uri.parse('http://gateway.test'),
      accessTokenProvider: () async => null,
      httpClient: MockClient((_) async => fail('aucun appel attendu')),
    );

    expect(
      client.listCapabilities,
      throwsA(isA<PqAiFabricException>()),
    );
  });
}
