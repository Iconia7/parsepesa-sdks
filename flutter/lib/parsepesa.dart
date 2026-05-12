import 'dart:convert';
import 'package:http/http.dart' as http;
import 'src/parsepesa_core.dart';

class ParsePesa {
  final String? apiKey;
  final String baseUrl;
  final bool syncToCloud;
  late final WebhooksManager darajaProxy;
  late final WebhooksManager parsingWebhooks;
  late final ParserRegistry _localRegistry;

  ParsePesa({
    this.apiKey,
    this.baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1',
    this.syncToCloud = false,
  }) {
    darajaProxy = WebhooksManager(this, '/user/daraja-proxy');
    parsingWebhooks = WebhooksManager(this, '/user/webhooks');
    _localRegistry = ParserRegistry();
  }

  // Static init for convenience in Flutter apps
  static ParsePesa? _instance;
  
  /// Initializes the ParsePesa singleton.
  /// If [apiKey] is provided and [syncToCloud] is true, transactions parsed 
  /// locally will be mirrored to your cloud dashboard.
  static void init({String? apiKey, bool syncToCloud = false}) {
    _instance = ParsePesa(apiKey: apiKey, syncToCloud: syncToCloud);
  }

  /// Returns the initialized instance or a default offline-only instance.
  static ParsePesa get instance => _instance ?? ParsePesa();

  Map<String, String> get _headers => {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// Parses an M-Pesa SMS locally without making any network calls.
  /// Returns a [ParseResult] containing the structured data.
  ParseResult parseLocal(String rawText, {String? senderId}) {
    return _localRegistry.parse(rawText, senderId: senderId);
  }

  /// The primary parsing method.
  /// 
  /// This method is "Smart":
  /// 1. It first tries to parse the message locally (Offline & Free).
  /// 2. If local parsing fails AND an [apiKey] is present, it falls back to the Cloud AI parser.
  /// 3. If [syncToCloud] is enabled, it pushes successful local parses to the dashboard in the background.
  Future<Map<String, dynamic>> parse(String rawText, {String? senderId}) async {
    // 1. Try local parse first (Instant & Private)
    final localResult = parseLocal(rawText, senderId: senderId);
    
    if (localResult.success) {
      // Background sync to Cloud if enabled
      if (syncToCloud && apiKey != null) {
        _syncTransaction(rawText, localResult, senderId);
      }
      return localResult.toJson();
    }

    // 2. Fallback to Cloud if local failed and we have an API Key
    if (apiKey != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/parse'),
          headers: _headers,
          body: jsonEncode({
            'raw_text': rawText,
            'sender_id': senderId,
          }),
        );
        
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        // Fallback to the failed local result if network fails
      }
    }

    return localResult.toJson();
  }

  /// Syncs a locally parsed transaction to the cloud dashboard.
  Future<void> _syncTransaction(String rawText, ParseResult result, String? senderId) async {
    try {
      // In a real implementation, you might want to use a more efficient sync endpoint
      await http.post(
        Uri.parse('$baseUrl/parse'), // Reusing the parse endpoint for now as it handles ingestion
        headers: _headers,
        body: jsonEncode({
          'raw_text': rawText,
          'sender_id': senderId,
          'is_sync': true, // Optional flag for backend tracking
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fail silently on sync errors to avoid disrupting user experience
    }
  }

  Future<Map<String, dynamic>> batchParse(List<String> rawTexts) async {
    if (apiKey == null) {
      return {'success': false, 'error': 'API Key required for batch parsing'};
    }
    final response = await http.post(
      Uri.parse('$baseUrl/batch-parse'),
      headers: _headers,
      body: jsonEncode({'messages': rawTexts}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getBalance() async {
    if (apiKey == null) {
      return {'success': false, 'error': 'API Key required'};
    }
    final response = await http.get(Uri.parse('$baseUrl/user/stats'), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'balance': data['balance'] ?? 0};
    }
    return jsonDecode(response.body);
  }
}

class WebhooksManager {
  final ParsePesa _client;
  final String _path;

  WebhooksManager(this._client, this._path);

  String get _endpoint => '${_client.baseUrl}$_path';

  Future<List<dynamic>> list() async {
    if (_client.apiKey == null) return [];
    final response = await http.get(Uri.parse(_endpoint), headers: _client._headers);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> create(String url, {String? name, bool autoValidate = true}) async {
    if (_client.apiKey == null) return {'success': false, 'error': 'API Key required'};
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: _client._headers,
      body: jsonEncode({
        'url': url,
        'destinationUrl': url,
        'name': name,
        'autoValidate': autoValidate,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<bool> delete(String id) async {
    if (_client.apiKey == null) return false;
    final response = await http.delete(Uri.parse('$_endpoint/$id'), headers: _client._headers);
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
