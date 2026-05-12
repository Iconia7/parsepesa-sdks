import 'transaction.dart';

class ParseResult {
  final bool success;
  final double confidence;
  final String parserVersion;
  final Transaction? data;

  ParseResult({
    required this.success,
    this.confidence = 0.0,
    required this.parserVersion,
    this.data,
  });

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    return ParseResult(
      success: json['success'] as bool,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      parserVersion: json['parserVersion'] as String,
      data: json['data'] != null ? Transaction.fromJson(json['data'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'confidence': confidence,
      'parserVersion': parserVersion,
      'data': data?.toJson(),
    };
  }
}
