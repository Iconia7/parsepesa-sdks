import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class BalanceRule implements ParseRule {
  @override
  String get transactionType => 'balance_info';

  @override
  String get version => '1.0.0';

  @override
  double get priority => 1.0;

  static final RegExp _pattern = RegExp(
    r'Airtime\s+Bal:\s*([\d,]+\.?\d*)KSH\.Expire\s+date:(\d{2}-\d{2}-\d{4})(?:,\s+Okoa\s+Bal\s*([\d,]+\.?\d*)\s*KSH)?',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final match = _pattern.firstMatch(rawSms);
    if (match == null) return null;

    final airtimeBal = double.parse(match.group(1)!.replaceAll(',', ''));
    final okoaBalStr = match.group(3);
    final double? okoaBal = okoaBalStr != null ? double.parse(okoaBalStr.replaceAll(',', '')) : null;

    return ParseResult(
      success: true,
      confidence: 1.0,
      parserVersion: version,
      data: Transaction(
        transactionId: 'BAL-${DateTime.now().millisecondsSinceEpoch}',
        type: transactionType,
        amount: 0.0,
        currency: 'KES',
        counterparty: 'Safaricom System',
        balance: airtimeBal,
        timestamp: DateTime.now(),
      ),
    );
  }
}
