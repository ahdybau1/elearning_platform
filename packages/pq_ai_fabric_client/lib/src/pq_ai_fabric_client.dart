import 'dart:convert';

import 'package:http/http.dart' as http;

import 'capability_models.dart';

typedef AccessTokenProvider = Future<String?> Function();

class PqAiFabricException implements Exception {
  const PqAiFabricException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'PqAiFabricException($statusCode): $message';
}

class PqAiFabricClient {
  PqAiFabricClient({
    required this.gatewayBaseUri,
    required this.accessTokenProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final Uri gatewayBaseUri;
  final AccessTokenProvider accessTokenProvider;
  final http.Client _httpClient;

  Uri _uri(String path) => gatewayBaseUri.resolve(path);

  Future<Map<String, String>> _headers() async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const PqAiFabricException(401, 'Session Supabase requise.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString() ?? response.reasonPhrase ?? 'Erreur Gateway'
          : response.reasonPhrase ?? 'Erreur Gateway';
      throw PqAiFabricException(response.statusCode, message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PqAiFabricException(502, 'Réponse Gateway invalide.');
    }
    return decoded;
  }

  Future<List<CapabilitySummary>> listCapabilities() async {
    final response = await _httpClient.get(
      _uri('/v1/capabilities'),
      headers: await _headers(),
    );
    final json = _decode(response);
    return (json['capabilities'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(CapabilitySummary.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getCapability(String capabilityId) async {
    final encodedId = Uri.encodeComponent(capabilityId);
    final response = await _httpClient.get(
      _uri('/v1/capabilities/$encodedId'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<CapabilityPlan> planCapability(CapabilityPlanRequest request) async {
    final response = await _httpClient.post(
      _uri('/v1/capabilities/plan'),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    return CapabilityPlan.fromJson(_decode(response));
  }

  void close() => _httpClient.close();
}
