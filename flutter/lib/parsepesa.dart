import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'src/parsepesa_core.dart';

/// ParsePesa Flutter/Dart SDK — v2.0.0
///
/// Changelog v2.0:
///   - parse() accepts idempotencyKey to prevent double billing on retries
///   - ParseApiResult wraps response with isReplay, idempotencyStored, requestId
///   - rotateKey() — zero-downtime key rotation with 24h grace period
///   - webhooks.deliveries() — view delivery history for a webhook
///   - Corrected batch endpoint (/parse/batch not /batch-parse)
///   - ParsePesaException with statusCode and code
///   - verifyWebhookSignature() static helper

class ParsePesaException implements Exception {
  final String message;
  final int statusCode;
  final String? code; // e.g. 'BALANCE_RACE'

  const ParsePesaException(this.message, {this.statusCode = 0, this.code});

  @override
  String toString() => 'ParsePesaException($statusCode): $message';
}

/// Wraps an API response from /v1/parse with metadata about idempotency.
class ParseApiResult {
  final Map<String, dynamic> data;
  final Map<String, String> headers;

  const ParseApiResult(this.data, this.headers);

  bool get success => data['success'] == true;
  double get confidence => (data['confidence'] as num?)?.toDouble() ?? 0.0;
  Map<String, dynamic>? get transaction => data['data'] as Map<String, dynamic>?;
  String? get errorMessage => data['errorMessage'] as String?;

  /// True if this response was served from the idempotency cache.
  /// No charge was applied — this is a replay of a previous response.
  bool get isReplay =>
      (headers['x-idempotent-replay'] ?? '').toLowerCase() == 'true';

  /// False if the idempotency record could not be persisted after billing.
  /// If false, do NOT retry with the same key — it will not deduplicate.
  bool get idempotencyStored =>
      (headers['x-idempotency-stored'] ?? 'true').toLowerCase() != 'false';

  String? get requestId => headers['x-request-id'];
}

class ParsePesa {
  static const String sdkVersion = '2.1.2';

  final String? apiKey;
  final String baseUrl;
  final bool syncToCloud;

  late final WebhooksManager webhooks;
  late final WebhooksManager darajaProxy;
  late final ParserRegistry _localRegistry;

  ParsePesa({
    this.apiKey,
    this.baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1',
    this.syncToCloud = false,
  }) {
    webhooks = WebhooksManager(this, '/user/webhooks');
    darajaProxy = WebhooksManager(this, '/user/daraja-proxy');
    _localRegistry = ParserRegistry();
  }

  static ParsePesa? _instance;

  static void init({String? apiKey, bool syncToCloud = false}) {
    _instance = ParsePesa(apiKey: apiKey, syncToCloud: syncToCloud);
  }

  static ParsePesa get instance => _instance ?? ParsePesa();

