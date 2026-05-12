import 'package:intl/intl.dart';
import '../engine/rule_based_parser.dart';
import '../models/parse_result.dart';
import '../models/transaction.dart';

class CardTransactionRule implements ParseRule {
  @override
  String get transactionType => 'card_transaction';

  @override
  String get version => '1.0.0';

  @override
  double get priority => 1.6; // High priority as these are specific

  // Loop Approved
  static final RegExp _loopApprovedPattern = RegExp(
    r'.+?,\s+Online\s+transaction\s+of\s+KES\.?\s*([\d,]+\.?\d*)\s+has\s+been\s+approved\s+on\s+your\s+card\s+ending\s+(\*\*?\d+)\s+at\s+(.+?)\.(?:\s+Forex\s+Adjustment,\s+KES\.?\s*([\d,]+\.?\d*))?\s+on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
    caseSensitive: false,
  );

  // Loop Declined
  static final RegExp _loopDeclinedPattern = RegExp(
    r'.+?,\s+your\s+Online\s+transaction\s+of\s+KES\s*([\d,]+\.?\d*).*?has\s+been\s+Declined\s+on\s+your\s+card\s+ending\s+(\*\*?\d+)\s+at\s+(.+?)\s+due\s+to\s+.*?on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
    caseSensitive: false,
  );

  // M-Pesa Global Pay
  static final RegExp _globalPayPattern = RegExp(
    r'Dear\s+.+?,\s+a\s+transaction\s+of\s+Ksh\.\s*([\d,]+\.?\d*)\s+\(inclusive\s+of\s+Ksh\.\s*([\d,]+\.?\d*)\s+forex\s+charge\)\s+done\s+at\s+(.+?)\s+has\s+been\s+approved\s+on\s+your\s+card\s+(\*+\d+)',
    caseSensitive: false,
  );

  @override
  ParseResult? tryParse(String rawSms, String? senderId) {
    // Try Loop Approved
    final m1 = _loopApprovedPattern.firstMatch(rawSms);
    if (m1 != null) {
      return _buildResult(
        amount: m1.group(1)!,
        card: m1.group(2)!,
        merchant: m1.group(3)!,
        fee: m1.group(4),
        dateStr: m1.group(5),
        status: 'approved',
      );
    }

    // Try Loop Declined
    final m2 = _loopDeclinedPattern.firstMatch(rawSms);
    if (m2 != null) {
      return _buildResult(
        amount: m2.group(1)!,
        card: m2.group(2)!,
        merchant: m2.group(3)!,
        dateStr: m2.group(4),
        status: 'declined',
      );
    }

    // Try Global Pay
    final m3 = _globalPayPattern.firstMatch(rawSms);
    if (m3 != null) {
      return _buildResult(
        amount: m3.group(1)!,
        fee: m3.group(2),
        merchant: m3.group(3)!,
        card: m3.group(4)!,
        status: 'approved',
      );
    }

    return null;
  }

  ParseResult _buildResult({
    required String amount,
    required String card,
    required String merchant,
    String? fee,
    String? dateStr,
    required String status,
  }) {
    DateTime timestamp;
    if (dateStr != null) {
      try {
        timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').parse(dateStr);
      } catch (_) {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    return ParseResult(
      success: true,
      confidence: 1.0,
      parserVersion: version,
      data: Transaction(
        transactionId: 'CARD-${timestamp.millisecondsSinceEpoch}',
        type: transactionType,
        amount: double.parse(amount.replaceAll(',', '')),
        currency: 'KES',
        counterparty: merchant.trim(),
        accountNumber: card,
        status: status,
        fee: fee != null ? double.parse(fee.replaceAll(',', '')) : null,
        timestamp: timestamp,
      ),
    );
  }
}
