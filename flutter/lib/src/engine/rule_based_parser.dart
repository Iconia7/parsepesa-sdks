import '../models/parse_result.dart';

abstract class ParseRule {
  String get transactionType;
  String get version;
  double get priority;
  
  /// Tries to parse the raw SMS text.
  /// Returns a [ParseResult] if successful, otherwise null.
  ParseResult? tryParse(String rawSms, String? senderId);
}