  Map<String, String> get _headers => {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'X-SDK-Platform': 'Flutter',
        'X-SDK-Version': sdkVersion,
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {..._headers, ...extraHeaders};
    final encodedBody = body != null ? jsonEncode(body) : null;

    final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    final Map<String, dynamic> responseBody;
    try {
      responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ParsePesaException(
        'Non-JSON response from server',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      throw ParsePesaException(
        (responseBody['error'] as String?) ?? 'Request failed: ${response.statusCode}',
        statusCode: response.statusCode,
        code: responseBody['code'] as String?,
      );
    }

    return responseBody;
  }

  /// Parses an M-Pesa SMS locally without any network calls.
  ParseResult parseLocal(String rawText, {String? senderId}) {
    return _localRegistry.parse(rawText, senderId: senderId);
  }

  /// Smart parse: tries local first, falls back to cloud AI if needed.
  ///
  /// [idempotencyKey]: Unique key (max 128 chars) to prevent double billing on
  /// retries. Use a stable ID tied to the SMS (e.g. sha256 of the SMS text).
  ///
  /// Returns [ParseApiResult] with metadata, or a local [ParseResult]-wrapped
  /// response if the network is unavailable.
  Future<ParseApiResult> parse(
    String rawText, {
    String? senderId,
    String? idempotencyKey,
  }) async {
    // 1. Try local (instant, free, private)
    final localResult = parseLocal(rawText, senderId: senderId);

    if (localResult.success) {
      if (syncToCloud && apiKey != null) {
        _syncTransaction(rawText, localResult, senderId);
      }
      // Wrap local result in ParseApiResult for consistent return type
      return ParseApiResult(localResult.toJson(), const {});
    }

    // 2. Cloud fallback
    if (apiKey != null) {
      try {
        final extraHeaders = <String, String>{};
        if (idempotencyKey != null) {
          extraHeaders['X-Idempotency-Key'] = idempotencyKey;
        }

        final uri = Uri.parse('$baseUrl/parse');
        final response = await http.post(
          uri,
          headers: {..._headers, ...extraHeaders},
          body: jsonEncode({'raw_text': rawText, 'sender_id': senderId}),
        );

        final respHeaders = Map<String, String>.fromEntries(
          response.headers.entries.map((e) => MapEntry(e.key.toLowerCase(), e.value)),
        );

        if (response.statusCode == 200) {
          return ParseApiResult(
            jsonDecode(response.body) as Map<String, dynamic>,
            respHeaders,
          );
        }

        final errBody = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        throw ParsePesaException(
          (errBody['error'] as String?) ?? 'Cloud parse failed',
          statusCode: response.statusCode,
          code: errBody['code'] as String?,
        );
      } on ParsePesaException {
        rethrow;
      } catch (_) {
        // Network unavailable — fall through to local failed result
      }
    }

    return ParseApiResult(localResult.toJson(), const {});
  }

  /// Like [parse], but auto-generates a stable idempotency key from the SMS text.
  /// Safe to call multiple times for the same SMS without double billing.
  Future<ParseApiResult> parseSafe(String rawText, {String? senderId}) {
    final key = sha256.convert(utf8.encode(rawText)).toString().substring(0, 32);
    return parse(rawText, senderId: senderId, idempotencyKey: key);
  }

  /// Parse up to 100 SMS messages in one request.
  Future<List<Map<String, dynamic>>> batchParse(List<String> rawTexts) async {
    if (rawTexts.length > 100) {
      throw ArgumentError('Batch limit is 100 items');
    }
    final data = await _request(
      'POST',
      '/parse/batch',   // ← corrected endpoint
      body: rawTexts.map((t) => {'raw_text': t}).toList(),
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Returns account balance in KES.
  Future<double> getBalance() async {
    final data = await _request('GET', '/user/stats');
    return (data['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns full account stats.
  Future<Map<String, dynamic>> getStats() async {
    return _request('GET', '/user/stats');
  }

  /// List all API keys on this account.
  Future<List<Map<String, dynamic>>> listKeys() async {
    final data = await _request('GET', '/user/keys');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Rotate an API key with zero downtime.
  /// The old key stays valid for 24 hours (grace period).
  ///
  /// Returns a map with 'apiKey' (new key string), 'graceExpiresAt', 'message'.
  Future<Map<String, dynamic>> rotateKey(String keyId) async {
    return _request('POST', '/user/keys/$keyId/rotate');
  }

  /// Verify an incoming webhook's HMAC-SHA256 signature.
  /// Call this in your webhook handler before processing any event.
  ///
  /// Returns true if the signature is valid.
  static bool verifyWebhookSignature(
    Uint8List payload,
    String signature,
    String secret,
  ) {
    final hmacSha256 = Hmac(sha256, utf8.encode(secret));
    final digest = hmacSha256.convert(payload);
    return digest.toString() == signature;
  }

  Future<void> _syncTransaction(
      String rawText, ParseResult result, String? senderId) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/parse'),
            headers: _headers,
            body: jsonEncode({
              'raw_text': rawText,
              'sender_id': senderId,
              'is_sync': true,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fail silently — sync should not block the user
    }
  }
}

class WebhooksManager {
  final ParsePesa _client;
  final String _path;

  WebhooksManager(this._client, this._path);

  /// List all registered webhooks.
  Future<List<Map<String, dynamic>>> list() async {
    final data = await _client._request('GET', _path);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Register a new webhook.
  Future<Map<String, dynamic>> create(
    String url, {
    String? name,
    bool autoValidate = true,
  }) async {
    return _client._request('POST', _path, body: {
      'url': url,
      'destinationUrl': url,
      'name': name,
      'autoValidate': autoValidate,
    });
  }

  /// Delete a webhook by ID.
  Future<void> delete(String id) async {
    await _client._request('DELETE', '$_path/$id');
  }

  /// Get the last 50 delivery attempts for a specific webhook.
  ///
  /// Each entry contains: status, attemptCount, lastResponseCode,
  /// deliveredAt, nextAttemptAt, lastError.
  ///
  /// Use this to debug failed deliveries or confirm delivery to your endpoint.
  Future<List<Map<String, dynamic>>> deliveries(String webhookId) async {
    final data = await _client._request('GET', '$_path/$webhookId/deliveries');
    return (data as List).cast<Map<String, dynamic>>();
  }
}
