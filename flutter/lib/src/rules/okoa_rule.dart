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

  // Pattern 1: Repayment
  static final RegExp _repayPattern = RegExp(
    r'([\d,]+\.\d{2})\s*KSH\s+has\s+been\s+deducted\s+to\s+repay\s+your\s+Okoa\s+Jahazi',
    caseSensitive: false,
  );

  // Pattern 2: Request/Received
  static final RegExp _requestPattern = RegExp(
    r'You\s+have\s+received\s+Sh([\d,]+\.?\d*)\.\s+The\s+fee\s+is\s+Sh([\d,]+\.?\d*)\.\s+Your\s+debt\s+of\s+Sh([\d,]+\.?\d*)\s+should\s+be\s+paid\s+by\s+(\d{4}-\d{2}-\d{2})',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    final m1 = _repayPattern.firstMatch(rawSms);
    if (m1 != null) {
      return _buildResult(
        amount: m1.group(1)!,
        type: 'loan_repayment',
      );
    }

    final m2 = _requestPattern.firstMatch(rawSms);
    if (m2 != null) {
      return _buildResult(
        amount: m2.group(1)!,
        fee: m2.group(2),
        type: 'loan_request',
      );
    }

    return null;
  }

  ParseResult _buildResult({
    required String amount,
    String? fee,
    required String type,
  }) {
    return ParseResult(
      success: true,
      confidence: 1.0,
      parserVersion: version,
      data: Transaction(
        transactionId: 'OKOA-${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        amount: double.parse(amount.replaceAll(',', '')),
        currency: 'KES',
        counterparty: 'Safaricom Okoa Jahazi',
        fee: fee != null ? double.parse(fee.replaceAll(',', '')) : null,
        timestamp: DateTime.now(),
      ),
    );
  }
}
