import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pq_ai_fabric_client/pq_ai_fabric_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _gatewayUrl = String.fromEnvironment(
  'PQ_AI_GATEWAY_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// Client commun du Capability Registry, authentifié avec la session Élève.
final pqAiFabricClientProvider = Provider<PqAiFabricClient>((ref) {
  final client = PqAiFabricClient(
    gatewayBaseUri: Uri.parse(_gatewayUrl),
    accessTokenProvider: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );
  ref.onDispose(client.close);
  return client;
});
