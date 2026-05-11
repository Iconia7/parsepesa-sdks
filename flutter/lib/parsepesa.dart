import 'dart:convert';
import 'package:http/http.dart' as http;

class ParsePesa {
  final String apiKey;
  final String baseUrl;
  late final WebhooksManager darajaProxy;
  late final WebhooksManager parsingWebhooks;

  ParsePesa(this.apiKey, {this.baseUrl = 'https://api.parsepesa.nexoracreatives.co.ke/v1'}) {
    darajaProxy = WebhooksManager(this, '/user/daraja-proxy');
    parsingWebhooks = WebhooksManager(this, '/user/webhooks');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> parse(String rawText) async {
    final response = await http.post(
      Uri.parse('$baseUrl/parse'),
      headers: _headers,
      body: jsonEncode({'raw_text': rawText}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> batchParse(List<String> rawTexts) async {
    final response = await http.post(
      Uri.parse('$baseUrl/batch-parse'),
      headers: _headers,
      body: jsonEncode({'messages': rawTexts}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getBalance() async {
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
    final response = await http.get(Uri.parse(_endpoint), headers: _client._headers);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> create(String url, {String? name, bool autoValidate = true}) async {
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
    final response = await http.delete(Uri.parse('$_endpoint/$id'), headers: _client._headers);
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
