import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class OkoaRule implements ParseRule {
  @override
  String get transactionType => 'loan_repayment';

  @override
  String get version => '1.0.0';

  @override
  double get priority => 1.1;

  // Pattern: [Amt] KSH has been deducted to repay your Okoa Jahazi.
  static final RegExp _pattern = RegExp(
    r'([\d,]+\.\d{2})\s*KSH\s+has\s+been\s+deducted\s+to\s+repay\s+your\s+Okoa\s+Jahazi',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final match = _pattern.firstMatch(rawSms);
    if (match == null) return null;

    final amount = double.parse(match.group(1)!.replaceAll(',', ''));

    return ParseResult(
      success: true,
      confidence: 1.0,
      parserVersion: version,
      data: Transaction(
        transactionId: 'OKOA-${DateTime.now().millisecondsSinceEpoch}', // Okoa doesn't always have a ref ID in the text
        type: transactionType,
        amount: amount,
        currency: 'KES',
        counterparty: 'Safaricom Okoa Jahazi',
        timestamp: DateTime.now(),
      ),
    );
  }
}
